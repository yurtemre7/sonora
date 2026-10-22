part of 'music_scanner.dart';

/// Legacy sequential sync, kept for benchmark comparisons.
extension ScannerLegacySync on MusicScanner {
  /// Legacy sequential syncLibrary method for benchmark comparisons.
  Future<List<Song>> syncLibraryLegacy({
    int maxWorkers = 4,
    bool skipMediaStore = false,
  }) async {
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
        await MusicScanner._fillReplayGain(verified, maxWorkers: maxWorkers);
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
      if (Platform.isAndroid && !skipMediaStore) {
        var msResult = await _scanViaMediaStore(folderPath, cachedSongs);
        var msSongs = msResult?['songs'] as List<Song>?;
        if (msSongs != null && msSongs.isNotEmpty) {
          await MusicScanner._fillReplayGain(msSongs, maxWorkers: maxWorkers);
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
      await MusicScanner._fillReplayGain(resultSongs, maxWorkers: maxWorkers);
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
}
