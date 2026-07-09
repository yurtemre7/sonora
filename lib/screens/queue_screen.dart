import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/widgets/song_tile.dart';

/// Screen displaying the current play queue with reordering and removal controls.
///
/// Automatically highlights the currently active song, dims played tracks,
/// shows full queue indices, and scrolls the active track into view on load.
class QueueScreen extends StatefulWidget {
  const QueueScreen({
    super.key,
    required this.playerProvider,
  });

  final PlayerProvider playerProvider;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _scrollController = ScrollController();
  var _hasScrolledToActive = false;

  @override
  void initState() {
    super.initState();
    _scrollToActiveItem();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the currently playing item to the center of the list view.
  void _scrollToActiveItem() {
    if (_hasScrolledToActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      var activeIndex = widget.playerProvider.currentIndex;
      if (activeIndex > 0 && _scrollController.hasClients) {
        // Average list item height is roughly 68.0
        var offset = max(0.0, activeIndex * 68.0 - 150.0);
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
        _hasScrolledToActive = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        var queue = widget.playerProvider.queue;
        var current = widget.playerProvider.currentSong;
        var currentIndex = widget.playerProvider.currentIndex;

        if (queue.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Queue'),
            ),
            body: Center(
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
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              currentIndex >= 0
                  ? 'Queue (${currentIndex + 1} of ${queue.length})'
                  : 'Queue',
            ),
          ),
          body: ReorderableListView.builder(
            scrollController: _scrollController,
            itemCount: queue.length,
            // ignore: deprecated_member_use
            onReorder: widget.playerProvider.moveInQueue,
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            itemBuilder: (context, index) {
              var song = queue[index];
              var isCurrent = current != null && song.id == current.id && index == currentIndex;
              var isOld = index < currentIndex;

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
                  widget.playerProvider.removeFromQueue(index);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed "${song.title}" from queue'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: isCurrent ? theme.colorScheme.primary : Colors.transparent,
                        width: 3.5,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Opacity(
                    opacity: isOld ? 0.35 : 1.0,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: isOld ? 0.25 : 0.5),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: isOld ? 0.35 : 0.7),
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SongTile(
                            song: song,
                            onTap: () {
                              if (!isCurrent) {
                                widget.playerProvider.audioHandler.skipToQueueItem(index);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
