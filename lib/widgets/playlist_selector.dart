import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';

class PlaylistSelectorBottomSheet extends StatefulWidget {
  const PlaylistSelectorBottomSheet({
    super.key,
    required this.song,
    required this.playerProvider,
  });

  final Song song;
  final PlayerProvider playerProvider;

  static Future<void> show(BuildContext context, Song song, PlayerProvider playerProvider) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaylistSelectorBottomSheet(
        song: song,
        playerProvider: playerProvider,
      ),
    );
  }

  @override
  State<PlaylistSelectorBottomSheet> createState() => _PlaylistSelectorBottomSheetState();
}

class _PlaylistSelectorBottomSheetState extends State<PlaylistSelectorBottomSheet> {
  final _playlistNameController = TextEditingController();

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        var playlists = widget.playerProvider.playlists;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 8,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add to Playlist',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _showCreatePlaylistDialog,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Create Playlist',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.playlist_add_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No playlists created yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: playlists.length,
                    itemBuilder: (_, index) {
                      var playlist = playlists[index];
                      var isAlreadyIn = playlist.songIds.contains(widget.song.id);
                      var isFavorites = playlist.id == 'favorites';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Material(
                          color: Colors.transparent,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            tileColor: isAlreadyIn
                                ? (isFavorites
                                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
                                    : theme.colorScheme.primaryContainer.withValues(alpha: 0.15))
                                : theme.colorScheme.surfaceContainerLow,
                            leading: Icon(
                              isFavorites
                                  ? (isAlreadyIn ? Icons.favorite_rounded : Icons.favorite_border_rounded)
                                  : Icons.playlist_add_rounded,
                              color: isAlreadyIn
                                  ? (isFavorites ? Colors.red : theme.colorScheme.primary)
                                  : null,
                            ),
                            title: Text(
                              playlist.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: isAlreadyIn ? FontWeight.w600 : null,
                              ),
                            ),
                            subtitle: Text(
                              '${playlist.songIds.length} ${playlist.songIds.length == 1 ? 'song' : 'songs'}',
                            ),
                            trailing: isAlreadyIn
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: isFavorites ? Colors.red : theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: () async {
                              var messenger = ScaffoldMessenger.of(context);
                              if (isFavorites) {
                                await widget.playerProvider.toggleFavorite(widget.song.id);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(!isAlreadyIn
                                        ? 'Added "${widget.song.displayTitle}" to favorites.'
                                        : 'Removed "${widget.song.displayTitle}" from favorites.'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                if (isAlreadyIn) {
                                  await widget.playerProvider.removeSongFromPlaylist(playlist.id, widget.song.id);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Removed "${widget.song.displayTitle}" from ${playlist.name}.'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  await widget.playerProvider.addSongToPlaylist(playlist.id, widget.song.id);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Added "${widget.song.displayTitle}" to ${playlist.name}.'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog() {
    _playlistNameController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: _playlistNameController,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              var name = _playlistNameController.text.trim();
              if (name.isNotEmpty) {
                await widget.playerProvider.createPlaylist(name);
                if (mounted && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
