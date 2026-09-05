import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/utils/format_utils.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/artist_avatar.dart';
import 'package:sonora/widgets/multi_select_action_bar.dart';
import 'package:sonora/widgets/song_tile.dart';

class FavoritesScreen extends StatefulWidget {
  final PlayerProvider playerProvider;
  final List<Song> allSongs;
  final List<AlbumGroup> allAlbums;
  final List<ArtistGroup> allArtists;

  const FavoritesScreen({
    super.key,
    required this.playerProvider,
    required this.allSongs,
    required this.allAlbums,
    required this.allArtists,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _albumScrollController = ScrollController();
  Timer? _autoScrollTimer;
  var _isAutoScrolling = true;
  var _scrollPosition = 0.0;
  final Set<int> _selectedSongIds = {};

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
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (!_isAutoScrolling || !_albumScrollController.hasClients) return;
      var maxScroll = _albumScrollController.position.maxScrollExtent;
      if (maxScroll == 0) return;

      _scrollPosition += 1.0;
      if (_scrollPosition >= maxScroll) {
        _scrollPosition = 0;
        _albumScrollController.jumpTo(_scrollPosition);
      } else {
        _albumScrollController.jumpTo(_scrollPosition);
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _albumScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.playerProvider,
        SettingsProvider.instance,
      ]),
      builder: (context, _) {
        var favSongs = widget.playerProvider.allSongs
            .where((s) => s.isFavorite)
            .toList();
        var favAlbums = widget.allAlbums.where((a) {
          return widget.playerProvider.favoriteAlbums.containsKey(
            '${a.nameLower}|||${a.artistLower}',
          );
        }).toList();
        var favArtists = widget.allArtists.where((a) {
          return widget.playerProvider.favoriteArtists.containsKey(a.nameLower);
        }).toList();

        var sortAsc = SettingsProvider.instance.favoritesSortAscending;
        var sortBy = SettingsProvider.instance.favoritesSortBy;

        favSongs.sort((a, b) {
          var cmp = 0;
          if (sortBy == 'duration') {
            cmp = a.duration.compareTo(b.duration);
          } else if (sortBy == 'date') {
            var dateA = a.favoriteDateMs ?? 0;
            var dateB = b.favoriteDateMs ?? 0;
            cmp = dateA.compareTo(dateB);
          } else {
            cmp = a.titleLower.compareTo(b.titleLower);
          }
          return sortAsc ? cmp : -cmp;
        });

        favAlbums.sort((a, b) {
          var cmp = 0;
          if (sortBy == 'duration') {
            var durA = a.songs.fold<int>(
              0,
              (s, x) => s + x.duration.inMilliseconds,
            );
            var durB = b.songs.fold<int>(
              0,
              (s, x) => s + x.duration.inMilliseconds,
            );
            cmp = durA.compareTo(durB);
          } else if (sortBy == 'date') {
            var dateA =
                widget
                    .playerProvider
                    .favoriteAlbums['${a.nameLower}|||${a.artistLower}'] ??
                0;
            var dateB =
                widget
                    .playerProvider
                    .favoriteAlbums['${b.nameLower}|||${b.artistLower}'] ??
                0;
            cmp = dateA.compareTo(dateB);
          } else {
            cmp = a.nameLower.compareTo(b.nameLower);
          }
          return sortAsc ? cmp : -cmp;
        });

        favArtists.sort((a, b) {
          var cmp = 0;
          if (sortBy == 'duration') {
            var durA = a.songs.fold<int>(
              0,
              (s, x) => s + x.duration.inMilliseconds,
            );
            var durB = b.songs.fold<int>(
              0,
              (s, x) => s + x.duration.inMilliseconds,
            );
            cmp = durA.compareTo(durB);
          } else if (sortBy == 'date') {
            var dateA = widget.playerProvider.favoriteArtists[a.nameLower] ?? 0;
            var dateB = widget.playerProvider.favoriteArtists[b.nameLower] ?? 0;
            cmp = dateA.compareTo(dateB);
          } else {
            cmp = a.nameLower.compareTo(b.nameLower);
          }
          return sortAsc ? cmp : -cmp;
        });

        var selectedSongsList = favSongs
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
            appBar: AppBar(
              title: Text(context.l10n.favorites),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => closeRoute(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  onPressed: () => _showSortBottomSheet(context),
                ),
              ],
            ),
            body: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    if (favArtists.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                context.l10n.artists,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.artistCount(favArtists.length),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: favArtists.length,
                            itemBuilder: (context, index) {
                              var artist = favArtists[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => openArtist(context, artist),
                                  child: Container(
                                    width: 100,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 4,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ArtistAvatar(
                                          artist: artist,
                                          radius: 34,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          artist.name,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          context.l10n.songCount(
                                            artist.songs.length,
                                          ),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 11,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    if (favAlbums.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                context.l10n.albums,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.albumCount(favAlbums.length),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 180,
                          child: NotificationListener<UserScrollNotification>(
                            onNotification: (notification) {
                              if (notification.direction !=
                                  ScrollDirection.idle) {
                                if (_isAutoScrolling) {
                                  setState(() => _isAutoScrolling = false);
                                  _autoScrollTimer?.cancel();
                                }
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _albumScrollController,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: favAlbums.length,
                              itemBuilder: (context, index) {
                                var album = favAlbums[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => openAlbum(context, album),
                                    child: Container(
                                      width: 120,
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AlbumArt(
                                            artworkPath: album.songs.first.artworkPath,
                                            size: 104,
                                            borderRadius: 12,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            album.name,
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
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
                                                  fontSize: 11,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (favSongs.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                context.l10n.songs,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${context.l10n.songCount(favSongs.length)} • ${formatTotalDuration(favSongs)}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          var song = favSongs[index];
                          var isCurrent =
                              widget.playerProvider.currentSong?.id == song.id;
                          var isSelecting = _selectedSongIds.isNotEmpty;
                          var isSelected = _selectedSongIds.contains(song.id);
                          return SongTile(
                            song: song,
                            playerProvider: widget.playerProvider,
                            isCurrent: isCurrent,
                            showDivider: index < favSongs.length - 1,
                            isSelecting: isSelecting,
                            isSelected: isSelected,
                            onSelect: () => _toggleSongSelection(song),
                            onLongPress: () => _onLongPressSong(song),
                            onTap: () =>
                                widget.playerProvider.playSong(song, favSongs),
                          );
                        }, childCount: favSongs.length),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],

                    if (favArtists.isEmpty &&
                        favAlbums.isEmpty &&
                        favSongs.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.favorite_border_rounded,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.noFavoritesYet,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (_selectedSongIds.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MultiSelectActionBar(
                      selectedSongs: selectedSongsList,
                      allAvailableSongs: favSongs,
                      playerProvider: widget.playerProvider,
                      onClearSelection: _clearSongSelection,
                      onSelectAll: () => _selectAllSongs(favSongs),
                      bottomPadding:
                          widget.playerProvider.currentSong != null
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

  void _showSortBottomSheet(BuildContext context) {
    var theme = Theme.of(context);
    var l10n = context.l10n;
    var settings = SettingsProvider.instance;

    var options = [
      (l10n.sortByName, 'name'),
      (l10n.sortByDuration, 'duration'),
      (l10n.sortByDateFavorited, 'date'),
    ];

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
                        l10n.sort,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.sortSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RadioGroup<String>(
                        groupValue: settings.favoritesSortBy,
                        onChanged: (val) {
                          settings.saveSortSettings(favoritesSortBy: val!);
                          setSheetState(() {});
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
                        title: Text(l10n.sortAscending),
                        value: settings.favoritesSortAscending,
                        onChanged: (val) {
                          settings.saveSortSettings(
                            favoritesSortAscending: val,
                          );
                          setSheetState(() {});
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
}
