import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/song_tile.dart';

class ArtistDetailScreen extends StatelessWidget {
  const ArtistDetailScreen({
    super.key,
    required this.artist,
    required this.playerProvider,
  });

  final ArtistGroup artist;
  final PlayerProvider playerProvider;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var firstSong = artist.songs.first;
    var imagePath = artist.localImagePath ?? firstSong.artworkPath;

    return Scaffold(
      body: Stack(
        children: [
          // Blurred background
          if (imagePath != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(File(imagePath)),
                      fit: BoxFit.cover,
                      opacity: 0.1,
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
                expandedHeight: 280,
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: AlbumArt(
                              artworkPath: imagePath,
                              size: 140,
                              borderRadius: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            artist.name,
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
                        Text(
                          '${artist.albums.length} ${artist.albums.length == 1 ? 'album' : 'albums'} • ${artist.songs.length} ${artist.songs.length == 1 ? 'song' : 'songs'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
                            if (artist.songs.isNotEmpty) {
                              playerProvider.playSong(
                                artist.songs.first,
                                artist.songs,
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play All'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (artist.songs.isNotEmpty) {
                              playerProvider.quickShuffle(artist.songs);
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Shuffle All'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Albums Carousel (only if they have albums)
              if (artist.albums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24.0,
                      right: 24.0,
                      top: 24.0,
                      bottom: 8.0,
                    ),
                    child: Text(
                      'Albums',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 165,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: artist.albums.length,
                      itemBuilder: (context, index) {
                        var album = artist.albums[index];
                        var albumArtSong = album.songs.first;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: InkWell(
                            onTap: () {
                              openAlbum(context, album);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AlbumArt(
                                  artworkPath: albumArtSong.artworkPath,
                                  size: 110,
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    album.name,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    '${album.songs.length} tracks',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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

              // Popular Tracks Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 24.0,
                    bottom: 8.0,
                  ),
                  child: Text(
                    'Tracks',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),

              // Tracks List
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 120),
                sliver: ListenableBuilder(
                  listenable: playerProvider,
                  builder: (context, _) {
                    var currentSong = playerProvider.currentSong;
                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        var song = artist.songs[index];
                        var isCurrent =
                            currentSong != null && currentSong.id == song.id;
                        return SongTile(
                          song: song,
                          isCurrent: isCurrent,
                          showDivider: index < artist.songs.length - 1,
                          onTap: () =>
                              playerProvider.playSong(song, artist.songs),
                        );
                      }, childCount: artist.songs.length),
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
