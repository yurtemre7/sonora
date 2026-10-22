import 'package:material_ui/material_ui.dart';
import 'package:sonora/utils/l10n_extension.dart';

/// Dialog body that asks for a new playlist name.
class CreatePlaylistDialogContent extends StatefulWidget {
  const CreatePlaylistDialogContent({super.key, required this.onCreate});

  final Future<void> Function(String name) onCreate;

  @override
  State<CreatePlaylistDialogContent> createState() =>
      _CreatePlaylistDialogContentState();
}

class _CreatePlaylistDialogContentState
    extends State<CreatePlaylistDialogContent> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.createPlaylist),
      content: TextField(
        controller: _controller,
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
            var name = _controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(context);
              await widget.onCreate(name);
            }
          },
          child: Text(context.l10n.create),
        ),
      ],
    );
  }
}
