import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/services/native_bridge.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/playlist_selector.dart';

/// Floating Material 3 Contextual Action Bar for batch operations on selected songs.
class MultiSelectActionBar extends StatelessWidget {
  const MultiSelectActionBar({
    super.key,
    required this.selectedSongs,
    required this.allAvailableSongs,
    this.playerProvider,
    required this.onClearSelection,
    required this.onSelectAll,
    this.playlistId,
    this.playlistName,
    this.bottomPadding = 80.0,
  });

  final List<Song> selectedSongs;
  final List<Song> allAvailableSongs;
  final PlayerProvider? playerProvider;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectAll;
  final String? playlistId;
  final String? playlistName;
  final double bottomPadding;

  bool get isVisible => selectedSongs.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var l10n = context.l10n;
    var allSelected =
        allAvailableSongs.isNotEmpty &&
        selectedSongs.length >= allAvailableSongs.length;

    var allFavorited =
        selectedSongs.isNotEmpty && selectedSongs.every((s) => s.isFavorite);

    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomPadding + 12,
          ),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top bar: Close button, Count Pill, Select All toggle
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: l10n.close,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          onClearSelection();
                        },
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l10n.selectedCount(selectedSongs.length),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (allSelected) {
                            onClearSelection();
                          } else {
                            onSelectAll();
                          }
                        },
                        icon: Icon(
                          allSelected
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 18,
                        ),
                        label: Text(
                          allSelected ? l10n.deselectAll : l10n.selectAll,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Actions row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Play Next
                        _ActionButton(
                          icon: Icons.playlist_play_rounded,
                          label: l10n.playNext,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            playerProvider?.playNextSongs(selectedSongs);
                            var messenger = ScaffoldMessenger.of(context);
                            onClearSelection();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.batchAddedToPlayNext(
                                    selectedSongs.length,
                                  ),
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),

                        // Add to Queue
                        _ActionButton(
                          icon: Icons.queue_music_rounded,
                          label: l10n.addToQueue,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            playerProvider?.addSongsToQueue(selectedSongs);
                            var messenger = ScaffoldMessenger.of(context);
                            onClearSelection();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.batchAddedToQueue(selectedSongs.length),
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),

                        // Add to Playlist
                        _ActionButton(
                          icon: Icons.playlist_add_rounded,
                          label: l10n.addToPlaylist,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if (playerProvider != null) {
                              PlaylistSelectorBottomSheet.showForMultiple(
                                context,
                                selectedSongs,
                                playerProvider!,
                              );
                            }
                            onClearSelection();
                          },
                        ),
                        const SizedBox(width: 4),

                        // Favorite / Unfavorite
                        _ActionButton(
                          icon: allFavorited
                              ? Icons.favorite_border_rounded
                              : Icons.favorite_rounded,
                          label: allFavorited
                              ? l10n.favoriteRemove
                              : l10n.favoriteSong,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            var newFavState = !allFavorited;
                            playerProvider?.setFavorites(
                              selectedSongs.map((s) => s.id).toList(),
                              newFavState,
                            );
                            var messenger = ScaffoldMessenger.of(context);
                            onClearSelection();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  newFavState
                                      ? l10n.batchFavorited(
                                          selectedSongs.length,
                                        )
                                      : l10n.batchUnfavorited(
                                          selectedSongs.length,
                                        ),
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),

                        // Share
                        _ActionButton(
                          icon: Icons.share_rounded,
                          label: l10n.share,
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            var filesToShare = selectedSongs
                                .map((s) => s.filePath)
                                .toList();
                            onClearSelection();
                            await NativeBridge.shareFiles(
                              filesToShare,
                              text: 'Sharing ${filesToShare.length} songs',
                            );
                          },
                        ),

                        // Remove from playlist (if within playlist detail view)
                        if (playlistId != null) ...[
                          const SizedBox(width: 4),
                          _ActionButton(
                            icon: Icons.playlist_remove_rounded,
                            iconColor: theme.colorScheme.error,
                            label: l10n.removeFromPlaylist,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              playerProvider?.removeSongsFromPlaylist(
                                playlistId!,
                                selectedSongs,
                              );
                              var messenger = ScaffoldMessenger.of(context);
                              onClearSelection();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.batchRemovedFromPlaylist(
                                      selectedSongs.length,
                                      playlistName ?? 'playlist',
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: iconColor ?? theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: iconColor ?? theme.colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
