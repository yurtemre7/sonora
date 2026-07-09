import 'package:flutter/material.dart';

import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/screens/now_playing_screen.dart';
import 'package:sonora/widgets/mini_player.dart';
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
  final Future<void> Function(String playlistId, List<int> reorderedIds) onReorderSongs;
  final List<Playlist> playlists;
  final Future<void> Function(String playlistId, int songId) onAddSongToPlaylist;

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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add to Playlist'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.playlists.length,
            itemBuilder: (context, index) {
              var playlist = widget.playlists[index];
              if (playlist.id == 'favorites') return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text(playlist.name),
                onTap: () async {
                  await widget.onAddSongToPlaylist(playlist.id, song.id);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "${song.title}" to ${playlist.name}.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
              _buildInfoRow('Title', song.title, theme),
              _buildInfoRow('Artist', song.artist, theme),
              _buildInfoRow('Album', song.album, theme),
              _buildInfoRow('Duration', song.durationFormatted, theme),
              _buildInfoRow('File Path', song.filePath, theme, isPath: true),
              if (song.format != null) _buildInfoRow('Format', song.format!.toUpperCase(), theme),
              if (song.bitrate != null) _buildInfoRow('Bitrate', '${song.bitrate} kbps', theme),
              if (song.samplerate != null) _buildInfoRow('Sample Rate', '${(song.samplerate! / 1000).toStringAsFixed(1)} kHz', theme),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme, {bool isPath = false}) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
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
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                  setState(() {
                    var songId = _playlist.songIds.removeAt(oldIndex);
                    _playlist.songIds.insert(newIndex, songId);
                    _updatePlaylistSongs();
                  });

                  await widget.onReorderSongs(_playlist.id, _playlist.songIds);
                },
                itemBuilder: (context, index) {
                  var song = _playlistSongs[index];
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
                      setState(() {
                        _playlist.songIds.remove(song.id);
                        _updatePlaylistSongs();
                      });
                      if (_playlist.id == 'favorites') {
                        await widget.playerProvider.toggleFavorite(song.id);
                      } else {
                        await widget.onRemoveSong(_playlist.id, song.id);
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed "${song.title}" from playlist.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: SongTile(
                      song: song,
                      onTap: () {
                        widget.playerProvider.playSong(song, _playlistSongs);
                      },
                      onPlayNext: () => widget.playerProvider.playNext(song),
                      onAddToQueue: () => widget.playerProvider.addToQueue(song),
                      onAddToPlaylist: () => _showAddToPlaylistDialog(song),
                      onShowInfo: () => _showSongInfoBottomSheet(song),
                      onToggleFavorite: () async {
                        await widget.playerProvider.toggleFavorite(song.id);
                        setState(() {
                          if (_playlist.id == 'favorites') {
                            _playlist.songIds.remove(song.id);
                          }
                          _updatePlaylistSongs();
                        });
                      },
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
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.playerProvider,
        builder: (context, child) {
          var currentSong = widget.playerProvider.currentSong;
          if (currentSong == null) return const SizedBox.shrink();

          return StreamBuilder<Duration>(
            stream: widget.playerProvider.audioHandler.player.positionStream,
            builder: (context, snapshot) {
              var position = snapshot.data ?? Duration.zero;
              var totalMs = currentSong.duration.inMilliseconds;
              var progress = totalMs > 0 ? position.inMilliseconds / totalMs : 0.0;

              return MiniPlayer(
                currentSong: currentSong,
                isPlaying: widget.playerProvider.audioHandler.player.playing,
                progress: progress,
                onTap: () => _openNowPlaying(context),
                onPlayPause: widget.playerProvider.playPause,
                onNext: widget.playerProvider.next,
                onSwipeUp: () => _openNowPlaying(context),
                onSwipeDown: widget.playerProvider.stop,
                onSwipeLeft: widget.playerProvider.previous,
                onSwipeRight: widget.playerProvider.next,
              );
            },
          );
        },
      ),
    );
  }

  void _openNowPlaying(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => NowPlayingScreen(playerProvider: widget.playerProvider),
    );
  }
}
