import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/artist_avatar.dart';

class ArtistsTab extends StatelessWidget {
  const ArtistsTab({
    super.key,
    required this.allSongs,
    required this.filteredArtists,
    required this.onUnfocusSearch,
  });

  final List<Song> allSongs;
  final List<ArtistGroup> filteredArtists;
  final VoidCallback onUnfocusSearch;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    if (allSongs.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noArtistsFound,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (filteredArtists.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noMatchingArtistsFound,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey<String>('artists_list'),
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: filteredArtists.length,
      itemBuilder: (context, index) {
        var artist = filteredArtists[index];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ArtistAvatar(
                artist: artist,
                radius: 24,
                iconSize: 28,
              ),
              title: Text(
                artist.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              subtitle: Text(
                '${context.l10n.albumCount(artist.albums.length)} • ${context.l10n.songCount(artist.songs.length)}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                onUnfocusSearch();
                openArtist(context, artist);
              },
            ),
            if (index < filteredArtists.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 72),
                child: Divider(
                  height: 1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
          ],
        );
      },
    );
  }
}
