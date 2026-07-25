import 'dart:io';

import 'package:animations/animations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/screens/favorites_screen.dart';
import 'package:sonora/services/update_service.dart';
import 'package:sonora/utils/format_utils.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/custom_scrollbar.dart';
import 'package:sonora/widgets/home/albums_tab.dart';
import 'package:sonora/widgets/home/artists_tab.dart';
import 'package:sonora/widgets/home/playlists_tab.dart';
import 'package:sonora/widgets/home/songs_tab.dart';
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
  final Future<void> Function(String playlistId, String newName)
  onRenamePlaylist;
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

    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdateAutomatically();
    });
  }

  Future<void> _checkUpdateAutomatically() async {
    if (kDebugMode) return;
    if (!SettingsProvider.instance.autoCheckUpdates) return;

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
    if (_playlistSortBy == 'songs') {
      var validIds = widget.songs.map((s) => s.id).toSet();
      var songCountMap = {
        for (var p in playlists)
          p.id: p.songIds.where(validIds.contains).length,
      };
      playlists.sort((a, b) {
        var cmp = (songCountMap[a.id] ?? 0).compareTo(songCountMap[b.id] ?? 0);
        if (cmp == 0) {
          cmp = a.nameLower.compareTo(b.nameLower);
        }
        return _playlistSortAscending ? cmp : -cmp;
      });
    } else {
      playlists.sort((a, b) {
        var cmp = a.nameLower.compareTo(b.nameLower);
        return _playlistSortAscending ? cmp : -cmp;
      });
    }
    return playlists;
  }

  void _showSortBottomSheet({int tabIndex = 0}) {
    var theme = Theme.of(context);

    String title;
    String subtitle;
    List<(String, String)> options;

    switch (tabIndex) {
      case 1:
        title = context.l10n.sortAlbumsBy;
        subtitle = context.l10n.sortSubtitle;
        options = [
          (context.l10n.sortByAlbumName, 'name'),
          (context.l10n.sortByArtist, 'artist'),
          (context.l10n.sortByTrackCount, 'tracks'),
          (context.l10n.sortByRecentlyAdded, 'recent'),
        ];
      case 2:
        title = context.l10n.sortArtistsBy;
        subtitle = context.l10n.sortSubtitle;
        options = [
          (context.l10n.sortByArtistName, 'name'),
          (context.l10n.sortByAlbumCount, 'albums'),
          (context.l10n.sortBySongCount, 'songs'),
        ];
      case 3:
        title = context.l10n.sortPlaylistsBy;
        subtitle = context.l10n.sortSubtitle;
        options = [
          (context.l10n.sortByPlaylistName, 'name'),
          (context.l10n.sortBySongCount, 'songs'),
        ];
      default:
        title = context.l10n.sortSongsBy;
        subtitle = context.l10n.sortSubtitle;
        options = [
          (context.l10n.sortByTitle, 'title'),
          (context.l10n.sortByArtist, 'artist'),
          (context.l10n.sortByDuration, 'duration'),
          (context.l10n.sortByRecentlyAdded, 'recent'),
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
                          if (tabIndex == 0) {
                            SettingsProvider.instance.saveSortSettings(
                              songSortBy: _sortByForTab(tabIndex),
                              songSortAscending: _sortAscendingForTab(tabIndex),
                            );
                          } else if (tabIndex == 1) {
                            SettingsProvider.instance.saveSortSettings(
                              albumSortBy: _sortByForTab(tabIndex),
                              albumSortAscending: _sortAscendingForTab(
                                tabIndex,
                              ),
                            );
                          } else if (tabIndex == 2) {
                            SettingsProvider.instance.saveSortSettings(
                              artistSortBy: _sortByForTab(tabIndex),
                              artistSortAscending: _sortAscendingForTab(
                                tabIndex,
                              ),
                            );
                          } else if (tabIndex == 3) {
                            SettingsProvider.instance.saveSortSettings(
                              playlistSortBy: _sortByForTab(tabIndex),
                              playlistSortAscending: _sortAscendingForTab(
                                tabIndex,
                              ),
                            );
                          }
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
                        title: Text(context.l10n.sortAscending),
                        value: _sortAscendingForTab(tabIndex),
                        onChanged: (val) {
                          setState(
                            () => _setSortAscendingForTab(tabIndex, val),
                          );
                          setSheetState(() {});
                          if (tabIndex == 0) {
                            SettingsProvider.instance.saveSortSettings(
                              songSortBy: _sortByForTab(tabIndex),
                              songSortAscending: _sortAscendingForTab(tabIndex),
                            );
                          } else if (tabIndex == 1) {
                            SettingsProvider.instance.saveSortSettings(
                              albumSortBy: _sortByForTab(tabIndex),
                              albumSortAscending: _sortAscendingForTab(
                                tabIndex,
                              ),
                            );
                          } else if (tabIndex == 2) {
                            SettingsProvider.instance.saveSortSettings(
                              artistSortBy: _sortByForTab(tabIndex),
                              artistSortAscending: _sortAscendingForTab(
                                tabIndex,
                              ),
                            );
                          } else if (tabIndex == 3) {
                            SettingsProvider.instance.saveSortSettings(
                              playlistSortBy: _sortByForTab(tabIndex),
                              playlistSortAscending: _sortAscendingForTab(
                                tabIndex,
                              ),
                            );
                          }
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
        label = context.l10n.albumCount(count);
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
        label = context.l10n.artistCount(count);
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
        label = context.l10n.playlistCount(count);
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
        label = '${context.l10n.songCount(count)} • $timeStr';
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
                  onTapOutside: (_) => _searchFocusNode.unfocus(),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: switch (tabIndex) {
                      1 => context.l10n.searchAlbumsHint,
                      2 => context.l10n.searchArtistsHint,
                      3 => context.l10n.searchPlaylistsHint,
                      _ => context.l10n.searchSongsHint,
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
              if (!_searchFocusNode.hasFocus) ...[
                ...[
                  const SizedBox(width: 8),
                  if (tabIndex != 3)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.shuffle_rounded),
                      onPressed: onShuffle,
                      tooltip: context.l10n.shufflePlay,
                    )
                  else ...[
                    IconButton.filledTonal(
                      icon: const Icon(Icons.file_download_rounded),
                      tooltip: 'Import M3U',
                      onPressed: () async {
                        var result = await FilePicker.pickFiles();
                        if (result != null && result.files.single.path != null) {
                          var file = File(result.files.single.path!);
                          if (file.path.toLowerCase().endsWith('.m3u') || file.path.toLowerCase().endsWith('.m3u8')) {
                            await widget.playerProvider.importM3u(file);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imported')));
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.playlist_add),
                      onPressed: onShuffle,
                      tooltip: context.l10n.createPlaylist,
                    ),
                  ],
                ],
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.sort_rounded),
                  onPressed: onSort,
                  tooltip: context.l10n.sort,
                ),
              ],
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

  Future<void> _showCreatePlaylistDialog() async {
    var textController = TextEditingController();
    try {
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.createPlaylist),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(hintText: context.l10n.playlistName),
            textCapitalization: TextCapitalization.sentences,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                var name = textController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  await widget.onCreatePlaylist(name);
                }
              },
              child: Text(context.l10n.create),
            ),
          ],
        ),
      );
    } finally {
      textController.dispose();
    }
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
                  context.l10n.syncLibraryDatabase,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.syncLibraryDatabaseSubtitle,
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
                  child: Text(context.l10n.syncNow),
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
          extendBody: true,
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
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.favorite_rounded),
                      onPressed: () {
                        _searchFocusNode.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FavoritesScreen(
                              playerProvider: widget.playerProvider,
                              allSongs: widget.playerProvider.allSongs,
                              allAlbums: widget.playerProvider.cachedAlbums,
                              allArtists: widget.playerProvider.cachedArtists,
                            ),
                          ),
                        );
                      },
                      tooltip: context.l10n.favorites,
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
                    title: ListenableBuilder(
                      listenable: SettingsProvider.instance,
                      builder: (context, _) {
                        if (SettingsProvider.instance.useGreetingTitle) {
                          var hour = DateTime.now().hour;
                          String greeting;
                          var userName = SettingsProvider.instance.userName;
                          if (hour < 12) {
                            greeting = context.l10n.goodMorning(userName);
                          } else if (hour < 17) {
                            greeting = context.l10n.goodAfternoon(userName);
                          } else {
                            greeting = context.l10n.goodEvening(userName);
                          }
                          return Text(
                            greeting,
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
                              context.l10n.appTitle,
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
                      },
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
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  labelColor:
                                      theme.colorScheme.onPrimaryContainer,
                                  labelStyle: theme.textTheme.labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                  unselectedLabelColor:
                                      theme.colorScheme.onSurfaceVariant,
                                  unselectedLabelStyle: theme
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(fontSize: 13),
                                  tabs: [
                                    Tab(
                                      child: Text(
                                        context.l10n.songs,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Tab(
                                      child: Text(
                                        context.l10n.albums,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Tab(
                                      child: Text(
                                        context.l10n.artists,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Tab(
                                      child: Text(
                                        context.l10n.playlists,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                              tooltip: context.l10n.settings,
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
                  child: CustomScrollbar(
                    child: PageTransitionSwitcher(
                      reverse:
                          _tabController.index < _tabController.previousIndex,
                      transitionBuilder:
                          (child, animation, secondaryAnimation) {
                            return SharedAxisTransition(
                              fillColor: Colors.transparent,
                              animation: animation,
                              secondaryAnimation: secondaryAnimation,
                              transitionType:
                                  SharedAxisTransitionType.horizontal,
                              child: child,
                            );
                          },
                      child: Builder(
                        key: ValueKey(_tabController.index),
                        builder: (context) {
                          switch (_tabController.index) {
                            case 1:
                              return AlbumsTab(
                                allSongs: widget.songs,
                                filteredAlbums: filteredAlbums,
                                onUnfocusSearch: _searchFocusNode.unfocus,
                              );
                            case 2:
                              return ArtistsTab(
                                allSongs: widget.songs,
                                filteredArtists: filteredArtists,
                                onUnfocusSearch: _searchFocusNode.unfocus,
                              );
                            case 3:
                              return PlaylistsTab(
                                allSongs: widget.songs,
                                filteredPlaylists: filteredPlaylists,
                                playerProvider: widget.playerProvider,
                                onUnfocusSearch: _searchFocusNode.unfocus,
                                onCreatePlaylistDialog: _showCreatePlaylistDialog,
                                onDeletePlaylist: widget.onDeletePlaylist,
                                onRenamePlaylist: widget.onRenamePlaylist,
                              );
                            default:
                              return SongsTab(
                                allSongs: widget.songs,
                                filteredSongs: filteredSongs,
                                playerProvider: widget.playerProvider,
                                scanFolder: widget.scanFolder,
                                showSyncPrompt: widget.showSyncPrompt,
                                onConfigureFolder: widget.onConfigureFolder,
                                onUnfocusSearch: _searchFocusNode.unfocus,
                                syncPromptBanner: _buildSyncPromptBanner(theme),
                              );
                          }
                        },
                      ),
                    ),
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
