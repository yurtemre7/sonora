import 'package:flutter/material.dart';

import 'package:sonora/services/music_scanner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onConfigureFolder,
    required this.onResetApp,
    required this.onRetriggerSync,
  });

  final Future<void> Function() onConfigureFolder;
  final VoidCallback onResetApp;
  final Future<void> Function() onRetriggerSync;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _scanFolder;
  String? _lastSyncTime;
  var _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var scanner = MusicScanner();
    var folder = await scanner.getScanFolder();
    var syncTime = await scanner.getLastSyncTime();
    if (!mounted) return;
    setState(() {
      _scanFolder = folder;
      _lastSyncTime = syncTime;
    });
  }

  void _confirmResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        var theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Reset Application?'),
          content: const Text(
            'This action will permanently delete all imported audio files and clear your library. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Close SettingsScreen
                widget.onResetApp();
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              'Library Sync',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_copy_rounded),
            title: const Text('Sync Folder'),
            subtitle: Text(
              _scanFolder ?? 'Not configured',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              Navigator.pop(context);
              await widget.onConfigureFolder();
            },
          ),
          if (_scanFolder != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 72.0, right: 20.0, bottom: 4.0),
              child: Row(
                children: [
                  Icon(
                    Icons.sync_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _lastSyncTime != null
                          ? 'Last synced: $_lastSyncTime'
                          : 'Never synced',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 64.0, right: 20.0, bottom: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isSyncing
                      ? null
                      : () async {
                          setState(() {
                            _isSyncing = true;
                          });
                          try {
                            await widget.onRetriggerSync();
                            await _loadSettings();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Library synchronization complete.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } finally {
                            if (context.mounted) {
                              setState(() {
                                _isSyncing = false;
                              });
                            }
                          }
                        },
                  icon: _isSyncing
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 72.0, right: 20.0, bottom: 8.0),
              child: Text(
                'New music files added to this folder will scan and sync automatically on app launch and resume.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              'Danger Zone',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
            title: Text(
              'Reset Application',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Delete all imported music and settings'),
            onTap: () {
              _confirmResetDialog(context);
            },
          ),
        ],
      ),
    );
  }
}
