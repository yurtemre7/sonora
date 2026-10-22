part of 'music_scanner.dart';

/// Detection and caching of local artist images.
extension ScannerArtistImages on MusicScanner {
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
}
