import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';

/// Provides media browsing capabilities for Android Auto / Automotive OS.
///
/// Builds a hierarchical [MediaItem] tree from the user's local music library
/// so that Android Auto can display Songs, Albums, Artists, and Playlists tabs
/// on the car head unit.
///
/// The tree structure is:
/// ```
/// root
/// ├── root_songs      → all songs (playable)
/// ├── root_albums     → album folders (browsable)
/// │   └── album:<key> → songs in album (playable)
/// ├── root_artists    → artist folders (browsable)
/// │   └── artist:<name> → songs by artist (playable)
/// └── root_playlists  → playlist folders (browsable)
///     └── playlist:<id> → songs in playlist (playable)
/// ```
class AndroidAutoMediaBrowser {
  // Media ID prefixes for the browsing tree.
  static const rootId = 'root';
  static const rootSongs = 'root_songs';
  static const rootAlbums = 'root_albums';
  static const rootArtists = 'root_artists';
  static const rootPlaylists = 'root_playlists';
  static const albumPrefix = 'album:';
  static const artistPrefix = 'artist:';
  static const playlistPrefix = 'playlist:';

  // Data sources — set by PlayerProvider whenever the library updates.
  List<Song> _allSongs = [];
  List<AlbumGroup> _albums = [];
  List<ArtistGroup> _artists = [];
  List<Playlist> _playlists = [];

  /// Updates the cached library data for media browsing.
  void updateLibrary({
    required List<Song> songs,
    required List<AlbumGroup> albums,
    required List<ArtistGroup> artists,
    required List<Playlist> playlists,
  }) {
    _allSongs = songs;
    _albums = albums;
    _artists = artists;
    _playlists = playlists;
  }

  /// Returns the children [MediaItem]s for the given [parentMediaId].
  ///
  /// Called by Android Auto when the user navigates the media browse tree.
  List<MediaItem> getChildren(String parentMediaId) {
    switch (parentMediaId) {
      case rootId:
        return _buildRootItems();
      case rootSongs:
        return _buildSongItems(_allSongs);
      case rootAlbums:
        return _buildAlbumBrowseItems();
      case rootArtists:
        return _buildArtistBrowseItems();
      case rootPlaylists:
        return _buildPlaylistBrowseItems();
      default:
        if (parentMediaId.startsWith(albumPrefix)) {
          return _buildAlbumChildren(
            parentMediaId.substring(albumPrefix.length),
          );
        }
        if (parentMediaId.startsWith(artistPrefix)) {
          return _buildArtistChildren(
            parentMediaId.substring(artistPrefix.length),
          );
        }
        if (parentMediaId.startsWith(playlistPrefix)) {
          return _buildPlaylistChildren(
            parentMediaId.substring(playlistPrefix.length),
          );
        }
        return [];
    }
  }

  /// Returns the [MediaItem] for the given [mediaId], or `null` if not found.
  MediaItem? getItem(String mediaId) {
    // Check if it's a browsable category
    for (var item in _buildRootItems()) {
      if (item.id == mediaId) return item;
    }

    // Check songs by file URI
    for (var song in _allSongs) {
      if (Uri.file(song.filePath).toString() == mediaId) {
        return _songToMediaItem(song);
      }
    }

    // Check album/artist/playlist browsable items
    if (mediaId.startsWith(albumPrefix)) {
      var key = mediaId.substring(albumPrefix.length);
      var album = _findAlbumByKey(key);
      if (album != null) return _albumToMediaItem(album);
    }
    if (mediaId.startsWith(artistPrefix)) {
      var name = mediaId.substring(artistPrefix.length);
      var artist = _findArtistByName(name);
      if (artist != null) return _artistToMediaItem(artist);
    }
    if (mediaId.startsWith(playlistPrefix)) {
      var id = mediaId.substring(playlistPrefix.length);
      var playlist = _findPlaylistById(id);
      if (playlist != null) return _playlistToMediaItem(playlist);
    }

    return null;
  }

  /// Searches the library for songs/albums/artists matching [query].
  ///
  /// Used by Google Assistant voice commands on Android Auto.
  List<MediaItem> search(String query) {
    var results = <MediaItem>[];
    var lowerQuery = query.toLowerCase();

    // Search songs by title
    for (var song in _allSongs) {
      if (song.titleLower.contains(lowerQuery) ||
          song.artistLower.contains(lowerQuery) ||
          song.albumLower.contains(lowerQuery)) {
        results.add(_songToMediaItem(song));
        if (results.length >= 20) break;
      }
    }

    return results;
  }

  /// Resolves a [mediaId] to a list of songs for playback.
  ///
  /// Returns `(songs, startIndex)` where [startIndex] is the index of the
  /// tapped song within the returned list (0 for folders/shuffle).
  (List<Song> songs, int startIndex)? resolveForPlayback(String mediaId) {
    // Direct song tap — find it and return the full context
    for (var i = 0; i < _allSongs.length; i++) {
      if (Uri.file(_allSongs[i].filePath).toString() == mediaId) {
        return (_allSongs, i);
      }
    }

    // Album folder play
    if (mediaId.startsWith(albumPrefix)) {
      var key = mediaId.substring(albumPrefix.length);
      var album = _findAlbumByKey(key);
      if (album != null && album.songs.isNotEmpty) {
        return (album.songs, 0);
      }
    }

    // Artist folder play
    if (mediaId.startsWith(artistPrefix)) {
      var name = mediaId.substring(artistPrefix.length);
      var artist = _findArtistByName(name);
      if (artist != null && artist.songs.isNotEmpty) {
        return (artist.songs, 0);
      }
    }

    // Playlist folder play
    if (mediaId.startsWith(playlistPrefix)) {
      var id = mediaId.substring(playlistPrefix.length);
      var playlist = _findPlaylistById(id);
      if (playlist != null && playlist.songIds.isNotEmpty) {
        var songs = <Song>[];
        for (var songId in playlist.songIds) {
          var song = _allSongs.where((s) => s.id == songId).firstOrNull;
          if (song != null) songs.add(song);
        }
        if (songs.isNotEmpty) return (songs, 0);
      }
    }

    return null;
  }

  /// Resolves a search [query] to a list of songs for playback.
  ///
  /// Used by `playFromSearch` when the user says e.g.
  /// *"Play Daft Punk on Sonora"* via Google Assistant.
  (List<Song> songs, int startIndex)? resolveSearchForPlayback(String query) {
    var lowerQuery = query.toLowerCase();

    // 1. Try matching an artist name exactly or closely
    for (var artist in _artists) {
      if (artist.nameLower == lowerQuery ||
          artist.nameLower.contains(lowerQuery)) {
        if (artist.songs.isNotEmpty) return (artist.songs, 0);
      }
    }

    // 2. Try matching an album name
    for (var album in _albums) {
      if (album.nameLower == lowerQuery ||
          album.nameLower.contains(lowerQuery)) {
        if (album.songs.isNotEmpty) return (album.songs, 0);
      }
    }

    // 3. Try matching a song title
    for (var i = 0; i < _allSongs.length; i++) {
      if (_allSongs[i].titleLower.contains(lowerQuery)) {
        return (_allSongs, i);
      }
    }

    // 4. Fallback: shuffle all songs if no match
    if (_allSongs.isNotEmpty) {
      var shuffled = List<Song>.from(_allSongs)..shuffle();
      return (shuffled, 0);
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Private: Root items
  // ---------------------------------------------------------------------------

  List<MediaItem> _buildRootItems() {
    return [
      const MediaItem(
        id: rootSongs,
        title: 'Songs',
        playable: false,
        extras: {'browsable': true},
      ),
      const MediaItem(
        id: rootAlbums,
        title: 'Albums',
        playable: false,
        extras: {'browsable': true},
      ),
      const MediaItem(
        id: rootArtists,
        title: 'Artists',
        playable: false,
        extras: {'browsable': true},
      ),
      const MediaItem(
        id: rootPlaylists,
        title: 'Playlists',
        playable: false,
        extras: {'browsable': true},
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Private: Song items
  // ---------------------------------------------------------------------------

  List<MediaItem> _buildSongItems(List<Song> songs) {
    return songs.map(_songToMediaItem).toList();
  }

  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: Uri.file(song.filePath).toString(),
      title: song.displayTitle,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: song.artworkPath != null ? Uri.file(song.artworkPath!) : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Private: Album items
  // ---------------------------------------------------------------------------

  List<MediaItem> _buildAlbumBrowseItems() {
    return _albums.map(_albumToMediaItem).toList();
  }

  MediaItem _albumToMediaItem(AlbumGroup album) {
    Uri? artUri;
    // Use the first song's artwork as the album cover
    for (var song in album.songs) {
      if (song.artworkPath != null && File(song.artworkPath!).existsSync()) {
        artUri = Uri.file(song.artworkPath!);
        break;
      }
    }

    return MediaItem(
      id: '$albumPrefix${album.name}|||${album.artist}',
      title: album.name,
      artist: album.artist,
      artUri: artUri,
      playable: false,
      extras: {'browsable': true},
    );
  }

  List<MediaItem> _buildAlbumChildren(String albumKey) {
    var album = _findAlbumByKey(albumKey);
    if (album == null) return [];
    return _buildSongItems(album.songs);
  }

  AlbumGroup? _findAlbumByKey(String key) {
    // Key format: "AlbumName|||ArtistName"
    var parts = key.split('|||');
    if (parts.length < 2) return null;
    var albumName = parts[0];
    var artistName = parts[1];
    return _albums
        .where((a) => a.name == albumName && a.artist == artistName)
        .firstOrNull;
  }

  // ---------------------------------------------------------------------------
  // Private: Artist items
  // ---------------------------------------------------------------------------

  List<MediaItem> _buildArtistBrowseItems() {
    return _artists.map(_artistToMediaItem).toList();
  }

  MediaItem _artistToMediaItem(ArtistGroup artist) {
    Uri? artUri;
    // Use local artist image if available, else first song's artwork
    if (artist.localImagePath != null &&
        File(artist.localImagePath!).existsSync()) {
      artUri = Uri.file(artist.localImagePath!);
    } else {
      for (var song in artist.songs) {
        if (song.artworkPath != null && File(song.artworkPath!).existsSync()) {
          artUri = Uri.file(song.artworkPath!);
          break;
        }
      }
    }

    return MediaItem(
      id: '$artistPrefix${artist.name}',
      title: artist.name,
      artist: '${artist.songs.length} songs',
      artUri: artUri,
      playable: false,
      extras: {'browsable': true},
    );
  }

  List<MediaItem> _buildArtistChildren(String artistName) {
    var artist = _findArtistByName(artistName);
    if (artist == null) return [];
    return _buildSongItems(artist.songs);
  }

  ArtistGroup? _findArtistByName(String name) {
    return _artists.where((a) => a.name == name).firstOrNull;
  }

  // ---------------------------------------------------------------------------
  // Private: Playlist items
  // ---------------------------------------------------------------------------

  List<MediaItem> _buildPlaylistBrowseItems() {
    return _playlists.map(_playlistToMediaItem).toList();
  }

  MediaItem _playlistToMediaItem(Playlist playlist) {
    Uri? artUri;
    if (playlist.coverImagePath != null &&
        File(playlist.coverImagePath!).existsSync()) {
      artUri = Uri.file(playlist.coverImagePath!);
    } else {
      // Use first song's artwork as fallback
      for (var songId in playlist.songIds) {
        var song = _allSongs.where((s) => s.id == songId).firstOrNull;
        if (song?.artworkPath != null &&
            File(song!.artworkPath!).existsSync()) {
          artUri = Uri.file(song.artworkPath!);
          break;
        }
      }
    }

    return MediaItem(
      id: '$playlistPrefix${playlist.id}',
      title: playlist.name,
      artist: '${playlist.songIds.length} songs',
      artUri: artUri,
      playable: false,
      extras: {'browsable': true},
    );
  }

  List<MediaItem> _buildPlaylistChildren(String playlistId) {
    var playlist = _findPlaylistById(playlistId);
    if (playlist == null) return [];

    var songs = <Song>[];
    for (var songId in playlist.songIds) {
      var song = _allSongs.where((s) => s.id == songId).firstOrNull;
      if (song != null) songs.add(song);
    }
    return _buildSongItems(songs);
  }

  Playlist? _findPlaylistById(String id) {
    return _playlists.where((p) => p.id == id).firstOrNull;
  }
}
