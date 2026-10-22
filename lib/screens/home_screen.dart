import 'dart:io';

import 'package:animations/animations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/models/song_activity.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/services/library_search_index.dart';
import 'package:sonora/services/native_bridge.dart';
import 'package:sonora/services/update_service.dart';
import 'package:sonora/utils/format_utils.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/create_playlist_dialog.dart';
import 'package:sonora/widgets/custom_scrollbar.dart';
import 'package:sonora/widgets/dev_badge.dart';
import 'package:sonora/widgets/home/albums_tab.dart';
import 'package:sonora/widgets/home/artists_tab.dart';
import 'package:sonora/widgets/home/playlists_tab.dart';
import 'package:sonora/widgets/home/songs_tab.dart';
import 'package:sonora/widgets/home/sort_bottom_sheet.dart';
import 'package:sonora/widgets/home/sync_prompt_banner.dart';
import 'package:sonora/widgets/multi_select_action_bar.dart';
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
  final Future<void> Function() onPostponeSync;

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
  final _searchIndex = LibrarySearchIndex();
  final Set<int> _selectedSongIds = {};
  late bool _showSyncPrompt;
  var _isSyncing = false;
  var _isDevBuild = false;

  SongActivityView get _currentSongActivityView {
    if (_songSortBy == 'plays') {
      return _songSortAscending
          ? SongActivityView.leastPlayed
          : SongActivityView.mostPlayed;
    }
    return SongActivityView.all;
  }

  @override
  void initState() {
    super.initState();
    NativeBridge.getPackageInfo().then((info) {
      if (mounted && info.isDevBuild) {
        setState(() {
          _isDevBuild = true;
        });
      }
    });
    _showSyncPrompt = widget.showSyncPrompt;
    _songSortBy = SettingsProvider.instance.songSortBy;
    _songSortAscending = SettingsProvider.instance.songSortAscending;
    SettingsProvider.instance.songActivityView = _currentSongActivityView;
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
      if (_selectedSongIds.isNotEmpty) {
        _clearSongSelection();
      }
      if (mounted) setState(() {});
    });

    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    widget.playerProvider.statsService.addListener(_onStatsChanged);

    _rebuildSearchIndex();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdateAutomatically();
    });
  }

  void _onStatsChanged() {
    if (mounted) setState(() {});
  }

  void _toggleSongSelection(Song song) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedSongIds.contains(song.id)) {
        _selectedSongIds.remove(song.id);
      } else {
        _selectedSongIds.add(song.id);
      }
    });
  }

  void _onLongPressSong(Song song) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedSongIds.add(song.id);
    });
  }

  void _selectAllSongs(List<Song> songs) {
    setState(() {
      _selectedSongIds.addAll(songs.map((s) => s.id));
    });
  }

  void _clearSongSelection() {
    setState(() {
      _selectedSongIds.clear();
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showSyncPrompt != oldWidget.showSyncPrompt) {
      _showSyncPrompt = widget.showSyncPrompt;
    }
    if (widget.songs != oldWidget.songs ||
        widget.playerProvider.cachedAlbums !=
            oldWidget.playerProvider.cachedAlbums ||
        widget.playerProvider.cachedArtists !=
            oldWidget.playerProvider.cachedArtists) {
      _rebuildSearchIndex();
    }
  }

  void _rebuildSearchIndex() {
    _searchIndex.buildIndex(
      songs: widget.songs,
      albums: _getAlbums(),
      artists: _getArtists(),
    );
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
    var matches = _searchIndex.searchSongs(
      _searchQuery,
      sortBy: _songSortBy == 'plays' ? 'title' : _songSortBy,
      ascending: _songSortBy == 'plays' ? true : _songSortAscending,
    );
    if (_songSortBy == 'plays') {
      return widget.playerProvider.statsService.applyActivityView(
        matches,
        _currentSongActivityView,
      );
    }
    return matches;
  }

  List<AlbumGroup> _getFilteredAlbums() {
    return _searchIndex.searchAlbums(
      _searchQuery,
      allAlbums: _getAlbums(),
      sortBy: _albumSortBy,
      ascending: _albumSortAscending,
    );
  }

  List<ArtistGroup> _getFilteredArtists() {
    return _searchIndex.searchArtists(
      _searchQuery,
      allArtists: _getArtists(),
      sortBy: _artistSortBy,
      ascending: _artistSortAscending,
    );
  }

  String _getScrollSection(
    double percentage, {
    required List<Song> filteredSongs,
    required List<AlbumGroup> filteredAlbums,
    required List<ArtistGroup> filteredArtists,
    required List<Playlist> filteredPlaylists,
  }) {
    switch (_tabController.index) {
      case 0:
        if (filteredSongs.isEmpty) return '';
        var idx = (percentage * (filteredSongs.length - 1)).round().clamp(
          0,
          filteredSongs.length - 1,
        );
        var song = filteredSongs[idx];
        if (_songSortBy == 'artist') {
          return _extractSectionLetter(song.artist);
        } else if (_songSortBy == 'duration') {
          return '${song.duration.inMinutes}m';
        } else if (_songSortBy == 'plays') {
          var count = widget.playerProvider.statsService.songPlayCount(song.id);
          return '$count';
        }
        return _extractSectionLetter(song.title);
      case 1:
        if (filteredAlbums.isEmpty) return '';
        var idx = (percentage * (filteredAlbums.length - 1)).round().clamp(
          0,
          filteredAlbums.length - 1,
        );
        var album = filteredAlbums[idx];
        if (_albumSortBy == 'artist') {
          return _extractSectionLetter(album.artist);
        }
        return _extractSectionLetter(album.name);
      case 2:
        if (filteredArtists.isEmpty) return '';
        var idx = (percentage * (filteredArtists.length - 1)).round().clamp(
          0,
          filteredArtists.length - 1,
        );
        return _extractSectionLetter(filteredArtists[idx].name);
      case 3:
        if (filteredPlaylists.isEmpty) return '';
        var idx = (percentage * (filteredPlaylists.length - 1)).round().clamp(
          0,
          filteredPlaylists.length - 1,
        );
        return _extractSectionLetter(filteredPlaylists[idx].name);
      default:
        return '';
    }
  }

  String _extractSectionLetter(String text) {
    var trimmed = text.trim();
    if (trimmed.isEmpty) return '#';
    var firstChar = trimmed[0].toUpperCase();
    if (RegExp(r'[A-Z]').hasMatch(firstChar)) {
      return firstChar;
    }
    return '#';
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
    showSortBottomSheet(
      context,
      tabIndex: tabIndex,
      sortBy: () => _sortByForTab(tabIndex),
      ascending: () => _sortAscendingForTab(tabIndex),
      onSortBySelected: (val) {
        if (tabIndex == 0) {
          // Switching into or out of play-count sorting flips the default
          // direction so "most played" shows first.
          if (val == 'plays' && _songSortBy != 'plays') {
            _songSortAscending = false;
          } else if (val != 'plays' && _songSortBy == 'plays') {
            _songSortAscending = true;
          }
        }
        _setSortByForTab(tabIndex, val);
        _saveSortSettingsForTab(tabIndex);
        setState(() {});
      },
      onAscendingSelected: (asc) {
        _setSortAscendingForTab(tabIndex, asc);
        _saveSortSettingsForTab(tabIndex);
        setState(() {});
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

  void _saveSortSettingsForTab(int tabIndex) {
    if (tabIndex == 0) {
      SettingsProvider.instance.songActivityView = _currentSongActivityView;
      SettingsProvider.instance.saveSortSettings(
        songSortBy: _songSortBy,
        songSortAscending: _songSortAscending,
      );
    } else if (tabIndex == 1) {
      SettingsProvider.instance.saveSortSettings(
        albumSortBy: _albumSortBy,
        albumSortAscending: _albumSortAscending,
      );
    } else if (tabIndex == 2) {
      SettingsProvider.instance.saveSortSettings(
        artistSortBy: _artistSortBy,
        artistSortAscending: _artistSortAscending,
      );
    } else if (tabIndex == 3) {
      SettingsProvider.instance.saveSortSettings(
        playlistSortBy: _playlistSortBy,
        playlistSortAscending: _playlistSortAscending,
      );
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
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
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
                      tooltip: context.l10n.importM3u,
                      onPressed: () async {
                        var result = await FilePicker.pickFiles();
                        if (result.isNotEmpty && result.single.path != null) {
                          var file = File(result.single.path!);
                          if (file.path.toLowerCase().endsWith('.m3u') ||
                              file.path.toLowerCase().endsWith('.m3u8')) {
                            await widget.playerProvider.importM3u(file);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.importedPlaylist),
                              ),
                            );
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
                  style: (tabIndex == 0 && _songSortBy == 'plays')
                      ? IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        )
                      : null,
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
    widget.playerProvider.statsService.removeListener(_onStatsChanged);
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showCreatePlaylistDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) =>
          CreatePlaylistDialogContent(onCreate: widget.onCreatePlaylist),
    );
  }

  Future<void> _handlePostponeSync() async {
    setState(() {
      _showSyncPrompt = false;
    });
    await widget.onPostponeSync();
  }

  Future<void> _handleResyncNow() async {
    setState(() {
      _showSyncPrompt = false;
      _isSyncing = true;
    });
    try {
      await widget.onResyncNow();
      if (!mounted) return;
      var durationText = SettingsProvider.instance.lastSyncDuration != null
          ? ' in ${SettingsProvider.instance.lastSyncDuration}ms'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.syncedXSongs(
              widget.playerProvider.allSongs.length,
              durationText,
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        var filteredSongs = _getFilteredSongs();
        var filteredAlbums = _getFilteredAlbums();
        var filteredArtists = _getFilteredArtists();
        var filteredPlaylists = _getFilteredPlaylists();

        var selectedSongsList = filteredSongs
            .where((s) => _selectedSongIds.contains(s.id))
            .toList();

        return PopScope(
          canPop: _selectedSongIds.isEmpty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _clearSongSelection();
            }
          },
          child: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        floating: true,
                        pinned: true,
                        backgroundColor: theme.colorScheme.surface,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        centerTitle: false,
                        title: ListenableBuilder(
                          listenable: SettingsProvider.instance,
                          builder: (context, _) {
                            Widget titleWidget;
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
                              titleWidget = Text(
                                greeting,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  color: theme.colorScheme.primary,
                                ),
                              );
                            } else {
                              titleWidget = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.l10n.appTitle,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.headphones,
                                    color: theme.colorScheme.primary,
                                    size: 22,
                                  ),
                                ],
                              );
                            }
                            if (!_isDevBuild) return titleWidget;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(child: titleWidget),
                                const SizedBox(width: 8),
                                const DevBadge(),
                              ],
                            );
                          },
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.history_rounded),
                            onPressed: () {
                              _searchFocusNode.unfocus();
                              openRecentlyPlayed(context);
                            },
                            tooltip: context.l10n.recentlyPlayed,
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite_rounded),
                            onPressed: () {
                              _searchFocusNode.unfocus();
                              openFavorites(context);
                            },
                            tooltip: context.l10n.favorites,
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_rounded),
                            onPressed: () {
                              _searchFocusNode.unfocus();
                              widget.onOpenSettings();
                            },
                            tooltip: context.l10n.settings,
                          ),
                          const SizedBox(width: 8),
                        ],
                        bottom: PreferredSize(
                          preferredSize: Size.fromHeight(
                            (_isSyncing || widget.isSyncing) ? 52 : 50,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSyncing || widget.isSyncing)
                                const LinearProgressIndicator(minHeight: 2),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: TabBar(
                                    onTap: (index) {
                                      _searchFocusNode.unfocus();
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
                                    splashBorderRadius: BorderRadius.circular(
                                      18,
                                    ),
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
                          sectionGetter: (percentage) => _getScrollSection(
                            percentage,
                            filteredSongs: filteredSongs,
                            filteredAlbums: filteredAlbums,
                            filteredArtists: filteredArtists,
                            filteredPlaylists: filteredPlaylists,
                          ),
                          child: PageTransitionSwitcher(
                            reverse:
                                _tabController.index <
                                _tabController.previousIndex,
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
                                      onCreatePlaylistDialog:
                                          _showCreatePlaylistDialog,
                                      onDeletePlaylist: widget.onDeletePlaylist,
                                      onRenamePlaylist: widget.onRenamePlaylist,
                                    );
                                  default:
                                    return SongsTab(
                                      allSongs: widget.songs,
                                      filteredSongs: filteredSongs,
                                      playerProvider: widget.playerProvider,
                                      scanFolder: widget.scanFolder,
                                      showSyncPrompt: _showSyncPrompt,
                                      onConfigureFolder:
                                          widget.onConfigureFolder,
                                      onUnfocusSearch: _searchFocusNode.unfocus,
                                      syncPromptBanner: SyncPromptBanner(
                                        isSyncing: _isSyncing,
                                        onPostpone: _handlePostponeSync,
                                        onResyncNow: _handleResyncNow,
                                      ),
                                      activityView: _currentSongActivityView,
                                      selectedSongIds: _selectedSongIds,
                                      onToggleSelect: _toggleSongSelection,
                                      onLongPressSong: _onLongPressSong,
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
                if (_selectedSongIds.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MultiSelectActionBar(
                      selectedSongs: selectedSongsList,
                      allAvailableSongs: filteredSongs,
                      playerProvider: widget.playerProvider,
                      onClearSelection: _clearSongSelection,
                      onSelectAll: () => _selectAllSongs(filteredSongs),
                      bottomPadding: widget.playerProvider.currentSong != null
                          ? 80.0
                          : 16.0,
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
