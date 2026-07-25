import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/utils/image_utils.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/confirm_delete_dialog.dart';
import 'package:sonora/widgets/edit_playlist_description_dialog.dart';
import 'package:sonora/widgets/rename_playlist_dialog.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({
    super.key,
    required this.allSongs,
    required this.filteredPlaylists,
    required this.playerProvider,
    required this.onUnfocusSearch,
    required this.onCreatePlaylistDialog,
    required this.onDeletePlaylist,
    required this.onRenamePlaylist,
  });

  final List<Song> allSongs;
  final List<Playlist> filteredPlaylists;
  final PlayerProvider playerProvider;
  final VoidCallback onUnfocusSearch;
  final VoidCallback onCreatePlaylistDialog;
  final Future<void> Function(String playlistId) onDeletePlaylist;
  final Future<void> Function(String playlistId, String newName) onRenamePlaylist;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    if (playerProvider.playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
                'No playlists yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Create custom playlists to group and organize your synced music files.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreatePlaylistDialog,
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Create Playlist'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredPlaylists.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noMatchingPlaylistsFound,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey<String>('playlists_list'),
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: filteredPlaylists.length,
      itemBuilder: (context, index) {
        var playlist = filteredPlaylists[index];
        var songCount = allSongs
            .where((s) => playlist.songIds.contains(s.id))
            .length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: playlist.coverImagePath != null
                  ? Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: ResizeImage(
                            FileImage(File(playlist.coverImagePath!)),
                            width: 144,
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.secondaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
              title: Text(playlist.name),
              subtitle: Text(context.l10n.songCount(songCount)),
              trailing: PopupMenuButton<int>(
                icon: const Icon(Icons.more_vert_rounded),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 6,
                    child: Row(
                      children: [
                        const Icon(Icons.share_rounded),
                        const SizedBox(width: 8),
                        Text(context.l10n.exportToM3u),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 5,
                    child: Row(
                      children: [
                        const Icon(Icons.description_rounded),
                        const SizedBox(width: 8),
                        Text(context.l10n.editDescription),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 3,
                    child: Row(
                      children: [
                        const Icon(Icons.image_rounded),
                        const SizedBox(width: 8),
                        Text(context.l10n.changeCover),
                      ],
                    ),
                  ),
                  if (playlist.coverImagePath != null)
                    PopupMenuItem(
                      value: 4,
                      child: Row(
                        children: [
                          const Icon(Icons.hide_image_rounded),
                          const SizedBox(width: 8),
                          Text(context.l10n.removeCover),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 2,
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded),
                        const SizedBox(width: 8),
                        Text(context.l10n.rename),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 1,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.delete,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (val) async {
                  if (val == 6) {
                    var exportedMsg = context.l10n.exportedPlaylist(playlist.name);
                    var failedMsg = context.l10n.failedToExport;
                    var file = await playerProvider.exportPlaylistToM3u(playlist);
                    if (file != null) {
                      await SharePlus.instance.share(ShareParams(
                        files: [XFile(file.path)],
                        text: exportedMsg,
                      ));
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failedMsg)));
                    }
                  } else if (val == 5) {
                    EditPlaylistDescriptionDialog.show(
                      context,
                      playlist: playlist,
                      onEdit: (newDesc) {
                        playerProvider.updatePlaylistDescription(playlist.id, newDesc);
                      },
                    );
                  } else if (val == 3) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.chooseSquareImage),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    var result = await FilePicker.pickFiles(type: FileType.image);
                    if (result != null && result.files.single.path != null) {
                      var sourceFile = File(result.files.single.path!);
                      var appDir = await getApplicationDocumentsDirectory();
                      var coversDir = Directory('${appDir.path}/playlist_covers');
                      if (!coversDir.existsSync()) {
                        coversDir.createSync(recursive: true);
                      }
                      var newPath = '${coversDir.path}/${playlist.id}.jpg';
                      await PlaylistImageUtils.processAndSavePlaylistCover(
                        sourceFile,
                        newPath,
                      );

                      FileImage(File(newPath)).evict();
                      imageCache.clearLiveImages();

                      await playerProvider.updatePlaylistCover(
                        playlist.id,
                        newPath,
                      );
                    }
                  } else if (val == 4) {
                    await playerProvider.updatePlaylistCover(
                      playlist.id,
                      null,
                    );
                  } else if (val == 2) {
                    RenamePlaylistDialog.show(
                      context,
                      playlist: playlist,
                      onRename: onRenamePlaylist,
                    );
                  } else if (val == 1) {
                    var confirmed = await ConfirmDeleteDialog.show(
                      context,
                      title: 'Delete Playlist?',
                      message: 'Delete "${playlist.name}"? This cannot be undone.',
                    );
                    if (confirmed != true) return;
                    await onDeletePlaylist(playlist.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playlist "${playlist.name}" deleted.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              onTap: () {
                onUnfocusSearch();
                openPlaylist(context, playlist);
              },
            ),
            if (index < filteredPlaylists.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 72),
                child: Divider(
                  height: 1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
          ],
        );
      },
    );
  }
}
