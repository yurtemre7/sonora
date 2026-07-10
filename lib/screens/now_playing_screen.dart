import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/screens/queue_screen.dart';
import 'package:sonora/services/lyrics_service.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/player_controls.dart';
import 'package:sonora/widgets/seek_bar.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({
    super.key,
    required this.playerProvider,
  });

  final PlayerProvider playerProvider;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  var _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        var song = widget.playerProvider.currentSong;

        if (song == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                iconSize: 32,
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Now Playing'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark, // iOS
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No song playing',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close Player'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!song.hasLyrics && _showLyrics) {
          _showLyrics = false;
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
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark, // iOS
            ),
            actions: [
              PopupMenuButton<int>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 1) _showSongInfoBottomSheet(context, song);
                  if (value == 2) {
                    widget.playerProvider.addToQueue(song);
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
                        SizedBox(width: 12),
                        Text('Song Info'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 2,
                    child: Row(
                      children: [
                        Icon(Icons.queue_play_next_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Add to Queue'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 3,
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Add to Playlist'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              // Blurred artwork background
              Positioned.fill(
                child: song.artworkPath != null
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                        child: Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: FileImage(File(song.artworkPath!)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                              theme.colorScheme.tertiary.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                      ),
              ),
              // Dark gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Main content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Spacer(),

                      // Album Art / Lyrics Stack Card
                      Card(
                        elevation: 10,
                        shadowColor: Colors.black.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width * 0.80,
                          height: MediaQuery.sizeOf(context).width * 0.80,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: AlbumArt(
                                  artworkPath: song.artworkPath,
                                  size: MediaQuery.sizeOf(context).width * 0.80,
                                  borderRadius: 28,
                                ),
                              ),
                              if (_showLyrics)
                                Positioned.fill(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                                    child: Container(
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.black.withValues(alpha: 0.75)
                                          : Colors.white.withValues(alpha: 0.80),
                                      child: SongLyricsOverlay(
                                        song: song,
                                        playerProvider: widget.playerProvider,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
                          if (song.hasLyrics) ...[
                            IconButton(
                              icon: Icon(
                                _showLyrics ? Icons.lyrics_rounded : Icons.lyrics_outlined,
                                color: _showLyrics
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                size: 28,
                              ),
                              onPressed: () => setState(() => _showLyrics = !_showLyrics),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: Icon(
                              song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: song.isFavorite ? Colors.red : theme.colorScheme.onSurfaceVariant,
                              size: 28,
                            ),
                            onPressed: () => widget.playerProvider.toggleFavorite(song.id),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // Seek Bar
                      SeekBar(
                        positionStream: widget.playerProvider.positionStream,
                        totalDuration: song.duration,
                        onSeek: widget.playerProvider.seek,
                        isPlaying: widget.playerProvider.isPlaying,
                      ),

                      const SizedBox(height: 24),

                      // Player Controls
                      PlayerControls(
                        isPlaying: widget.playerProvider.isPlaying,
                        isShuffled: widget.playerProvider.isShuffled,
                        repeatMode: widget.playerProvider.repeatMode,
                        onPlayPause: widget.playerProvider.playPause,
                        onNext: widget.playerProvider.next,
                        onPrevious: widget.playerProvider.previous,
                        onShuffle: widget.playerProvider.toggleShuffle,
                        onRepeat: widget.playerProvider.cycleRepeatMode,
                      ),

                      const Spacer(),

                      // Bottom actions (Queue screen button - restored to original centered layout)
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QueueScreen(
                                playerProvider: widget.playerProvider,
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

class SongLyricsOverlay extends StatefulWidget {
  const SongLyricsOverlay({
    super.key,
    required this.song,
    required this.playerProvider,
  });

  final Song song;
  final PlayerProvider playerProvider;

  @override
  State<SongLyricsOverlay> createState() => _SongLyricsOverlayState();
}

class _SongLyricsOverlayState extends State<SongLyricsOverlay> {
  List<LyricLine>? _lyrics;
  var _isLoading = false;
  late ScrollController _scrollController;
  var _activeIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(SongLyricsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.song.id != oldWidget.song.id) {
      _loadLyrics();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    setState(() {
      _isLoading = true;
      _lyrics = null;
      _activeIndex = -1;
    });

    var lyrics = await LyricsService.parseLyricsForSong(widget.song.filePath);

    if (!mounted) return;
    setState(() {
      _lyrics = lyrics;
      _isLoading = false;
    });

    _scrollToCurrentPosition(immediate: true);
  }

  void _scrollToCurrentPosition({bool immediate = false}) {
    if (_lyrics == null || _lyrics!.isEmpty) return;

    var position = widget.playerProvider.audioHandler.player.position;
    var activeIndex = -1;
    for (var i = 0; i < _lyrics!.length; i++) {
      if (position >= _lyrics![i].time) {
        activeIndex = i;
      } else {
        break;
      }
    }

    if (activeIndex != -1) {
      _activeIndex = activeIndex;
      var viewportHeight = MediaQuery.sizeOf(context).width * 0.80;
      _scrollToActiveIndex(activeIndex, viewportHeight, immediate: immediate);
    }
  }

  void _scrollToActiveIndex(int index, double viewportHeight, {bool immediate = false}) {
    if (index < 0 || _lyrics == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      const itemHeight = 64.0;
      var targetScroll = (index * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
      
      if (immediate) {
        _scrollController.jumpTo(targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent));
      } else {
        _scrollController.animateTo(
          targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    var lyricsList = _lyrics;
    if (lyricsList == null || lyricsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No synchronized lyrics found',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Place a .lrc file with the same name next to the audio file to load lyrics.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        var viewportHeight = constraints.maxHeight;

        return StreamBuilder<Duration>(
          stream: widget.playerProvider.audioHandler.player.positionStream,
          builder: (context, snapshot) {
            var position = snapshot.data ?? Duration.zero;

            var activeIndex = -1;
            for (var i = 0; i < lyricsList.length; i++) {
              if (position >= lyricsList[i].time) {
                activeIndex = i;
              } else {
                break;
              }
            }

            if (activeIndex != _activeIndex) {
              _activeIndex = activeIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToActiveIndex(activeIndex, viewportHeight);
              });
            }

            var isDark = theme.brightness == Brightness.dark;
            var activeTextColor = isDark ? Colors.white : theme.colorScheme.onSurface;
            var inactiveTextColor = isDark
                ? Colors.white.withValues(alpha: 0.4)
                : theme.colorScheme.onSurface.withValues(alpha: 0.4);

            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                vertical: viewportHeight / 2 - 32,
                horizontal: 20,
              ),
              itemCount: lyricsList.length,
              itemBuilder: (context, index) {
                var isCurrent = index == activeIndex;
                var line = lyricsList[index];

                return SizedBox(
                  height: 64.0,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: isCurrent
                          ? theme.textTheme.titleMedium!.copyWith(
                              color: activeTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            )
                          : theme.textTheme.bodyMedium!.copyWith(
                              color: inactiveTextColor,
                              fontSize: 15,
                            ),
                      textAlign: TextAlign.center,
                      child: Text(
                        line.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
