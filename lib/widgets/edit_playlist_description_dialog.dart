import 'package:flutter/material.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/utils/l10n_extension.dart';

class EditPlaylistDescriptionDialog extends StatefulWidget {
  final Playlist playlist;
  final ValueChanged<String?> onEdit;

  const EditPlaylistDescriptionDialog({
    super.key,
    required this.playlist,
    required this.onEdit,
  });

  static Future<void> show(
    BuildContext context, {
    required Playlist playlist,
    required ValueChanged<String?> onEdit,
  }) {
    return showDialog(
      context: context,
      builder: (context) => EditPlaylistDescriptionDialog(
        playlist: playlist,
        onEdit: onEdit,
      ),
    );
  }

  @override
  State<EditPlaylistDescriptionDialog> createState() => _EditPlaylistDescriptionDialogState();
}

class _EditPlaylistDescriptionDialogState extends State<EditPlaylistDescriptionDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.playlist.description ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.editDescription),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.description,
          border: const OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            widget.onEdit(_controller.text.trim().isEmpty ? null : _controller.text.trim());
            Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
