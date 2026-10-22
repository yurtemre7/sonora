import 'package:material_ui/material_ui.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';

/// Dialog body that saves the current queue as a new playlist.
class SaveQueueDialogContent extends StatefulWidget {
  const SaveQueueDialogContent({super.key, required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<SaveQueueDialogContent> createState() => _SaveQueueDialogContentState();
}

class _SaveQueueDialogContentState extends State<SaveQueueDialogContent> {
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
      title: Text(context.l10n.saveQueueAsPlaylist),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: context.l10n.playlistName),
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            var name = _controller.text.trim();
            if (name.isNotEmpty) {
              var messenger = ScaffoldMessenger.of(context);
              var message = context.l10n.savedPlaylist(name);
              Navigator.pop(context);
              widget.playerProvider.saveQueueAsPlaylist(name);
              messenger.showSnackBar(SnackBar(content: Text(message)));
            }
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
