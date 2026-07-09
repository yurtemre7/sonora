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
  });

  final Playlist playlist;
  final List<Song> songs;
  final PlayerProvider playerProvider;
  final Future<void> Function(String playlistId, int songId) onRemoveSong;
  final Future<void> Function(String playlistId, List<int> reorderedIds) onReorderSongs;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late List<Song> _playlistSongs;

  @override
  void initState() {
    super.initState();
    _updatePlaylistSongs();
  }

  @override
  void didUpdateWidget(covariant PlaylistDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePlaylistSongs();
  }

  void _updatePlaylistSongs() {
    // Map song IDs to actual Song objects, filtering out any that no longer exist on disk
    _playlistSongs = widget.songs
        .where((s) => widget.playlist.songIds.contains(s.id))
        .toList();
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
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 160),
              itemCount: _playlistSongs.length,
              onReorderItem: (oldIndex, newIndex) async {
                var updatedIds = List<int>.from(widget.playlist.songIds);
                var songId = updatedIds.removeAt(oldIndex);
                updatedIds.insert(newIndex, songId);

                await widget.onReorderSongs(widget.playlist.id, updatedIds);
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
                    await widget.onRemoveSong(widget.playlist.id, song.id);
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
                  ),
                );
              },
            ),
      floatingActionButton: _playlistSongs.isEmpty
          ? null
          : Container(
              margin: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton.extended(
                onPressed: () {
                  widget.playerProvider.quickShuffle(_playlistSongs);
                },
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Shuffle Play'),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
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
      builder: (context) => NowPlayingScreen(playerProvider: widget.playerProvider),
    );
  }
}
