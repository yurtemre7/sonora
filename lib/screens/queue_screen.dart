import 'package:flutter/material.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/widgets/song_tile.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({
    super.key,
    required this.playerProvider,
  });

  final PlayerProvider playerProvider;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
      ),
      body: ListenableBuilder(
        listenable: playerProvider,
        builder: (context, _) {
          var queue = playerProvider.queue;
          var current = playerProvider.currentSong;

          if (queue.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Queue is empty',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            itemCount: queue.length,
            // ignore: deprecated_member_use
            onReorder: playerProvider.moveInQueue,
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            itemBuilder: (context, index) {
              var song = queue[index];
              var isCurrent = current != null && song.id == current.id && index == playerProvider.currentIndex;

              return Dismissible(
                key: ValueKey<String>('${song.id}_$index'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: theme.colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24.0),
                  child: Icon(
                    Icons.delete_sweep_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                onDismissed: (_) {
                  playerProvider.removeFromQueue(index);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed "${song.title}" from queue'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  color: isCurrent
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      // Reorder Drag Handle (custom or built-in, but ReorderableListView automatically creates one or we can build one)
                      const SizedBox(width: 8),
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      Expanded(
                        child: SongTile(
                          song: song,
                          onTap: () {
                            if (!isCurrent) {
                              playerProvider.audioHandler.skipToQueueItem(index);
                            }
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
      ),
    );
  }
}
