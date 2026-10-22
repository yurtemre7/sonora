part of 'player_provider.dart';

/// Library snapshots, favorites and playlists.
extension PlayerLibrary on PlayerProvider {
  /// Sets all songs and updates the queue with the list.
  ///
  /// If a song is currently playing, the active queue is preserved and only
  /// [allSongs] is refreshed. The audio handler's internal playlist is patched
  /// in-place so that [skipToQueueItem] always lands on the correct track even
  /// after a resync that may have changed library metadata.
  void updateSongs(List<Song> songs) {
    allSongs = List<Song>.from(songs);
    _refreshLibrarySnapshots();
    if (currentIndex < 0 || queue.isEmpty) {
      if (!_hasRestoredLastPlayed) {
        _hasRestoredLastPlayed = true;
        restoreLastPlayedState(allSongs);
      } else {
        // Nothing playing — replace queue entirely.
        queue = List<Song>.from(songs);
        _originalQueue = List<Song>.from(songs);
      }
    } else {
      // A song is playing — keep the queue order intact but swap in the
      // rescanned songs (same file) so new metadata such as ReplayGain gains
      // reaches the queue, then refresh the audio handler's raw playlist so
      // index-based skips stay correct.
      var byPath = {for (var s in allSongs) s.filePath: s};
      queue = [for (var s in queue) byPath[s.filePath] ?? s];
      _originalQueue = [for (var s in _originalQueue) byPath[s.filePath] ?? s];
      audioHandler.syncQueueMetadata(queue.map(_songToMediaItem).toList());
    }
    _notify();
    _startBackgroundColorExtraction();
    _startLocalArtistImageDetection();
    _startImagePreflight();
  }

  void _startImagePreflight() {
    ImagePreflightService.instance.preflightSongs(allSongs);
    ImagePreflightService.instance.preflightAlbums(cachedAlbums);
    if (queue.isNotEmpty && currentIndex >= 0) {
      ImagePreflightService.instance.preflightQueueUpcoming(
        queue,
        currentIndex,
      );
    }
  }

  void _refreshLibrarySnapshots() {
    cachedAlbums = buildAlbumGroups(allSongs);
    cachedArtists = buildArtistGroups(
      allSongs,
      cachedAlbums,
      settingsProvider.preferLocalArtistImages
          ? MusicScanner().localArtistImages
          : {},
    );
    uniqueThemeCount = AppTheme.precomputeThemes(allSongs);

    // Keep Android Auto / Automotive OS browse tree in sync.
    audioHandler.mediaBrowser.updateLibrary(
      songs: allSongs,
      albums: cachedAlbums,
      artists: cachedArtists,
      playlists: playlists,
    );
  }

  /// Toggles a song's favorite status in the cache index and favorite playlist.
  Future<void> toggleFavoriteAlbum(String key) async {
    unawaited(HapticFeedback.lightImpact());
    favoriteAlbums = Map<String, int>.from(favoriteAlbums);
    if (favoriteAlbums.containsKey(key)) {
      favoriteAlbums.remove(key);
    } else {
      favoriteAlbums[key] = DateTime.now().millisecondsSinceEpoch;
    }
    var prefs = SharedPreferencesAsync();
    await prefs.setString('favorite_albums_map', jsonEncode(favoriteAlbums));
    _notify();
  }

  Future<void> toggleFavoriteArtist(String nameLower) async {
    unawaited(HapticFeedback.lightImpact());
    favoriteArtists = Map<String, int>.from(favoriteArtists);
    if (favoriteArtists.containsKey(nameLower)) {
      favoriteArtists.remove(nameLower);
    } else {
      favoriteArtists[nameLower] = DateTime.now().millisecondsSinceEpoch;
    }
    var prefs = SharedPreferencesAsync();
    await prefs.setString('favorite_artists_map', jsonEncode(favoriteArtists));
    _notify();
  }

  Future<void> toggleFavorite(int songId) async {
    unawaited(HapticFeedback.lightImpact());
    var scanner = MusicScanner();
    var updatedSongs = await scanner.toggleFavoriteSong(songId);

    // Find the updated song from scanner result
    var updatedSong = updatedSongs.where((s) => s.id == songId).firstOrNull;

    allSongs = List<Song>.from(updatedSongs);

    if (updatedSong != null) {
      // Update queue with the exact song from scanner
      for (var i = 0; i < queue.length; i++) {
        if (queue[i].id == songId) {
          queue[i] = updatedSong;
        }
      }

      // Update original queue
      for (var i = 0; i < _originalQueue.length; i++) {
        if (_originalQueue[i].id == songId) {
          _originalQueue[i] = updatedSong;
        }
      }
    }

    // Refresh the playlists list so that the Favorites count and item inclusions are in sync!
    playlists = await scanner.getPlaylists();
    allSongs = List<Song>.from(updatedSongs);
    _refreshLibrarySnapshots();

    _notify();
  }

  /// Bulk updates favorite status for [songIds].
  Future<void> setFavorites(List<int> songIds, bool isFavorite) async {
    if (songIds.isEmpty) return;
    var scanner = MusicScanner();
    var updatedSongs = await scanner.setFavoriteSongs(songIds, isFavorite);
    allSongs = List<Song>.from(updatedSongs);

    var idSet = songIds.toSet();
    var updatedMap = {
      for (var s in updatedSongs)
        if (idSet.contains(s.id)) s.id: s,
    };

    for (var i = 0; i < queue.length; i++) {
      var updated = updatedMap[queue[i].id];
      if (updated != null) {
        queue[i] = updated;
      }
    }

    for (var i = 0; i < _originalQueue.length; i++) {
      var updated = updatedMap[_originalQueue[i].id];
      if (updated != null) {
        _originalQueue[i] = updated;
      }
    }

    playlists = await scanner.getPlaylists();
    _refreshLibrarySnapshots();
    _notify();
  }

  /// Adds multiple [songs] to a playlist.
  Future<void> addSongsToPlaylist(String playlistId, List<Song> songs) async {
    if (songs.isEmpty) return;
    var scanner = MusicScanner();
    await scanner.addSongsToPlaylist(
      playlistId,
      songs.map((s) => s.id).toList(),
    );
    playlists = await scanner.getPlaylists();
    _notify();
  }

  /// Removes multiple [songs] from a playlist.
  Future<void> removeSongsFromPlaylist(
    String playlistId,
    List<Song> songs,
  ) async {
    if (songs.isEmpty) return;
    var scanner = MusicScanner();
    await scanner.removeSongsFromPlaylist(
      playlistId,
      songs.map((s) => s.id).toList(),
    );
    playlists = await scanner.getPlaylists();
    _notify();
  }

  /// Reloads everything a restored backup can change: favorite flags from
  /// [songs], playlists and the player's own settings (favorite albums and
  /// artists, volume, speed, effects, theme color).
  Future<void> reloadAfterRestore(List<Song> songs) async {
    var byId = {for (var s in songs) s.id: s};
    // Keep the current sort order; only swap in the updated song objects.
    allSongs = [for (var s in allSongs) byId[s.id] ?? s];
    for (var i = 0; i < queue.length; i++) {
      queue[i] = byId[queue[i].id] ?? queue[i];
    }
    for (var i = 0; i < _originalQueue.length; i++) {
      _originalQueue[i] = byId[_originalQueue[i].id] ?? _originalQueue[i];
    }
    playlists = await MusicScanner().getPlaylists();
    _refreshLibrarySnapshots();
    await loadSettings();
  }

  // ── Playlist management APIs ────────────────────────────────────────────────

  void updatePlaylists(List<Playlist> newPlaylists) {
    playlists = List<Playlist>.from(newPlaylists);
    _notify();
  }

  Future<void> loadPlaylists() async {
    var scanner = MusicScanner();
    playlists = await scanner.getPlaylists();
    _notify();
  }

  Future<void> createPlaylist(String name) async {
    var scanner = MusicScanner();
    await scanner.createPlaylist(name);
    await loadPlaylists();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    var scanner = MusicScanner();
    var list = await scanner.getPlaylists();
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) {
        list[i] = list[i].copyWith(name: newName);
        break;
      }
    }
    await scanner.savePlaylists(list);
    playlists = list;
    _notify();
  }

  Future<void> deletePlaylist(String id) async {
    var scanner = MusicScanner();
    await scanner.deletePlaylist(id);
    await loadPlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, int songId) async {
    var scanner = MusicScanner();
    await scanner.addSongToPlaylist(playlistId, songId);
    await loadPlaylists();
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    var scanner = MusicScanner();
    await scanner.removeSongFromPlaylist(playlistId, songId);
    await loadPlaylists();
  }

  Future<void> updatePlaylistCover(
    String playlistId,
    String? coverImagePath,
  ) async {
    var scanner = MusicScanner();
    await scanner.updatePlaylistCover(playlistId, coverImagePath);
    await loadPlaylists();
  }

  Future<void> updatePlaylistDescription(
    String playlistId,
    String? description,
  ) async {
    var scanner = MusicScanner();
    await scanner.updatePlaylistDescription(playlistId, description);
    await loadPlaylists();
  }

  Future<void> saveQueueAsPlaylist(String name) async {
    var scanner = MusicScanner();
    var songIds = queue.map((s) => s.id).toList();
    await scanner.createPlaylistFromSongs(name, songIds);
    await loadPlaylists();
  }

  Future<void> importM3u(File m3uFile) async {
    var scanner = MusicScanner();
    await scanner.importM3u(m3uFile);
    await loadPlaylists();
  }

  Future<File?> exportPlaylistToM3u(Playlist playlist) async {
    var scanner = MusicScanner();
    return await scanner.exportPlaylistToM3u(playlist);
  }

  Future<void> reorderPlaylistSongs(
    String playlistId,
    List<int> reorderedIds,
  ) async {
    var scanner = MusicScanner();
    await scanner.reorderPlaylistSongs(playlistId, reorderedIds);
    await loadPlaylists();
  }
}
