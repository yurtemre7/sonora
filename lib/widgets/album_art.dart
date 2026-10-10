import 'dart:io';

import 'package:material_ui/material_ui.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.artworkPath,
    required this.size,
    this.borderRadius = 16,
  });

  final String? artworkPath;
  final double size;
  final double borderRadius;

  static final _existingFiles = <String>{};
  static final _missingFiles = <String>{};

  /// Fast file existence check with in-memory set to prevent repeated sync disk stats during scrolling.
  static bool checkFileExists(String path) {
    if (_existingFiles.contains(path)) return true;
    if (_missingFiles.contains(path)) return false;
    var exists = File(path).existsSync();
    if (exists) {
      _existingFiles.add(path);
    } else {
      _missingFiles.add(path);
    }
    return exists;
  }

  /// Clears the file existence cache (e.g. when albums or playlists change).
  static void clearFileCache([String? path]) {
    if (path != null) {
      _existingFiles.remove(path);
      _missingFiles.remove(path);
    } else {
      _existingFiles.clear();
      _missingFiles.clear();
    }
  }

  /// Standardized cache dimension calculation matching [Image.file] resize behavior.
  static int computeCacheDim(double size, [double devicePixelRatio = 2.0]) {
    var dpr = devicePixelRatio.clamp(1.0, 2.5);
    var rawCacheDim = (size * dpr).toInt();
    return ((rawCacheDim / 128).ceil() * 128).clamp(128, 800);
  }

  /// Standardized [ImageProvider] factory ensuring pre-flight and UI cache keys match 100%.
  static ImageProvider provider(
    String artworkPath, {
    double size = 48,
    int? cacheDim,
    double devicePixelRatio = 2.0,
  }) {
    var targetDim = cacheDim ?? computeCacheDim(size, devicePixelRatio);
    return ResizeImage.resizeIfNeeded(
      targetDim,
      null,
      FileImage(File(artworkPath)),
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var hasArtworkFile = artworkPath != null && checkFileExists(artworkPath!);

    return LayoutBuilder(
      builder: (context, constraints) {
        var resolvedSize = (size.isInfinite || size > 10000.0)
            ? (constraints.hasBoundedWidth ? constraints.maxWidth : 120.0)
            : size;

        var dpr = MediaQuery.of(context).devicePixelRatio;
        var targetCacheDim = computeCacheDim(resolvedSize, dpr);

        return Container(
          width: resolvedSize,
          height: resolvedSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: hasArtworkFile
                ? Image(
                    image: provider(artworkPath!, cacheDim: targetCacheDim),
                    width: resolvedSize,
                    height: resolvedSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholder(theme, resolvedSize),
                  )
                : _buildPlaceholder(theme, resolvedSize),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(ThemeData theme, double resolvedSize) {
    return Container(
      width: resolvedSize,
      height: resolvedSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: resolvedSize * 0.4,
        color: Colors.white70,
      ),
    );
  }
}
