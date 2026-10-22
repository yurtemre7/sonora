part of 'music_scanner.dart';

/// Playlist storage, favorites and M3U import/export.
extension ScannerPlaylists on MusicScanner {
  // --- Playlists API ---

  /// Reads the playlists list from SharedPreferencesAsync (with fallback migration to playlists.json).
  Future<List<Playlist>> getPlaylists() async {
    try {
      return await getPlaylistsStrict();
    } catch (_) {
      return [];
    }
  }

  /// Like [getPlaylists] but throws when stored playlists cannot be read, so callers can tell "no playlists" from "read failed".
  Future<List<Playlist>> getPlaylistsStrict() async {
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
  }

  /// Writes the playlists list to SharedPreferencesAsync and disk backup.
  Future<void> savePlaylists(List<Playlist> playlists) async {
    try {
      await savePlaylistsStrict(playlists);
    } catch (_) {}
  }

  /// Like [savePlaylists] but throws when the primary (prefs) write fails.
  /// The legacy disk copy stays best effort.
  Future<void> savePlaylistsStrict(List<Playlist> playlists) async {
    var jsonList = playlists.map((p) => p.toJson()).toList();
    var jsonStr = jsonEncode(jsonList);
    await _prefs.setString('playlists_json', jsonStr);

    // Keep legacy file updated as double backup so playlists are NEVER lost
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var file = File('${appDir.path}/playlists.json');
      await file.writeAsString(jsonStr);
    } catch (_) {}
  }

  /// Removes all stored playlists (prefs and legacy disk copy), returning
  /// to the state of a fresh install. Throws when the prefs write fails.
  Future<void> clearStoredPlaylistsStrict() async {
    await _prefs.remove('playlists_json');
    var appDir = await getApplicationDocumentsDirectory();
    var file = File('${appDir.path}/playlists.json');
    if (file.existsSync()) await file.delete();
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

  /// Sets favorite status for multiple songs atomically.
  Future<List<Song>> setFavoriteSongs(
    List<int> songIds,
    bool isFavorite,
  ) async {
    try {
      var songs = await _readImportedSongsMetadata();
      var idSet = songIds.toSet();
      var now = isFavorite ? DateTime.now().millisecondsSinceEpoch : null;
      var modified = false;

      for (var i = 0; i < songs.length; i++) {
        if (idSet.contains(songs[i].id)) {
          songs[i] = songs[i].copyWith(
            isFavorite: isFavorite,
            favoriteDateMs: now,
          );
          modified = true;
        }
      }

      if (modified) {
        await _writeImportedSongsMetadata(songs);
      }
      return songs;
    } catch (_) {
      return [];
    }
  }

  /// Returns the cached library exactly as stored, without sorting or
  /// triggering any background work. Throws when the cache exists but cannot
  /// be read; returns an empty list when there is no cache yet.
  Future<List<Song>> readLibrarySongs() => _readImportedSongsMetadataStrict();

  /// Writes [songs] as the library cache; throws when the write fails.
  Future<void> writeLibrarySongs(List<Song> songs) =>
      _writeImportedSongsMetadataStrict(songs);

  /// Marks the songs in [favoriteDates] (song id to favorite timestamp) as
  /// favorites. Songs that already are favorites keep their current date, so
  /// running this twice changes nothing the second time. Throws when the
  /// library cannot be read or written.
  Future<List<Song>> mergeFavoriteSongs(Map<int, int?> favoriteDates) async {
    var songs = await _readImportedSongsMetadataStrict();
    if (favoriteDates.isEmpty) return songs;
    var now = DateTime.now().millisecondsSinceEpoch;
    var modified = false;

    for (var i = 0; i < songs.length; i++) {
      var song = songs[i];
      if (song.isFavorite || !favoriteDates.containsKey(song.id)) continue;
      songs[i] = song.copyWith(
        isFavorite: true,
        favoriteDateMs: favoriteDates[song.id] ?? now,
      );
      modified = true;
    }

    if (modified) {
      await _writeImportedSongsMetadataStrict(songs);
    }
    return songs;
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
    await addSongsToPlaylist(playlistId, [songId]);
  }

  /// Adds multiple songs to a playlist if not already present.
  Future<void> addSongsToPlaylist(String playlistId, List<int> songIds) async {
    if (songIds.isEmpty) return;
    var playlists = await getPlaylists();
    for (var i = 0; i < playlists.length; i++) {
      if (playlists[i].id == playlistId) {
        var existingSet = playlists[i].songIds.toSet();
        var toAdd = songIds.where((id) => !existingSet.contains(id)).toList();
        if (toAdd.isNotEmpty) {
          playlists[i].songIds.addAll(toAdd);
          await savePlaylists(playlists);
        }
        break;
      }
    }
  }

  /// Removes a song from a playlist.
  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    await removeSongsFromPlaylist(playlistId, [songId]);
  }

  /// Removes multiple songs from a playlist.
  Future<void> removeSongsFromPlaylist(
    String playlistId,
    List<int> songIds,
  ) async {
    if (songIds.isEmpty) return;
    var playlists = await getPlaylists();
    var idSet = songIds.toSet();
    for (var i = 0; i < playlists.length; i++) {
      if (playlists[i].id == playlistId) {
        playlists[i].songIds.removeWhere(idSet.contains);
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
        playlists[i] = playlists[i].copyWith(
          description: description,
          clearDescription: description == null,
        );
        await savePlaylists(playlists);
        break;
      }
    }
  }

  /// Reorders songs within an existing playlist.
  Future<void> reorderPlaylistSongs(
    String playlistId,
    List<int> reorderedIds,
  ) async {
    var playlists = await getPlaylists();
    for (var i = 0; i < playlists.length; i++) {
      if (playlists[i].id == playlistId) {
        playlists[i] = playlists[i].copyWith(songIds: reorderedIds);
        await savePlaylists(playlists);
        break;
      }
    }
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
}
