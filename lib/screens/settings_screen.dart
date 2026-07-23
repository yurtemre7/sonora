import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/routing/app_routes.dart';
import 'package:sonora/screens/settings/debug_caches_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onConfigureFolder,
    required this.onResetApp,
    required this.onRetriggerSync,
    required this.themeProvider,
    required this.playerProvider,
    required this.settingsProvider,
  });

  final Future<void> Function() onConfigureFolder;
  final VoidCallback onResetApp;
  final Future<void> Function() onRetriggerSync;
  final ThemeProvider themeProvider;
  final PlayerProvider playerProvider;
  final SettingsProvider settingsProvider;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _isSyncing = false;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
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
          ListenableBuilder(
            listenable: widget.settingsProvider,
            builder: (context, _) {
              return Padding(
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
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.settingsProvider.scanFolder ??
                                        'Not configured',
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
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              width: constraints.maxWidth,
                              height: 1,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
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
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.settingsProvider.lastSyncTime ??
                                        'Never synced',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (widget
                                          .settingsProvider
                                          .lastSyncDuration !=
                                      null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Duration: ${widget.settingsProvider.lastSyncDuration}ms',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            if (widget.settingsProvider.scanFolder != null)
                              FilledButton.tonalIcon(
                                onPressed: _isSyncing
                                    ? null
                                    : () async {
                                        setState(() {
                                          _isSyncing = true;
                                        });
                                        try {
                                          await widget.onRetriggerSync();
                                          if (!context.mounted) return;

                                          var durationText =
                                              widget
                                                      .settingsProvider
                                                      .lastSyncDuration !=
                                                  null
                                              ? ' in ${widget.settingsProvider.lastSyncDuration}ms'
                                              : '';

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Synced ${widget.playerProvider.allSongs.length} songs$durationText.',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
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
                                label: Text(
                                  _isSyncing ? 'Syncing...' : 'Sync Now',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
            leading: const Icon(Icons.title_rounded),
            title: const Text('Library Formatting'),
            subtitle: const Text('Configure how song titles are displayed'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.settingsFormatting);
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
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy & Permissions'),
            subtitle: const Text('Data management and required permissions'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.settingsPrivacy);
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
          if (kDebugMode) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Text(
                'Developer Tools',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.bug_report_outlined,
                color: theme.colorScheme.tertiary,
              ),
              title: Text(
                'Debug Cache Info',
                style: TextStyle(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'View raw formatted cache data, local artist images, and sync state',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DebugCachesScreen(
                      playerProvider: widget.playerProvider,
                      settingsProvider: widget.settingsProvider,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
