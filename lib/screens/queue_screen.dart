import 'package:flutter/material.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/song_tile.dart';

/// Screen displaying the current play queue with reordering and removal controls.
///
/// Automatically highlights the currently active song, dims played tracks,
/// shows full queue indices, and scrolls the active track into view on load.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key, required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
            appBar: AppBar(title: Text(context.l10n.queue)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.queueEmpty,
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
                  ? context.l10n.queueNOfM(currentIndex + 1, queue.length)
                  : context.l10n.queue,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: context.l10n.saveAsPlaylist,
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => _SaveQueueDialogContent(
                      playerProvider: widget.playerProvider,
                    ),
                  );
                },
              ),
            ],
          ),
          body: Scrollbar(
            controller: _scrollController,
            child: ReorderableListView.builder(
              scrollController: _scrollController,
              itemCount: queue.length,
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                widget.playerProvider.reorderQueue(oldIndex, newIndex);
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    var animValue = Curves.easeInOut.transform(animation.value);
                    var elevation = animValue * 6.0;
                    return Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      shadowColor: theme.colorScheme.shadow.withValues(
                        alpha: 0.2,
                      ),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              itemBuilder: (context, index) {
                var song = queue[index];
                var isCurrent =
                    current != null &&
                    song.id == current.id &&
                    index == currentIndex;
                var isOld = index < currentIndex;

                return Column(
                  key: ValueKey<String>('queue_${song.id}_$index'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Dismissible(
                      key: ValueKey<String>('dismiss_${song.id}_$index'),
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
                        var currentIndex = widget.playerProvider.queue
                            .indexWhere((s) => s.id == song.id);
                        if (currentIndex >= 0) {
                          widget.playerProvider.removeFromQueue(currentIndex);
                        }
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.removedFromQueue(song.displayTitle),
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.15,
                                )
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: 3.5,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Opacity(
                          opacity: isOld ? 0.35 : 1.0,
                          child: Row(
                            children: [
                              const SizedBox(width: 2),
                              ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: isOld ? 0.25 : 0.5),
                                    size: 20,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 26,
                                child: Text(
                                  '${index + 1}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isCurrent
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant
                                              .withValues(
                                                alpha: isOld ? 0.35 : 0.7,
                                              ),
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: SongTile(
                                  hideMenu: true,
                                  song: song,
                                  isCurrent: isCurrent,
                                  showHighlightBackground: false,
                                  onTap: () {
                                    if (!isCurrent) {
                                      widget.playerProvider.audioHandler
                                          .skipToQueueItem(index);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (index < queue.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Divider(
                          height: 1,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.06,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SaveQueueDialogContent extends StatefulWidget {
  const _SaveQueueDialogContent({required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<_SaveQueueDialogContent> createState() =>
      _SaveQueueDialogContentState();
}

class _SaveQueueDialogContentState extends State<_SaveQueueDialogContent> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.saveQueueAsPlaylist),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: context.l10n.playlistName),
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            var name = _controller.text.trim();
            if (name.isNotEmpty) {
              widget.playerProvider.saveQueueAsPlaylist(name);
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Saved $name')));
            }
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
