import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/services/backup_service.dart';
import 'package:sonora/services/native_bridge.dart';
import 'package:sonora/utils/l10n_extension.dart';

/// Exports personal data to a JSON file and restores it again.
class BackupSettingsScreen extends StatefulWidget {
  final PlayerProvider playerProvider;
  final SettingsProvider settingsProvider;
  final ThemeProvider themeProvider;

  const BackupSettingsScreen({
    super.key,
    required this.playerProvider,
    required this.settingsProvider,
    required this.themeProvider,
  });

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _backupService = BackupService();
  var _isBusy = false;

  Future<void> _export() async {
    if (_isBusy) return;
    var l10n = context.l10n;
    var messenger = ScaffoldMessenger.of(context);
    setState(() => _isBusy = true);
    try {
      var appVersion = '';
      try {
        var info = await NativeBridge.getPackageInfo();
        appVersion = info.buildNumber.isEmpty
            ? info.version
            : '${info.version}+${info.buildNumber}';
      } catch (_) {}

      var json = await _backupService.exportToJson(appVersion: appVersion);
      var uri = await FilePicker.saveFile(
        fileName: BackupService.defaultFileName(DateTime.now()),
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (uri != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.backupExportSuccess)),
        );
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupExportFailed)));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _import() async {
    if (_isBusy) return;
    var l10n = context.l10n;
    var messenger = ScaffoldMessenger.of(context);

    BackupDocument document;
    try {
      var file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      var content = utf8.decode(await file.readAsBytes());
      document = BackupService.parse(content);
    } on BackupException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.kind == BackupErrorKind.unsupportedVersion
                ? l10n.backupErrorUnsupportedVersion
                : l10n.backupErrorInvalidFile,
          ),
        ),
      );
      return;
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.backupErrorInvalidFile)),
      );
      return;
    }

    if (!mounted) return;
    var confirmed = await _confirmRestore(document);
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      var result = await _backupService.restoreDocument(document);
      await _reloadProviders(result);

      var parts = [
        l10n.backupRestoreSuccess,
        l10n.playlistCount(result.playlistsRestored),
        l10n.backupRestoredFavorites(result.favoriteSongsRestored),
        if (result.unmatchedSongs > 0)
          l10n.backupUnmatchedSongs(result.unmatchedSongs),
      ];
      messenger.showSnackBar(
        SnackBar(
          content: Text(parts.join(' · ')),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.backupErrorRestoreFailed)),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Applies the restored data to the running app so no restart is needed.
  Future<void> _reloadProviders(BackupRestoreResult result) async {
    var settings = widget.settingsProvider;
    var audioHandler = widget.playerProvider.audioHandler;
    await settings.loadSettings();
    audioHandler.setPauseOnDisconnect(settings.pauseOnDisconnect);
    audioHandler.setResumeOnConnect(settings.resumeOnConnect);
    await audioHandler.setPauseOnDuck(settings.pauseOnDuck);
    await widget.themeProvider.reload();
    await widget.playerProvider.reloadAfterRestore(result.songs);
  }

  Future<bool?> _confirmRestore(BackupDocument document) {
    var locale = Localizations.localeOf(context).toString();
    var date = DateFormat.yMMMd(locale)
        .add_jm()
        .format(document.createdAt.toLocal());

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.settings_backup_restore_rounded),
        title: Text(dialogContext.l10n.backupRestoreConfirmTitle),
        content: SingleChildScrollView(
          child: Text(dialogContext.l10n.backupRestoreConfirmContent(date)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.backupRestoreAction),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(context.l10n.backupRestore),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: _isBusy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 8 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _buildActionCard(
            theme,
            icon: Icons.upload_file_rounded,
            title: context.l10n.backupExportTitle,
            content: context.l10n.backupExportDescription,
            onTap: _isBusy ? null : _export,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            theme,
            icon: Icons.settings_backup_restore_rounded,
            title: context.l10n.backupImportTitle,
            content: context.l10n.backupImportDescription,
            onTap: _isBusy ? null : _import,
          ),
          const SizedBox(height: 24),
          _buildActionCard(
            theme,
            icon: Icons.info_outline_rounded,
            title: context.l10n.backupContentsTitle,
            content: context.l10n.backupContentsContent,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String content,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
