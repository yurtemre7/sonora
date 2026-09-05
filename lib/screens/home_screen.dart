import 'dart:io';

import 'package:animations/animations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/models/song_activity.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/services/library_search_index.dart';
import 'package:sonora/services/update_service.dart';
import 'package:sonora/utils/format_utils.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/custom_scrollbar.dart';
import 'package:sonora/widgets/home/albums_tab.dart';
import 'package:sonora/widgets/home/artists_tab.dart';
import 'package:sonora/widgets/home/playlists_tab.dart';
import 'package:sonora/widgets/home/songs_tab.dart';
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
  final _searchIndex = LibrarySearchIndex();
  final Set<int> _selectedSongIds = {};

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
    var theme = Theme.of(context);

    String title;
    switch (tabIndex) {
      case 1:
        title = context.l10n.sortAlbumsBy;
      case 2:
        title = context.l10n.sortArtistsBy;
      case 3:
        title = context.l10n.sortPlaylistsBy;
      default:
        title = context.l10n.sortSongsBy;
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            var currentGroupValue = _sortByForTab(tabIndex);

            List<(String, String, IconData)> options;
            switch (tabIndex) {
              case 1:
                options = [
                  (context.l10n.sortByAlbumName, 'name', Icons.album_rounded),
                  (context.l10n.sortByArtist, 'artist', Icons.person_rounded),
                  (
                    context.l10n.sortByTrackCount,
                    'tracks',
                    Icons.format_list_numbered_rounded,
                  ),
                  (
                    context.l10n.sortByRecentlyAdded,
                    'recent',
                    Icons.calendar_today_rounded,
                  ),
                ];
              case 2:
                options = [
                  (
                    context.l10n.sortByArtistName,
                    'name',
                    Icons.person_rounded,
                  ),
                  (
                    context.l10n.sortByAlbumCount,
                    'albums',
                    Icons.album_rounded,
                  ),
                  (
                    context.l10n.sortBySongCount,
                    'songs',
                    Icons.music_note_rounded,
                  ),
                ];
              case 3:
                options = [
                  (
                    context.l10n.sortByPlaylistName,
                    'name',
                    Icons.playlist_play_rounded,
                  ),
                  (
                    context.l10n.sortBySongCount,
                    'songs',
                    Icons.music_note_rounded,
                  ),
                ];
              default:
                var isPlaysSelected = currentGroupValue == 'plays';
                var playsLabel = isPlaysSelected && _songSortAscending
                    ? context.l10n.leastPlayed
                    : context.l10n.mostPlayed;
                var playsIcon = isPlaysSelected && _songSortAscending
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded;

                options = [
                  (
                    context.l10n.sortByTitle,
                    'title',
                    Icons.sort_by_alpha_rounded,
                  ),
                  (context.l10n.sortByArtist, 'artist', Icons.person_rounded),
                  (
                    context.l10n.sortByDuration,
                    'duration',
                    Icons.schedule_rounded,
                  ),
                  (
                    context.l10n.sortByRecentlyAdded,
                    'recent',
                    Icons.calendar_today_rounded,
                  ),
                  (playsLabel, 'plays', playsIcon),
                ];
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.sort_rounded,
                            size: 20,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < options.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 52,
                                endIndent: 16,
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.2),
                              ),
                            _SortOptionTile(
                              icon: options[i].$3,
                              label: options[i].$1,
                              isSelected: currentGroupValue == options[i].$2,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                var val = options[i].$2;
                                if (tabIndex == 0) {
                                  if (val == 'plays') {
                                    if (_songSortBy != 'plays') {
                                      _songSortAscending = false;
                                    }
                                    _songSortBy = 'plays';
                                  } else {
                                    if (_songSortBy == 'plays') {
                                      _songSortAscending = true;
                                    }
                                    _songSortBy = val;
                                  }
                                } else {
                                  _setSortByForTab(tabIndex, val);
                                }
                                _saveSortSettingsForTab(tabIndex);
                                setSheetState(() {});
                                setState(() {});
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        context.l10n.sort,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: (tabIndex == 0 &&
                                currentGroupValue == 'plays')
                            ? [
                                ButtonSegment<bool>(
                                  value: false,
                                  icon: const Icon(
                                    Icons.trending_up_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    context.l10n.mostPlayed,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ButtonSegment<bool>(
                                  value: true,
                                  icon: const Icon(
                                    Icons.trending_down_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    context.l10n.leastPlayed,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]
                            : [
                                ButtonSegment<bool>(
                                  value: true,
                                  icon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    context.l10n.sortAscending,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ButtonSegment<bool>(
                                  value: false,
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    context.l10n.sortDescending,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                        selected: {_sortAscendingForTab(tabIndex)},
                        onSelectionChanged: (newSelection) {
                          HapticFeedback.selectionClick();
                          var asc = newSelection.first;
                          _setSortAscendingForTab(tabIndex, asc);
                          _saveSortSettingsForTab(tabIndex);
                          setSheetState(() {});
                          setState(() {});
                        },
                      ),
                    ),
                  ],
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
          _CreatePlaylistDialogContent(onCreate: widget.onCreatePlaylist),
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
                            return Row(
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
                            widget.isSyncing ? 52 : 50,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.isSyncing)
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
                                      showSyncPrompt: widget.showSyncPrompt,
                                      onConfigureFolder:
                                          widget.onConfigureFolder,
                                      onUnfocusSearch: _searchFocusNode.unfocus,
                                      syncPromptBanner: _buildSyncPromptBanner(
                                        theme,
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

class _CreatePlaylistDialogContent extends StatefulWidget {
  const _CreatePlaylistDialogContent({required this.onCreate});

  final Future<void> Function(String name) onCreate;

  @override
  State<_CreatePlaylistDialogContent> createState() =>
      _CreatePlaylistDialogContentState();
}

class _CreatePlaylistDialogContentState
    extends State<_CreatePlaylistDialogContent> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.createPlaylist),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: context.l10n.playlistName),
        textCapitalization: TextCapitalization.sentences,
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            var name = _controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(context);
              await widget.onCreate(name);
            }
          },
          child: Text(context.l10n.create),
        ),
      ],
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                )
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

