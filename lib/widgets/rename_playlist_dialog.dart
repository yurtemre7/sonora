import 'package:flutter/material.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/utils/l10n_extension.dart';

class RenamePlaylistDialog {
  static Future<void> show(
    BuildContext context, {
    required Playlist playlist,
    required Future<void> Function(String id, String newName) onRename,
  }) async {
    var textController = TextEditingController(text: playlist.name);
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.renamePlaylist),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.playlistName),
          textCapitalization: TextCapitalization.sentences,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              var newName = textController.text.trim();
              if (newName.isNotEmpty && newName != playlist.name) {
                Navigator.pop(dialogContext);
                await onRename(playlist.id, newName);
              } else if (newName == playlist.name) {
                Navigator.pop(dialogContext);
              }
            },
            child: Text(context.l10n.rename),
          ),
        ],
      ),
    );
  }
}
