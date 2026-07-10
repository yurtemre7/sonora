import 'dart:io';

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var hasArtworkFile = artworkPath != null && File(artworkPath!).existsSync();

    return LayoutBuilder(
      builder: (context, constraints) {
        var resolvedSize = (size.isInfinite || size > 10000.0)
            ? (constraints.hasBoundedWidth ? constraints.maxWidth : 120.0)
            : size;

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
                ? Image.file(
                    File(artworkPath!),
                    width: resolvedSize,
                    height: resolvedSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(theme, resolvedSize),
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
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
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
