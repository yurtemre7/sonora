import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/album_art.dart';

class AlbumsTab extends StatelessWidget {
  const AlbumsTab({
    super.key,
    required this.allSongs,
    required this.filteredAlbums,
    required this.onUnfocusSearch,
  });

  final List<Song> allSongs;
  final List<AlbumGroup> filteredAlbums;
  final VoidCallback onUnfocusSearch;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    if (allSongs.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noAlbumsFound,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (filteredAlbums.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noMatchingAlbumsFound,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return GridView.builder(
      key: const PageStorageKey<String>('albums_grid'),
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: filteredAlbums.length,
      itemBuilder: (context, index) {
        var album = filteredAlbums[index];
        var firstSong = album.songs.first;

        return InkWell(
          onTap: () {
            onUnfocusSearch();
            openAlbum(context, album);
          },
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: AlbumArt(
                    artworkPath: firstSong.artworkPath,
                    size: 200,
                    borderRadius: 20,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                album.artist,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.trackCount(album.songs.length),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
