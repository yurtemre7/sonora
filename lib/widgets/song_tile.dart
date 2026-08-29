import 'package:flutter/material.dart';

import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/playlist_selector.dart';
import 'package:sonora/widgets/song_info_bottom_sheet.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.playerProvider,
    this.onLongPress,
    this.onRemoveFromPlaylist,
    this.hideMenu = false,
    this.isCurrent = false,
    this.showHighlightBackground = true,
    this.showDivider = false,
    this.isSelecting = false,
    this.isSelected = false,
    this.onSelect,
    this.leadingDragHandle,
  });

  final Song song;
  final VoidCallback onTap;

  /// Optional: provide the player provider so the popup menu can look up
  /// the live favorite state from [PlayerProvider.allSongs] at open time,
  /// avoiding stale-closure issues.
  final PlayerProvider? playerProvider;
  final VoidCallback? onLongPress;
  final VoidCallback? onRemoveFromPlaylist;
  final bool hideMenu;
  final bool isCurrent;
  final bool showHighlightBackground;
  final bool showDivider;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback? onSelect;
  final Widget? leadingDragHandle;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    var isHighlighted = isSelected || (isCurrent && showHighlightBackground && !isSelecting);
    var backgroundColor = isSelected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
        : (isCurrent && showHighlightBackground && !isSelecting
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : Colors.transparent);

    var tileContent = InkWell(
      onTap: isSelecting ? (onSelect ?? onTap) : onTap,
      onLongPress: isSelecting ? (onSelect ?? onTap) : onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.only(
          left: (leadingDragHandle != null && !isSelecting) ? 0 : 12,
          right: 12,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AlbumArt(
                  artworkPath: song.artworkPath,
                  size: 48,
                  borderRadius: 10,
                ),
                if (isSelecting)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : Colors.white.withValues(alpha: 0.85),
                      size: 24,
                    ),
                  ),
              ],
            ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.displayTitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: (isCurrent && !isSelecting)
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: (isCurrent && !isSelecting)
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.7,
                                  )
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    song.durationFormatted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: (isCurrent && !isSelecting)
                          ? theme.colorScheme.primary.withValues(alpha: 0.7)
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: (isCurrent && !isSelecting)
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (!isSelecting &&
                      !hideMenu &&
                      (playerProvider != null ||
                          onRemoveFromPlaylist != null)) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<int>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 160),
                      onSelected: (value) {
                        if (playerProvider != null) {
                          if (value == 1) {
                            playerProvider!.playNext(song);
                          }
                          if (value == 2) {
                            playerProvider!.addToQueue(song);
                          }
                          if (value == 4) {
                            PlaylistSelectorBottomSheet.show(
                              context,
                              song,
                              playerProvider!,
                            );
                          }
                          if (value == 5) {
                            showSongInfoBottomSheet(context, song);
                          }
                          if (value == 6) {
                            playerProvider!.toggleFavorite(song.id);
                          }
                        }
                        if (value == 7 && onRemoveFromPlaylist != null) {
                          onRemoveFromPlaylist!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (playerProvider != null)
                          PopupMenuItem(
                            value: 1,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.playlist_play_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(context.l10n.playNext),
                              ],
                            ),
                          ),
                        if (playerProvider != null)
                          PopupMenuItem(
                            value: 2,
                            child: Row(
                              children: [
                                const Icon(Icons.queue_music_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(context.l10n.addToQueue),
                              ],
                            ),
                          ),
                        if (playerProvider != null)
                          PopupMenuItem(
                            value: 4,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.playlist_add_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(context.l10n.addToPlaylist),
                              ],
                            ),
                          ),
                        if (onRemoveFromPlaylist != null)
                          PopupMenuItem(
                            value: 7,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.playlist_remove_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(context.l10n.removeFromPlaylist),
                              ],
                            ),
                          ),
                        if (playerProvider != null)
                          PopupMenuItem(
                            value: 5,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(context.l10n.songInfo),
                              ],
                            ),
                          ),
                        if (playerProvider != null)
                          // Look up the live isFavorite state from the
                          // provider so this menu item is always fresh
                          // at the moment the menu opens.
                          PopupMenuItem(
                            value: 6,
                            child: Builder(
                              builder: (context) {
                                var liveSong = playerProvider?.allSongs
                                    .where((s) => s.id == song.id)
                                    .firstOrNull;
                                var isFav =
                                    liveSong?.isFavorite ?? song.isFavorite;
                                return Row(
                                  children: [
                                    Icon(
                                      isFav
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 20,
                                      color: isFav ? Colors.red : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isFav
                                          ? context.l10n.favoriteRemove
                                          : context.l10n.favoriteSong,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              left: BorderSide(
                color: isHighlighted
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 3.5,
              ),
            ),
          ),
          child: (leadingDragHandle != null && !isSelecting)
              ? Row(
                  children: [
                    leadingDragHandle!,
                    Expanded(child: tileContent),
                  ],
                )
              : tileContent,
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(
              left: (leadingDragHandle != null && !isSelecting) ? 104 : 72,
            ),
            child: Divider(
              height: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
      ],
    );
  }
}
