import 'package:flutter/material.dart';

import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/screens/album_detail_screen.dart';
import 'package:sonora/screens/artist_detail_screen.dart';
import 'package:sonora/screens/now_playing_screen.dart';
import 'package:sonora/screens/playlist_detail_screen.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/mini_player.dart';
import 'package:sonora/widgets/playlist_selector.dart';
import 'package:sonora/widgets/song_tile.dart';

class AlbumGroup {
  final String name;
  final String artist;
  final List<Song> songs;

  AlbumGroup({required this.name, required this.artist, required this.songs});
}

class ArtistGroup {
  final String name;
  final List<Song> songs;
  final List<AlbumGroup> albums;

  ArtistGroup({required this.name, required this.songs, required this.albums});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.playerProvider,
    required this.songs,
    required this.playlists,
    required this.onOpenSettings,
    required this.scanFolder,
    required this.onConfigureFolder,
    required this.onCreatePlaylist,
    required this.onDeletePlaylist,
    required this.onAddSongToPlaylist,
    required this.onRemoveSongFromPlaylist,
    required this.onReorderPlaylistSongs,
    required this.isSyncing,
    required this.showSyncPrompt,
    required this.onResyncNow,
    required this.onPostponeSync,
  });

  final PlayerProvider playerProvider;
  final List<Song> songs;
  final List<Playlist> playlists;
  final VoidCallback onOpenSettings;
  final String? scanFolder;
  final VoidCallback onConfigureFolder;
  final Future<void> Function(String name) onCreatePlaylist;
  final Future<void> Function(String playlistId) onDeletePlaylist;
  final Future<void> Function(String playlistId, int songId)
  onAddSongToPlaylist;
  final Future<void> Function(String playlistId, int songId)
  onRemoveSongFromPlaylist;
  final Future<void> Function(String playlistId, List<int> reorderedIds)
  onReorderPlaylistSongs;
  final bool isSyncing;
  final bool showSyncPrompt;
  final Future<void> Function() onResyncNow;
  final VoidCallback onPostponeSync;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  var _searchQuery = '';
  var _songSortBy = 'title';
  var _songSortAscending = true;
  var _albumSortBy = 'name';
  var _albumSortAscending = true;
  var _artistSortBy = 'name';
  var _artistSortAscending = true;
  var _playlistSortBy = 'name';
  var _playlistSortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadSortSettings();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSortSettings() async {
    var scanner = MusicScanner();
    var songsSettings = await scanner.getTabSortSettings('songs');
    var albumsSettings = await scanner.getTabSortSettings('albums');
    var artistsSettings = await scanner.getTabSortSettings('artists');
    var playlistsSettings = await scanner.getTabSortSettings('playlists');
    _songSortBy = songsSettings['sortBy'] as String;
    _songSortAscending = songsSettings['sortAscending'] as bool;
    _albumSortBy = albumsSettings['sortBy'] as String;
    _albumSortAscending = albumsSettings['sortAscending'] as bool;
    _artistSortBy = artistsSettings['sortBy'] as String;
    _artistSortAscending = artistsSettings['sortAscending'] as bool;
    _playlistSortBy = playlistsSettings['sortBy'] as String;
    _playlistSortAscending = playlistsSettings['sortAscending'] as bool;
  }

  List<AlbumGroup> _getAlbums() {
    var albumsMap = <String, List<Song>>{};
    for (var song in widget.songs) {
      var albumName = song.album.trim().isEmpty ? 'Unknown Album' : song.album;
      albumsMap.putIfAbsent(albumName, () => []).add(song);
    }

    var list = albumsMap.entries.map((entry) {
      var artistCounts = <String, int>{};
      for (var s in entry.value) {
        artistCounts[s.artist] = (artistCounts[s.artist] ?? 0) + 1;
      }
      var albumArtist = 'Unknown Artist';
      var maxCount = 0;
      artistCounts.forEach((artist, count) {
        if (count > maxCount) {
          maxCount = count;
          albumArtist = artist;
        }
      });

      return AlbumGroup(
        name: entry.key,
        artist: albumArtist,
        songs: entry.value,
      );
    }).toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<ArtistGroup> _getArtists() {
    var artistsMap = <String, List<Song>>{};
    for (var song in widget.songs) {
      var artistName = song.artist.trim().isEmpty
          ? 'Unknown Artist'
          : song.artist;
      artistsMap.putIfAbsent(artistName, () => []).add(song);
    }

    var albumsList = _getAlbums();

    var list = artistsMap.entries.map((entry) {
      var artistAlbums = albumsList
          .where((a) => a.artist == entry.key)
          .toList();
      return ArtistGroup(
        name: entry.key,
        songs: entry.value,
        albums: artistAlbums,
      );
    }).toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<Song> _getFilteredSongs() {
    var filtered = widget.songs.where((song) {
      if (_searchQuery.isEmpty) return true;
      var query = _searchQuery.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          song.album.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      int comparison;
      if (_songSortBy == 'artist') {
        comparison = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      } else if (_songSortBy == 'duration') {
        comparison = a.duration.compareTo(b.duration);
      } else if (_songSortBy == 'recent') {
        var aTime = a.lastModifiedMs ?? 0;
        var bTime = b.lastModifiedMs ?? 0;
        comparison = bTime.compareTo(aTime);
      } else {
        comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return _songSortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  List<AlbumGroup> _getFilteredAlbums() {
    var albums = _getAlbums();
    if (_searchQuery.isNotEmpty) {
      var query = _searchQuery.toLowerCase();
      albums = albums
          .where(
            (a) =>
                a.name.toLowerCase().contains(query) ||
                a.artist.toLowerCase().contains(query),
          )
          .toList();
    }
    albums.sort((a, b) {
      int cmp;
      if (_albumSortBy == 'artist') {
        cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      } else if (_albumSortBy == 'tracks') {
        cmp = a.songs.length.compareTo(b.songs.length);
      } else {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _albumSortAscending ? cmp : -cmp;
    });
    return albums;
  }

  List<ArtistGroup> _getFilteredArtists() {
    var artists = _getArtists();
    if (_searchQuery.isNotEmpty) {
      var query = _searchQuery.toLowerCase();
      artists = artists
          .where((a) => a.name.toLowerCase().contains(query))
          .toList();
    }
    artists.sort((a, b) {
      int cmp;
      if (_artistSortBy == 'albums') {
        cmp = a.albums.length.compareTo(b.albums.length);
      } else if (_artistSortBy == 'songs') {
        cmp = a.songs.length.compareTo(b.songs.length);
      } else {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _artistSortAscending ? cmp : -cmp;
    });
    return artists;
  }

  List<Playlist> _getFilteredPlaylists() {
    var playlists = widget.playlists.toList();
    if (_searchQuery.isNotEmpty) {
      var query = _searchQuery.toLowerCase();
      playlists = playlists
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }
    playlists.sort((a, b) {
      int cmp;
      if (_playlistSortBy == 'songs') {
        var aCount = widget.songs.where((s) => a.songIds.contains(s.id)).length;
        var bCount = widget.songs.where((s) => b.songIds.contains(s.id)).length;
        cmp = aCount.compareTo(bCount);
      } else {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _playlistSortAscending ? cmp : -cmp;
    });
    return playlists;
  }

  void _showSortBottomSheet({int tabIndex = 0}) {
    var theme = Theme.of(context);

    String title;
    String subtitle;
    List<(String, String)> options;
    String tabName;

    switch (tabIndex) {
      case 1:
        title = 'Sort Albums By';
        subtitle =
            'Your sorting preference will be saved per tab and automatically applied on next startup.';
        tabName = 'albums';
        options = [
          ('Album Name', 'name'),
          ('Artist', 'artist'),
          ('Track Count', 'tracks'),
        ];
      case 2:
        title = 'Sort Artists By';
        subtitle =
            'Your sorting preference will be saved per tab and automatically applied on next startup.';
        tabName = 'artists';
        options = [
          ('Artist Name', 'name'),
          ('Album Count', 'albums'),
          ('Song Count', 'songs'),
        ];
      case 3:
        title = 'Sort Playlists By';
        subtitle =
            'Your sorting preference will be saved per tab and automatically applied on next startup.';
        tabName = 'playlists';
        options = [('Playlist Name', 'name'), ('Song Count', 'songs')];
      default:
        title = 'Sort Songs By';
        subtitle =
            'Your sorting preference will be saved per tab and automatically applied on next startup.';
        tabName = 'songs';
        options = [
          ('Title', 'title'),
          ('Artist', 'artist'),
          ('Duration', 'duration'),
          ('Recently Added', 'recent'),
        ];
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RadioGroup<String>(
                    groupValue: _sortByForTab(tabIndex),
                    onChanged: (val) {
                      setState(() => _setSortByForTab(tabIndex, val!));
                      setSheetState(() {});
                      MusicScanner().saveTabSortSettings(
                        tabName,
                        _sortByForTab(tabIndex),
                        _sortAscendingForTab(tabIndex),
                      );
                      Navigator.pop(context);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: options.map((opt) {
                        return RadioListTile<String>(
                          title: Text(opt.$1),
                          value: opt.$2,
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Sort Ascending'),
                    value: _sortAscendingForTab(tabIndex),
                    onChanged: (val) {
                      setState(() => _setSortAscendingForTab(tabIndex, val));
                      setSheetState(() {});
                      MusicScanner().saveTabSortSettings(
                        tabName,
                        _sortByForTab(tabIndex),
                        _sortAscendingForTab(tabIndex),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _sortByForTab(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _albumSortBy;
      case 2:
        return _artistSortBy;
      case 3:
        return _playlistSortBy;
      default:
        return _songSortBy;
    }
  }

  bool _sortAscendingForTab(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _albumSortAscending;
      case 2:
        return _artistSortAscending;
      case 3:
        return _playlistSortAscending;
      default:
        return _songSortAscending;
    }
  }

  void _setSortByForTab(int tabIndex, String val) {
    switch (tabIndex) {
      case 1:
        _albumSortBy = val;
        break;
      case 2:
        _artistSortBy = val;
        break;
      case 3:
        _playlistSortBy = val;
        break;
      default:
        _songSortBy = val;
    }
  }

  void _setSortAscendingForTab(int tabIndex, bool val) {
    switch (tabIndex) {
      case 1:
        _albumSortAscending = val;
        break;
      case 2:
        _artistSortAscending = val;
        break;
      case 3:
        _playlistSortAscending = val;
        break;
      default:
        _songSortAscending = val;
    }
  }

  void _showSongInfoBottomSheet(Song song) {
    var theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Song Information',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Title', song.displayTitle, theme),
                _buildInfoRow('Artist', song.artist, theme),
                _buildInfoRow('Album', song.album, theme),
                _buildInfoRow('Duration', song.durationFormatted, theme),
                _buildInfoRow('File Path', song.filePath, theme, isPath: true),
                if (song.format != null)
                  _buildInfoRow('Format', song.format!.toUpperCase(), theme),
                if (song.bitrate != null)
                  _buildInfoRow('Bitrate', '${song.bitrate} kbps', theme),
                if (song.samplerate != null)
                  _buildInfoRow(
                    'Sample Rate',
                    '${(song.samplerate! / 1000).toStringAsFixed(1)} kHz',
                    theme,
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    ThemeData theme, {
    bool isPath = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontFamily: isPath ? 'monospace' : null,
              fontSize: isPath ? 12 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterHeader(ThemeData theme) {
    var tabIndex = _tabController.index;
    String label;
    int count;
    VoidCallback? onShuffle;
    VoidCallback onSort;

    void unfocus() => _searchFocusNode.unfocus();

    switch (tabIndex) {
      case 1:
        var albums = _getFilteredAlbums();
        count = albums.length;
        label = '$count ${count == 1 ? 'album' : 'albums'} found';
        onShuffle = () {
          unfocus();
          widget.playerProvider.quickShuffle(
            albums.expand((a) => a.songs).toList(),
          );
        };
        onSort = () {
          unfocus();
          _showSortBottomSheet(tabIndex: 1);
        };
      case 2:
        var artists = _getFilteredArtists();
        count = artists.length;
        label = '$count ${count == 1 ? 'artist' : 'artists'} found';
        onShuffle = () {
          unfocus();
          widget.playerProvider.quickShuffle(
            artists.expand((a) => a.songs).toList(),
          );
        };
        onSort = () {
          unfocus();
          _showSortBottomSheet(tabIndex: 2);
        };
      case 3:
        var playlists = _getFilteredPlaylists();
        count = playlists.length;
        label = '$count ${count == 1 ? 'playlist' : 'playlists'} found';
        onShuffle = null;
        onSort = () {
          unfocus();
          _showSortBottomSheet(tabIndex: 3);
        };
      default:
        var songs = _getFilteredSongs();
        count = songs.length;
        label = '$count ${count == 1 ? 'song' : 'songs'} found';
        onShuffle = () {
          unfocus();
          widget.playerProvider.quickShuffle(songs);
        };
        onSort = () {
          unfocus();
          _showSortBottomSheet();
        };
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: switch (tabIndex) {
                      1 => 'Search albums...',
                      2 => 'Search artists...',
                      3 => 'Search playlists...',
                      _ => 'Search songs, artists...',
                    },
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (onShuffle != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.shuffle_rounded),
                  onPressed: onShuffle,
                  tooltip: 'Shuffle Play',
                ),
              ],
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.sort_rounded),
                onPressed: onSort,
                tooltip: 'Sort',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog() {
    var textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              var name = textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogContext);
                await widget.onCreatePlaylist(name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(Song song) {
    PlaylistSelectorBottomSheet.show(context, song, widget.playerProvider);
  }

  Widget _buildSyncPromptBanner(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sync_problem_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Sync Library Database?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "It's been at least a month since your last library synchronization. Sonora runs offline—if you have loaded new music files into your device folder, run a sync now to discover and listen to them.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.9,
                ),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onPostponeSync,
                  child: Text(
                    'Remind Next Month',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: widget.onResyncNow,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sync Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.playerProvider,
        builder: (context, _) {
          var currentSong = widget.playerProvider.currentSong;
          if (currentSong == null) return const SizedBox.shrink();

          return StreamBuilder<Duration>(
            stream: widget.playerProvider.audioHandler.player.positionStream,
            builder: (context, snapshot) {
              var position = snapshot.data ?? Duration.zero;
              var totalMs = currentSong.duration.inMilliseconds;
              var progress = totalMs > 0
                  ? position.inMilliseconds / totalMs
                  : 0.0;

              return MiniPlayer(
                currentSong: currentSong,
                isPlaying: widget.playerProvider.audioHandler.player.playing,
                progress: progress,
                onTap: () {
                  _searchFocusNode.unfocus();
                  _openNowPlaying(context);
                },
                onPlayPause: widget.playerProvider.playPause,
                onNext: widget.playerProvider.next,
                onSwipeUp: () {
                  _searchFocusNode.unfocus();
                  _openNowPlaying(context);
                },
                onSwipeDown: widget.playerProvider.stop,
                onSwipeLeft: widget.playerProvider.previous,
                onSwipeRight: widget.playerProvider.next,
              );
            },
          );
        },
      ),
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              expandedHeight: 120,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () {
                    _searchFocusNode.unfocus();
                    widget.onOpenSettings();
                  },
                  tooltip: 'Settings',
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
                title: Text(
                  'Sonora',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(widget.isSyncing ? 56 : 54),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isSyncing)
                      const LinearProgressIndicator(minHeight: 2),
                    Container(
                      height: 38,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        splashBorderRadius: BorderRadius.circular(18),
                        indicator: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        labelColor: theme.colorScheme.onPrimaryContainer,
                        labelStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                        unselectedLabelStyle: theme.textTheme.labelLarge,
                        tabs: [
                          const Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Songs'),
                            ),
                          ),
                          const Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Albums'),
                            ),
                          ),
                          const Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Artists'),
                            ),
                          ),
                          const Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Playlists'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            _buildSearchAndFilterHeader(theme),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                      // Tab 1: Songs
                      widget.songs.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32.0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.scanFolder == null
                                          ? Icons.folder_open_rounded
                                          : Icons.music_off_rounded,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      widget.scanFolder == null
                                          ? 'Set Music Directory'
                                          : 'No music files found',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.scanFolder == null
                                          ? 'Choose a folder directory on your device to scan and play music from.'
                                          : 'Please put some audio files (e.g. .mp3, .m4a) in the folder:\n\n${widget.scanFolder}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.7),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton.icon(
                                      onPressed: widget.onConfigureFolder,
                                      icon: Icon(
                                        widget.scanFolder == null
                                            ? Icons.folder_copy_rounded
                                            : Icons.create_new_folder_rounded,
                                      ),
                                      label: Text(
                                        widget.scanFolder == null
                                            ? 'Set Sync Folder'
                                            : 'Change Folder',
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.primaryContainer,
                                        foregroundColor: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                if (widget.showSyncPrompt)
                                  _buildSyncPromptBanner(theme),
                                Expanded(
                                  child: _getFilteredSongs().isEmpty
                                      ? Center(
                                          child: Text(
                                            'No matching songs found',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        )
                                      : ListenableBuilder(
                                          listenable: widget.playerProvider,
                                          builder: (context, _) {
                                            var filteredSongs =
                                                _getFilteredSongs();
                                            var currentSong = widget
                                                .playerProvider
                                                .currentSong;
                                            return RefreshIndicator(
                                              onRefresh: widget.onResyncNow,
                                              child: ListView.builder(
                                                  primary: true,
                                                  physics: const AlwaysScrollableScrollPhysics(),
                                                  padding: const EdgeInsets.only(
                                                    bottom: 100,
                                                  ),
                                                  itemCount: filteredSongs.length,
                                                itemBuilder: (context, index) {
                                                  var song =
                                                      filteredSongs[index];
                                                  var isCurrent =
                                                      currentSong != null &&
                                                      currentSong.id == song.id;
                                                  return SongTile(
                                                    song: song,
                                                    isCurrent: isCurrent,
                                                    showDivider:
                                                        index <
                                                        filteredSongs.length -
                                                            1,
                                                    onTap: () {
                                                      _searchFocusNode
                                                          .unfocus();
                                                      widget.playerProvider
                                                          .playSong(
                                                            song,
                                                            filteredSongs,
                                                          );
                                                    },
                                                    onPlayNext: () => widget
                                                        .playerProvider
                                                        .playNext(song),
                                                    onAddToQueue: () => widget
                                                        .playerProvider
                                                        .addToQueue(song),
                                                    onAddToPlaylist: () =>
                                                        _showAddToPlaylistDialog(
                                                          song,
                                                        ),
                                                    onShowInfo: () =>
                                                        _showSongInfoBottomSheet(
                                                          song,
                                                        ),
                                                    onToggleFavorite: () =>
                                                        widget.playerProvider
                                                            .toggleFavorite(
                                                              song.id,
                                                            ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),

                      // Tab 2: Albums
                      widget.songs.isEmpty
                          ? Center(
                              child: Text(
                                'No albums found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : _getFilteredAlbums().isEmpty
                          ? Center(
                              child: Text(
                                'No matching albums found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: widget.onResyncNow,
                              child: GridView.builder(
                                  primary: true,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                  top: 16,
                                  bottom: 100,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.78,
                                    ),
                                itemCount: _getFilteredAlbums().length,
                                itemBuilder: (context, index) {
                                  var album = _getFilteredAlbums()[index];
                                  var firstSong = album.songs.first;

                                  return InkWell(
                                    onTap: () {
                                      _searchFocusNode.unfocus();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AlbumDetailScreen(
                                                album: album,
                                                playerProvider:
                                                    widget.playerProvider,
                                              ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: AspectRatio(
                                            aspectRatio: 1.0,
                                            child: AlbumArt(
                                              artworkPath:
                                                  firstSong.artworkPath,
                                              size: 200,
                                              borderRadius: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          album.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Outfit',
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          album.artist,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${album.songs.length} ${album.songs.length == 1 ? 'track' : 'tracks'}',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                      // Tab 3: Artists
                      widget.songs.isEmpty
                          ? Center(
                              child: Text(
                                'No artists found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : _getFilteredArtists().isEmpty
                          ? Center(
                              child: Text(
                                'No matching artists found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: widget.onResyncNow,
                              child: ListView.builder(
                                  primary: true,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 100,
                                ),
                                itemCount: _getFilteredArtists().length,
                                itemBuilder: (context, index) {
                                  var artist = _getFilteredArtists()[index];
                                  var firstSong = artist.songs.first;
                                  var artists = _getFilteredArtists();

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.15,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: AlbumArt(
                                              artworkPath:
                                                  firstSong.artworkPath,
                                              size: 48,
                                              borderRadius: 0,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          artist.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Outfit',
                                              ),
                                        ),
                                        subtitle: Text(
                                          '${artist.albums.length} ${artist.albums.length == 1 ? 'album' : 'albums'} • ${artist.songs.length} ${artist.songs.length == 1 ? 'song' : 'songs'}',
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right_rounded,
                                        ),
                                        onTap: () {
                                          _searchFocusNode.unfocus();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ArtistDetailScreen(
                                                    artist: artist,
                                                    playerProvider:
                                                        widget.playerProvider,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (index < artists.length - 1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 72,
                                          ),
                                          child: Divider(
                                            height: 1,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.06),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),

                      // Tab 4: Playlists
                      widget.playlists.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32.0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.queue_music_rounded,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No playlists yet',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Create custom playlists to group and organize your synced music files.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.7),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton.icon(
                                      onPressed: _showCreatePlaylistDialog,
                                      icon: const Icon(
                                        Icons.playlist_add_rounded,
                                      ),
                                      label: const Text('Create Playlist'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _getFilteredPlaylists().isEmpty
                          ? Center(
                              child: Text(
                                'No matching playlists found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: widget.onResyncNow,
                              child: ListView.builder(
                                  primary: true,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 100),
                                itemCount: _getFilteredPlaylists().length,
                                itemBuilder: (context, index) {
                                  var playlist = _getFilteredPlaylists()[index];
                                  var songCount = widget.songs
                                      .where(
                                        (s) => playlist.songIds.contains(s.id),
                                      )
                                      .length;
                                  var playlists = _getFilteredPlaylists();

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                theme
                                                    .colorScheme
                                                    .primaryContainer,
                                                theme
                                                    .colorScheme
                                                    .secondaryContainer,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Icon(
                                            playlist.id == 'favorites'
                                                ? Icons.favorite_rounded
                                                : Icons.music_note_rounded,
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                        ),
                                        title: Text(playlist.name),
                                        subtitle: Text(
                                          '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                                        ),
                                        trailing: playlist.id == 'favorites'
                                            ? null
                                            : PopupMenuButton<int>(
                                                icon: const Icon(
                                                  Icons.more_vert_rounded,
                                                ),
                                                onSelected: (val) async {
                                                  if (val == 1) {
                                                    await widget
                                                        .onDeletePlaylist(
                                                          playlist.id,
                                                        );
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Playlist "${playlist.name}" deleted.',
                                                        ),
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                      ),
                                                    );
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                    value: 1,
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Delete Playlist',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        onTap: () {
                                          _searchFocusNode.unfocus();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PlaylistDetailScreen(
                                                    playlist: playlist,
                                                    songs: widget.songs,
                                                    playerProvider:
                                                        widget.playerProvider,
                                                    onRemoveSong: widget
                                                        .onRemoveSongFromPlaylist,
                                                    onReorderSongs: widget
                                                        .onReorderPlaylistSongs,
                                                    playlists: widget.playlists,
                                                    onAddSongToPlaylist: widget
                                                        .onAddSongToPlaylist,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (index < playlists.length - 1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 72,
                                          ),
                                          child: Divider(
                                            height: 1,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.06),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
      ),
      floatingActionButton:
          _tabController.index == 3 && widget.playlists.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showCreatePlaylistDialog,
              child: const Icon(Icons.playlist_add_rounded),
            )
          : null,
    );
  }

  void _openNowPlaying(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          NowPlayingScreen(playerProvider: widget.playerProvider),
    );
  }
}
