part of 'player_provider.dart';

/// Loading settings and restoring the last played state.
extension PlayerPersistence on PlayerProvider {
  Future<void> loadSettings() async {
    var prefs = SharedPreferencesAsync();
    var albumsMapStr = await prefs.getString('favorite_albums_map');
    if (albumsMapStr != null) {
      favoriteAlbums = Map<String, int>.from(jsonDecode(albumsMapStr));
    } else {
      var oldAlbums = await prefs.getStringList('favorite_albums') ?? [];
      var now = DateTime.now().millisecondsSinceEpoch;
      favoriteAlbums = {for (var k in oldAlbums) k: now};
    }

    var artistsMapStr = await prefs.getString('favorite_artists_map');
    if (artistsMapStr != null) {
      favoriteArtists = Map<String, int>.from(jsonDecode(artistsMapStr));
    } else {
      var oldArtists = await prefs.getStringList('favorite_artists') ?? [];
      var now = DateTime.now().millisecondsSinceEpoch;
      favoriteArtists = {for (var k in oldArtists) k: now};
    }

    var defaultColorVal = await prefs.getInt('default_theme_color');
    if (defaultColorVal != null) {
      defaultThemeColor = Color(defaultColorVal);
    }

    var savedVolume = await prefs.getDouble('volume');
    if (savedVolume != null) {
      _volume = savedVolume;
      await audioHandler.applyVolume(_volume);
    }

    var savedSpeed = await prefs.getDouble('speed');
    if (savedSpeed != null) {
      _speed = savedSpeed;
      // We will apply this via _applyMfx below if no presets override it.
    }

    var savedPresetName = await prefs.getString('mfx_preset_name');
    if (savedPresetName != null) {
      _mfxPreset = MfxPreset.fromName(savedPresetName);
    } else {
      var savedPreset = await prefs.getDouble('mfx_preset');
      if (savedPreset != null) {
        _mfxPreset = MfxPreset.fromSpeed(savedPreset);
      }
    }

    if (_mfxPreset == null) {
      _isSlowed = await prefs.getBool('mfx_isSlowed') ?? false;
      _isSuperSlowed = await prefs.getBool('mfx_isSuperSlowed') ?? false;
      _isSpedUp = await prefs.getBool('mfx_isSpedUp') ?? false;
      _isSuperSpedUp = await prefs.getBool('mfx_isSuperSpedUp') ?? false;
      _isNightcore = await prefs.getBool('mfx_isNightcore') ?? false;
      if (_isSuperSlowed) {
        _mfxPreset = MfxPreset.superSlowed;
      } else if (_isSlowed) {
        _mfxPreset = MfxPreset.slowed;
      } else if (_isSuperSpedUp) {
        _mfxPreset = MfxPreset.superSpedUp;
      } else if (_isSpedUp) {
        _mfxPreset = MfxPreset.spedUp;
      } else if (_isNightcore) {
        _mfxPreset = MfxPreset.nightcore;
      }
    }

    if (_mfxPreset != null) {
      _isSuperSlowed = _mfxPreset == MfxPreset.superSlowed;
      _isSlowed = _mfxPreset == MfxPreset.slowed;
      _isSpedUp = _mfxPreset == MfxPreset.spedUp;
      _isNightcore = _mfxPreset == MfxPreset.nightcore;
      _isSuperSpedUp = _mfxPreset == MfxPreset.superSpedUp;
    }
    _isReverbEnabled = await prefs.getBool('mfx_isReverbEnabled') ?? false;
    _isLofiEnabled = await prefs.getBool('mfx_isLofiEnabled') ?? false;
    _isBassBoostEnabled =
        await prefs.getBool('mfx_isBassBoostEnabled') ?? false;
    _isCustomEqEnabled = await prefs.getBool('mfx_isCustomEqEnabled') ?? false;
    _isBluetoothMfxPatchEnabled =
        await prefs.getBool('mfx_bluetoothMfxPatch') ?? false;
    var gains = await prefs.getStringList('mfx_customEqGains');
    if (gains != null) {
      _customEqGains = gains.map((e) => double.tryParse(e) ?? 0.0).toList();
    }

    // Apply initial audio settings
    await _applyMfx();

    if (!settingsProvider.useDynamicTheme) {
      themeColorNotifier.value = defaultThemeColor;
      settingsProvider.dynamicThemeColor = defaultThemeColor;
    }

    if (settingsProvider.useDynamicTheme && currentSong != null) {
      _extractThemeColorForSong(currentSong!);
    }
    _notify();
  }

  Future<void> _saveLastPlayedState() async {
    if (currentSong == null) return;
    try {
      var prefs = SharedPreferencesAsync();
      await prefs.setInt('last_played_song_id', currentSong!.id);
      await prefs.setStringList(
        'last_played_queue_ids',
        queue.map((s) => s.id.toString()).toList(),
      );
      await prefs.setStringList(
        'last_played_original_queue_ids',
        _originalQueue.map((s) => s.id.toString()).toList(),
      );
      await prefs.setInt(
        'last_played_position_ms',
        audioHandler.player.position.inMilliseconds,
      );
      await prefs.setBool('last_played_is_shuffled', isShuffled);
    } catch (_) {}
  }

  Future<void> _clearLastPlayedState() async {
    try {
      var prefs = SharedPreferencesAsync();
      await prefs.remove('last_played_song_id');
      await prefs.remove('last_played_queue_ids');
      await prefs.remove('last_played_original_queue_ids');
      await prefs.remove('last_played_position_ms');
      await prefs.remove('last_played_is_shuffled');
    } catch (_) {}
  }

  /// Restores the last played song, position, and queue state from storage.
  Future<void> restoreLastPlayedState([List<Song>? targetSongs]) async {
    if (!settingsProvider.restoreLastPlayedSong) return;
    var library = targetSongs ?? allSongs;
    if (library.isEmpty) return;
    if (currentIndex >= 0 && queue.isNotEmpty) return;

    try {
      var prefs = SharedPreferencesAsync();
      var savedSongId = await prefs.getInt('last_played_song_id');
      if (savedSongId == null) return;

      var songMap = {for (var s in library) s.id: s};
      var targetSong = songMap[savedSongId];
      if (targetSong == null) return;

      var savedQueueIds =
          await prefs.getStringList('last_played_queue_ids') ?? [];
      var savedOrigIds =
          await prefs.getStringList('last_played_original_queue_ids') ?? [];
      var savedPositionMs = await prefs.getInt('last_played_position_ms') ?? 0;
      var savedShuffled =
          await prefs.getBool('last_played_is_shuffled') ?? false;

      var restoredQueue = <Song>[];
      for (var idStr in savedQueueIds) {
        var id = int.tryParse(idStr);
        if (id != null && songMap.containsKey(id)) {
          restoredQueue.add(songMap[id]!);
        }
      }
      if (restoredQueue.isEmpty) {
        restoredQueue = [targetSong];
      }

      var restoredOrigQueue = <Song>[];
      for (var idStr in savedOrigIds) {
        var id = int.tryParse(idStr);
        if (id != null && songMap.containsKey(id)) {
          restoredOrigQueue.add(songMap[id]!);
        }
      }
      if (restoredOrigQueue.isEmpty) {
        restoredOrigQueue = List<Song>.from(restoredQueue);
      }

      var index = restoredQueue.indexWhere((s) => s.id == savedSongId);
      if (index < 0) index = 0;

      queue = restoredQueue;
      _originalQueue = restoredOrigQueue;
      currentIndex = index;
      isShuffled = savedShuffled;

      var mediaItems = queue.map(_songToMediaItem).toList();
      var initialPos = Duration(milliseconds: savedPositionMs);

      await audioHandler.loadPlaylist(
        mediaItems,
        initialIndex: currentIndex,
        initialPosition: initialPos,
      );

      if (settingsProvider.useDynamicTheme) {
        _extractThemeColorForSong(targetSong);
      }

      _notify();
    } catch (_) {}
  }
}
