import 'package:flutter/material.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/widgets/album_art.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.currentSong,
    required this.isPlaying,
    required this.progress,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  final Song currentSong;
  final bool isPlaying;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var mediaQuery = MediaQuery.of(context);
    var clampedTextScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.3,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedTextScaler),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GestureDetector(
            onTap: onTap,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -100) {
                  // Swipe Up
                  if (onSwipeUp != null) onSwipeUp!();
                } else if (details.primaryVelocity! > 100) {
                  // Swipe Down
                  if (onSwipeDown != null) onSwipeDown!();
                }
              }
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -100) {
                  // Swipe Left (previous track)
                  if (onSwipeLeft != null) onSwipeLeft!();
                } else if (details.primaryVelocity! > 100) {
                  // Swipe Right (next track)
                  if (onSwipeRight != null) onSwipeRight!();
                }
              }
            },
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Progress indicator
                    Positioned(
                      top: 0,
                      left: 12,
                      right: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 6,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              var fillWidth =
                                  constraints.maxWidth *
                                  progress.clamp(0.0, 1.0);
                              return Stack(
                                children: [
                                  Container(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.08),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                    width: fillWidth,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          theme.colorScheme.primary,
                                          theme.colorScheme.tertiary,
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (fillWidth > 8)
                                    Positioned(
                                      left: fillWidth - 5,
                                      top: 0,
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.tertiary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Player contents
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Album art thumbnail
                          AlbumArt(
                            artworkPath: currentSong.artworkPath,
                            size: 44,
                            borderRadius: 8,
                          ),
                          const SizedBox(width: 14),

                          // Title & Artist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  currentSong.displayTitle,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentSong.artist,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Play/Pause button
                          IconButton(
                            onPressed: onPlayPause,
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            iconSize: 30,
                            color: theme.colorScheme.onSurface,
                          ),

                          // Next button
                          IconButton(
                            onPressed: onNext,
                            icon: const Icon(Icons.skip_next_rounded),
                            iconSize: 30,
                            color: theme.colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
