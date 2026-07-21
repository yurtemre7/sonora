import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/screens/favorites_screen.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/services/update_service.dart';
import 'package:sonora/utils/format_utils.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/confirm_delete_dialog.dart';
import 'package:sonora/widgets/rename_playlist_dialog.dart';
import 'package:sonora/widgets/song_tile.dart';
import 'package:sonora/widgets/update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.playerProvider,
    required this.songs,
    required this.onOpenSettings,
    required this.scanFolder,
    required this.onConfigureFolder,
    required this.onCreatePlaylist,
    required this.onDeletePlaylist,
    required this.onRenamePlaylist,
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
  final VoidCallback onOpenSettings;
  final String? scanFolder;
  final VoidCallback onConfigureFolder;
  final Future<void> Function(String name) onCreatePlaylist;
  final Future<void> Function(String playlistId) onDeletePlaylist;
  final Future<void> Function(String playlistId, String newName) onRenamePlaylist;
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
  final _scrollController = ScrollController();
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
    _songSortBy = SettingsProvider.instance.songSortBy;
    _songSortAscending = SettingsProvider.instance.songSortAscending;
    _albumSortBy = SettingsProvider.instance.albumSortBy;
    _albumSortAscending = SettingsProvider.instance.albumSortAscending;
    _artistSortBy = SettingsProvider.instance.artistSortBy;
    _artistSortAscending = SettingsProvider.instance.artistSortAscending;
    _playlistSortBy = SettingsProvider.instance.playlistSortBy;
    _playlistSortAscending = SettingsProvider.instance.playlistSortAscending;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: SettingsProvider.instance.defaultStartPage,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdateAutomatically();
    });
  }

  Future<void> _checkUpdateAutomatically() async {
    if (kDebugMode) return;

    var result = await UpdateService.checkForUpdate();
    if (result.update != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => UpdateDialog(updateInfo: result.update!),
      );
    }
  }

  List<AlbumGroup> _getAlbums() {
    if (widget.playerProvider.cachedAlbums.isNotEmpty) {
      return List<AlbumGroup>.from(widget.playerProvider.cachedAlbums);
    }
    return buildAlbumGroups(widget.songs);
  }

  List<ArtistGroup> _getArtists() {
    if (widget.playerProvider.cachedArtists.isNotEmpty) {
      return List<ArtistGroup>.from(widget.playerProvider.cachedArtists);
    }
    var albumsList = _getAlbums();
    return buildArtistGroups(widget.songs, albumsList);
  }

  List<Song> _getFilteredSongs() {
    // Pre-compute the query lowercase once — not once per element in where().
    var query = _searchQuery.isEmpty ? '' : _searchQuery.toLowerCase();

    var filtered = query.isEmpty
        ? widget.songs
        : widget.songs.where((song) {
            return song.titleLower.contains(query) ||
                song.artistLower.contains(query) ||
                song.albumLower.contains(query);
          }).toList();

    filtered.sort((a, b) {
      int comparison;
      if (_songSortBy == 'artist') {
        comparison = a.artistLower.compareTo(b.artistLower);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (_songSortBy == 'duration') {
        comparison = a.duration.compareTo(b.duration);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (_songSortBy == 'recent') {
        var aTime = a.lastModifiedMs ?? 0;
        var bTime = b.lastModifiedMs ?? 0;
        comparison = bTime.compareTo(aTime);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else {
        comparison = a.titleLower.compareTo(b.titleLower);
      }

      if (comparison == 0) {
        comparison = a.id.compareTo(b.id);
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
            (a) => a.nameLower.contains(query) || a.artistLower.contains(query),
          )
          .toList();
    }
    albums.sort((a, b) {
      int cmp;
      if (_albumSortBy == 'artist') {
        cmp = a.artistLower.compareTo(b.artistLower);
      } else if (_albumSortBy == 'tracks') {
        cmp = a.songs.length.compareTo(b.songs.length);
      } else if (_albumSortBy == 'recent') {
        cmp = a.latestModifiedMs.compareTo(b.latestModifiedMs);
      } else {
        cmp = a.nameLower.compareTo(b.nameLower);
      }
      return _albumSortAscending ? cmp : -cmp;
    });
    return albums;
  }

  List<ArtistGroup> _getFilteredArtists() {
    var artists = _getArtists();
    if (_searchQuery.isNotEmpty) {
      var query = _searchQuery.toLowerCase();
      artists = artists.where((a) => a.nameLower.contains(query)).toList();
    }
    artists.sort((a, b) {
      int cmp;
      if (_artistSortBy == 'albums') {
        cmp = a.albums.length.compareTo(b.albums.length);
      } else if (_artistSortBy == 'songs') {
        cmp = a.songs.length.compareTo(b.songs.length);
      } else {
        cmp = a.nameLower.compareTo(b.nameLower);
      }
      return _artistSortAscending ? cmp : -cmp;
    });
    return artists;
  }

  List<Playlist> _getFilteredPlaylists() {
    var playlists = widget.playerProvider.playlists.toList();
    if (_searchQuery.isNotEmpty) {
      var query = _searchQuery.toLowerCase();
      playlists = playlists.where((p) => p.nameLower.contains(query)).toList();
    }
    playlists.sort((a, b) {
      int cmp;
      if (_playlistSortBy == 'songs') {
        var aCount = widget.songs.where((s) => a.songIds.contains(s.id)).length;
        var bCount = widget.songs.where((s) => b.songIds.contains(s.id)).length;
        cmp = aCount.compareTo(bCount);
      } else {
        cmp = a.nameLower.compareTo(b.nameLower);
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
          ('Recently Added', 'recent'),
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
      useRootNavigator: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
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
                          setState(
                            () => _setSortAscendingForTab(tabIndex, val),
                          );
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
                ),
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

  Widget _buildSearchAndFilterHeader(
    ThemeData theme, {
    required List<Song> filteredSongs,
    required List<AlbumGroup> filteredAlbums,
    required List<ArtistGroup> filteredArtists,
    required List<Playlist> filteredPlaylists,
  }) {
    var tabIndex = _tabController.index;
    String label;
    int count;
    VoidCallback? onShuffle;
    VoidCallback onSort;

    void unfocus() => _searchFocusNode.unfocus();

    switch (tabIndex) {
      case 1:
        count = filteredAlbums.length;
        label = '$count ${count == 1 ? 'album' : 'albums'}';
        onShuffle = () {
          unfocus();
          widget.playerProvider.quickShuffle(
            filteredAlbums.expand((a) => a.songs).toList(),
          );
        };
        onSort = () {
          unfocus();
          _showSortBottomSheet(tabIndex: 1);
        };
      case 2:
        count = filteredArtists.length;
        label = '$count ${count == 1 ? 'artist' : 'artists'}';
        onShuffle = () {
          unfocus();
          widget.playerProvider.quickShuffle(
            filteredArtists.expand((a) => a.songs).toList(),
          );
        };
        onSort = () {
          unfocus();
          _showSortBottomSheet(tabIndex: 2);
        };
      case 3:
        count = filteredPlaylists.length;
        label = '$count ${count == 1 ? 'playlist' : 'playlists'}';
        onShuffle = () {
          unfocus();
          _showCreatePlaylistDialog();
        };
        onSort = () {
          unfocus();
          _showSortBottomSheet(tabIndex: 3);
        };
      default:
        count = filteredSongs.length;
        var timeStr = formatTotalDuration(filteredSongs);
        label = '$count ${count == 1 ? 'song' : 'songs'} • $timeStr';
        onShuffle = () {
          unfocus();
          widget.playerProvider.quickShuffle(filteredSongs);
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
              ...[
                const SizedBox(width: 8),
                if (tabIndex != 3)
                  IconButton.filledTonal(
                    icon: const Icon(Icons.shuffle_rounded),
                    onPressed: onShuffle,
                    tooltip: 'Shuffle Play',
                  )
                else
                  IconButton.filledTonal(
                    icon: const Icon(Icons.playlist_add),
                    onPressed: onShuffle,
                    tooltip: 'Create a playlist',
                  ),
              ],
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.sort_rounded),
                onPressed: onSort,
                tooltip: 'Sort',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.favorite_rounded),
                onPressed: () {
                  unfocus();
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FavoritesScreen(
                      playerProvider: widget.playerProvider,
                      allSongs: widget.playerProvider.allSongs,
                      allAlbums: widget.playerProvider.cachedAlbums,
                      allArtists: widget.playerProvider.cachedArtists,
                    )
                  ));
                },
                tooltip: 'Favorites',
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
    _scrollController.dispose();
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
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
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

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        // Compute all filtered lists once per rebuild so both the header
        // (count label + shuffle) and the tab body share the same result.
        var filteredSongs = _getFilteredSongs();
        var filteredAlbums = _getFilteredAlbums();
        var filteredArtists = _getFilteredArtists();
        var filteredPlaylists = _getFilteredPlaylists();

        return Scaffold(
          body: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  backgroundColor: theme.colorScheme.surfaceContainer,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  expandedHeight: 120,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
                    title: ListenableBuilder(
                      listenable: SettingsProvider.instance,
                      builder: (context, _) {
                        if (SettingsProvider.instance.useGreetingTitle) {
                          var hour = DateTime.now().hour;
                          String greeting;
                          if (hour < 12) {
                            greeting = 'Good morning';
                          } else if (hour < 17) {
                            greeting = 'Good afternoon';
                          } else {
                            greeting = 'Good evening';
                          }
                          return Text(
                            '$greeting, ${SettingsProvider.instance.userName}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: theme.colorScheme.primary,
                            ),
                          );
                        }
                        return Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Sonora',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.headphones,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: Size.fromHeight(widget.isSyncing ? 56 : 54),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isSyncing)
                          const LinearProgressIndicator(minHeight: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 38,
                                margin: const EdgeInsets.only(
                                  left: 16,
                                  top: 8,
                                  bottom: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: TabBar(
                                  onTap: (index) {
                                    if (!_tabController.indexIsChanging) {
                                      _scrollController.animateTo(
                                        0,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                  },
                                  controller: _tabController,
                                  dividerColor: Colors.transparent,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  splashBorderRadius: BorderRadius.circular(18),
                                  indicator: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  labelColor:
                                      theme.colorScheme.onPrimaryContainer,
                                  labelStyle: theme.textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  unselectedLabelColor:
                                      theme.colorScheme.onSurfaceVariant,
                                  unselectedLabelStyle:
                                      theme.textTheme.labelLarge,
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
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.settings_rounded),
                              onPressed: () {
                                _searchFocusNode.unfocus();
                                widget.onOpenSettings();
                              },
                              tooltip: 'Settings',
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: Column(
              children: [
                _buildSearchAndFilterHeader(
                  theme,
                  filteredSongs: filteredSongs,
                  filteredAlbums: filteredAlbums,
                  filteredArtists: filteredArtists,
                  filteredPlaylists: filteredPlaylists,
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      switch (_tabController.index) {
                        case 1:
                          // Tab 2: Albums.
                          return widget.songs.isEmpty
                              ? Center(
                                  child: Text(
                                    'No albums found',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : filteredAlbums.isEmpty
                              ? Center(
                                  child: Text(
                                    'No matching albums found',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Scrollbar(
                                  child: RefreshIndicator(
                                    onRefresh: widget.onResyncNow,
                                    child: GridView.builder(
                                      key: const PageStorageKey<String>(
                                        'albums_grid',
                                      ),
                                      primary: true,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        top: 12,
                                        bottom: 120,
                                      ),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                            childAspectRatio: 0.78,
                                          ),
                                      itemCount: filteredAlbums.length,
                                      itemBuilder: (context, index) {
                                        var album = filteredAlbums[index];
                                        var firstSong = album.songs.first;

                                        return InkWell(
                                          onTap: () {
                                            _searchFocusNode.unfocus();
                                            openAlbum(context, album);
                                          },
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );

                        case 2:
                          // Tab 3: Artists.
                          return widget.songs.isEmpty
                              ? Center(
                                  child: Text(
                                    'No artists found',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : filteredArtists.isEmpty
                              ? Center(
                                  child: Text(
                                    'No matching artists found',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Scrollbar(
                                  child: RefreshIndicator(
                                    onRefresh: widget.onResyncNow,
                                    child: ListView.builder(
                                      key: const PageStorageKey<String>(
                                        'artists_list',
                                      ),
                                      primary: true,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.only(
                                        bottom: 120,
                                      ),
                                      itemCount: filteredArtists.length,
                                      itemBuilder: (context, index) {
                                        var artist = filteredArtists[index];
                                        var firstSong = artist.songs.first;

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
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        3,
                                                      ),
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
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                openArtist(context, artist);
                                              },
                                            ),
                                            if (index <
                                                filteredArtists.length - 1)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 72,
                                                ),
                                                child: Divider(
                                                  height: 1,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.06),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                );

                        case 3:
                          // Tab 4: Playlists.
                          return widget.playerProvider.playlists.isEmpty
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
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
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
                              : filteredPlaylists.isEmpty
                              ? Center(
                                  child: Text(
                                    'No matching playlists found',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Scrollbar(
                                  child: RefreshIndicator(
                                    onRefresh: widget.onResyncNow,
                                    child: ListView.builder(
                                      key: const PageStorageKey<String>(
                                        'playlists_list',
                                      ),
                                      primary: true,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.only(
                                        bottom: 120,
                                      ),
                                      itemCount: filteredPlaylists.length,
                                      itemBuilder: (context, index) {
                                        var playlist = filteredPlaylists[index];
                                        var songCount = widget.songs
                                            .where(
                                              (s) => playlist.songIds.contains(
                                                s.id,
                                              ),
                                            )
                                            .length;

                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
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
                                                      : Icons
                                                            .music_note_rounded,
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                                ),
                                              ),
                                              title: Text(playlist.name),
                                              subtitle: Text(
                                                '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                                              ),
                                              trailing:
                                                  playlist.id == 'favorites'
                                                  ? null
                                                  : PopupMenuButton<int>(
                                                      icon: const Icon(
                                                        Icons.more_vert_rounded,
                                                      ),
                                                      itemBuilder: (context) => [
                                                        const PopupMenuItem(
                                                          value: 2,
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.edit_rounded),
                                                              SizedBox(width: 8),
                                                              Text('Rename'),
                                                            ],
                                                          ),
                                                        ),
                                                        const PopupMenuItem(
                                                          value: 1,
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.delete_outline_rounded,
                                                                color: Colors.red,
                                                              ),
                                                              SizedBox(width: 8),
                                                              Text(
                                                                'Delete',
                                                                style: TextStyle(
                                                                  color: Colors.red,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                      onSelected: (val) async {
                                                        if (val == 2) {
                                                          RenamePlaylistDialog.show(
                                                            context,
                                                            playlist: playlist,
                                                            onRename: widget.onRenamePlaylist,
                                                          );
                                                        } else if (val == 1) {
                                                          var confirmed =
                                                              await ConfirmDeleteDialog.show(
                                                                context,
                                                                title:
                                                                    'Delete Playlist?',
                                                                message:
                                                                    'Delete "${playlist.name}"? This cannot be undone.',
                                                              );
                                                          if (confirmed !=
                                                              true) {
                                                            return;
                                                          }
                                                          await widget
                                                              .onDeletePlaylist(
                                                                playlist.id,
                                                              );
                                                          if (!context
                                                              .mounted) {
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
                                                    ),
                                              onTap: () {
                                                _searchFocusNode.unfocus();
                                                openPlaylist(context, playlist);
                                              },
                                            ),
                                            if (index <
                                                filteredPlaylists.length - 1)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 72,
                                                ),
                                                child: Divider(
                                                  height: 1,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.06),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                );

                        default:
                          // Tab 1: Songs
                          return widget.songs.isEmpty
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
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
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
                                                : Icons
                                                      .create_new_folder_rounded,
                                          ),
                                          label: Text(
                                            widget.scanFolder == null
                                                ? 'Set Sync Folder'
                                                : 'Change Folder',
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: theme
                                                .colorScheme
                                                .primaryContainer,
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
                                      child: filteredSongs.isEmpty
                                          ? Center(
                                              child: Text(
                                                'No matching songs found',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
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
                                                var currentSong = widget
                                                    .playerProvider
                                                    .currentSong;
                                                return Scrollbar(
                                                  child: RefreshIndicator(
                                                    onRefresh:
                                                        widget.onResyncNow,
                                                    child: ListView.builder(
                                                      key:
                                                          const PageStorageKey<
                                                            String
                                                          >('songs_list'),
                                                      primary: true,
                                                      physics:
                                                          const AlwaysScrollableScrollPhysics(),
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 120,
                                                          ),
                                                      itemCount:
                                                          filteredSongs.length,
                                                      itemBuilder: (context, index) {
                                                        var song =
                                                            filteredSongs[index];
                                                        var isCurrent =
                                                            currentSong !=
                                                                null &&
                                                            currentSong.id ==
                                                                song.id;
                                                        return SongTile(
                                                          song: song,
                                                          playerProvider: widget
                                                              .playerProvider,
                                                          isCurrent: isCurrent,
                                                          showDivider:
                                                              index <
                                                              filteredSongs
                                                                      .length -
                                                                  1,
                                                          onTap: () {
                                                            _searchFocusNode
                                                                .unfocus();
                                                            widget
                                                                .playerProvider
                                                                .playSong(
                                                                  song,
                                                                  filteredSongs,
                                                                );
                                                          },
                                                          
                                                          
                                                          
                                                          
                                                          
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
