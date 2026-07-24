import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/screens/album_detail_screen.dart';
import 'package:sonora/screens/artist_detail_screen.dart';
import 'package:sonora/utils/format_utils.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/artist_avatar.dart';
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
            var durA = a.songs.fold<int>(0, (s, x) => s + x.duration.inMilliseconds);
            var durB = b.songs.fold<int>(0, (s, x) => s + x.duration.inMilliseconds);
            cmp = durA.compareTo(durB);
          } else if (sortBy == 'date') {
            var dateA = widget.playerProvider.favoriteAlbums['${a.nameLower}|||${a.artistLower}'] ?? 0;
            var dateB = widget.playerProvider.favoriteAlbums['${b.nameLower}|||${b.artistLower}'] ?? 0;
            cmp = dateA.compareTo(dateB);
          } else {
            cmp = a.nameLower.compareTo(b.nameLower);
          }
          return sortAsc ? cmp : -cmp;
        });

        favArtists.sort((a, b) {
          var cmp = 0;
          if (sortBy == 'duration') {
            var durA = a.songs.fold<int>(0, (s, x) => s + x.duration.inMilliseconds);
            var durB = b.songs.fold<int>(0, (s, x) => s + x.duration.inMilliseconds);
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

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.favorites),
            centerTitle: true,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded),
                onSelected: (val) {
                  if (val.startsWith('sort_')) {
                    SettingsProvider.instance.saveSortSettings(
                      favoritesSortBy: val.replaceFirst('sort_', ''),
                    );
                  } else if (val.startsWith('asc_')) {
                    SettingsProvider.instance.saveSortSettings(
                      favoritesSortAscending: val == 'asc_true',
                    );
                  }
                },
                itemBuilder: (context) {
                  var sortBy = SettingsProvider.instance.favoritesSortBy;
                  var isAsc = SettingsProvider.instance.favoritesSortAscending;
                  return [
                    PopupMenuItem(
                      value: 'sort_name',
                      child: Row(
                        children: [
                          if (sortBy == 'name')
                            Icon(Icons.check, color: theme.colorScheme.primary)
                          else
                            const SizedBox(width: 24),
                          const SizedBox(width: 8),
                          Text(context.l10n.sortByName),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_duration',
                      child: Row(
                        children: [
                          if (sortBy == 'duration')
                            Icon(Icons.check, color: theme.colorScheme.primary)
                          else
                            const SizedBox(width: 24),
                          const SizedBox(width: 8),
                          Text(context.l10n.sortByDuration),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_date',
                      child: Row(
                        children: [
                          if (sortBy == 'date')
                            Icon(Icons.check, color: theme.colorScheme.primary)
                          else
                            const SizedBox(width: 24),
                          const SizedBox(width: 8),
                          Text(context.l10n.sortByDateFavorited),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'asc_true',
                      child: Row(
                        children: [
                          if (isAsc)
                            Icon(Icons.check, color: theme.colorScheme.primary)
                          else
                            const SizedBox(width: 24),
                          const SizedBox(width: 8),
                          Text(context.l10n.sortAscending),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'asc_false',
                      child: Row(
                        children: [
                          if (!isAsc)
                            Icon(Icons.check, color: theme.colorScheme.primary)
                          else
                            const SizedBox(width: 24),
                          const SizedBox(width: 8),
                          Text(context.l10n.sortDescending),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: CustomScrollView(
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
                          '${favArtists.length}',
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
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: favArtists.length,
                      itemBuilder: (context, index) {
                        var artist = favArtists[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArtistDetailScreen(
                                    artist: artist,
                                    playerProvider: widget.playerProvider,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ArtistAvatar(artist: artist, radius: 36),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    artist.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
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
                          '${favAlbums.length}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Listener(
                    onPointerDown: (_) => _isAutoScrolling = false,
                    onPointerUp: (_) => _isAutoScrolling = true,
                    child: SizedBox(
                      height: 160,
                      child: ListView.builder(
                        controller: _albumScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: favAlbums.length,
                        itemBuilder: (context, index) {
                          var album = favAlbums[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlbumDetailScreen(
                                      album: album,
                                      playerProvider: widget.playerProvider,
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AlbumArt(
                                    artworkPath: album.songs.first.artworkPath,
                                    size: 120,
                                    borderRadius: 12,
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      album.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ],
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
                    return SongTile(
                      song: song,
                      playerProvider: widget.playerProvider,
                      isCurrent: isCurrent,
                      showDivider: index < favSongs.length - 1,
                      onTap: () =>
                          widget.playerProvider.playSong(song, favSongs),
                    );
                  }, childCount: favSongs.length),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ), // padding at bottom
              ],

              if (favArtists.isEmpty && favAlbums.isEmpty && favSongs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
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
        );
      },
    );
  }
}
