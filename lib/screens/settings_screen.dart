import 'package:flutter/material.dart';

import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/services/music_scanner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onConfigureFolder,
    required this.onResetApp,
    required this.onRetriggerSync,
    required this.themeProvider,
  });

  final Future<void> Function() onConfigureFolder;
  final VoidCallback onResetApp;
  final Future<void> Function() onRetriggerSync;
  final ThemeProvider themeProvider;

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

  void _showThemeModeSheet(BuildContext context) {
    var theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListenableBuilder(
            listenable: widget.themeProvider,
            builder: (context, _) {
              var currentMode = widget.themeProvider.themeMode;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(
                      'Choose Theme',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RadioGroup<ThemeMode>(
                    groupValue: currentMode,
                    onChanged: (value) {
                      if (value == null) return;
                      widget.themeProvider.setThemeMode(value);
                      Navigator.pop(sheetContext);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          title: const Text('System Default'),
                          subtitle: const Text('Follows your device theme'),
                          secondary: const Icon(Icons.brightness_auto_rounded),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          title: const Text('Light'),
                          subtitle: const Text('Always use light theme'),
                          secondary: const Icon(Icons.light_mode_rounded),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          title: const Text('Dark'),
                          subtitle: const Text('Always use dark theme'),
                          secondary: const Icon(Icons.dark_mode_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showAboutAppDialog(BuildContext context) {
    var theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 40,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sonora',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A beautiful local music player for Android, built with Flutter and Material 3 Expressive design.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Made with ❤️ by yurtemre',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Flutter ${_getFlutterInfo()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _getFlutterInfo() {
    return '• Material 3';
  }

  String _themeModeName(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System Default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  IconData _themeModeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
    };
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
          // ── Appearance ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              'Appearance',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: widget.themeProvider,
            builder: (context, _) {
              var mode = widget.themeProvider.themeMode;
              return ListTile(
                leading: Icon(_themeModeIcon(mode)),
                title: const Text('Theme'),
                subtitle: Text(_themeModeName(mode)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showThemeModeSheet(context),
              );
            },
          ),

          const Divider(height: 32),

          // ── Library Sync ──────────────────────────────────────────────
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

          // ── About ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              'About',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About Sonora'),
            subtitle: const Text('Version 1.0.0'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showAboutAppDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licenses'),
            subtitle: const Text('Open source licenses'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Sonora',
                applicationVersion: '1.0.0',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 32,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              );
            },
          ),

          const Divider(height: 32),

          // ── Danger Zone ───────────────────────────────────────────────
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
