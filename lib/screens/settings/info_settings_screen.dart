import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/routing/app_routes.dart';
import 'package:sonora/services/update_service.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/confirm_delete_dialog.dart';
import 'package:sonora/widgets/update_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoSettingsScreen extends StatefulWidget {
  const InfoSettingsScreen({super.key, required this.onResetApp});

  final VoidCallback onResetApp;

  @override
  State<InfoSettingsScreen> createState() => _InfoSettingsScreenState();
}

class _InfoSettingsScreenState extends State<InfoSettingsScreen>
    with SingleTickerProviderStateMixin {
  var _isCheckingUpdate = false;
  var _appVersion = '1.0.0';

  // For the 3-second hold gesture
  late AnimationController _dangerZoneController;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _dangerZoneController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              HapticFeedback.heavyImpact();
              _confirmResetDialog();
              _dangerZoneController.reset();
            }
          });
  }

  @override
  void dispose() {
    _dangerZoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    var version = '1.0.0';
    try {
      var packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.version;
      if (packageInfo.buildNumber.isNotEmpty) {
        version += '+${packageInfo.buildNumber}';
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _appVersion = version;
    });
  }

  Future<void> _confirmResetDialog() async {
    var confirmed = await ConfirmDeleteDialog.show(
      context,
      title: context.l10n.resetApplicationConfirmTitle,
      message: context.l10n.resetApplicationConfirmMessage,
      confirmLabel: context.l10n.reset,
    );
    if (confirmed != true || !mounted) return;
    widget.onResetApp();
  }

  String _getFlutterInfo() {
    return '• Material 3';
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset('assets/icon/ic_launcher.png'),
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
                  context.l10n.version(_appVersion),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.appDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Divider(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.madeWithLove,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Flutter ${_getFlutterInfo()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.close),
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
        title: Text(context.l10n.infoSettings),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            // ── App Info ──────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(context.l10n.aboutSonora),
              subtitle: Text(context.l10n.version(_appVersion)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showAboutAppDialog(context),
            ),
            ListTile(
              leading: _isCheckingUpdate
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_rounded),
              title: Text(context.l10n.checkForUpdates),
              subtitle: Text(context.l10n.checkForUpdatesSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _isCheckingUpdate
                  ? null
                  : () async {
                      setState(() {
                        _isCheckingUpdate = true;
                      });

                      var result = await UpdateService.checkForUpdate();

                      if (!context.mounted) return;
                      setState(() {
                        _isCheckingUpdate = false;
                      });

                      if (result.isRateLimited) {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            title: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                Text(context.l10n.rateLimitTitle),
                              ],
                            ),
                            content: Text(context.l10n.rateLimitMessage),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext),
                                child: Text(context.l10n.cancel),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  Navigator.pop(dialogContext);
                                  var githubUrl = Uri.parse(
                                    'https://github.com/yurtemre7/sonora/releases',
                                  );
                                  await launchUrl(
                                    githubUrl,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: Text(context.l10n.openGithubReleases),
                              ),
                            ],
                          ),
                        );
                      } else if (result.hasError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.updateCheckFailed),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else if (result.update != null) {
                        showDialog(
                          context: context,
                          builder: (context) =>
                              UpdateDialog(updateInfo: result.update!),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.alreadyOnLatest),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.sync_rounded),
              title: Text(context.l10n.autoCheckUpdates),
              subtitle: Text(context.l10n.autoCheckUpdatesSubtitle),
              value: SettingsProvider.instance.autoCheckUpdates,
              onChanged: (val) {
                setState(() {
                  SettingsProvider.instance.setAutoCheckUpdates(val);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(context.l10n.changelogTitle),
              subtitle: Text(context.l10n.changelogSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                context.push(AppRoutes.changelog);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(context.l10n.licenses),
              subtitle: Text(context.l10n.licensesSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'Sonora',
                  applicationVersion: _appVersion,
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

            // ── Community & Support ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Text(
                context.l10n.communityAndSupport,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: Text(context.l10n.sourceCode),
              subtitle: Text(context.l10n.sourceCodeSubtitle),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () async {
                var url = Uri.parse('https://github.com/yurtemre7/sonora');
                await launchUrl(url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: Text(context.l10n.developerProfile),
              subtitle: Text(context.l10n.developerProfileSubtitle),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () async {
                var url = Uri.parse('https://github.com/yurtemre7');
                await launchUrl(url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.send_rounded),
              title: Text(context.l10n.telegramContact),
              subtitle: Text(context.l10n.telegramContactSubtitle),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () async {
                var url = Uri.parse('https://t.me/emredev');
                await launchUrl(url);
              },
            ),

            const Divider(height: 32),

            // ── Danger Zone ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Text(
                context.l10n.dangerZone,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: GestureDetector(
                onLongPressDown: (_) {
                  HapticFeedback.lightImpact();
                  _dangerZoneController.forward();
                },
                onLongPressUp: () {
                  _dangerZoneController.reverse();
                },
                onLongPressCancel: () {
                  _dangerZoneController.reverse();
                },
                child: AnimatedBuilder(
                  animation: _dangerZoneController,
                  builder: (context, child) {
                    return Card(
                      elevation: 0,
                      color: Color.lerp(
                        theme.colorScheme.errorContainer,
                        theme.colorScheme.errorContainer,
                        _dangerZoneController.value,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: theme.colorScheme.error.withValues(
                            alpha: 0.5 + (_dangerZoneController.value * 0.5),
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Progress indicator background
                          if (_dangerZoneController.value > 0)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: LinearProgressIndicator(
                                  value: _dangerZoneController.value,
                                  backgroundColor: Colors.transparent,
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: theme.colorScheme.error,
                                  size: 28,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.resetApplication,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: theme.colorScheme.error,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.l10n.resetApplicationSubtitle,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onErrorContainer,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
