import 'package:flutter/material.dart';

import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/widgets/playlist_selector.dart';
import 'package:sonora/widgets/song_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.songs,
    required this.playerProvider,
    required this.onRemoveSong,
    required this.onReorderSongs,
    required this.playlists,
    required this.onAddSongToPlaylist,
  });

  final Playlist playlist;
  final List<Song> songs;
  final PlayerProvider playerProvider;
  final Future<void> Function(String playlistId, int songId) onRemoveSong;
  final Future<void> Function(String playlistId, List<int> reorderedIds)
  onReorderSongs;
  final List<Playlist> playlists;
  final Future<void> Function(String playlistId, int songId)
  onAddSongToPlaylist;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late List<Song> _playlistSongs;
  final _scrollController = ScrollController();
  late Playlist _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _updatePlaylistSongs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaylistDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playlist = widget.playlist;
    _updatePlaylistSongs();
  }

  void _updatePlaylistSongs() {
    // Map song IDs to actual Song objects preserving the exact order in the playlist
    var songMap = {for (var s in widget.songs) s.id: s};
    _playlistSongs = _playlist.songIds
        .map((id) => songMap[id])
        .whereType<Song>()
        .toList();
  }

  void _showAddToPlaylistDialog(Song song) {
    PlaylistSelectorBottomSheet.show(context, song, widget.playerProvider);
  }

  void _showSongInfoBottomSheet(Song song) {
    var theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                _buildInfoRow('File Path', song.filePath, theme, isPath: true),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: isPath ? 'monospace' : null,
                fontSize: isPath ? 12 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        // Sync with the latest playlists and songs state from the reactive provider
        var providerPlaylists = widget.playerProvider.playlists;
        var matchingPlaylist = providerPlaylists
            .where((p) => p.id == widget.playlist.id)
            .firstOrNull;
        if (matchingPlaylist != null) {
          _playlist = matchingPlaylist;
        } else if (_playlist.id == 'favorites') {
          // Reconstruct favorites dynamically from allSongs
          var favoriteIds = widget.playerProvider.allSongs
              .where((s) => s.isFavorite)
              .map((s) => s.id)
              .toList();
          _playlist = Playlist(
            id: 'favorites',
            name: 'Favorites',
            songIds: favoriteIds,
          );
        }
        _updatePlaylistSongs();

        return Scaffold(
          appBar: AppBar(
            title: Text(_playlist.name),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => closeRoute(context),
            ),
          ),
          body: _playlistSongs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Playlist is empty',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Go to the Songs list and use the song menu to add music to this playlist.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  child: ReorderableListView.builder(
                    scrollController: _scrollController,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _playlistSongs.length,
                    onReorderItem: (oldIndex, newIndex) async {
                      var songId = _playlist.songIds.removeAt(oldIndex);
                      _playlist.songIds.insert(newIndex, songId);
                      await widget.onReorderSongs(
                        _playlist.id,
                        _playlist.songIds,
                      );
                    },
                    itemBuilder: (context, index) {
                      var song = _playlistSongs[index];
                      var isCurrent =
                          widget.playerProvider.currentSong?.id == song.id;

                      return Dismissible(
                        key: ValueKey(song.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          color: theme.colorScheme.errorContainer,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        onDismissed: (direction) async {
                          if (_playlist.id == 'favorites') {
                            await widget.playerProvider.toggleFavorite(song.id);
                          } else {
                            await widget.onRemoveSong(_playlist.id, song.id);
                          }
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Removed "${song.displayTitle}" from playlist.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: SongTile(
                          song: song,
                          isCurrent: isCurrent,
                          showDivider: index < _playlistSongs.length - 1,
                          onTap: () {
                            widget.playerProvider.playSong(
                              song,
                              _playlistSongs,
                            );
                          },
                          onPlayNext: () =>
                              widget.playerProvider.playNext(song),
                          onAddToQueue: () =>
                              widget.playerProvider.addToQueue(song),
                          onAddToPlaylist: () => _showAddToPlaylistDialog(song),
                          onRemoveFromPlaylist: () async {
                            if (_playlist.id == 'favorites') {
                              await widget.playerProvider.toggleFavorite(
                                song.id,
                              );
                            } else {
                              await widget.onRemoveSong(_playlist.id, song.id);
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Removed "${song.displayTitle}" from playlist.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          onShowInfo: () => _showSongInfoBottomSheet(song),
                          onToggleFavorite: () =>
                              widget.playerProvider.toggleFavorite(song.id),
                        ),
                      );
                    },
                  ),
                ),
          floatingActionButton: _playlistSongs.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    widget.playerProvider.quickShuffle(_playlistSongs);
                  },
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Shuffle Play'),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
        );
      },
    );
  }
}
