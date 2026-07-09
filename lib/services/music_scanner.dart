import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart' as tags;
import 'package:path_provider/path_provider.dart';

import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';

/// Handles scanning, custom file references, and playlists for the application library.
class MusicScanner {
  /// Queries the cached list of songs from storage instantly.
  Future<List<Song>> scanAllSongs() async {
    var songs = <Song>[];

    try {
      // Read existing metadata cache directly for instant UI loading
      songs = await _readImportedSongsMetadata();
    } catch (_) {
      // Return whatever is left on error
    }

    // Sort songs by title alphabetically
    songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return songs;
  }

  /// Performs an asynchronous background scan of the sync folder, updating the metadata index.
  /// Runs inside a background isolate to keep the UI thread completely free and responsive.
  Future<List<Song>> syncLibrary() async {
    try {
      var folderPath = await getScanFolder();
      var appDir = await getApplicationDocumentsDirectory();
      var appDocsDirPath = appDir.path;

      var cachedSongs = await _readImportedSongsMetadata();

      if (folderPath == null) {
        // No sync folder configured. Filter existing cached references by physical existence.
        var verified = cachedSongs.where((s) => File(s.filePath).existsSync()).toList();
        await _writeImportedSongsMetadata(verified);
        return verified;
      }

      var dir = Directory(folderPath);
      if (!dir.existsSync()) {
        // Synced folder no longer exists.
        await _writeImportedSongsMetadata([]);
        return [];
      }

      // Offload all directory scanning, metadata parsing, and artwork caching to background isolate
      var resultSongs = await Isolate.run<List<Song>>(() {
        var localCachedSongs = List<Song>.from(cachedSongs);

        // Supports wide variety of standard audio formats
        var audioExtensions = {
          'mp3', 'm4a', 'mp4', 'aac', 'flac', 'ogg', 'opus', 
          'wav', 'wma', 'amr', '3gp', 'ts', 'mkv', 'mid', 'midi'
        };
        var foundFiles = <File>[];

        try {
          var syncDir = Directory(folderPath);
          for (var entity in syncDir.listSync(recursive: true, followLinks: false)) {
            if (entity is File) {
              var ext = entity.path.split('.').last.toLowerCase();
              if (audioExtensions.contains(ext)) {
                foundFiles.add(entity);
              }
            }
          }
        } catch (_) {}

        var foundPaths = foundFiles.map((f) => f.path).toSet();
        var verifiedSongs = localCachedSongs.where((s) => foundPaths.contains(s.filePath)).toList();

        // Migrate existing songs that were cached with placeholders
        for (var i = 0; i < verifiedSongs.length; i++) {
          var song = verifiedSongs[i];
          if (song.artist == 'Local Audio' || song.album == 'Synced Folder') {
            try {
              var meta = tags.readMetadata(song.filePath, true);
              if (meta != null) {
                var title = meta.title?.trim();
                var artist = meta.artist?.trim() ?? meta.albumArtist?.trim();
                var album = meta.album?.trim();
                var format = meta.format?.trim();
                var bitrate = meta.bitrate;
                var samplerate = meta.samplerate;
                String? artworkPath;

                if (meta.pictureBytes != null && meta.pictureBytes!.isNotEmpty) {
                  var artFile = File('$appDocsDirPath/artwork_${DateTime.now().millisecondsSinceEpoch}_${song.id}.jpg');
                  artFile.writeAsBytesSync(meta.pictureBytes!);
                  artworkPath = artFile.path;
                }

                var fileName = song.filePath.split(Platform.pathSeparator).last;
                var extIndex = fileName.lastIndexOf('.');
                var defaultTitle = extIndex != -1 ? fileName.substring(0, extIndex) : fileName;

                verifiedSongs[i] = Song(
                  id: song.id,
                  title: (title == null || title.isEmpty) ? defaultTitle : title,
                  artist: (artist == null || artist.isEmpty) ? 'Unknown Artist' : artist,
                  album: (album == null || album.isEmpty) ? 'Unknown Album' : album,
                  duration: song.duration,
                  filePath: song.filePath,
                  artworkPath: artworkPath ?? song.artworkPath,
                  format: format,
                  bitrate: bitrate,
                  samplerate: samplerate,
                );
              }
            } catch (_) {}
          }
        }

        // Find files that are not yet in verified cache (new files)
        var verifiedPaths = verifiedSongs.map((s) => s.filePath).toSet();
        var newFiles = foundFiles.where((f) => !verifiedPaths.contains(f.path)).toList();

        if (newFiles.isNotEmpty) {
          var idCounter = verifiedSongs.isEmpty
              ? 1
              : verifiedSongs.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;

          var newSongs = <Song>[];
          for (var file in newFiles) {
            try {
              // Read metadata synchronously inside background isolate (includes duration parsed by lofty!)
              var meta = tags.readMetadata(file.path, true);
              
              String? title;
              String? artist;
              String? album;
              String? artworkPath;
              String? format;
              int? bitrate;
              int? samplerate;
              var duration = Duration.zero;

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

                if (meta.pictureBytes != null && meta.pictureBytes!.isNotEmpty) {
                  var artFile = File('$appDocsDirPath/artwork_${DateTime.now().millisecondsSinceEpoch}_$idCounter.jpg');
                  artFile.writeAsBytesSync(meta.pictureBytes!);
                  artworkPath = artFile.path;
                }
              }

              var fileName = file.path.split(Platform.pathSeparator).last;
              var extIndex = fileName.lastIndexOf('.');
              var defaultTitle = extIndex != -1 ? fileName.substring(0, extIndex) : fileName;

              newSongs.add(Song(
                id: idCounter++,
                title: (title == null || title.isEmpty) ? defaultTitle : title,
                artist: (artist == null || artist.isEmpty) ? 'Unknown Artist' : artist,
                album: (album == null || album.isEmpty) ? 'Unknown Album' : album,
                duration: duration,
                filePath: file.path,
                artworkPath: artworkPath,
                format: format,
                bitrate: bitrate,
                samplerate: samplerate,
              ));
            } catch (_) {}
          }
          verifiedSongs.addAll(newSongs);
        }

        return verifiedSongs;
      });

      // Save updated index to JSON
      await _writeImportedSongsMetadata(resultSongs);

      // Save formatted last sync time
      var now = DateTime.now();
      var hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      var ampm = now.hour >= 12 ? 'PM' : 'AM';
      var minute = now.minute.toString().padLeft(2, '0');
      var second = now.second.toString().padLeft(2, '0');
      var monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      var month = monthNames[now.month - 1];
      var formatted = '$month ${now.day}, ${now.year} at $hour:$minute:$second $ampm';
      await setLastSyncTime(formatted);

      resultSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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

  /// Reads the configured scan folder path from settings.json.
  Future<String?> getScanFolder() async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var settingsFile = File('${appDir.path}/settings.json');
      if (!settingsFile.existsSync()) return null;

      var content = await settingsFile.readAsString();
      var json = jsonDecode(content) as Map<String, dynamic>;
      return json['scan_folder_path'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Writes the configured scan folder path to settings.json.
  Future<void> setScanFolder(String? path) async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var settingsFile = File('${appDir.path}/settings.json');
      var json = <String, dynamic>{};
      if (settingsFile.existsSync()) {
        try {
          var content = await settingsFile.readAsString();
          json = Map<String, dynamic>.from(jsonDecode(content) as Map);
        } catch (_) {}
      }
      json['scan_folder_path'] = path;
      await settingsFile.writeAsString(jsonEncode(json));
    } catch (_) {}
  }

  /// Reads the last sync time from settings.json.
  Future<String?> getLastSyncTime() async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var settingsFile = File('${appDir.path}/settings.json');
      if (!settingsFile.existsSync()) return null;

      var content = await settingsFile.readAsString();
      var json = jsonDecode(content) as Map<String, dynamic>;
      return json['last_sync_time'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Writes the last sync time to settings.json.
  Future<void> setLastSyncTime(String? timestamp) async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var settingsFile = File('${appDir.path}/settings.json');
      var json = <String, dynamic>{};
      if (settingsFile.existsSync()) {
        try {
          var content = await settingsFile.readAsString();
          json = Map<String, dynamic>.from(jsonDecode(content) as Map);
        } catch (_) {}
      }
      json['last_sync_time'] = timestamp;
      await settingsFile.writeAsString(jsonEncode(json));
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
        list = jsonList.map((item) => Playlist.fromJson(item as Map<String, dynamic>)).toList();
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
        
        songs[songIndex] = Song(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          duration: song.duration,
          filePath: song.filePath,
          artworkPath: song.artworkPath,
          format: song.format,
          bitrate: song.bitrate,
          samplerate: song.samplerate,
          isFavorite: newFavoriteStatus,
        );
        
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
      
      songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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

      var jsonList = songs.map((s) => {
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
      }).toList();

      await jsonFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Helper placeholder to avoid breaking any references
  Future<Uint8List?> getArtwork(int songId) async {
    return null;
  }
}
