import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/album_art.dart';

class PlaylistSelectorBottomSheet extends StatefulWidget {
  const PlaylistSelectorBottomSheet({
    super.key,
    this.song,
    this.songs,
    required this.playerProvider,
  }) : assert(song != null || songs != null, 'Either song or songs must be provided');

  final Song? song;
  final List<Song>? songs;
  final PlayerProvider playerProvider;

  List<Song> get targetSongs => songs ?? (song != null ? [song!] : const []);

  static Future<void> show(
    BuildContext context,
    Song song,
    PlayerProvider playerProvider,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaylistSelectorBottomSheet(
        song: song,
        playerProvider: playerProvider,
      ),
    );
  }

  static Future<void> showForMultiple(
    BuildContext context,
    List<Song> songs,
    PlayerProvider playerProvider,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaylistSelectorBottomSheet(
        songs: songs,
        playerProvider: playerProvider,
      ),
    );
  }

  @override
  State<PlaylistSelectorBottomSheet> createState() =>
      _PlaylistSelectorBottomSheetState();
}

class _PlaylistSelectorBottomSheetState
    extends State<PlaylistSelectorBottomSheet> {
  final _playlistNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.playerProvider.loadPlaylists();
  }

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

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Padding(
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
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.addToPlaylist,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: _showCreatePlaylistDialog,
                            icon: const Icon(Icons.add_rounded),
                            tooltip: context.l10n.createPlaylist,
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
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
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
                          child: Scrollbar(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: playlists.length,
                              itemBuilder: (_, index) {
                                var playlist = playlists[index];
                                var targetSongs = widget.targetSongs;
                                var isSingle = targetSongs.length == 1;
                                var isAlreadyIn = isSingle &&
                                    playlist.songIds.contains(
                                      targetSongs.first.id,
                                    );
                                Song? firstSong;
                                for (var id in playlist.songIds) {
                                  var s = widget.playerProvider.allSongs
                                      .where((s) => s.id == id)
                                      .firstOrNull;
                                  if (s != null) {
                                    firstSong = s;
                                    break;
                                  }
                                }
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        clipBehavior: Clip.antiAlias,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: ListTile(
                                          tileColor: isAlreadyIn
                                              ? theme
                                                    .colorScheme
                                                    .primaryContainer
                                                    .withValues(alpha: 0.15)
                                              : theme
                                                    .colorScheme
                                                    .surfaceContainerLow,
                                          leading: playlist.coverImagePath != null
                                              ? Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    image: DecorationImage(
                                                      image: ResizeImage(
                                                        FileImage(
                                                          File(
                                                            playlist
                                                                .coverImagePath!,
                                                          ),
                                                        ),
                                                        width: 120,
                                                      ),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                )
                                              : firstSong != null
                                                  ? AlbumArt(
                                                      artworkPath:
                                                          firstSong.artworkPath,
                                                      size: 40,
                                                      borderRadius: 8,
                                                    )
                                                  : Icon(
                                                      Icons.playlist_add_rounded,
                                                      color: isAlreadyIn
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                          : null,
                                                    ),
                                          title: Text(
                                            playlist.name,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: isAlreadyIn
                                                      ? FontWeight.w600
                                                      : null,
                                                ),
                                          ),
                                          subtitle: Builder(
                                            builder: (context) {
                                              // Count only IDs that still exist in the
                                              // loaded library, so orphaned/stale IDs
                                              // do not inflate the displayed count.
                                              var allIds = widget
                                                  .playerProvider
                                                  .allSongs
                                                  .map((s) => s.id)
                                                  .toSet();
                                              var liveCount = playlist.songIds
                                                  .where(
                                                    (id) => allIds.contains(id),
                                                  )
                                                  .length;
                                              return Text(
                                                context.l10n.songCount(
                                                  liveCount,
                                                ),
                                              );
                                            },
                                          ),
                                          trailing: isAlreadyIn
                                              ? Icon(
                                                  Icons.check_circle_rounded,
                                                  color:
                                                      theme.colorScheme.primary,
                                                )
                                              : null,
                                          onTap: () async {
                                            var messenger =
                                                ScaffoldMessenger.of(context);
                                            var l10n = context.l10n;
                                            if (isSingle) {
                                              var singleSong =
                                                  targetSongs.first;
                                              if (isAlreadyIn) {
                                                await widget.playerProvider
                                                    .removeSongFromPlaylist(
                                                      playlist.id,
                                                      singleSong.id,
                                                    );
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Removed "${singleSong.displayTitle}" from ${playlist.name}.',
                                                    ),
                                                    behavior:
                                                        SnackBarBehavior.floating,
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                await widget.playerProvider
                                                    .addSongToPlaylist(
                                                      playlist.id,
                                                      singleSong.id,
                                                    );
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Added "${singleSong.displayTitle}" to ${playlist.name}.',
                                                    ),
                                                    behavior:
                                                        SnackBarBehavior.floating,
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                              }
                                            } else {
                                              await widget.playerProvider
                                                  .addSongsToPlaylist(
                                                    playlist.id,
                                                    targetSongs,
                                                  );
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                              }
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10n.batchAddedToPlaylist(
                                                      targetSongs.length,
                                                      playlist.name,
                                                    ),
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    if (index < playlists.length - 1)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 16,
                                        ),
                                        child: Divider(
                                          height: 1,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.06),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog() {
    _playlistNameController.clear();
    var l10n = context.l10n;
    var messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.createPlaylist),
        content: TextField(
          controller: _playlistNameController,
          decoration: InputDecoration(hintText: l10n.playlistName),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              var name = _playlistNameController.text.trim();
              if (name.isNotEmpty) {
                await widget.playerProvider.createPlaylist(name);
                if (widget.targetSongs.isNotEmpty) {
                  var created = widget.playerProvider.playlists
                      .where((p) => p.name == name)
                      .lastOrNull;
                  if (created != null) {
                    await widget.playerProvider.addSongsToPlaylist(
                      created.id,
                      widget.targetSongs,
                    );
                  }
                }
                if (mounted && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (widget.targetSongs.length > 1 && mounted) {
                  Navigator.pop(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.batchAddedToPlaylist(
                          widget.targetSongs.length,
                          name,
                        ),
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }
}
