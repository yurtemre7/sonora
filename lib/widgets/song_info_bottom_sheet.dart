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
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                Text(
                  'Song Information',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      _buildInfoGroup(
                        theme: theme,
                        title: 'Metadata',
                        children: [
                          _buildInfoRow('Title', song.displayTitle, theme),
                          _buildInfoRow('Artist', song.artist, theme),
                          _buildInfoRow('Album', song.album, theme),
                          if (song.trackNumber != null)
                            _buildInfoRow(
                              'Track',
                              song.trackNumber.toString(),
                              theme,
                            ),
                          if (song.genre != null)
                            _buildInfoRow('Genre', song.genre!, theme),
                          if (song.year != null)
                            _buildInfoRow('Year', song.year.toString(), theme),
                          _buildInfoRow(
                            'Duration',
                            song.durationFormatted,
                            theme,
                            isLast: true,
                          ),
                        ],
                      ),
                      _buildInfoGroup(
                        theme: theme,
                        title: 'File Info',
                        children: [
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
                              isLast: song.format == null,
                            ),
                          if (song.format == null)
                            const SizedBox.shrink()
                          else
                            _buildInfoRow(
                              'Format',
                              song.format!.toUpperCase(),
                              theme,
                              isLast: true,
                            ),
                        ],
                      ),
                      if (song.bitrate != null || song.samplerate != null)
                        _buildInfoGroup(
                          theme: theme,
                          title: 'Audio Properties',
                          children: [
                            if (song.bitrate != null)
                              _buildInfoRow(
                                'Bitrate',
                                '${song.bitrate} kbps',
                                theme,
                                isLast: song.samplerate == null,
                              ),
                            if (song.samplerate != null)
                              _buildInfoRow(
                                'Sample Rate',
                                '${(song.samplerate! / 1000).toStringAsFixed(1)} kHz',
                                theme,
                                isLast: true,
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildInfoGroup({
  required ThemeData theme,
  required String title,
  required List<Widget> children,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}

Widget _buildInfoRow(
  String label,
  String value,
  ThemeData theme, {
  bool isPath = false,
  bool isLast = false,
}) {
  return Column(
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
      if (!isLast)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
    ],
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
