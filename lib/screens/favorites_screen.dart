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
          return widget.playerProvider.favoriteAlbums.contains(
            '${a.nameLower}|||${a.artistLower}',
          );
        }).toList();
        var favArtists = widget.allArtists.where((a) {
          return widget.playerProvider.favoriteArtists.contains(a.nameLower);
        }).toList();

        var sortAsc = SettingsProvider.instance.favoritesSortAscending;
        favSongs.sort((a, b) => sortAsc ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
        favAlbums.sort((a, b) => sortAsc ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
        favArtists.sort((a, b) => sortAsc ? a.name.compareTo(b.name) : b.name.compareTo(a.name));

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.favorites),
            centerTitle: true,
            actions: [
              PopupMenuButton<bool>(
                icon: const Icon(Icons.sort_rounded),
                onSelected: (asc) {
                  SettingsProvider.instance.saveSortSettings(favoritesSortAscending: asc);
                },
                itemBuilder: (context) {
                  var isAsc = SettingsProvider.instance.favoritesSortAscending;
                  return [
                    PopupMenuItem(
                      value: true,
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: isAsc ? theme.colorScheme.primary : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.sortAscending,
                            style: TextStyle(
                              color: isAsc ? theme.colorScheme.primary : null,
                              fontWeight: isAsc ? FontWeight.bold : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: false,
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            color: !isAsc ? theme.colorScheme.primary : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.sortDescending,
                            style: TextStyle(
                              color: !isAsc ? theme.colorScheme.primary : null,
                              fontWeight: !isAsc ? FontWeight.bold : null,
                            ),
                          ),
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
