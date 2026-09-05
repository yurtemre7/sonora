import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/models/song_activity.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/services/stats_service.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/multi_select_action_bar.dart';
import 'package:sonora/widgets/song_tile.dart';

class RecentlyPlayedScreen extends StatefulWidget {
  const RecentlyPlayedScreen({super.key, required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  final _stats = StatsService();
  final Set<int> _selectedSongIds = {};

  void _toggleSelection(Song song) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedSongIds.add(song.id)) {
        _selectedSongIds.remove(song.id);
      }
    });
  }

  void _selectAll(List<Song> songs) {
    setState(() => _selectedSongIds.addAll(songs.map((song) => song.id)));
  }

  void _clearSelection() {
    setState(_selectedSongIds.clear);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.playerProvider, _stats]),
      builder: (context, _) {
        var recent = _stats.recentSongs(widget.playerProvider.allSongs);
        var songs = recent.map((entry) => entry.song).toList();
        var selectedSongs = songs
            .where((song) => _selectedSongIds.contains(song.id))
            .toList();

        return PopScope(
          canPop: _selectedSongIds.isEmpty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _clearSelection();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.recentlyPlayed),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => closeRoute(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.shuffle_rounded),
                  tooltip: context.l10n.shufflePlay,
                  onPressed: songs.isEmpty
                      ? null
                      : () => widget.playerProvider.quickShuffle(songs),
                ),
              ],
            ),
            body: Stack(
              children: [
                if (recent.isEmpty)
                  _EmptyRecentlyPlayed(onReturnHome: () => closeRoute(context))
                else
                  CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Text(
                            context.l10n.songCount(recent.length),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                      ..._buildSections(context, recent, songs),
                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 140),
                      ),
                    ],
                  ),
                if (_selectedSongIds.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MultiSelectActionBar(
                      selectedSongs: selectedSongs,
                      allAvailableSongs: songs,
                      playerProvider: widget.playerProvider,
                      onClearSelection: _clearSelection,
                      onSelectAll: () => _selectAll(songs),
                      bottomPadding: widget.playerProvider.currentSong == null
                          ? 16
                          : 80,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    List<({Song song, DateTime lastPlayedAt, int listenCount})> recent,
    List<Song> queue,
  ) {
    var sections =
        <String, List<({Song song, DateTime lastPlayedAt, int listenCount})>>{};
    for (var entry in recent) {
      var label = formatRelativePlayDate(context, entry.lastPlayedAt);
      sections.putIfAbsent(label, () => []).add(entry);
    }

    var slivers = <Widget>[];
    for (var section in sections.entries) {
      slivers
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text(
                section.key,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        )
        ..add(
          SliverList.builder(
            itemCount: section.value.length,
            itemBuilder: (context, index) {
              var entry = section.value[index];
              var song = entry.song;
              var isSelecting = _selectedSongIds.isNotEmpty;
              return SongTile(
                song: song,
                playerProvider: widget.playerProvider,
                isCurrent: widget.playerProvider.currentSong?.id == song.id,
                showDivider: index < section.value.length - 1,
                isSelecting: isSelecting,
                isSelected: _selectedSongIds.contains(song.id),
                onSelect: () => _toggleSelection(song),
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _selectedSongIds.add(song.id));
                },
                metadataLabel: context.l10n.listensCount(entry.listenCount),
                onTap: () => widget.playerProvider.playSong(song, queue),
              );
            },
          ),
        );
    }
    return slivers;
  }
}

class _EmptyRecentlyPlayed extends StatelessWidget {
  const _EmptyRecentlyPlayed({required this.onReturnHome});

  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.noRecentlyPlayedSongs,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.noRecentlyPlayedSongsSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onReturnHome,
              icon: const Icon(Icons.library_music_rounded),
              label: Text(context.l10n.allSongs),
            ),
          ],
        ),
      ),
    );
  }
}
