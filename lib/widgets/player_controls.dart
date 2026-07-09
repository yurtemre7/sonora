import 'package:flutter/material.dart' hide RepeatMode;

import 'package:sonora/providers/player_provider.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.isShuffled,
    required this.repeatMode,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onRepeat,
  });

  final bool isPlaying;
  final bool isShuffled;
  final RepeatMode repeatMode;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle
        IconButton(
          onPressed: onShuffle,
          icon: Icon(
            isShuffled ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
          ),
          iconSize: 24,
          color: isShuffled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),

        // Previous
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 36,
          color: theme.colorScheme.onSurface,
        ),
        const SizedBox(width: 8),

        // Play / Pause
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: IconButton(
              key: ValueKey<bool>(isPlaying),
              onPressed: onPlayPause,
              icon: Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              iconSize: 36,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Next
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 36,
          color: theme.colorScheme.onSurface,
        ),
        const SizedBox(width: 12),

        // Repeat
        IconButton(
          onPressed: onRepeat,
          icon: Icon(
            repeatMode == RepeatMode.one
                ? Icons.repeat_one_on_rounded
                : (repeatMode == RepeatMode.all
                    ? Icons.repeat_on_rounded
                    : Icons.repeat_rounded),
          ),
          iconSize: 24,
          color: repeatMode != RepeatMode.off
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
