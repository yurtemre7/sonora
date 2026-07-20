import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/routing/app_routes.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/services/update_service.dart';
import 'package:sonora/widgets/confirm_delete_dialog.dart';
import 'package:sonora/widgets/theme_color_selector.dart';
import 'package:sonora/widgets/update_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

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
  var _appVersion = '1.0.0';
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

  var _keepPlayingOnClose = false;
  var _pauseOnDuck = true;
  var _isCheckingUpdate = false;
  String? _pendingUpdateUrl;

  Future<void> _loadSettings() async {
    var scanner = MusicScanner();
    var folder = await scanner.getScanFolder();
    var syncTime = await scanner.getLastSyncTime();
    var prefs = SharedPreferencesAsync();
    var keepPlaying = await prefs.getBool('keep_playing_on_close') ?? false;
    var pauseOnDuck = await prefs.getBool('pause_on_duck') ?? false;

    var duration = await scanner.getLastSyncDuration('sequential');

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
      _scanFolder = folder;
      _lastSyncTime = syncTime;
      _keepPlayingOnClose = keepPlaying;
      _pauseOnDuck = pauseOnDuck;
      _appVersion = version;
      _lastSyncDuration = duration;
    });

    if (mounted && UpdateService.pendingUpdateUrl != null) {
      setState(() {
        _pendingUpdateUrl = UpdateService.pendingUpdateUrl;
      });
    }
  }

  Future<void> _confirmResetDialog() async {
    var confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Reset Application?',
      message:
          'This will permanently delete all imported audio files and clear your library. This cannot be undone.',
      confirmLabel: 'Reset',
    );
    if (confirmed != true || !mounted) return;
    closeRoute(context);
    widget.onResetApp();
  }

  void _showThemeModeSheet(BuildContext context) {
    var theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      useRootNavigator: true,
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
                  'Version $_appVersion',
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
                Divider(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
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

  Widget _buildStatRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    var theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => closeRoute(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // ── Appearance ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
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

          ListenableBuilder(
            listenable: widget.playerProvider,
            builder: (context, _) {
              var uniqueColors = widget.playerProvider.getUniqueThemeColors();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'Default App Color',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ThemeColorSelector(
                    colors: uniqueColors,
                    selectedColor: widget.playerProvider.defaultThemeColor,
                    onColorSelected: (color) {
                      widget.playerProvider.setDefaultThemeColor(color);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),

          const Divider(height: 32),

          // ── Playback ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Text(
              'Playback',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline_rounded),
            title: const Text('Keep playing on app close'),
            subtitle: const Text(
              'Keep playing music in the background when swiped away',
            ),
            value: _keepPlayingOnClose,
            onChanged: (val) async {
              var prefs = SharedPreferencesAsync();
              await prefs.setBool('keep_playing_on_close', val);
              setState(() {
                _keepPlayingOnClose = val;
              });
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_paused_rounded),
            title: const Text('Pause on notifications'),
            subtitle: const Text(
              'Pause music instead of lowering volume when a notification arrives',
            ),
            value: _pauseOnDuck,
            onChanged: (val) async {
              var prefs = SharedPreferencesAsync();
              await prefs.setBool('pause_on_duck', val);
              await widget.playerProvider.audioHandler.setPauseOnDuck(val);
              setState(() {
                _pauseOnDuck = val;
              });
            },
          ),
          ListenableBuilder(
            listenable: widget.playerProvider,
            builder: (context, _) {
              return Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.color_lens_outlined),
                    title: const Text('Dynamic Theme (Material You)'),
                    subtitle: const Text(
                      'Automatically theme the app using active album art',
                    ),
                    value: widget.playerProvider.useDynamicTheme,
                    onChanged: (val) =>
                        widget.playerProvider.toggleDynamicTheme(val),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.account_box_outlined),
                    title: const Text('Prefer Local Artist Images'),
                    subtitle: const Text(
                      'Use local artist.jpg files from your music folders when available',
                    ),
                    value: widget.playerProvider.preferLocalArtistImages,
                    onChanged: (val) => widget.playerProvider
                        .togglePreferLocalArtistImages(val),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.bar_chart_rounded),
                    title: const Text('Show Audio Visualizer'),
                    subtitle: const Text(
                      'Animate audio wave visualizer inside player screen',
                    ),
                    value: widget.playerProvider.showVisualizer,
                    onChanged: (val) =>
                        widget.playerProvider.toggleVisualizer(val),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Default Sleep Timer'),
                    subtitle: const Text(
                      'Default duration selected when opening the sleep timer',
                    ),
                    trailing: DropdownButton<int>(
                      value: widget.playerProvider.sleepTimerDefaultMinutes,
                      underline: const SizedBox(),
                      items: [5, 10, 15, 20, 25, 30, 60, 120]
                          .map(
                            (min) => DropdownMenuItem<int>(
                              value: min,
                              child: Text('$min min'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          widget.playerProvider.setSleepTimerDefaultMinutes(
                            val,
                          );
                        }
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: const Text('Default Start Page'),
                    subtitle: const Text('Page to show when the app starts'),
                    trailing: DropdownButton<int>(
                      value: widget.playerProvider.defaultStartPage,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem<int>(value: 0, child: Text('Songs')),
                        DropdownMenuItem<int>(value: 1, child: Text('Albums')),
                        DropdownMenuItem<int>(value: 2, child: Text('Artists')),
                        DropdownMenuItem<int>(
                          value: 3,
                          child: Text('Playlists'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          widget.playerProvider.setDefaultStartPage(val);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          const Divider(height: 32),

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
                    const Divider(),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: widget.playerProvider,
                      builder: (context, _) {
                        var songs = widget.playerProvider.allSongs;
                        if (songs.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        var fileCount = songs.length;
                        var totalBytes = 0;
                        var songsWithLyrics = 0;
                        var formats = <String>{};

                        for (var song in songs) {
                          if (song.fileSize != null) {
                            totalBytes += song.fileSize!;
                          }
                          if (song.hasLyrics) {
                            songsWithLyrics++;
                          }
                          var fmt = song.format;
                          if (fmt != null && fmt.isNotEmpty) {
                            formats.add(fmt.toUpperCase());
                          } else {
                            var dotIdx = song.filePath.lastIndexOf('.');
                            if (dotIdx >= 0) {
                              var ext = song.filePath
                                  .substring(dotIdx + 1)
                                  .toUpperCase();
                              if (ext.length <= 4) {
                                formats.add(ext);
                              }
                            }
                          }
                        }

                        String formattedSize;
                        if (totalBytes >= 1024 * 1024 * 1024) {
                          formattedSize =
                              '${(totalBytes / (1024.0 * 1024.0 * 1024.0)).toStringAsFixed(2)} GB';
                        } else if (totalBytes >= 1024 * 1024) {
                          formattedSize =
                              '${(totalBytes / (1024.0 * 1024.0)).toStringAsFixed(2)} MB';
                        } else if (totalBytes >= 1024) {
                          formattedSize =
                              '${(totalBytes / 1024.0).toStringAsFixed(2)} KB';
                        } else {
                          formattedSize = '$totalBytes B';
                        }

                        var formatList = formats.toList()..sort();
                        var formatText = formatList.join(', ');

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync Details',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                context,
                                Icons.library_music_rounded,
                                'Library Size',
                                '$fileCount songs ($formattedSize)',
                              ),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                context,
                                Icons.audiotrack_rounded,
                                'Audio Formats',
                                formatText.isEmpty ? 'None' : formatText,
                              ),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                context,
                                Icons.palette_rounded,
                                'Unique Themes',
                                '${widget.playerProvider.uniqueThemeCount} unique themes',
                                trailing:
                                    widget.playerProvider.isExtractingColors
                                    ? SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          color: theme.colorScheme.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                context,
                                Icons.lyrics_rounded,
                                'Lyrics Synced',
                                '$songsWithLyrics songs',
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
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

          const Divider(height: 32),

          // ── Statistics ─────────────────────────────────────────────────
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
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text('Listening Statistics'),
            subtitle: const Text('Your listening habits and top songs'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openStats(context),
          ),

          const Divider(height: 32),

          // ── About ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
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
            subtitle: Text('Version $_appVersion'),
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
                : Icon(
                    _pendingUpdateUrl != null
                        ? Icons.download_rounded
                        : Icons.system_update_rounded,
                    color: _pendingUpdateUrl != null
                        ? theme.colorScheme.primary
                        : null,
                  ),
            title: Text(
              _pendingUpdateUrl != null ? 'Update now' : 'Check for Updates',
              style: TextStyle(
                color: _pendingUpdateUrl != null
                    ? theme.colorScheme.primary
                    : null,
                fontWeight: _pendingUpdateUrl != null ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text(
              _pendingUpdateUrl != null
                  ? 'A new version is ready to download'
                  : 'Check GitHub for a new release',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _isCheckingUpdate
                ? null
                : () async {
                    if (_pendingUpdateUrl != null) {
                      var url = Uri.parse(_pendingUpdateUrl!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                      return;
                    }

                    setState(() {
                      _isCheckingUpdate = true;
                    });

                    var result = await UpdateService.checkForUpdate(
                      manual: true,
                    );

                    if (!context.mounted) return;
                    setState(() {
                      _isCheckingUpdate = false;
                      _pendingUpdateUrl = UpdateService.pendingUpdateUrl;
                    });

                    if (result.isRateLimited) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'GitHub API rate limit exceeded. Please try again later.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (result.hasError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to check for updates. Check your internet connection.',
                          ),
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
                        const SnackBar(
                          content: Text(
                            'You are already on the latest version.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
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

          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Changelog'),
            subtitle: const Text('View what\'s new'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.changelog),
          ),

          const Divider(height: 32),

          // ── Danger Zone ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Text(
              'Danger Zone',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SafeArea(
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Reset Application',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text('Delete all imported music and settings'),
              onTap: () {
                _confirmResetDialog();
              },
            ),
          ),
        ],
      ),
    );
  }
}
