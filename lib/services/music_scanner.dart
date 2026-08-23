import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_tags_lofty/audio_tags_lofty.dart' as tags;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';

/// Handles scanning, custom file references, and playlists for the application library.
class MusicScanner {
  MusicScanner._();
  static final _instance = MusicScanner._();
  factory MusicScanner() => _instance;

  final _prefs = SharedPreferencesAsync();

  static const _mediastoreChannel = MethodChannel(
    'de.yurtemre.sonora/mediastore',
  );

  /// Opens the native system file manager / parent folder for the given file path.
  static Future<bool> openFileFolder(String filePath) async {
    if (!Platform.isAndroid) return false;
    try {
      var result = await _mediastoreChannel.invokeMethod<bool>(
        'openFileFolder',
        {'filePath': filePath},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cached local artist images path mapping
  Map<String, String> localArtistImages = {};

  /// Loads cached local artist images mapping.
  Future<Map<String, String>> loadLocalArtistImages() async {
    try {
      var prefStr = await _prefs.getString('artist_images_json');
      if (prefStr != null && prefStr.isNotEmpty) {
        var map = jsonDecode(prefStr) as Map<String, dynamic>;
        localArtistImages = map.map((k, v) => MapEntry(k, v.toString()));
      } else {
        var appDir = await getApplicationDocumentsDirectory();
        var imagesFile = File('${appDir.path}/artist_images.json');
        if (imagesFile.existsSync()) {
          var map = jsonDecode(
            await imagesFile.readAsString(),
          ) as Map<String, dynamic>;
          localArtistImages = map.map((k, v) => MapEntry(k, v.toString()));
          await _prefs.setString(
            'artist_images_json',
            jsonEncode(localArtistImages),
          );
        }
      }
    } catch (_) {}
    return localArtistImages;
  }

  /// Detects and caches local artist cover images (artist.jpg, artist.png, etc.) from the sync folder.
  Future<Map<String, String>> detectLocalArtistImages(
    String folderPath,
    List<Song> songs,
  ) async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var appDocsDirPath = appDir.path;

      var artistImages = await Isolate.run<Map<String, String>>(() {
        var dir = Directory(folderPath);
        if (!dir.existsSync()) return {};

        var localImageFiles = <String, List<String>>{};
        try {
          for (var entity in dir.listSync(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              var pathLower = entity.path.toLowerCase();
              if (pathLower.endsWith('.jpg') ||
                  pathLower.endsWith('.jpeg') ||
                  pathLower.endsWith('.png') ||
                  pathLower.endsWith('.webp')) {
                var parentPath = entity.parent.path;
                localImageFiles
                    .putIfAbsent(parentPath, () => [])
                    .add(entity.path);
                var normParent = parentPath.replaceAll('\\', '/');
                localImageFiles
                    .putIfAbsent(normParent, () => [])
                    .add(entity.path);
              }
            }
          }
        } catch (_) {}

        var finalArtistImages = <String, String>{};
        var normFolderPath = folderPath.replaceAll('\\', '/');

        String? findArtistImage(String targetArtistLower, Directory startDir) {
          Directory? current = startDir;
          while (current != null) {
            var normCurrentPath = current.path.replaceAll('\\', '/');
            var images =
                localImageFiles[current.path] ??
                localImageFiles[normCurrentPath];
            if (images != null && images.isNotEmpty) {
              for (var img in images) {
                var name = img.split(RegExp(r'[/\\]')).last.toLowerCase();
                if (name == 'artist.jpg' ||
                    name == 'artist.png' ||
                    name == 'artist.webp' ||
                    name == 'artist.jpeg') {
                  return img;
                }
                if (name == '$targetArtistLower.jpg' ||
                    name == '$targetArtistLower.png' ||
                    name == '$targetArtistLower.webp' ||
                    name == '$targetArtistLower.jpeg') {
                  return img;
                }
              }
              var dirName = normCurrentPath
                  .split('/')
                  .last
                  .toLowerCase()
                  .trim();
              if (dirName == targetArtistLower) {
                return images.first;
              }
            }
            if (normCurrentPath == normFolderPath) break;
            var parent = current.parent;
            if (parent.path == current.path) break;
            current = parent;
          }
          return null;
        }

        for (var song in songs) {
          var artists = parseIndividualArtists(song.artist);
          for (var artistName in artists) {
            var lowerArtist = artistName.trim().toLowerCase();
            if (lowerArtist.isEmpty || lowerArtist == 'unknown artist') {
              continue;
            }
            if (finalArtistImages.containsKey(lowerArtist)) continue;

            var songFile = File(song.filePath);
            var match = findArtistImage(lowerArtist, songFile.parent);
            if (match != null) {
              finalArtistImages[lowerArtist] = match;
            }
          }

          var rawLower = song.artist.trim().toLowerCase();
          if (rawLower.isNotEmpty &&
              rawLower != 'unknown artist' &&
              !finalArtistImages.containsKey(rawLower)) {
            var match = findArtistImage(rawLower, File(song.filePath).parent);
            if (match != null) {
              finalArtistImages[rawLower] = match;
            }
          }
        }

        return finalArtistImages;
      });

      localArtistImages = artistImages;
      var jsonStr = jsonEncode(artistImages);
      await _prefs.setString('artist_images_json', jsonStr);
      try {
        var imagesFile = File('$appDocsDirPath/artist_images.json');
        await imagesFile.writeAsString(jsonStr);
      } catch (_) {}
      return artistImages;
    } catch (_) {
      return localArtistImages;
    }
  }

  /// Queries the cached list of songs from storage instantly.
  Future<List<Song>> scanAllSongs() async {
    var songs = <Song>[];

    try {
      // Read existing metadata cache directly for instant UI loading
      songs = await _readImportedSongsMetadata();
      await loadLocalArtistImages();
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

  /// Fast native MediaStore scanner on Android with instant incremental caching.
  Future<Map<String, dynamic>?> _scanViaMediaStore(
    String folderPath,
    List<Song> cachedSongs, {
    bool isFast = false,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      var swChannel = Stopwatch()..start();
      var response = await _mediastoreChannel.invokeMethod<dynamic>(
        'scanMediaStore',
        {'folderPath': folderPath, 'isFast': isFast},
      );
      swChannel.stop();
      var channelMs = swChannel.elapsedMilliseconds;

      if (response == null) return null;

      var swParse = Stopwatch()..start();
      List<dynamic> rawList = [];
      int? kQueryMs;
      int? kLoopMs;
      int? kTotalMs;

      if (response is Map) {
        var map = Map<dynamic, dynamic>.from(response);
        rawList = map['songs'] as List<dynamic>? ?? [];
        kQueryMs = int.tryParse(map['perf_query_cursor_ms']?.toString() ?? '');
        kLoopMs = int.tryParse(map['perf_cursor_loop_ms']?.toString() ?? '');
        kTotalMs = int.tryParse(map['perf_total_kotlin_ms']?.toString() ?? '');

        var artistImagesMap = map['artist_images'] as Map<dynamic, dynamic>?;
        if (artistImagesMap != null && artistImagesMap.isNotEmpty) {
          var parsedImages = artistImagesMap.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          );
          localArtistImages = parsedImages;
          var appDir = await getApplicationDocumentsDirectory();
          var imagesFile = File('${appDir.path}/artist_images.json');
          await imagesFile.writeAsString(jsonEncode(parsedImages));
        }
      } else if (response is List) {
        rawList = response;
      } else {
        return null;
      }

      var cacheMap = {for (var s in cachedSongs) s.filePath: s};
      var existingFavoriteStatus = {
        for (var s in cachedSongs) s.filePath: s.isFavorite,
      };
      var existingFavoriteDates = {
        for (var s in cachedSongs) s.filePath: s.favoriteDateMs,
      };
      var existingDominantColors = {
        for (var s in cachedSongs) s.filePath: s.dominantColor,
      };

      var songs = <Song>[];
      var nextId = 1;
      if (cachedSongs.isNotEmpty) {
        nextId =
            cachedSongs.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;
      }
      var existingIds = {for (var s in cachedSongs) s.filePath: s.id};

      for (var item in rawList) {
        if (item is! Map) continue;
        var map = Map<String, dynamic>.from(item);
        var filePath = map['file_path'] as String? ?? '';
        if (filePath.isEmpty) continue;

        var mtime = (map['last_modified_ms'] as num?)?.toInt();
        var size = (map['file_size'] as num?)?.toInt();
        var artPath = map['artwork_path'] as String?;

        var dotIdx = filePath.lastIndexOf('.');
        var hasLrc = (map['has_lyrics'] as bool?);
        if (hasLrc == null && dotIdx > 0) {
          var prefix = filePath.substring(0, dotIdx);
          hasLrc =
              File('$prefix.lrc').existsSync() ||
              File('$prefix.txt').existsSync();
        }
        hasLrc ??= false;

        var cached = cacheMap[filePath];
        if (cached != null &&
            cached.lastModifiedMs == mtime &&
            cached.fileSize == size &&
            (artPath == null || cached.artworkPath == artPath)) {
          // Song is unchanged — verify if lyrics file was added/removed
          if (cached.hasLyrics != hasLrc) {
            songs.add(cached.copyWith(hasLyrics: hasLrc));
          } else {
            songs.add(cached);
          }
          continue;
        }

        var songId =
            (map['id'] as num?)?.toInt() ?? existingIds[filePath] ?? nextId++;
        var isFav = existingFavoriteStatus[filePath] ?? false;
        var favDate = existingFavoriteDates[filePath];
        var domColor = existingDominantColors[filePath];
        var ext = filePath.split('.').last.toLowerCase();

        songs.add(
          Song(
            id: songId,
            title: (map['title'] as String?)?.trim().isNotEmpty == true
                ? map['title'] as String
                : filePath.split(Platform.pathSeparator).last,
            artist: (map['artist'] as String?)?.trim().isNotEmpty == true
                ? map['artist'] as String
                : 'Unknown Artist',
            album: (map['album'] as String?)?.trim().isNotEmpty == true
                ? map['album'] as String
                : 'Unknown Album',
            duration: Duration(
              milliseconds: (map['duration_ms'] as num?)?.toInt() ?? 0,
            ),
            filePath: filePath,
            artworkPath: artPath,
            format: ext,
            isFavorite: isFav,
            favoriteDateMs: favDate,
            lastModifiedMs: mtime,
            fileSize: size,
            dominantColor: domColor,
            trackNumber: (map['track_number'] as num?)?.toInt(),
            year: (map['year'] as num?)?.toInt(),
            hasLyrics: hasLrc,
          ),
        );
      }

      swParse.stop();
      var parseMs = swParse.elapsedMilliseconds;

      return {
        'songs': songs,
        'channel_ms': channelMs,
        'parse_ms': parseMs,
        'kotlin_query_ms': kQueryMs,
        'kotlin_loop_ms': kLoopMs,
        'kotlin_total_ms': kTotalMs,
      };
    } catch (_) {
      return null;
    }
  }

  /// Performs an asynchronous background scan of the sync folder, updating the metadata index.
  Future<List<Song>> syncLibrary({int maxWorkers = 4}) async {
    return await syncLibraryFast(maxWorkers: maxWorkers);
  }

  /// Optimized sub-second background library scan.
  /// Eliminates blocking file system stat calls and defers disk metadata serialization.
  Future<List<Song>> syncLibraryFast({int maxWorkers = 4}) async {
    var swTotal = Stopwatch()..start();
    try {
      var swReadCache = Stopwatch()..start();
      var folderPath = await getScanFolder();
      var cachedSongs = await _readImportedSongsMetadata();
      swReadCache.stop();
      var readCacheMs = swReadCache.elapsedMilliseconds;

      if (folderPath != null && folderPath.isNotEmpty) {
        var dir = Directory(folderPath);
        if (!dir.existsSync()) {
          unawaited(_writeImportedSongsMetadata([]));
          return [];
        }
      }

      var prefs = SharedPreferencesAsync();

      if (Platform.isAndroid) {
        var scanResult = await _scanViaMediaStore(
          folderPath ?? '',
          cachedSongs,
          isFast: true,
        );
        if (scanResult != null) {
          var msSongs = scanResult['songs'] as List<Song>? ?? [];
          var swArtistImages = Stopwatch()..start();
          await loadLocalArtistImages();
          swArtistImages.stop();
          var artistImagesMs = swArtistImages.elapsedMilliseconds;

          var swSort = Stopwatch()..start();
          var sortSettings = await getTabSortSettings('songs');
          sortSongs(
            msSongs,
            sortSettings['sortBy'] as String,
            sortSettings['sortAscending'] as bool,
          );
          swSort.stop();
          var sortMs = swSort.elapsedMilliseconds;

          var swSave = Stopwatch()..start();
          unawaited(_writeImportedSongsMetadata(msSongs));
          swSave.stop();
          var saveMs = swSave.elapsedMilliseconds;

          var now = DateTime.now();
          var formatted = _formatTimestamp(now);
          await setLastSyncTime(formatted);
          await setLastSyncTimestamp(now.millisecondsSinceEpoch);
          await prefs.setInt('metadata_version', 1);

          swTotal.stop();
          var totalMs = swTotal.elapsedMilliseconds;

          var channelMs = scanResult['channel_ms'] as int? ?? 0;
          var parseMs = scanResult['parse_ms'] as int? ?? 0;
          var kQueryMs = scanResult['kotlin_query_ms'] as int?;
          var kLoopMs = scanResult['kotlin_loop_ms'] as int?;
          var kTotalMs = scanResult['kotlin_total_ms'] as int?;

          var perfLog =
              '''
==== SONORA PERFORMANCE LOG ====
• Total Scan Duration: ${totalMs}ms
• Songs Scanned: ${msSongs.length}
• Read Cache (Dart): ${readCacheMs}ms
• MethodChannel Roundtrip: ${channelMs}ms
  └─ Kotlin Query Cursor: ${kQueryMs ?? '?'}ms
  └─ Kotlin Cursor Loop: ${kLoopMs ?? '?'}ms
  └─ Kotlin Total Execution: ${kTotalMs ?? '?'}ms
  └─ IPC Serialization Overhead: ${(channelMs - (kTotalMs ?? 0))}ms
• Parse JSON Payload (Dart): ${parseMs}ms
• Load Local Artist Images (Dart): ${artistImagesMs}ms
• Sort Library (Dart): ${sortMs}ms
• Save Preferences (Dart): ${saveMs}ms
=================================''';

          debugPrint(perfLog);
          await prefs.setString('last_perf_log', perfLog);

          await setLastSyncDuration('last', totalMs);

          return msSongs;
        }
      }

      if (folderPath == null) {
        var verified = cachedSongs
            .where((s) => File(s.filePath).existsSync())
            .toList();
        unawaited(_writeImportedSongsMetadata(verified));
        return verified;
      }

      return await syncLibraryLegacy(maxWorkers: maxWorkers);
    } catch (_) {
      swTotal.stop();
      return await _readImportedSongsMetadata();
    }
  }

  String _formatTimestamp(DateTime now) {
    var hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
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
    return '$month ${now.day}, ${now.year} at $hour:$minute:$second $ampm';
  }

  /// Legacy sequential syncLibrary method for benchmark comparisons.
  Future<List<Song>> syncLibraryLegacy({int maxWorkers = 4}) async {
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

      var prefs = SharedPreferencesAsync();
      var metadataVersion = await prefs.getInt('metadata_version') ?? 0;

      // Try instant native Android MediaStore scan first
      if (Platform.isAndroid) {
        var msResult = await _scanViaMediaStore(folderPath, cachedSongs);
        var msSongs = msResult?['songs'] as List<Song>?;
        if (msSongs != null && msSongs.isNotEmpty) {
          await loadLocalArtistImages();
          if (localArtistImages.isEmpty) {
            unawaited(detectLocalArtistImages(folderPath, msSongs));
          }

          var sortSettings = await getTabSortSettings('songs');
          sortSongs(
            msSongs,
            sortSettings['sortBy'] as String,
            sortSettings['sortAscending'] as bool,
          );

          await _writeImportedSongsMetadata(msSongs);

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
          await prefs.setInt('metadata_version', 1);

          sw.stop();
          var durationMs = sw.elapsedMilliseconds;
          await setLastSyncDuration('last', durationMs);

          return msSongs;
        }
      }

      // Offload all directory scanning, metadata comparison, and parsing to background isolate
      var isolateData = await Isolate.run<Map<String, dynamic>>(() {
        var localCachedSongs = metadataVersion < 1
            ? <Song>[]
            : List<Song>.from(cachedSongs);

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
        var localCoverImageDirs = <String, String>{}; // dirPath -> imagePath
        var localImageFiles =
            <String, List<String>>{}; // dirPath -> List<imagePath>

        try {
          var syncDir = Directory(folderPath);
          for (var entity in syncDir.listSync(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              var name = entity.uri.pathSegments.last.toLowerCase();
              if (name == 'cover.jpg' ||
                  name == 'cover.png' ||
                  name == 'cover.webp') {
                localCoverImageDirs[entity.parent.path] = entity.path;
              } else if (name.endsWith('.jpg') ||
                  name.endsWith('.png') ||
                  name.endsWith('.webp') ||
                  name.endsWith('.jpeg')) {
                var parentPath = entity.parent.path;
                var normParentPath = parentPath.replaceAll('\\', '/');
                localImageFiles
                    .putIfAbsent(parentPath, () => [])
                    .add(entity.path);
                if (normParentPath != parentPath) {
                  localImageFiles
                      .putIfAbsent(normParentPath, () => [])
                      .add(entity.path);
                }
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
                  (File('${file.path.substring(0, lastDotLrc)}.lrc')
                          .existsSync() ||
                      File('${file.path.substring(0, lastDotLrc)}.txt')
                          .existsSync());

              if (cached.lastModifiedMs == mtime &&
                  cached.fileSize == size &&
                  cached.artist != 'Local Audio' &&
                  cached.album != 'Synced Folder' &&
                  cached.format != null) {
                if (cached.hasLyrics != hasLrc) {
                  songsToKeep.add(cached.copyWith(hasLyrics: hasLrc));
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
              int? trackNumber;
              int? discNumber;
              String? genre;
              int? year;
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
                trackNumber = meta.track;
                discNumber = meta.disc;
                genre = meta.genre;
                year = meta.year;
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

              // Fallback to directory structure for artist/album if metadata is missing
              if (artist == null ||
                  artist.isEmpty ||
                  artist == 'Unknown Artist') {
                var parentDirName = file.parent.parent.path
                    .split(RegExp(r'[/\\]'))
                    .last;
                if (parentDirName.isNotEmpty &&
                    parentDirName != 'music' &&
                    parentDirName != 'Download') {
                  artist = parentDirName;
                }
              }

              if (album == null || album.isEmpty || album == 'Unknown Album') {
                var dirName = file.parent.path.split(RegExp(r'[/\\]')).last;
                if (dirName.isNotEmpty) {
                  album = dirName;
                }
              }

              // Fallback to filename parsing
              if (trackNumber == null) {
                var match = RegExp(r'^(\d+)\s*[-_.]?\s*')
                    .firstMatch(file.uri.pathSegments.last);
                if (match != null) {
                  trackNumber = int.tryParse(match.group(1)!);
                }
              }

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
                  trackNumber: trackNumber,
                  discNumber: discNumber,
                  genre: genre,
                  year: year,
                ),
              );
            } catch (_) {}
          }
        }
        var finalArtistImages = <String, String>{};
        for (var song in songsToKeep) {
          var lowerArtist = song.artist.trim().toLowerCase();
          var cleanArtist = lowerArtist
              .split(RegExp(r'[,;/]|\sfeat\.|\sft\.', caseSensitive: false))
              .first
              .trim();

          String? findArtistImage(Directory startDir) {
            Directory? current = startDir;
            var normFolderPath = folderPath.replaceAll('\\', '/');
            while (current != null) {
              var normCurrentPath = current.path.replaceAll('\\', '/');
              var images =
                  localImageFiles[current.path] ??
                  localImageFiles[normCurrentPath];
              if (images != null && images.isNotEmpty) {
                for (var img in images) {
                  var name = img.split(RegExp(r'[/\\]')).last.toLowerCase();
                  if (name == 'artist.jpg' ||
                      name == 'artist.png' ||
                      name == 'artist.webp' ||
                      name == 'artist.jpeg') {
                    return img;
                  }
                  if (name == '$cleanArtist.jpg' ||
                      name == '$cleanArtist.png' ||
                      name == '$cleanArtist.webp' ||
                      name == '$cleanArtist.jpeg') {
                    return img;
                  }
                }
                var dirName = normCurrentPath
                    .split('/')
                    .last
                    .toLowerCase()
                    .trim();
                if (dirName == cleanArtist || dirName == lowerArtist) {
                  return images.first;
                }
                // If we are at the artist folder level and any image exists, return it
                if (images.isNotEmpty) {
                  return images.first;
                }
              }
              if (normCurrentPath == normFolderPath) break;
              var parent = current.parent;
              if (parent.path == current.path) break;
              current = parent;
            }
            return null;
          }

          var match = findArtistImage(File(song.filePath).parent);
          if (match != null) {
            finalArtistImages[lowerArtist] = match;
            if (cleanArtist.isNotEmpty) {
              finalArtistImages[cleanArtist] = match;
            }
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
      await prefs.setInt('metadata_version', 1);

      sw.stop();
      var durationMs = sw.elapsedMilliseconds;
      await setLastSyncDuration('last', durationMs);

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

              if (cached.lastModifiedMs == mtime &&
                  cached.fileSize == size &&
                  cached.format != null) {
                var hasLrc = false;
                var extIndex = file.path.lastIndexOf('.');
                if (extIndex != -1) {
                  var basePath = file.path.substring(0, extIndex);
                  hasLrc =
                      File('$basePath.lrc').existsSync() ||
                      File('$basePath.txt').existsSync();
                }

                if (cached.hasLyrics != hasLrc) {
                  songsToKeep.add(cached.copyWith(hasLyrics: hasLrc));
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

  /// Reads the playlists list from SharedPreferencesAsync (with fallback migration to playlists.json).
  Future<List<Playlist>> getPlaylists() async {
    try {
      var prefContent = await _prefs.getString('playlists_json');
      var list = <Playlist>[];

      if (prefContent != null && prefContent.isNotEmpty) {
        var jsonList = jsonDecode(prefContent) as List<dynamic>;
        list = jsonList
            .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to legacy disk file if present
        var appDir = await getApplicationDocumentsDirectory();
        var file = File('${appDir.path}/playlists.json');
        if (file.existsSync()) {
          var content = await file.readAsString();
          var jsonList = jsonDecode(content) as List<dynamic>;
          list = jsonList
              .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
              .toList();
          // Save to SharedPreferencesAsync
          await savePlaylists(list);
        }
      }

      // Migrate existing users by removing the legacy favorites playlist
      if (list.any((p) => p.id == 'favorites')) {
        list.removeWhere((p) => p.id == 'favorites');
        await savePlaylists(list);
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Writes the playlists list to SharedPreferencesAsync and disk backup.
  Future<void> savePlaylists(List<Playlist> playlists) async {
    try {
      var jsonList = playlists.map((p) => p.toJson()).toList();
      var jsonStr = jsonEncode(jsonList);
      await _prefs.setString('playlists_json', jsonStr);

      // Keep legacy file updated as double backup so playlists are NEVER lost
      try {
        var appDir = await getApplicationDocumentsDirectory();
        var file = File('${appDir.path}/playlists.json');
        await file.writeAsString(jsonStr);
      } catch (_) {}
    } catch (_) {}
  }

  /// Toggles a song's favorite status in the cache index and updates the default Favorites playlist.
  Future<List<Song>> toggleFavoriteSong(int songId) async {
    try {
      var songs = await _readImportedSongsMetadata();

      var songIndex = songs.indexWhere((s) => s.id == songId);
      if (songIndex >= 0) {
        var song = songs[songIndex];
        var newFavoriteStatus = !song.isFavorite;
        var newFavoriteDateMs = newFavoriteStatus
            ? DateTime.now().millisecondsSinceEpoch
            : null;

        songs[songIndex] = song.copyWith(
          isFavorite: newFavoriteStatus,
          favoriteDateMs: newFavoriteDateMs,
        );

        await _writeImportedSongsMetadata(songs);
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

  /// Updates a playlist's cover image path.
  Future<void> updatePlaylistCover(
    String playlistId,
    String? coverImagePath,
  ) async {
    var playlists = await getPlaylists();
    for (var i = 0; i < playlists.length; i++) {
      if (playlists[i].id == playlistId) {
        var oldPlaylist = playlists[i];

        if (oldPlaylist.coverImagePath != null &&
            oldPlaylist.coverImagePath != coverImagePath) {
          try {
            var oldFile = File(oldPlaylist.coverImagePath!);
            if (oldFile.existsSync()) {
              oldFile.deleteSync();
            }
          } catch (_) {}
        }

        playlists[i] = Playlist(
          id: oldPlaylist.id,
          name: oldPlaylist.name,
          songIds: oldPlaylist.songIds,
          coverImagePath: coverImagePath,
          description: oldPlaylist.description,
        );
        await savePlaylists(playlists);
        break;
      }
    }
  }

  /// Updates a playlist's description.
  Future<void> updatePlaylistDescription(
    String playlistId,
    String? description,
  ) async {
    var playlists = await getPlaylists();
    for (var i = 0; i < playlists.length; i++) {
      if (playlists[i].id == playlistId) {
        var oldPlaylist = playlists[i];
        playlists[i] = Playlist(
          id: oldPlaylist.id,
          name: oldPlaylist.name,
          songIds: oldPlaylist.songIds,
          coverImagePath: oldPlaylist.coverImagePath,
          description: description,
        );
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
      var prefContent = await _prefs.getString('imported_songs_json');
      String content;

      if (prefContent != null && prefContent.isNotEmpty) {
        content = prefContent;
      } else {
        var appDir = await getApplicationDocumentsDirectory();
        var jsonFile = File('${appDir.path}/imported_songs.json');
        if (!jsonFile.existsSync()) return [];
        content = await jsonFile.readAsString();
        await _prefs.setString('imported_songs_json', content);
      }

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
          favoriteDateMs:
              item['favorite_date_ms'] as int? ??
              (item['is_favorite'] == true
                  ? DateTime.now().millisecondsSinceEpoch
                  : null),
          lastModifiedMs: item['last_modified_ms'] as int?,
          fileSize: item['file_size'] as int?,
          hasLyrics: item['has_lyrics'] == true,
          dominantColor: item['dominant_color'] as int?,
          trackNumber: item['track_number'] as int?,
          discNumber: item['disc_number'] as int?,
          genre: item['genre'] as String?,
          year: item['year'] as int?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeImportedSongsMetadata(List<Song> songs) async {
    try {
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
              'favorite_date_ms': s.favoriteDateMs,
              'last_modified_ms': s.lastModifiedMs,
              'file_size': s.fileSize,
              'has_lyrics': s.hasLyrics,
              'dominant_color': s.dominantColor,
              'track_number': s.trackNumber,
              'disc_number': s.discNumber,
              'genre': s.genre,
              'year': s.year,
            },
          )
          .toList();

      var jsonStr = jsonEncode(jsonList);
      await _prefs.setString('imported_songs_json', jsonStr);

      try {
        var appDir = await getApplicationDocumentsDirectory();
        var jsonFile = File('${appDir.path}/imported_songs.json');
        await jsonFile.writeAsString(jsonStr);
      } catch (_) {}
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

  /// Bulk creates a playlist from a list of song IDs
  Future<void> createPlaylistFromSongs(String name, List<int> songIds) async {
    var playlists = await getPlaylists();
    var newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      songIds: songIds,
    );
    playlists.add(newPlaylist);
    await savePlaylists(playlists);
  }

  /// Imports an M3U file and creates a new playlist from it.
  Future<void> importM3u(File m3uFile) async {
    try {
      var lines = await m3uFile.readAsLines();
      var songs = await _readImportedSongsMetadata();
      var songIds = <int>[];

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        // Extract filename from the path in the m3u
        var filename = line.split(RegExp(r'[/\\]')).last;

        // Find matching song in library
        var match = songs
            .where((s) => s.filePath.endsWith(filename))
            .firstOrNull;
        if (match != null) {
          songIds.add(match.id);
        }
      }

      if (songIds.isNotEmpty) {
        var name = m3uFile.path
            .split(RegExp(r'[/\\]'))
            .last
            .replaceAll(RegExp(r'\.m3u8?$'), '');
        var playlists = await getPlaylists();
        var newPlaylist = Playlist(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          songIds: songIds,
          description: 'Imported from M3U',
        );
        playlists.add(newPlaylist);
        await savePlaylists(playlists);
      }
    } catch (_) {}
  }

  /// Exports a playlist to an M3U file in the temporary directory.
  Future<File?> exportPlaylistToM3u(Playlist playlist) async {
    try {
      var songs = await _readImportedSongsMetadata();
      var playlistSongs = playlist.songIds
          .map((id) => songs.where((s) => s.id == id).firstOrNull)
          .where((s) => s != null)
          .cast<Song>()
          .toList();

      var tempDir = Directory.systemTemp;
      var file = File('${tempDir.path}/${playlist.name}.m3u');

      var buffer = StringBuffer();
      buffer.writeln('#EXTM3U');
      for (var song in playlistSongs) {
        buffer.writeln(
          '#EXTINF:${song.duration.inSeconds},${song.artist} - ${song.title}',
        );
        buffer.writeln(song.filePath);
      }

      await file.writeAsString(buffer.toString());
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Persists the active playback queue as a lightweight list of integer song IDs.
  Future<void> saveQueueIds(List<int> songIds) async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var queueFile = File('${appDir.path}/saved_queue_ids.json');
      await queueFile.writeAsString(jsonEncode(songIds));
    } catch (_) {}
  }

  /// Reads the saved active queue song IDs.
  Future<List<int>> getSavedQueueIds() async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var queueFile = File('${appDir.path}/saved_queue_ids.json');
      if (queueFile.existsSync()) {
        var raw = await queueFile.readAsString();
        var list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => (e as num).toInt()).toList();
      }
    } catch (_) {}
    return [];
  }
}
