import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/widgets/confirm_delete_dialog.dart';

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
  var _syncMethod = 'parallel';
  int? _lastSyncDurationParallel;
  int? _lastSyncDurationSequential;
  String? _lastSyncMethodUsed;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  var _keepPlayingOnClose = false;

  Future<void> _loadSettings() async {
    var scanner = MusicScanner();
    var folder = await scanner.getScanFolder();
    var syncTime = await scanner.getLastSyncTime();
    var prefs = SharedPreferencesAsync();
    var keepPlaying = await prefs.getBool('keep_playing_on_close') ?? false;

    var syncMethod = await scanner.getSyncMethod();
    var durationParallel = await scanner.getLastSyncDuration('parallel');
    var durationSequential = await scanner.getLastSyncDuration('sequential');
    var lastMethodUsed = await scanner.getLastSyncMethodUsed();

    var version = '1.0.0';
    try {
      var packageInfo = await PackageInfo.fromPlatform();
      version = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _scanFolder = folder;
      _lastSyncTime = syncTime;
      _keepPlayingOnClose = keepPlaying;
      _appVersion = version;
      _syncMethod = syncMethod;
      _lastSyncDurationParallel = durationParallel;
      _lastSyncDurationSequential = durationSequential;
      _lastSyncMethodUsed = lastMethodUsed;
    });
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
    String value,
  ) {
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
                    title: const Text('Sleep Timer Extension'),
                    subtitle: Text(
                      'Add ${widget.playerProvider.sleepTimerExtendMinutes} minutes on extend button press',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Slider(
                      value: widget.playerProvider.sleepTimerExtendMinutes
                          .toDouble(),
                      min: 1.0,
                      max: 30.0,
                      divisions: 29,
                      label:
                          '${widget.playerProvider.sleepTimerExtendMinutes} min',
                      onChanged: (val) => widget.playerProvider
                          .setSleepTimerExtendMinutes(val.toInt()),
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
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 16),
                    Text(
                      'Sync Method',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Parallel uses multi-core isolates to scan your files concurrently. Sequential runs on a single thread.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Parallel sync is resource-heavy and recommended for devices with at least 4 CPU cores.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'parallel',
                            label: Text('Parallel (Isolates)'),
                            icon: Icon(Icons.bolt_rounded),
                          ),
                          ButtonSegment(
                            value: 'sequential',
                            label: Text('Sequential (Legacy)'),
                            icon: Icon(Icons.slow_motion_video_rounded),
                          ),
                        ],
                        selected: {_syncMethod},
                        onSelectionChanged: (newSelection) async {
                          var method = newSelection.first;
                          var scanner = MusicScanner();
                          await scanner.setSyncMethod(method);
                          setState(() {
                            _syncMethod = method;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_lastSyncDurationParallel != null || _lastSyncDurationSequential != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Scan Time Comparison:',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Parallel (Multi-core):',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  _lastSyncDurationParallel != null
                                      ? '${_lastSyncDurationParallel}ms'
                                      : 'Not scanned yet',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _lastSyncMethodUsed == 'parallel'
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sequential (Legacy):',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  _lastSyncDurationSequential != null
                                      ? '${_lastSyncDurationSequential}ms'
                                      : 'Not scanned yet',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _lastSyncMethodUsed == 'sequential'
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Divider(),
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
                            ],
                          ),
                        ),
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

                                      var methodDisplay = _lastSyncMethodUsed == 'sequential'
                                          ? 'Sequential (Legacy)'
                                          : 'Parallel (Isolates)';
                                      var durationMs = _lastSyncMethodUsed == 'sequential'
                                          ? _lastSyncDurationSequential
                                          : _lastSyncDurationParallel;
                                      var durationText = durationMs != null ? ' in ${durationMs}ms' : '';

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Synced ${widget.playerProvider.allSongs.length} songs$durationText using $methodDisplay method.',
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
