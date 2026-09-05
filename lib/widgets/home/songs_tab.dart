import 'package:flutter/material.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/models/song_activity.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/song_tile.dart';

class SongsTab extends StatelessWidget {
  const SongsTab({
    super.key,
    required this.allSongs,
    required this.filteredSongs,
    required this.playerProvider,
    required this.scanFolder,
    required this.showSyncPrompt,
    required this.onConfigureFolder,
    required this.onUnfocusSearch,
    required this.syncPromptBanner,
    required this.activityView,
    this.selectedSongIds = const {},
    this.onToggleSelect,
    this.onLongPressSong,
  });

  final List<Song> allSongs;
  final List<Song> filteredSongs;
  final PlayerProvider playerProvider;
  final String? scanFolder;
  final bool showSyncPrompt;
  final VoidCallback onConfigureFolder;
  final VoidCallback onUnfocusSearch;
  final Widget syncPromptBanner;
  final SongActivityView activityView;
  final Set<int> selectedSongIds;
  final ValueChanged<Song>? onToggleSelect;
  final ValueChanged<Song>? onLongPressSong;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    if (allSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                scanFolder == null
                    ? Icons.folder_open_rounded
                    : Icons.music_off_rounded,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                scanFolder == null
                    ? context.l10n.setMusicDirectory
                    : context.l10n.noMusicFilesFound,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                scanFolder == null
                    ? context.l10n.chooseFolderSubtitle
                    : context.l10n.noMusicFilesInFolderSubtitle(scanFolder!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onConfigureFolder,
                icon: Icon(
                  scanFolder == null
                      ? Icons.folder_copy_rounded
                      : Icons.create_new_folder_rounded,
                ),
                label: Text(
                  scanFolder == null
                      ? context.l10n.setMusicDirectory
                      : context.l10n.change,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (showSyncPrompt) syncPromptBanner,
        Expanded(
          child: filteredSongs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activityView == SongActivityView.recentlyPlayed
                              ? Icons.history_rounded
                              : Icons.search_off_rounded,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          activityView == SongActivityView.recentlyPlayed
                              ? context.l10n.noRecentlyPlayedSongs
                              : context.l10n.noMatchingSongsFound,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (activityView ==
                            SongActivityView.recentlyPlayed) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.noRecentlyPlayedSongsSubtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListenableBuilder(
                  listenable: playerProvider,
                  builder: (context, _) {
                    var currentSong = playerProvider.currentSong;
                    return ListView.builder(
                      key: const PageStorageKey<String>('songs_list'),
                      primary: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        var song = filteredSongs[index];
                        var isCurrent =
                            currentSong != null && currentSong.id == song.id;
                        var isSelecting = selectedSongIds.isNotEmpty;
                        var isSelected = selectedSongIds.contains(song.id);
                        return SongTile(
                          song: song,
                          playerProvider: playerProvider,
                          isCurrent: isCurrent,
                          showDivider: index < filteredSongs.length - 1,
                          isSelecting: isSelecting,
                          isSelected: isSelected,
                          onSelect: () => onToggleSelect?.call(song),
                          onLongPress: () => onLongPressSong?.call(song),
                          metadataLabel: _resolveMetadataLabel(context, song),
                          onTap: () {
                            onUnfocusSearch();
                            playerProvider.playSong(song, filteredSongs);
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  String? _resolveMetadataLabel(BuildContext context, Song song) {
    switch (activityView) {
      case SongActivityView.mostPlayed:
      case SongActivityView.leastPlayed:
        return context.l10n.listensCount(
          playerProvider.statsService.songPlayCount(song.id),
        );
      case SongActivityView.recentlyPlayed:
        var playedAt = playerProvider.statsService.songLastPlayedAt(song.id);
        if (playedAt == null) return null;
        return formatRelativePlayDate(context, playedAt);
      case SongActivityView.all:
        return null;
    }
  }
}
