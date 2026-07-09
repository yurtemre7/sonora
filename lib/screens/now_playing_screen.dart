import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/screens/queue_screen.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/player_controls.dart';
import 'package:sonora/widgets/seek_bar.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({
    super.key,
    required this.playerProvider,
  });

  final PlayerProvider playerProvider;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: playerProvider,
      builder: (context, _) {
        var song = playerProvider.currentSong;

        if (song == null) {
          return const Scaffold(
            body: Center(
              child: Text('No song playing'),
            ),
          );
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              iconSize: 32,
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Now Playing'),
            actions: [
              PopupMenuButton<int>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 1) _showSongInfoBottomSheet(context, song);
                  if (value == 2) {
                    playerProvider.addToQueue(song);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to Queue.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  if (value == 3) _showAddToPlaylistDialog(context, song);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Song Info'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 2,
                    child: Row(
                      children: [
                        Icon(Icons.queue_music_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Add to Queue'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 3,
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Add to Playlist'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              // Blurred background artwork
              if (song.artworkPath != null && File(song.artworkPath!).existsSync())
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                    child: Image.file(
                      File(song.artworkPath!),
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(0.2),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.surfaceContainerHighest,
                          theme.colorScheme.surface,
                        ],
                      ),
                    ),
                  ),
                ),

              // Solid overlay gradient (theme-aware)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        theme.colorScheme.surface.withValues(alpha: 0.6),
                        theme.colorScheme.surface.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),
              ),

              // Player Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Spacer(),

                      // Album Art Card
                      Card(
                        elevation: 10,
                        shadowColor: Colors.black.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AlbumArt(
                          artworkPath: song.artworkPath,
                          size: MediaQuery.sizeOf(context).width * 0.80,
                          borderRadius: 28,
                        ),
                      ),

                      const Spacer(),

                      // Song Info & Favorite Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${song.artist} • ${song.album}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(
                              song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: song.isFavorite ? Colors.red : theme.colorScheme.onSurfaceVariant,
                              size: 28,
                            ),
                            onPressed: () => playerProvider.toggleFavorite(song.id),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // Seek Bar
                      SeekBar(
                        positionStream: playerProvider.positionStream,
                        totalDuration: song.duration,
                        onSeek: playerProvider.seek,
                      ),

                      const SizedBox(height: 24),

                      // Player Controls
                      PlayerControls(
                        isPlaying: playerProvider.isPlaying,
                        isShuffled: playerProvider.isShuffled,
                        repeatMode: playerProvider.repeatMode,
                        onPlayPause: playerProvider.playPause,
                        onNext: playerProvider.next,
                        onPrevious: playerProvider.previous,
                        onShuffle: playerProvider.toggleShuffle,
                        onRepeat: playerProvider.cycleRepeatMode,
                      ),

                      const Spacer(),

                      // Bottom actions (Queue screen button)
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QueueScreen(
                                playerProvider: playerProvider,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.queue_music_rounded),
                        iconSize: 28,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddToPlaylistDialog(BuildContext context, Song song) async {
    var theme = Theme.of(context);
    var playlists = await MusicScanner().getPlaylists();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add "${song.title}" to:'),
        content: playlists.isEmpty
            ? Text(
                'No playlists found.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    var playlist = playlists[index];
                    return ListTile(
                      leading: Icon(
                        playlist.id == 'favorites'
                            ? Icons.favorite_rounded
                            : Icons.queue_music_rounded,
                      ),
                      title: Text(playlist.name),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await MusicScanner().addSongToPlaylist(playlist.id, song.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to "${playlist.name}".'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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

  void _showSongInfoBottomSheet(BuildContext context, Song song) {
    var theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontFamily: isPath ? 'monospace' : null,
              fontSize: isPath ? 12 : null,
            ),
          ),
        ],
      ),
    );
  }
}
