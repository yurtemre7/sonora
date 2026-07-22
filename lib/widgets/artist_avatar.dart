import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/widgets/album_art.dart';

class ArtistAvatar extends StatelessWidget {
  final ArtistGroup artist;
  final double radius;
  final double? iconSize;

  const ArtistAvatar({
    super.key,
    required this.artist,
    required this.radius,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var hasLocalImage = artist.localImagePath != null;
    var fallbackArtworkPath = artist.songs.isNotEmpty
        ? artist.songs.first.artworkPath
        : null;
    var hasFallback = fallbackArtworkPath != null;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: radius * 0.25,
            offset: Offset(0, radius * 0.1),
          ),
        ],
      ),
      child: hasLocalImage
          ? CircleAvatar(
              radius: radius,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: ResizeImage(
                FileImage(File(artist.localImagePath!)),
                width: (radius * 3).toInt(),
              ),
            )
          : hasFallback
          ? ClipOval(
              child: AlbumArt(
                artworkPath: fallbackArtworkPath,
                size: radius * 2,
                borderRadius: 0,
              ),
            )
          : CircleAvatar(
              radius: radius,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.person_rounded,
                size: iconSize ?? radius,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}
