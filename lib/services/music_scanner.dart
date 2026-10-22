import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:audio_tags_lofty/audio_tags_lofty.dart' as tags;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/replay_gain.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/image_preflight_service.dart';
import 'package:sonora/services/replay_gain_reader.dart';

part 'scanner_artist_images.dart';
part 'scanner_legacy_sync.dart';
part 'scanner_preferences.dart';
part 'scanner_playlists.dart';

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

  /// Retrieves the native Android 12+ Monet dynamic wallpaper accent color.
  static Future<Color?> getDynamicWallpaperColor() async {
    if (!Platform.isAndroid &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      var result = await _mediastoreChannel.invokeMethod<int>(
        'getDynamicWallpaperColor',
      );
      if (result != null) {
        return Color(result);
      }
    } catch (_) {}
    return null;
  }

  /// Cached local artist images path mapping
  Map<String, String> localArtistImages = {};

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

    if (songs.isNotEmpty) {
      unawaited(ImagePreflightService.instance.preflightSongs(songs));
    }

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
    var songs = await syncLibraryFast(maxWorkers: maxWorkers);
    if (songs.isNotEmpty) {
      unawaited(ImagePreflightService.instance.preflightSongs(songs));
    }
    return songs;
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
      var mediaStoreReturnedEmpty = false;

      if (Platform.isAndroid) {
        var scanResult = await _scanViaMediaStore(
          folderPath ?? '',
          cachedSongs,
          isFast: true,
        );
        if (scanResult != null) {
          var msSongs = scanResult['songs'] as List<Song>? ?? [];
          // MediaStore can omit files in a selected folder (for example, before
          // Android has indexed them). Let the directory scanner below handle
          // an empty result instead of treating it as a successful full scan.
          if (msSongs.isNotEmpty) {
            var swReplayGain = Stopwatch()..start();
            await _fillReplayGain(msSongs, maxWorkers: maxWorkers);
            swReplayGain.stop();
            var replayGainMs = swReplayGain.elapsedMilliseconds;

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
• ReplayGain Tags (Dart): ${replayGainMs}ms
• Load Local Artist Images (Dart): ${artistImagesMs}ms
• Sort Library (Dart): ${sortMs}ms
• Save Preferences (Dart): ${saveMs}ms
=================================''';

            debugPrint(perfLog);
            await prefs.setString('last_perf_log', perfLog);

            await setLastSyncDuration('last', totalMs);

            return msSongs;
          }
          mediaStoreReturnedEmpty = true;
        }
      }

      if (folderPath == null) {
        var verified = cachedSongs
            .where((s) => File(s.filePath).existsSync())
            .toList();
        await _fillReplayGain(verified, maxWorkers: maxWorkers);
        unawaited(_writeImportedSongsMetadata(verified));
        return verified;
      }

      return await syncLibraryLegacy(
        maxWorkers: maxWorkers,
        skipMediaStore: mediaStoreReturnedEmpty,
      );
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

  /// Recursively scans the selected folder path and updates references. Files are NOT copied.
  Future<List<Song>> importFromFolder(String folderPath) async {
    try {
      await setScanFolder(folderPath);
      var songs = await syncLibrary();
      if (songs.isNotEmpty) {
        unawaited(ImagePreflightService.instance.preflightSongs(songs));
      }
      return songs;
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

  /// Reads ReplayGain tags for every song not yet checked, in place.
  ///
  /// Unchanged files keep their cached [Song] (and its scan marker) during
  /// sync, so only new or modified files are read, plus, once, songs cached
  /// before ReplayGain support existed. Reads are split over [maxWorkers]
  /// background isolates and only touch tag headers.
  static Future<void> _fillReplayGain(
    List<Song> songs, {
    int maxWorkers = 4,
  }) async {
    var pending = [
      for (var i = 0; i < songs.length; i++)
        if (!songs[i].replayGainScanned) i,
    ];
    if (pending.isEmpty) return;

    var workers = maxWorkers.clamp(1, pending.length);
    var chunkSize = (pending.length / workers).ceil();
    var chunks = [
      for (var start = 0; start < pending.length; start += chunkSize)
        pending.sublist(start, min(start + chunkSize, pending.length)),
    ];
    try {
      var results = await Future.wait([
        for (var chunk in chunks)
          _readReplayGainInIsolate([for (var i in chunk) songs[i].filePath]),
      ]);
      for (var c = 0; c < chunks.length; c++) {
        for (var k = 0; k < chunks[c].length; k++) {
          var index = chunks[c][k];
          songs[index] = songs[index].withReplayGain(results[c][k]);
        }
      }
    } catch (_) {
      // Leave songs unmarked so the next sync tries again.
    }
  }

  static Future<List<ReplayGainInfo?>> _readReplayGainInIsolate(
    List<String> paths,
  ) => Isolate.run(() => [for (var p in paths) ReplayGainReader.readFile(p)]);

  // --- Private Helpers ---

  /// Legacy SharedPreferences key that used to hold a second copy of the
  /// library cache. Migrated to the file on first read, then removed.
  static const _legacyLibraryPrefsKey = 'imported_songs_json';

  /// Serialises cache writes so they land in call order and reads always see
  /// the latest write, even when the write was not awaited.
  var _libraryWrite = Future<void>.value();

  Future<File> _libraryFile() async {
    var appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/imported_songs.json');
  }

  Future<List<Song>> _readImportedSongsMetadata() async {
    try {
      return await _readImportedSongsMetadataStrict();
    } catch (_) {
      return [];
    }
  }

  /// Like [_readImportedSongsMetadata] but throws when the cache exists and
  /// cannot be read, so callers can tell "empty" from "failed".
  Future<List<Song>> _readImportedSongsMetadataStrict() async {
    await _libraryWrite;
    var jsonFile = await _libraryFile();

    var legacyContent = await _prefs.getString(_legacyLibraryPrefsKey);
    if (legacyContent != null) {
      // The prefs copy was the primary read source before, so it wins.
      if (legacyContent.isNotEmpty) {
        await _writeLibraryFileAtomically(jsonFile, legacyContent);
      }
      await _prefs.remove(_legacyLibraryPrefsKey);
      if (legacyContent.isNotEmpty) {
        return await _decodeLibraryInIsolate(legacyContent);
      }
    }

    if (!jsonFile.existsSync()) return [];
    return await _decodeLibraryInIsolate(await jsonFile.readAsString());
  }

  Future<void> _writeImportedSongsMetadata(List<Song> songs) {
    var snapshot = List<Song>.of(songs);
    return _libraryWrite = _libraryWrite.then((_) async {
      try {
        var jsonStr = await _encodeLibraryInIsolate(snapshot);
        await _writeLibraryFileAtomically(await _libraryFile(), jsonStr);
      } catch (_) {}
    });
  }

  /// Like [_writeImportedSongsMetadata] but the returned future fails when
  /// the write fails. The shared write queue itself never fails.
  Future<void> _writeImportedSongsMetadataStrict(List<Song> songs) {
    var snapshot = List<Song>.of(songs);
    var result = Completer<void>();
    _libraryWrite = _libraryWrite.then((_) async {
      try {
        var jsonStr = await _encodeLibraryInIsolate(snapshot);
        await _writeLibraryFileAtomically(await _libraryFile(), jsonStr);
        result.complete();
      } catch (e, stack) {
        result.completeError(e, stack);
      }
    });
    return result.future;
  }

  // Static so the isolate closures capture only their argument, never `this`
  // (instance state such as pending futures cannot cross isolates).
  static Future<List<Song>> _decodeLibraryInIsolate(String content) =>
      Isolate.run(() => _decodeLibrary(content));

  static Future<String> _encodeLibraryInIsolate(List<Song> songs) =>
      Isolate.run(() => _encodeLibrary(songs));

  /// Writes to a temp file and renames it over the target, so a crash or
  /// full disk mid-write never leaves a truncated library behind.
  static Future<void> _writeLibraryFileAtomically(
    File target,
    String content,
  ) async {
    var temp = File('${target.path}.tmp');
    await temp.writeAsString(content, flush: true);
    await temp.rename(target.path);
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

List<Song> _decodeLibrary(String content) {
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
      replayGainTrack: (item['replaygain_track_gain'] as num?)?.toDouble(),
      replayGainAlbum: (item['replaygain_album_gain'] as num?)?.toDouble(),
      replayGainTrackPeak: (item['replaygain_track_peak'] as num?)?.toDouble(),
      replayGainAlbumPeak: (item['replaygain_album_peak'] as num?)?.toDouble(),
      replayGainScanned: item['replaygain_scanned'] == true,
    );
  }).toList();
}

String _encodeLibrary(List<Song> songs) {
  return jsonEncode([
    for (var s in songs)
      {
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
        'replaygain_track_gain': s.replayGainTrack,
        'replaygain_album_gain': s.replayGainAlbum,
        'replaygain_track_peak': s.replayGainTrackPeak,
        'replaygain_album_peak': s.replayGainAlbumPeak,
        'replaygain_scanned': s.replayGainScanned,
      },
  ]);
}
