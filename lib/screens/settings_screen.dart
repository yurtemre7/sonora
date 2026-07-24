import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/l10n/app_localizations_en.dart';
import 'package:sonora/l10n/app_localizations_ja.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/routing/app_routes.dart';
import 'package:sonora/screens/settings/debug_caches_screen.dart';
import 'package:sonora/utils/l10n_extension.dart';

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
    widget.settingsProvider.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    widget.playerProvider.removeListener(_onPlayerProviderUpdate);
    widget.settingsProvider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onPlayerProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings),
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
              context.l10n.librarySync,
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
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.folder_rounded,
                                color: theme.colorScheme.onPrimaryContainer,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.settingsProvider.scanFolder ??
                                        context.l10n.setMusicDirectory,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.settingsProvider.scanFolder !=
                                      null)
                                    Text(
                                      context.l10n.activeSyncLocation,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: widget.onConfigureFolder,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                widget.settingsProvider.scanFolder == null
                                    ? context.l10n.setSyncFolder
                                    : context.l10n.change,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.syncExplanation,
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
                                    context.l10n.lastSync,
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
                                        context.l10n.neverSynced,
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
                                      context.l10n.syncDuration(widget.settingsProvider.lastSyncDuration.toString()),
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
                                              content: Text(context.l10n.syncedXSongs(widget.playerProvider.allSongs.length, durationText)),
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
                                  _isSyncing
                                      ? context.l10n.syncing
                                      : context.l10n.syncNow,
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
              context.l10n.stats,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: Text(context.l10n.viewStatistics),
            subtitle: Text(context.l10n.viewStatisticsSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.stats);
            },
          ),
          const Divider(height: 24),

          // ── Language ──────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(context.l10n.appLanguage),
            subtitle: Text(
              switch (widget.settingsProvider.appLocale) {
                'en' => AppLocalizationsEn().arbLanguage,
                'ja' => AppLocalizationsJa().arbLanguage,
                _ => context.l10n.systemDefault,
              },
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) => SimpleDialog(
                  title: Text(context.l10n.selectLanguage),
                  children: [
                    for (var option in [
                      ('system', context.l10n.systemDefault),
                      ('en', AppLocalizationsEn().arbLanguage),
                      ('ja', AppLocalizationsJa().arbLanguage),
                    ])
                      ListTile(
                        leading: Icon(
                          widget.settingsProvider.appLocale == option.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: widget.settingsProvider.appLocale == option.$1
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(option.$2),
                        onTap: () {
                          widget.settingsProvider.setAppLocale(option.$1);
                          Navigator.pop(dialogContext);
                        },
                      ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 24),

          // ── Sub Settings ──────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.appearance),
            subtitle: Text(context.l10n.appearanceSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.settingsAppearance);
            },
          ),
          ListTile(
            leading: const Icon(Icons.title_rounded),
            title: Text(context.l10n.libraryFormatting),
            subtitle: Text(context.l10n.formattingSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.settingsFormatting);
            },
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline_rounded),
            title: Text(context.l10n.playback),
            subtitle: Text(context.l10n.playbackSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.settingsPlayback);
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(context.l10n.privacySettings),
            subtitle: Text(context.l10n.privacySubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.push(AppRoutes.settingsPrivacy);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(context.l10n.infoSettings),
            subtitle: Text(context.l10n.infoSubtitle),
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
