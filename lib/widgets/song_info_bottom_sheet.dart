import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sonora/models/song.dart';

void showSongInfoBottomSheet(BuildContext context, Song song) {
  var theme = Theme.of(context);
  var stat = _getFileStat(song.filePath);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Song Information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Title', song.displayTitle, theme),
                  _buildInfoRow('Artist', song.artist, theme),
                  _buildInfoRow('Album', song.album, theme),
                  _buildInfoRow('Duration', song.durationFormatted, theme),
                  _buildInfoRow(
                    'File Path',
                    song.filePath,
                    theme,
                    isPath: true,
                  ),
                  if (song.fileSize != null)
                    _buildInfoRow(
                      'File Size',
                      _formatFileSize(song.fileSize!),
                      theme,
                    ),
                  if (song.lastModifiedMs != null)
                    _buildInfoRow(
                      'Date Modified',
                      _formatDate(
                        DateTime.fromMillisecondsSinceEpoch(
                          song.lastModifiedMs!,
                        ),
                      ),
                      theme,
                    ),
                  if (stat != null && stat.changed != stat.modified)
                    _buildInfoRow(
                      'Date Created',
                      _formatDate(stat.changed),
                      theme,
                    ),
                  if (song.format != null)
                    _buildInfoRow('Format', song.format!.toUpperCase(), theme),
                  if (song.bitrate != null)
                    _buildInfoRow('Bitrate', '${song.bitrate} kbps', theme),
                  if (song.samplerate != null)
                    _buildInfoRow(
                      'Sample Rate',
                      '${(song.samplerate! / 1000).toStringAsFixed(1)} kHz',
                      theme,
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildInfoRow(
  String label,
  String value,
  ThemeData theme, {
  bool isPath = false,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 2),
        isPath
            ? SelectableText(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              )
            : Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
      ],
    ),
  );
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String _formatDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  var m = months[dt.month - 1];
  var d = dt.day;
  var y = dt.year;
  var hr = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  var min = dt.minute.toString().padLeft(2, '0');
  var ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$m $d, $y, $hr:$min $ampm';
}

FileStat? _getFileStat(String path) {
  try {
    return File(path).statSync();
  } catch (_) {
    return null;
  }
}
