import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/song_tile.dart';

/// "Up Next" tab of Now Playing: the queue with drag-to-reorder,
/// swipe-to-remove and scroll-to-current.
class UpNextQueueView extends StatefulWidget {
  const UpNextQueueView({super.key, required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<UpNextQueueView> createState() => _UpNextQueueViewState();
}

class _UpNextQueueViewState extends State<UpNextQueueView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    var queue = widget.playerProvider.queue;

    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.queueEmpty,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        var queue = widget.playerProvider.queue;
        var current = widget.playerProvider.currentSong;
        var currentIndex = widget.playerProvider.currentIndex;
        var safeCurrentIndex =
            (currentIndex >= 0 && currentIndex < queue.length)
            ? currentIndex
            : 0;
        var displayOffset = safeCurrentIndex > 0 ? safeCurrentIndex - 1 : 0;
        var displayQueue = queue.sublist(displayOffset);
        var numDigits = queue.length.toString().length;
        var numberWidth = (numDigits * 9.0 + 16.0).clamp(32.0, 52.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      currentIndex >= 0
                          ? context.l10n.queueNOfM(
                              currentIndex + 1,
                              queue.length,
                            )
                          : context.l10n.queue,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location_rounded, size: 20),
                    tooltip: context.l10n.scrollToCurrentTrack,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: _scrollController,
                itemCount: displayQueue.length,
                buildDefaultDragHandles: false,
                onReorderItem: (oldIndex, newIndex) {
                  widget.playerProvider.reorderQueue(
                    oldIndex + displayOffset,
                    newIndex + displayOffset,
                  );
                },
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      var animValue = Curves.easeInOut.transform(
                        animation.value,
                      );
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
                itemBuilder: (context, index) {
                  var song = displayQueue[index];
                  var actualIndex = index + displayOffset;
                  var isCurrent =
                      current != null &&
                      song.id == current.id &&
                      actualIndex == currentIndex;
                  var isOld = actualIndex < currentIndex;

                  return Column(
                    key: ValueKey<String>(
                      'np_queue_${song.id}_${identityHashCode(song)}',
                    ),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Dismissible(
                        key: ValueKey<String>(
                          'np_dismiss_${song.id}_${identityHashCode(song)}',
                        ),
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
                          var removeIndex = widget.playerProvider.queue
                              .indexWhere((s) => s.id == song.id);
                          if (removeIndex >= 0) {
                            widget.playerProvider.removeFromQueue(removeIndex);
                          }
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
                                          .withValues(
                                            alpha: isOld ? 0.25 : 0.5,
                                          ),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: numberWidth,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${actualIndex + 1}',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: isCurrent
                                                  ? theme.colorScheme.primary
                                                  : theme
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(
                                                          alpha: isOld
                                                              ? 0.35
                                                              : 0.7,
                                                        ),
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
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
                                            .skipToQueueItem(actualIndex);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (index < displayQueue.length - 1)
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
          ],
        );
      },
    );
  }
}
