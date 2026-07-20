import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart' as tags;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';

/// Handles scanning, custom file references, and playlists for the application library.
class MusicScanner {
  MusicScanner._();
  static final _instance = MusicScanner._();
  factory MusicScanner() => _instance;

  final _prefs = SharedPreferencesAsync();

  /// Cached local artist images path mapping
  Map<String, String> localArtistImages = {};

  /// Queries the cached list of songs from storage instantly.
  Future<List<Song>> scanAllSongs() async {
    var songs = <Song>[];

    try {
      // Read existing metadata cache directly for instant UI loading
      songs = await _readImportedSongsMetadata();

      var appDir = await getApplicationDocumentsDirectory();
      var imagesFile = File('${appDir.path}/artist_images.json');
      if (imagesFile.existsSync()) {
        var map =
            jsonDecode(await imagesFile.readAsString()) as Map<String, dynamic>;
        localArtistImages = map.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {
      // Return whatever is left on error
    }

    // Load saved song tab-specific sort settings and pre-sort songs so they load instantly in correct order
    var sortSettings = await getTabSortSettings('songs');
    sortSongs(
      songs,
      sortSettings['sortBy'] as String,
      sortSettings['sortAscending'] as bool,
    );

    return songs;
  }

  /// Performs an asynchronous background scan of the sync folder, updating the metadata index.
  /// Runs inside a background isolate and checks file size/modification times to skip unchanged files.
  Future<List<Song>> syncLibrary({int maxWorkers = 4}) async {
    var sw = Stopwatch()..start();
    try {
      var folderPath = await getScanFolder();
      var appDir = await getApplicationDocumentsDirectory();
      var appDocsDirPath = appDir.path;

      var cachedSongs = await _readImportedSongsMetadata();

      if (folderPath == null) {
        // No sync folder configured. Filter existing cached references by physical existence.
        var verified = cachedSongs
            .where((s) => File(s.filePath).existsSync())
            .toList();
        await _writeImportedSongsMetadata(verified);
        return verified;
      }

      var dir = Directory(folderPath);
      if (!dir.existsSync()) {
        // Synced folder no longer exists.
        await _writeImportedSongsMetadata([]);
        return [];
      }

      // Offload all directory scanning, metadata comparison, and parsing to background isolate
      var isolateData = await Isolate.run<Map<String, dynamic>>(() {
        var localCachedSongs = List<Song>.from(cachedSongs);

        // Supports wide variety of standard audio formats
        var audioExtensions = {
          'mp3',
          'm4a',
          'mp4',
          'aac',
          'flac',
          'ogg',
          'opus',
          'wav',
          'wma',
          'amr',
          '3gp',
          'ts',
          'mkv',
          'mid',
          'midi',
        };
        var foundFiles = <File>[];
        var localArtistImageDirs = <String, String>{}; // dirPath -> imagePath
        var localCoverImageDirs = <String, String>{}; // dirPath -> imagePath

        try {
          var syncDir = Directory(folderPath);
          for (var entity in syncDir.listSync(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              var name = entity.uri.pathSegments.last.toLowerCase();
              if (name == 'artist.jpg' ||
                  name == 'artist.png' ||
                  name == 'artist.webp') {
                localArtistImageDirs[entity.parent.path] = entity.path;
              } else if (name == 'cover.jpg' ||
                  name == 'cover.png' ||
                  name == 'cover.webp') {
                localCoverImageDirs[entity.parent.path] = entity.path;
              } else {
                var ext = name.split('.').last;
                if (audioExtensions.contains(ext)) {
                  foundFiles.add(entity);
                }
              }
            }
          }
        } catch (_) {}

        var foundPaths = foundFiles.map((f) => f.path).toSet();
        var verifiedSongs = localCachedSongs
            .where((s) => foundPaths.contains(s.filePath))
            .toList();

        // Create quick lookup maps of existing cache
        var cacheMap = {for (var s in verifiedSongs) s.filePath: s};
        var existingIds = {for (var s in verifiedSongs) s.filePath: s.id};
        var existingFavoriteStatus = {
          for (var s in verifiedSongs) s.filePath: s.isFavorite,
        };

        var songsToKeep = <Song>[];
        var filesToScan = <File>[];

        // Check each file's size and mtime to decide if we need to re-parse it
        for (var file in foundFiles) {
          var cached = cacheMap[file.path];
          if (cached != null) {
            try {
              var stat = file.statSync();
              var mtime = stat.modified.millisecondsSinceEpoch;
              var size = stat.size;

              var lastDotLrc = file.path.lastIndexOf('.');
              var hasLrc =
                  lastDotLrc != -1 &&
                  (File(
                        '${file.path.substring(0, lastDotLrc)}.lrc',
                      ).existsSync() ||
                      File(
                        '${file.path.substring(0, lastDotLrc)}.txt',
                      ).existsSync());

              if (cached.lastModifiedMs == mtime &&
                  cached.fileSize == size &&
                  cached.artist != 'Local Audio' &&
                  cached.album != 'Synced Folder') {
                if (cached.hasLyrics != hasLrc) {
                  songsToKeep.add(
                    Song(
                      id: cached.id,
                      title: cached.title,
                      artist: cached.artist,
                      album: cached.album,
                      duration: cached.duration,
                      filePath: cached.filePath,
                      artworkPath: cached.artworkPath,
                      format: cached.format,
                      bitrate: cached.bitrate,
                      samplerate: cached.samplerate,
                      isFavorite: cached.isFavorite,
                      lastModifiedMs: cached.lastModifiedMs,
                      fileSize: cached.fileSize,
                      hasLyrics: hasLrc,
                    ),
                  );
                } else {
                  songsToKeep.add(cached);
                }
                continue;
              }
            } catch (_) {}
          }
          // File is either brand new or modified/replaced on disk
          filesToScan.add(file);
        }

        if (filesToScan.isNotEmpty) {
          var idCounter = verifiedSongs.isEmpty
              ? 1
              : verifiedSongs.map((s) => s.id).reduce((a, b) => a > b ? a : b) +
                    1;

          // Pre-allocate IDs and favorite status to avoid ID assignment race conditions
          var scanTasks = <(String, int, bool)>[];
          for (var file in filesToScan) {
            var songId = existingIds[file.path] ?? idCounter++;
            var isFav = existingFavoriteStatus[file.path] ?? false;
            scanTasks.add((file.path, songId, isFav));
          }

          for (var task in scanTasks) {
            var filePath = task.$1;
            var songId = task.$2;
            var isFav = task.$3;

            try {
              var file = File(filePath);
              tags.AudioMetadata? meta;
              try {
                meta = tags.readMetadata(file.path, true);
              } catch (_) {}

              String? title;
              String? artist;
              String? album;
              String? artworkPath;
              String? format;
              int? bitrate;
              int? samplerate;
              var duration = Duration.zero;

              var stat = file.statSync();
              var mtime = stat.modified.millisecondsSinceEpoch;
              var size = stat.size;

              if (meta != null) {
                title = meta.title?.trim();
                artist = meta.artist?.trim() ?? meta.albumArtist?.trim();
                album = meta.album?.trim();
                format = meta.format?.trim();
                bitrate = meta.bitrate;
                samplerate = meta.samplerate;
                if (meta.duration != null) {
                  duration = meta.duration!;
                }

                if (meta.pictureBytes != null &&
                    meta.pictureBytes!.isNotEmpty) {
                  var artFile = File(
                    '$appDocsDirPath/artwork_${DateTime.now().millisecondsSinceEpoch}_$songId.jpg',
                  );
                  artFile.writeAsBytesSync(meta.pictureBytes!);
                  artworkPath = artFile.path;
                }
              }

              if (artworkPath == null) {
                var dir = file.parent.path;
                if (localCoverImageDirs.containsKey(dir)) {
                  artworkPath = localCoverImageDirs[dir];
                } else {
                  var parentDir = file.parent.parent.path;
                  if (localCoverImageDirs.containsKey(parentDir)) {
                    artworkPath = localCoverImageDirs[parentDir];
                  }
                }
              }

              var fileName = file.path.split(Platform.pathSeparator).last;
              var extIndex = fileName.lastIndexOf('.');
              var defaultTitle = extIndex != -1
                  ? fileName.substring(0, extIndex)
                  : fileName;

              var lastDot = file.path.lastIndexOf('.');
              var hasLrc = false;
              if (lastDot != -1) {
                var basePath = file.path.substring(0, lastDot);
                hasLrc =
                    File('$basePath.lrc').existsSync() ||
                    File('$basePath.txt').existsSync();
              }

              songsToKeep.add(
                Song(
                  id: songId,
                  title: (title == null || title.isEmpty)
                      ? defaultTitle
                      : title,
                  artist: (artist == null || artist.isEmpty)
                      ? 'Unknown Artist'
                      : artist,
                  album: (album == null || album.isEmpty)
                      ? 'Unknown Album'
                      : album,
                  duration: duration,
                  filePath: file.path,
                  artworkPath: artworkPath,
                  format: format,
                  bitrate: bitrate,
                  samplerate: samplerate,
                  isFavorite: isFav,
                  lastModifiedMs: mtime,
                  fileSize: size,
                  hasLyrics: hasLrc,
                ),
              );
            } catch (_) {}
          }
        }
        var finalArtistImages = <String, String>{};
        for (var song in songsToKeep) {
          var dir = File(song.filePath).parent.path;
          var parentDir = File(song.filePath).parent.parent.path;

          if (localArtistImageDirs.containsKey(dir)) {
            finalArtistImages[song.artist.toLowerCase()] =
                localArtistImageDirs[dir]!;
          } else if (localArtistImageDirs.containsKey(parentDir)) {
            finalArtistImages[song.artist.toLowerCase()] =
                localArtistImageDirs[parentDir]!;
          }
        }

        return {'songs': songsToKeep, 'artistImages': finalArtistImages};
      });

      var resultSongs = isolateData['songs'] as List<Song>;
      var finalArtistImages =
          isolateData['artistImages'] as Map<String, String>;

      // Save local artist images to cache
      var imagesFile = File('$appDocsDirPath/artist_images.json');
      await imagesFile.writeAsString(jsonEncode(finalArtistImages));
      localArtistImages = finalArtistImages;
      // Sort resultSongs by user's saved song tab settings before writing to file
      var sortSettings = await getTabSortSettings('songs');
      sortSongs(
        resultSongs,
        sortSettings['sortBy'] as String,
        sortSettings['sortAscending'] as bool,
      );

      // Save updated index to JSON
      await _writeImportedSongsMetadata(resultSongs);

      // Save formatted last sync time
      var now = DateTime.now();
      var hour = now.hour > 12
          ? now.hour - 12
          : (now.hour == 0 ? 12 : now.hour);
      var ampm = now.hour >= 12 ? 'PM' : 'AM';
      var minute = now.minute.toString().padLeft(2, '0');
      var second = now.second.toString().padLeft(2, '0');
      var monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      var month = monthNames[now.month - 1];
      var formatted =
          '$month ${now.day}, ${now.year} at $hour:$minute:$second $ampm';
      await setLastSyncTime(formatted);
      await setLastSyncTimestamp(now.millisecondsSinceEpoch);
      try {
        await _prefs.remove('postpone_sync_until');
      } catch (_) {}

      sw.stop();
      var durationMs = sw.elapsedMilliseconds;
      await setLastSyncDuration('sequential', durationMs);
      await setLastSyncMethodUsed('sequential');

      return resultSongs;
    } catch (e, stack) {
      // ignore: avoid_print
      print('SYNC ERROR: $e\n$stack');
      return [];
    }
  }

  /// Legacy sequential syncLibrary method for benchmark comparisons.
  Future<List<Song>> legacySyncLibrary() async {
    try {
      var folderPath = await getScanFolder();
      var appDir = await getApplicationDocumentsDirectory();
      var appDocsDirPath = appDir.path;

      var cachedSongs = await _readImportedSongsMetadata();

      if (folderPath == null) {
        var verified = cachedSongs
            .where((s) => File(s.filePath).existsSync())
            .toList();
        await _writeImportedSongsMetadata(verified);
        return verified;
      }

      var dir = Directory(folderPath);
      if (!dir.existsSync()) {
        await _writeImportedSongsMetadata([]);
        return [];
      }

      var resultSongs = await Isolate.run<List<Song>>(() {
        var localCachedSongs = List<Song>.from(cachedSongs);

        var audioExtensions = {
          'mp3',
          'm4a',
          'mp4',
          'aac',
          'flac',
          'ogg',
          'opus',
          'wav',
          'wma',
          'amr',
          '3gp',
          'ts',
          'mkv',
          'mid',
          'midi',
        };
        var foundFiles = <File>[];

        try {
          var syncDir = Directory(folderPath);
          for (var entity in syncDir.listSync(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              var ext = entity.path.split('.').last.toLowerCase();
              if (audioExtensions.contains(ext)) {
                foundFiles.add(entity);
              }
            }
          }
        } catch (_) {}

        var foundPaths = foundFiles.map((f) => f.path).toSet();
        var verifiedSongs = localCachedSongs
            .where((s) => foundPaths.contains(s.filePath))
            .toList();

        var existingIds = {for (var s in verifiedSongs) s.filePath: s.id};
        var existingFavoriteStatus = {
          for (var s in verifiedSongs) s.filePath: s.isFavorite,
        };
        var cachedMap = {for (var s in verifiedSongs) s.filePath: s};

        var songsToKeep = <Song>[];
        var filesToScan = <File>[];

        for (var file in foundFiles) {
          var cached = cachedMap[file.path];
          if (cached != null) {
            try {
              var stat = file.statSync();
              var mtime = stat.modified.millisecondsSinceEpoch;
              var size = stat.size;

              if (cached.lastModifiedMs == mtime && cached.fileSize == size) {
                var hasLrc = false;
                var extIndex = file.path.lastIndexOf('.');
                if (extIndex != -1) {
                  var basePath = file.path.substring(0, extIndex);
                  hasLrc =
                      File('$basePath.lrc').existsSync() ||
                      File('$basePath.txt').existsSync();
                }

                if (cached.hasLyrics != hasLrc) {
                  songsToKeep.add(
                    Song(
                      id: cached.id,
                      title: cached.title,
                      artist: cached.artist,
                      album: cached.album,
                      duration: cached.duration,
                      filePath: cached.filePath,
                      artworkPath: cached.artworkPath,
                      format: cached.format,
                      bitrate: cached.bitrate,
                      samplerate: cached.samplerate,
                      isFavorite: cached.isFavorite,
                      lastModifiedMs: cached.lastModifiedMs,
                      fileSize: cached.fileSize,
                      hasLyrics: hasLrc,
                    ),
                  );
                } else {
                  songsToKeep.add(cached);
                }
                continue;
              }
            } catch (_) {}
          }
          filesToScan.add(file);
        }

        if (filesToScan.isNotEmpty) {
          var idCounter = verifiedSongs.isEmpty
              ? 1
              : verifiedSongs.map((s) => s.id).reduce((a, b) => a > b ? a : b) +
                    1;

          for (var file in filesToScan) {
            try {
              tags.AudioMetadata? meta;
              try {
                meta = tags.readMetadata(file.path, true);
              } catch (_) {}

              String? title;
              String? artist;
              String? album;
              String? artworkPath;
              String? format;
              int? bitrate;
              int? samplerate;
              var duration = Duration.zero;

              var stat = file.statSync();
              var mtime = stat.modified.millisecondsSinceEpoch;
              var size = stat.size;

              if (meta != null) {
                title = meta.title?.trim();
                artist = meta.artist?.trim() ?? meta.albumArtist?.trim();
                album = meta.album?.trim();
                format = meta.format?.trim();
                bitrate = meta.bitrate;
                samplerate = meta.samplerate;
                if (meta.duration != null) {
                  duration = meta.duration!;
                }

                if (meta.pictureBytes != null &&
                    meta.pictureBytes!.isNotEmpty) {
                  var artFile = File(
                    '$appDocsDirPath/artwork_${DateTime.now().millisecondsSinceEpoch}_$idCounter.jpg',
                  );
                  artFile.writeAsBytesSync(meta.pictureBytes!);
                  artworkPath = artFile.path;
                }
              }

              var fileName = file.path.split(Platform.pathSeparator).last;
              var extIndex = fileName.lastIndexOf('.');
              var defaultTitle = extIndex != -1
                  ? fileName.substring(0, extIndex)
                  : fileName;

              var songId = existingIds[file.path] ?? idCounter++;
              var isFav = existingFavoriteStatus[file.path] ?? false;

              var hasLrc = false;
              if (extIndex != -1) {
                var basePath = file.path.substring(0, extIndex);
                hasLrc =
                    File('$basePath.lrc').existsSync() ||
                    File('$basePath.txt').existsSync();
              }

              songsToKeep.add(
                Song(
                  id: songId,
                  title: (title == null || title.isEmpty)
                      ? defaultTitle
                      : title,
                  artist: (artist == null || artist.isEmpty)
                      ? 'Unknown Artist'
                      : artist,
                  album: (album == null || album.isEmpty)
                      ? 'Unknown Album'
                      : album,
                  duration: duration,
                  filePath: file.path,
                  artworkPath: artworkPath,
                  format: format,
                  bitrate: bitrate,
                  samplerate: samplerate,
                  isFavorite: isFav,
                  lastModifiedMs: mtime,
                  fileSize: size,
                  hasLyrics: hasLrc,
                  trackNumber: meta?.track,
                  discNumber: meta?.disc,
                ),
              );
            } catch (_) {}
          }
        }

        return songsToKeep;
      });

      var sortSettings = await getSortSettings();
      sortSongs(
        resultSongs,
        sortSettings['sortBy'] as String,
        sortSettings['sortAscending'] as bool,
      );

      await _writeImportedSongsMetadata(resultSongs);

      var now = DateTime.now();
      var hour = now.hour > 12
          ? now.hour - 12
          : (now.hour == 0 ? 12 : now.hour);
      var ampm = now.hour >= 12 ? 'PM' : 'AM';
      var minute = now.minute.toString().padLeft(2, '0');
      var second = now.second.toString().padLeft(2, '0');
      var monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      var month = monthNames[now.month - 1];
      var formatted =
          '$month ${now.day}, ${now.year} at $hour:$minute:$second $ampm';
      await setLastSyncTime(formatted);
      await setLastSyncTimestamp(now.millisecondsSinceEpoch);
      try {
        await _prefs.remove('postpone_sync_until');
      } catch (_) {}

      return resultSongs;
    } catch (_) {
      return [];
    }
  }

  /// Recursively scans the selected folder path and updates references. Files are NOT copied.
  Future<List<Song>> importFromFolder(String folderPath) async {
    try {
      await setScanFolder(folderPath);
      return await syncLibrary();
    } catch (_) {
      return [];
    }
  }

  /// Removes a song reference from the library list (does NOT delete user's physical file).
  Future<bool> deleteSong(Song song) async {
    try {
      var savedSongs = await _readImportedSongsMetadata();

      // Remove from metadata list
      savedSongs.removeWhere((s) => s.filePath == song.filePath);
      await _writeImportedSongsMetadata(savedSongs);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reads the configured scan folder path from shared preferences.
  Future<String?> getScanFolder() async {
    try {
      return await _prefs.getString('scan_folder_path');
    } catch (_) {
      return null;
    }
  }

  /// Writes the configured scan folder path to shared preferences.
  Future<void> setScanFolder(String? path) async {
    try {
      if (path == null) {
        await _prefs.remove('scan_folder_path');
      } else {
        await _prefs.setString('scan_folder_path', path);
      }
    } catch (_) {}
  }

  /// Reads the last sync time from shared preferences.
  Future<String?> getLastSyncTime() async {
    try {
      return await _prefs.getString('last_sync_time');
    } catch (_) {
      return null;
    }
  }

  /// Writes the last sync time to shared preferences.
  Future<void> setLastSyncTime(String? timestamp) async {
    try {
      if (timestamp == null) {
        await _prefs.remove('last_sync_time');
      } else {
        await _prefs.setString('last_sync_time', timestamp);
      }
    } catch (_) {}
  }

  /// Reads the last sync epoch milliseconds timestamp.
  Future<int?> getLastSyncTimestamp() async {
    try {
      return await _prefs.getInt('last_sync_timestamp');
    } catch (_) {
      return null;
    }
  }

  /// Writes the last sync epoch milliseconds timestamp.
  Future<void> setLastSyncTimestamp(int? timestamp) async {
    try {
      if (timestamp == null) {
        await _prefs.remove('last_sync_timestamp');
      } else {
        await _prefs.setInt('last_sync_timestamp', timestamp);
      }
    } catch (_) {}
  }

  /// Reads the sorting configuration from shared preferences.
  Future<Map<String, dynamic>> getSortSettings() async {
    try {
      var sortBy = await _prefs.getString('sort_by') ?? 'title';
      var sortAscending = await _prefs.getBool('sort_ascending') ?? true;
      return {'sortBy': sortBy, 'sortAscending': sortAscending};
    } catch (_) {
      return {'sortBy': 'title', 'sortAscending': true};
    }
  }

  /// Writes the sorting configuration to shared preferences.
  Future<void> saveSortSettings(String sortBy, bool sortAscending) async {
    try {
      await _prefs.setString('sort_by', sortBy);
      await _prefs.setBool('sort_ascending', sortAscending);
    } catch (_) {}
  }

  /// Reads per-tab sorting configuration from shared preferences.
  Future<Map<String, dynamic>> getTabSortSettings(String tab) async {
    try {
      var defaultBy = tab == 'songs'
          ? 'title'
          : tab == 'albums'
          ? 'name'
          : 'name';
      var sortBy = await _prefs.getString('sort_by_$tab') ?? defaultBy;
      var sortAscending = await _prefs.getBool('sort_ascending_$tab') ?? true;
      return {'sortBy': sortBy, 'sortAscending': sortAscending};
    } catch (_) {
      return {'sortBy': 'title', 'sortAscending': true};
    }
  }

  /// Writes per-tab sorting configuration to shared preferences.
  Future<void> saveTabSortSettings(
    String tab,
    String sortBy,
    bool sortAscending,
  ) async {
    try {
      await _prefs.setString('sort_by_$tab', sortBy);
      await _prefs.setBool('sort_ascending_$tab', sortAscending);
    } catch (_) {}
  }

  // --- Playlists API ---

  /// Reads the playlists list from playlists.json.
  Future<List<Playlist>> getPlaylists() async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var file = File('${appDir.path}/playlists.json');
      var list = <Playlist>[];
      if (file.existsSync()) {
        var content = await file.readAsString();
        var jsonList = jsonDecode(content) as List<dynamic>;
        list = jsonList
            .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      var hasFavorites = list.any((p) => p.id == 'favorites');
      if (!hasFavorites) {
        var favoritesPlaylist = Playlist(
          id: 'favorites',
          name: 'Favorites',
          songIds: [],
        );
        list.insert(0, favoritesPlaylist);
        await savePlaylists(list);
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Writes the playlists list to playlists.json.
  Future<void> savePlaylists(List<Playlist> playlists) async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var file = File('${appDir.path}/playlists.json');
      var jsonList = playlists.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Toggles a song's favorite status in the cache index and updates the default Favorites playlist.
  Future<List<Song>> toggleFavoriteSong(int songId) async {
    try {
      var songs = await _readImportedSongsMetadata();
      var playlists = await getPlaylists();

      var songIndex = songs.indexWhere((s) => s.id == songId);
      if (songIndex >= 0) {
        var song = songs[songIndex];
        var newFavoriteStatus = !song.isFavorite;

        songs[songIndex] = song.copyWith(isFavorite: newFavoriteStatus);

        await _writeImportedSongsMetadata(songs);

        // Update favorites playlist
        var favoritesIndex = playlists.indexWhere((p) => p.id == 'favorites');
        if (favoritesIndex >= 0) {
          var favPlaylist = playlists[favoritesIndex];
          if (newFavoriteStatus) {
            if (!favPlaylist.songIds.contains(songId)) {
              favPlaylist.songIds.add(songId);
            }
          } else {
            favPlaylist.songIds.remove(songId);
          }
          await savePlaylists(playlists);
        }
      }

      return songs;
    } catch (_) {
      return [];
    }
  }

  /// Creates a new empty playlist.
  Future<void> createPlaylist(String name) async {
    var playlists = await getPlaylists();
    var newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      songIds: [],
    );
    playlists.add(newPlaylist);
    await savePlaylists(playlists);
  }

  /// Deletes a playlist.
  Future<void> deletePlaylist(String id) async {
    var playlists = await getPlaylists();
    playlists.removeWhere((p) => p.id == id);
    await savePlaylists(playlists);
  }

  /// Adds a song to a playlist if not already present.
  Future<void> addSongToPlaylist(String playlistId, int songId) async {
    var playlists = await getPlaylists();
    for (var i = 0; i < playlists.length; i++) {
      if (playlists[i].id == playlistId) {
        if (!playlists[i].songIds.contains(songId)) {
          playlists[i].songIds.add(songId);
          await savePlaylists(playlists);
        }
        break;
      }
    }
  }

  /// Removes a song from a playlist.
  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    var playlists = await getPlaylists();
    for (var i = 0; i < playlists.length; i++) {
      if (playlists[i].id == playlistId) {
        playlists[i].songIds.remove(songId);
        await savePlaylists(playlists);
        break;
      }
    }
  }

  /// Helper to sort list of songs by specified sort configurations.
  void sortSongs(List<Song> songs, String sortBy, bool sortAscending) {
    songs.sort((a, b) {
      int comparison;
      if (sortBy == 'artist') {
        comparison = a.artistLower.compareTo(b.artistLower);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (sortBy == 'duration') {
        comparison = a.duration.compareTo(b.duration);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (sortBy == 'recent') {
        var aTime = a.lastModifiedMs ?? 0;
        var bTime = b.lastModifiedMs ?? 0;
        comparison = bTime.compareTo(aTime);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else {
        comparison = a.titleLower.compareTo(b.titleLower);
      }

      if (comparison == 0) {
        comparison = a.id.compareTo(b.id);
      }
      return sortAscending ? comparison : -comparison;
    });
  }

  // --- Private Helpers ---

  Future<List<Song>> _readImportedSongsMetadata() async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var jsonFile = File('${appDir.path}/imported_songs.json');
      if (!jsonFile.existsSync()) return [];

      var content = await jsonFile.readAsString();
      var jsonList = jsonDecode(content) as List<dynamic>;

      return jsonList.map((item) {
        return Song(
          id: item['id'] as int,
          title: item['title'] as String,
          artist: item['artist'] as String,
          album: item['album'] as String,
          duration: Duration(milliseconds: item['duration_ms'] as int),
          filePath: item['file_path'] as String,
          artworkPath: item['artwork_path'] as String?,
          format: item['format'] as String?,
          bitrate: item['bitrate'] as int?,
          samplerate: item['samplerate'] as int?,
          isFavorite: item['is_favorite'] as bool? ?? false,
          lastModifiedMs: item['last_modified_ms'] as int?,
          fileSize: item['file_size'] as int?,
          hasLyrics: item['has_lyrics'] as bool? ?? false,
          dominantColor: item['dominant_color'] as int?,
          trackNumber: item['track_number'] as int?,
          discNumber: item['disc_number'] as int?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeImportedSongsMetadata(List<Song> songs) async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var jsonFile = File('${appDir.path}/imported_songs.json');

      var jsonList = songs
          .map(
            (s) => {
              'id': s.id,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'duration_ms': s.duration.inMilliseconds,
              'file_path': s.filePath,
              'artwork_path': s.artworkPath,
              'format': s.format,
              'bitrate': s.bitrate,
              'samplerate': s.samplerate,
              'is_favorite': s.isFavorite,
              'last_modified_ms': s.lastModifiedMs,
              'file_size': s.fileSize,
              'has_lyrics': s.hasLyrics,
              'dominant_color': s.dominantColor,
              'track_number': s.trackNumber,
              'disc_number': s.discNumber,
            },
          )
          .toList();

      await jsonFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Persists a dominant color value for a song so it survives app restarts.
  Future<void> saveDominantColor(int songId, int color) async {
    try {
      var songs = await _readImportedSongsMetadata();
      var idx = songs.indexWhere((s) => s.id == songId);
      if (idx >= 0) {
        songs[idx] = songs[idx].copyWith(dominantColor: color);
        await _writeImportedSongsMetadata(songs);
      }
    } catch (_) {}
  }

  /// Persists the entire songs list metadata back to disk in one bulk write.
  Future<void> saveAllSongsMetadata(List<Song> songs) async {
    try {
      await _writeImportedSongsMetadata(songs);
    } catch (_) {}
  }

  /// Helper placeholder to avoid breaking any references
  Future<Uint8List?> getArtwork(int songId) async {
    return null;
  }

  Future<String> getSyncMethod() async {
    return await _prefs.getString('sync_method') ?? 'parallel';
  }

  Future<void> setSyncMethod(String method) async {
    await _prefs.setString('sync_method', method);
  }

  Future<int?> getLastSyncDuration(String method) async {
    return await _prefs.getInt('last_sync_duration_$method');
  }

  Future<void> setLastSyncDuration(String method, int durationMs) async {
    await _prefs.setInt('last_sync_duration_$method', durationMs);
  }

  Future<String?> getLastSyncMethodUsed() async {
    return await _prefs.getString('last_sync_method_used');
  }

  Future<void> setLastSyncMethodUsed(String method) async {
    await _prefs.setString('last_sync_method_used', method);
  }
}
