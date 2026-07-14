import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/widgets/album_art.dart';
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
                      image: FileImage(File(firstSong.artworkPath!)),
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
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => closeRoute(context),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                expandedHeight: 320,
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Hero(
                          tag: 'album_art_${album.name}',
                          child: AlbumArt(
                            artworkPath: firstSong.artworkPath,
                            size: 180,
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
                          '${album.songs.length} ${album.songs.length == 1 ? 'track' : 'tracks'}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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
                          label: const Text('Play'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (album.songs.isNotEmpty) {
                              var shuffled = List<Song>.from(album.songs)
                                ..shuffle();
                              playerProvider.playSong(shuffled.first, shuffled);
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Shuffle'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tracks List
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
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
