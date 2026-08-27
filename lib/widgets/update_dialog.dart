import 'package:flutter/material.dart';
import 'package:sonora/services/native_bridge.dart';
import 'package:sonora/services/update_service.dart';
import 'package:sonora/utils/l10n_extension.dart';

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.updateInfo});

  final UpdateInfo updateInfo;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  late String _selectedUrl;
  var _isDownloading = false;
  var _downloadProgress = 0.0;
  String? _statusText;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedUrl = widget.updateInfo.recommendedUrl;
  }

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusText = 'Preparing download...';
      _errorMessage = null;
    });

    try {
      var filePath = await UpdateService.downloadApk(
        _selectedUrl,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = total > 0
                  ? (received / total).clamp(0.0, 1.0)
                  : 0.0;
              var percentage = (_downloadProgress * 100).toInt();
              _statusText = 'Downloading update... $percentage%';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _statusText = 'Opening installer...';
        });
      }

      var installed = await UpdateService.installApk(filePath);

      if (!installed && mounted) {
        // Fallback to opening URL in browser if direct native installation launch fails
        await NativeBridge.openUrl(_selectedUrl);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed. Tap to try via browser.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var assets = widget.updateInfo.apkAssets;
    var recommendedAbi = widget.updateInfo.recommendedAbi;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(context.l10n.updateAvailable),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.updateAvailableMessage(widget.updateInfo.version),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (assets.isNotEmpty && !_isDownloading) ...[
              const SizedBox(height: 16),
              Text(
                'Architecture / APK Package',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: assets.entries.map((entry) {
                  var abi = entry.key;
                  var url = entry.value;
                  var isSelected = _selectedUrl == url;
                  var isRecommended = recommendedAbi == abi;

                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(abi),
                        if (isRecommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Recommended',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedUrl = url;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Text(
                _statusText ?? 'Downloading update...',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              context.l10n.changelogLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.updateInfo.changelog,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.later),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open link in browser',
            onPressed: () async {
              await NativeBridge.openUrl(_selectedUrl);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          FilledButton.icon(
            onPressed: _startDownloadAndInstall,
            icon: const Icon(Icons.system_update_alt_rounded),
            label: const Text('Update Now'),
          ),
        ] else ...[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(context.l10n.cancel),
          ),
        ],
      ],
    );
  }
}
