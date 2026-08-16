import 'package:flutter/material.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/utils/l10n_extension.dart';

class RenamePlaylistDialog extends StatefulWidget {
  const RenamePlaylistDialog({
    super.key,
    required this.playlist,
    required this.onRename,
  });

  final Playlist playlist;
  final Future<void> Function(String id, String newName) onRename;

  static Future<void> show(
    BuildContext context, {
    required Playlist playlist,
    required Future<void> Function(String id, String newName) onRename,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) =>
          RenamePlaylistDialog(playlist: playlist, onRename: onRename),
    );
  }

  @override
  State<RenamePlaylistDialog> createState() => _RenamePlaylistDialogState();
}

class _RenamePlaylistDialogState extends State<RenamePlaylistDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.playlist.name);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.renamePlaylist),
      content: TextField(
        controller: _textController,
        autofocus: true,
        decoration: InputDecoration(hintText: context.l10n.playlistName),
        textCapitalization: TextCapitalization.sentences,
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            var newName = _textController.text.trim();
            if (newName.isNotEmpty && newName != widget.playlist.name) {
              Navigator.pop(context);
              await widget.onRename(widget.playlist.id, newName);
            } else if (newName == widget.playlist.name) {
              Navigator.pop(context);
            }
          },
          child: Text(context.l10n.rename),
        ),
      ],
    );
  }
}
