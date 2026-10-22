part of 'player_provider.dart';

const _colorlessArtworkPrefsKey = 'colorless_artwork_paths';

/// Dynamic theme colors extracted from album art.
extension PlayerTheme on PlayerProvider {
  Future<void> setDefaultThemeColor(Color color) async {
    if (defaultThemeColor == color) return;
    defaultThemeColor = color;
    var prefs = SharedPreferencesAsync();
    await prefs.setInt('default_theme_color', color.toARGB32());

    // Apply immediately if not playing or dynamic theme is off
    if (!settingsProvider.useDynamicTheme || currentSong == null) {
      _applyThemeColor(color);
    } else if (currentSong?.artworkPath == null &&
        currentSong?.dominantColor == null) {
      _applyThemeColor(color);
    }
    _notify();
  }

  List<Color> getUniqueThemeColors() {
    var colors = <Color>[
      const Color(0xFF7C4DFF),
    ]; // Always include base default
    var buckets = <String>{};

    for (var song in allSongs) {
      if (song.dominantColor != null) {
        var color = Color(song.dominantColor!);
        var hsl = HSLColor.fromColor(color);

        String bucketKey;
        if (hsl.saturation < 0.15 ||
            hsl.lightness < 0.15 ||
            hsl.lightness > 0.85) {
          bucketKey = 'neutral';
        } else {
          var hueSector = ((hsl.hue / 30).round() * 30) % 360;
          bucketKey = 'hue_$hueSector';
        }

        if (!buckets.contains(bucketKey)) {
          buckets.add(bucketKey);
          colors.add(color);
        }
      }
    }
    return colors;
  }

  Future<void> _extractThemeColorForSong(Song song) async {
    if (!settingsProvider.useDynamicTheme) {
      _applyThemeColor(defaultThemeColor);
      return;
    }
    _lastExtractedSongId = song.id;

    if (song.artworkPath == null) {
      _applyThemeColor(defaultThemeColor);
      return;
    }

    // Use cached dominant color if available — avoids artwork I/O entirely.
    if (song.dominantColor != null) {
      _applyThemeColor(Color(song.dominantColor!));
      return;
    }

    var colorless = await _loadColorlessArtwork();
    if (colorless.contains(song.artworkPath)) {
      _applyThemeColor(defaultThemeColor);
      return;
    }

    var color = await ColorExtractor.extractDominantColor(song.artworkPath!);
    var newColor = color ?? defaultThemeColor;
    _applyThemeColor(newColor);

    // Cache the extracted color for future plays.
    if (color != null) {
      var songColor = color.toARGB32();
      _cacheDominantColor(song.id, songColor);
    } else {
      colorless.add(song.artworkPath!);
      unawaited(_saveColorlessArtwork());
    }
  }

  void _applyThemeColor(Color color) {
    if (settingsProvider.dynamicThemeColor == color) return;
    settingsProvider.dynamicThemeColor = color;
    themeColorNotifier.value = color;
  }

  /// Writes [colorsById] into every in-memory song list in one pass.
  void _applyDominantColors(Map<int, int> colorsById) {
    if (colorsById.isEmpty) return;
    void apply(List<Song> songs) {
      for (var i = 0; i < songs.length; i++) {
        var color = colorsById[songs[i].id];
        if (color != null && songs[i].dominantColor != color) {
          songs[i] = songs[i].copyWith(dominantColor: color);
        }
      }
    }

    apply(allSongs);
    apply(queue);
    apply(_originalQueue);
  }

  /// Artwork files that produced no usable color, so they are not decoded
  /// again on every launch.
  Future<Set<String>> _loadColorlessArtwork() async {
    if (_colorlessArtwork != null) return _colorlessArtwork!;
    var stored = await SharedPreferencesAsync().getStringList(
      _colorlessArtworkPrefsKey,
    );
    return _colorlessArtwork ??= {...?stored};
  }

  Future<void> _saveColorlessArtwork() async {
    var paths = _colorlessArtwork;
    if (paths == null) return;
    await SharedPreferencesAsync().setStringList(
      _colorlessArtworkPrefsKey,
      paths.toList(),
    );
  }

  void _cacheDominantColor(int songId, int color) {
    _applyDominantColors({songId: color});
    _refreshLibrarySnapshots();
    // Persist so the cache survives app restarts.
    MusicScanner().saveDominantColor(songId, color);
  }

  void _startBackgroundColorExtraction() {
    if (_isExtractingColors) return;
    _isExtractingColors = true;

    Future(() async {
      // Defer color extraction by 3 seconds so initial sync, UI rendering,
      // and audio player initialization complete 100% first without any competition.
      await Future.delayed(const Duration(seconds: 3));
      if (!_isExtractingColors) return;

      // Group songs by artworkPath to extract color once per unique image
      var colorless = await _loadColorlessArtwork();
      var artworkMap = <String, List<int>>{};
      for (var song in allSongs) {
        var path = song.artworkPath;
        if (path != null &&
            song.dominantColor == null &&
            !colorless.contains(path)) {
          artworkMap.putIfAbsent(path, () => []).add(song.id);
        }
      }

      if (artworkMap.isEmpty) {
        _isExtractingColors = false;
        return;
      }

      // Results are collected and applied once at the end: rebuilding the
      // album/artist/theme snapshots per batch made the first run quadratic.
      var colorsById = <int, int>{};
      var foundColorless = false;

      for (var entry in artworkMap.entries) {
        if (!_isExtractingColors) break;

        try {
          var color = await ColorExtractor.extractDominantColor(entry.key);
          if (color != null) {
            var songColor = color.toARGB32();
            for (var id in entry.value) {
              colorsById[id] = songColor;
            }
          } else {
            colorless.add(entry.key);
            foundColorless = true;
          }
        } catch (_) {}

        // Low-priority 100ms idle yield between extractions to guarantee 0% UI impact
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (foundColorless) await _saveColorlessArtwork();
      if (colorsById.isNotEmpty && _isExtractingColors) {
        _applyDominantColors(colorsById);
        _refreshLibrarySnapshots();
        await MusicScanner().saveAllSongsMetadata(allSongs);
        _notify();
      }
      _isExtractingColors = false;
    });
  }

  void _startLocalArtistImageDetection() {
    if (MusicScanner().localArtistImages.isNotEmpty) return;
    Future(() async {
      var folderPath = await MusicScanner().getScanFolder();
      if (folderPath != null && allSongs.isNotEmpty) {
        var images = await MusicScanner().detectLocalArtistImages(
          folderPath,
          allSongs,
        );
        if (images.isNotEmpty) {
          _refreshLibrarySnapshots();
          _notify();
        }
      }
    });
  }
}
