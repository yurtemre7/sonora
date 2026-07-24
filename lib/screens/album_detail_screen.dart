import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/utils/format_utils.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/animated_favorite_button.dart';
import 'package:sonora/widgets/song_tile.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.playerProvider,
  });

  final AlbumGroup album;
  final PlayerProvider playerProvider;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var firstSong = album.songs.first;

    return Scaffold(
      body: Stack(
        children: [
          // Blurred background
          if (firstSong.artworkPath != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: ResizeImage(
                        FileImage(File(firstSong.artworkPath!)),
                        width: 120,
                      ),
                      fit: BoxFit.cover,
                      opacity: 0.15,
                    ),
                  ),
                ),
              ),
            ),

          CustomScrollView(
            slivers: [
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => closeRoute(context),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                expandedHeight: 340,
                flexibleSpace: FlexibleSpaceBar(
                  background: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: kToolbarHeight + 12),
                      Hero(
                        tag: 'album_art_${album.name}',
                        child: AlbumArt(
                          artworkPath: firstSong.artworkPath,
                          size: 160,
                          borderRadius: 24,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          album.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          album.artist,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${context.l10n.trackCount(album.songs.length)} • ${formatTotalDuration(album.songs)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Play/Shuffle actions bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            if (album.songs.isNotEmpty) {
                              playerProvider.playSong(
                                album.songs.first,
                                album.songs,
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(context.l10n.play),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (album.songs.isNotEmpty) {
                              playerProvider.quickShuffle(album.songs);
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded),
                          label: Text(context.l10n.shuffle),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ListenableBuilder(
                        listenable: playerProvider,
                        builder: (context, _) {
                          var key = '${album.nameLower}|||${album.artistLower}';
                          var isFav = playerProvider.favoriteAlbums.containsKey(key);
                          return AnimatedFavoriteButton(
                            isFavorite: isFav,
                            onToggle: () =>
                                playerProvider.toggleFavoriteAlbum(key),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Tracks List
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 120),
                sliver: ListenableBuilder(
                  listenable: playerProvider,
                  builder: (context, _) {
                    var currentSong = playerProvider.currentSong;
                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        var song = album.songs[index];
                        var isCurrent =
                            currentSong != null && currentSong.id == song.id;
                        return SongTile(
                          song: song,
                          playerProvider: playerProvider,
                          isCurrent: isCurrent,
                          showDivider: index < album.songs.length - 1,
                          onTap: () =>
                              playerProvider.playSong(song, album.songs),
                        );
                      }, childCount: album.songs.length),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
