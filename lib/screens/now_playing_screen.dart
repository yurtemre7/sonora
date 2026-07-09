import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/screens/queue_screen.dart';
import 'package:sonora/widgets/animated_vinyl.dart';
import 'package:sonora/widgets/player_controls.dart';
import 'package:sonora/widgets/seek_bar.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({
    super.key,
    required this.playerProvider,
  });

  final PlayerProvider playerProvider;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: playerProvider,
      builder: (context, _) {
        var song = playerProvider.currentSong;

        if (song == null) {
          return const Scaffold(
            body: Center(
              child: Text('No song playing'),
            ),
          );
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              iconSize: 32,
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Now Playing'),
          ),
          body: Stack(
            children: [
              // Blurred background artwork
              if (song.artworkPath != null && File(song.artworkPath!).existsSync())
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                    child: Image.file(
                      File(song.artworkPath!),
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(0.2),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.surfaceContainerHighest,
                          theme.colorScheme.surface,
                        ],
                      ),
                    ),
                  ),
                ),

              // Solid dark overlay gradient
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black54,
                        Colors.black87,
                      ],
                    ),
                  ),
                ),
              ),

              // Player Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Spacer(),

                      // Animated Vinyl disk
                      AnimatedVinyl(
                        artworkPath: song.artworkPath,
                        isPlaying: playerProvider.isPlaying,
                        size: MediaQuery.sizeOf(context).width * 0.72,
                      ),

                      const Spacer(),

                      // Song Info
                      Text(
                        song.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${song.artist} • ${song.album}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 48),

                      // Seek Bar
                      SeekBar(
                        positionStream: playerProvider.positionStream,
                        totalDuration: song.duration,
                        onSeek: playerProvider.seek,
                      ),

                      const SizedBox(height: 24),

                      // Player Controls
                      PlayerControls(
                        isPlaying: playerProvider.isPlaying,
                        isShuffled: playerProvider.isShuffled,
                        repeatMode: playerProvider.repeatMode,
                        onPlayPause: playerProvider.playPause,
                        onNext: playerProvider.next,
                        onPrevious: playerProvider.previous,
                        onShuffle: playerProvider.toggleShuffle,
                        onRepeat: playerProvider.cycleRepeatMode,
                      ),

                      const Spacer(),

                      // Bottom actions (Queue screen button)
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QueueScreen(
                                playerProvider: playerProvider,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.queue_music_rounded),
                        iconSize: 28,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
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
