import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/routing/app_routes.dart';
import 'package:sonora/services/music_scanner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onConfigureFolder,
    required this.onResetApp,
    required this.onRetriggerSync,
    required this.themeProvider,
    required this.playerProvider,
  });

  final Future<void> Function() onConfigureFolder;
  final VoidCallback onResetApp;
  final Future<void> Function() onRetriggerSync;
  final ThemeProvider themeProvider;
  final PlayerProvider playerProvider;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _scanFolder;
  String? _lastSyncTime;
  var _isSyncing = false;
  int? _lastSyncDuration;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    widget.playerProvider.addListener(_onPlayerProviderUpdate);
  }

  @override
  void dispose() {
    widget.playerProvider.removeListener(_onPlayerProviderUpdate);
    super.dispose();
  }

  void _onPlayerProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSettings() async {
    var scanner = MusicScanner();
    var folder = await scanner.getScanFolder();
    var syncTime = await scanner.getLastSyncTime();
    var duration = await scanner.getLastSyncDuration('sequential');

    if (!mounted) return;
    setState(() {
      _scanFolder = folder;
      _lastSyncTime = syncTime;
      _lastSyncDuration = duration;
    });
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            closeRoute(context);
          },
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ── Library Sync ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Text(
              'Library Sync',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 4.0,
            ),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder_shared_rounded,
                          color: theme.colorScheme.primary,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync Folder Path',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _scanFolder ?? 'Not configured',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        OutlinedButton(
                          onPressed: () async {
                            await widget.onConfigureFolder();
                          },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sonora plays your files locally and offline. When you copy new tracks into this folder, run a sync below to add them to your library.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          width: constraints.maxWidth,
                          height: 1,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                          child: Row(
                            children: List.generate(
                              (constraints.maxWidth / 6).floor(),
                              (index) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  child: Container(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last Sync',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lastSyncTime ?? 'Never synced',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_lastSyncDuration != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Duration: ${_lastSyncDuration}ms',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        if (_scanFolder != null)
                          FilledButton.tonalIcon(
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

                                      var durationText =
                                          _lastSyncDuration != null
                                          ? ' in ${_lastSyncDuration}ms'
                                          : '';

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Synced ${widget.playerProvider.allSongs.length} songs$durationText.',
                                          ),
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
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            icon: _isSyncing
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Statistics ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Text(
              'Statistics',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('View Statistics'),
            subtitle: const Text('See your playback history and stats'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.stats);
            },
          ),
          const Divider(height: 24),

          // ── Sub Settings ──────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: const Text('Theme, colors, visualizer, local images'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.settingsAppearance);
            },
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline_rounded),
            title: const Text('Playback'),
            subtitle: const Text('Sleep timer, start page, background play'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.settingsPlayback);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Info & Support'),
            subtitle: const Text('About, updates, changelog, danger zone'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.settingsInfo);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
