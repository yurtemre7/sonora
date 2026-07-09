import 'package:flutter/material.dart';

import 'package:sonora/models/song.dart';
import 'package:sonora/widgets/album_art.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.onPlayNext,
    this.onAddToQueue,
    this.onShowInFolder,
    this.onAddToPlaylist,
    this.onShowInfo,
    this.onToggleFavorite,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onShowInFolder;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShowInfo;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            AlbumArt(
              artworkPath: song.artworkPath,
              size: 48,
              borderRadius: 10,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onPlayNext != null || onAddToQueue != null || onShowInFolder != null || onAddToPlaylist != null || onShowInfo != null || onToggleFavorite != null) ...[
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
                  if (value == 1 && onPlayNext != null) onPlayNext!();
                  if (value == 2 && onAddToQueue != null) onAddToQueue!();
                  if (value == 3 && onShowInFolder != null) onShowInFolder!();
                  if (value == 4 && onAddToPlaylist != null) onAddToPlaylist!();
                  if (value == 5 && onShowInfo != null) onShowInfo!();
                  if (value == 6 && onToggleFavorite != null) onToggleFavorite!();
                },
                itemBuilder: (context) => [
                  if (onPlayNext != null)
                    const PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(Icons.playlist_play_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Play Next'),
                        ],
                      ),
                    ),
                  if (onAddToQueue != null)
                    const PopupMenuItem(
                      value: 2,
                      child: Row(
                        children: [
                          Icon(Icons.queue_music_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Add to Queue'),
                        ],
                      ),
                    ),
                  if (onShowInFolder != null)
                    const PopupMenuItem(
                      value: 3,
                      child: Row(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Show in folder'),
                        ],
                      ),
                    ),
                  if (onAddToPlaylist != null)
                    const PopupMenuItem(
                      value: 4,
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Add to playlist'),
                        ],
                      ),
                    ),
                  if (onShowInfo != null)
                    const PopupMenuItem(
                      value: 5,
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Song Info'),
                        ],
                      ),
                    ),
                  if (onToggleFavorite != null)
                    PopupMenuItem(
                      value: 6,
                      child: Row(
                        children: [
                          Icon(
                            song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 20,
                            color: song.isFavorite ? Colors.red : null,
                          ),
                          const SizedBox(width: 8),
                          Text(song.isFavorite ? 'Remove Favorite' : 'Favorite Song'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
