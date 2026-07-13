import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/screens/album_detail_screen.dart';
import 'package:sonora/screens/artist_detail_screen.dart';
import 'package:sonora/screens/queue_screen.dart';
import 'package:sonora/services/lyrics_service.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/ambient_glow.dart';
import 'package:sonora/widgets/audio_visualizer.dart';
import 'package:sonora/widgets/marquee_text.dart';
import 'package:sonora/widgets/player_controls.dart';
import 'package:sonora/widgets/playlist_selector.dart';
import 'package:sonora/widgets/seek_bar.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key, required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  var _showLyrics = false;
  var _immersiveMode = false;
  late AnimationController _likeAnimController;
  late Animation<double> _likeAnim;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _likeAnimController.reverse();
      }
    });
    _likeAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(
        parent: _likeAnimController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        var song = widget.playerProvider.currentSong;

        if (song == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
          return const SizedBox.shrink();
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
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: theme.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: theme.brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
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
                  if (value == 4) _showSleepTimerSheet(context);
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
                  const PopupMenuItem(
                    value: 4,
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Sleep Timer'),
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
                        imageFilter: ImageFilter.blur(
                          sigmaX: 50.0,
                          sigmaY: 50.0,
                        ),
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
              // Theme-aware gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: theme.brightness == Brightness.dark
                          ? [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.black.withValues(alpha: 0.75),
                            ]
                          : [
                              theme.colorScheme.surface.withValues(alpha: 0.45),
                              theme.colorScheme.surface.withValues(alpha: 0.85),
                            ],
                    ),
                  ),
                ),
              ),
              // Main content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Album Art / Lyrics Stack Card (tap for immersive mode)
                              GestureDetector(
                                onTap: () => setState(
                                  () => _immersiveMode = !_immersiveMode,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AmbientGlow(
                                      isPlaying: widget
                                          .playerProvider
                                          .audioHandler
                                          .player
                                          .playing,
                                      color: theme.colorScheme.primary,
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      curve: Curves.easeInOut,
                                      width: _immersiveMode
                                          ? constraints.maxWidth
                                          : min(
                                              MediaQuery.sizeOf(context).width *
                                                  0.80,
                                              300.0,
                                            ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: AlbumArt(
                                                artworkPath: song.artworkPath,
                                                size: _immersiveMode
                                                    ? constraints.maxWidth
                                                    : min(
                                                        MediaQuery.sizeOf(
                                                              context,
                                                            ).width *
                                                            0.80,
                                                        300.0,
                                                      ),
                                                borderRadius: 28,
                                              ),
                                            ),
                                            if (_showLyrics)
                                              Positioned.fill(
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(
                                                    sigmaX: 18.0,
                                                    sigmaY: 18.0,
                                                  ),
                                                  child: Container(
                                                    color:
                                                        theme.brightness ==
                                                            Brightness.dark
                                                        ? Colors.black
                                                              .withValues(
                                                                alpha: 0.75,
                                                              )
                                                        : Colors.white
                                                              .withValues(
                                                                alpha: 0.80,
                                                              ),
                                                    child: SongLyricsOverlay(
                                                      song: song,
                                                      playerProvider:
                                                          widget.playerProvider,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Song Info & Favorite Row
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        MarqueeText(
                                          key: ValueKey(
                                            'np_title_${song.displayTitle}',
                                          ),
                                          text: song.displayTitle,
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: GestureDetector(
                                                onTap: () => _showArtistSheet(
                                                  context,
                                                  song.artist,
                                                ),
                                                child: MarqueeText(
                                                  key: ValueKey(
                                                    'np_artist_${song.artist}',
                                                  ),
                                                  text: song.artist,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                  ),
                                              child: Text(
                                                '•',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                            Flexible(
                                              child: GestureDetector(
                                                onTap: () => _showAlbumSheet(
                                                  context,
                                                  song.album,
                                                  song.artist,
                                                ),
                                                child: MarqueeText(
                                                  key: ValueKey(
                                                    'np_album_${song.album}_${song.artist}',
                                                  ),
                                                  text: song.album,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (widget
                                                .playerProvider
                                                .sleepTimerDuration !=
                                            null) ...[
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () =>
                                                _showSleepTimerSheet(context),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .primaryContainer
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.timer_outlined,
                                                    size: 14,
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Stop in ${_formatDuration(widget.playerProvider.sleepTimerDuration!)}',
                                                    style: theme
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  if (song.hasLyrics) ...[
                                    IconButton(
                                      icon: Icon(
                                        _showLyrics
                                            ? Icons.lyrics_rounded
                                            : Icons.lyrics_outlined,
                                        color: _showLyrics
                                            ? theme.colorScheme.primary
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        size: 28,
                                      ),
                                      onPressed: () => setState(
                                        () => _showLyrics = !_showLyrics,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  AnimatedBuilder(
                                    animation: _likeAnim,
                                    builder: (context, child) =>
                                        Transform.scale(
                                      scale: _likeAnim.value,
                                      child: child,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        song.isFavorite
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: song.isFavorite
                                            ? Colors.red
                                            : theme
                                                .colorScheme.onSurfaceVariant,
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        var wasFavorite = song.isFavorite;
                                        widget.playerProvider
                                            .toggleFavorite(song.id);
                                        if (!wasFavorite) {
                                          _likeAnimController.forward(
                                            from: 0.0,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // Seek Bar
                              SeekBar(
                                positionStream:
                                    widget.playerProvider.positionStream,
                                totalDuration: song.duration,
                                onSeek: widget.playerProvider.seek,
                                isPlaying: widget.playerProvider.isPlaying,
                              ),

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

                              const SizedBox(height: 16),

                              // Bottom actions (Queue screen button)
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
                      );
                    },
                  ),
                ),
              ),
              if (widget.playerProvider.showVisualizer)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                    child: SizedBox(
                      height: 80.0,
                      child: AudioVisualizer(
                        isPlaying: widget.playerProvider.isPlaying,
                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                        barCount: 20,
                        height: 80.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
    PlaylistSelectorBottomSheet.show(context, song, widget.playerProvider);
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
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
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

  String _formatDuration(Duration d) {
    var minutes = d.inMinutes;
    var seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showSleepTimerSheet(BuildContext context) {
    var theme = Theme.of(context);
    var selectedDuration = ValueNotifier<Duration?>(null);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            widget.playerProvider,
            selectedDuration,
          ]),
          builder: (context, _) {
            var activeTimer = widget.playerProvider.sleepTimerDuration != null;
            var sel = selectedDuration.value;
            var showConfirmation = !activeTimer && sel != null;

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sleep Timer',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (activeTimer) ...[
                    Card(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Music will stop in',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDuration(
                                widget.playerProvider.sleepTimerDuration!,
                              ),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              widget.playerProvider.stopSleepTimer();
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel Timer'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              widget.playerProvider.extendSleepTimer(
                                Duration(
                                  minutes: widget
                                      .playerProvider
                                      .sleepTimerExtendMinutes,
                                ),
                              );
                              Navigator.pop(context);
                            },
                            child: Text(
                              '+${widget.playerProvider.sleepTimerExtendMinutes} min',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (showConfirmation) ...[
                    Card(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Timer Duration',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDuration(sel),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => selectedDuration.value = null,
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              widget.playerProvider.startSleepTimer(sel);
                              Navigator.pop(context);
                            },
                            child: const Text('Start Timer'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildPresetChip(
                          context,
                          '5 min',
                          const Duration(minutes: 5),
                          () => selectedDuration.value = const Duration(
                            minutes: 5,
                          ),
                        ),
                        _buildPresetChip(
                          context,
                          '15 min',
                          const Duration(minutes: 15),
                          () => selectedDuration.value = const Duration(
                            minutes: 15,
                          ),
                        ),
                        _buildPresetChip(
                          context,
                          '30 min',
                          const Duration(minutes: 30),
                          () => selectedDuration.value = const Duration(
                            minutes: 30,
                          ),
                        ),
                        _buildPresetChip(
                          context,
                          '45 min',
                          const Duration(minutes: 45),
                          () => selectedDuration.value = const Duration(
                            minutes: 45,
                          ),
                        ),
                        _buildPresetChip(
                          context,
                          '60 min',
                          const Duration(minutes: 60),
                          () => selectedDuration.value = const Duration(
                            minutes: 60,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () async {
                        var duration = await _showCustomTimerDialog(context);
                        if (duration != null) {
                          selectedDuration.value = duration;
                        }
                      },
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: const Text('Custom Duration...'),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showArtistSheet(BuildContext context, String artistName) {
    var artist = buildArtistGroup(artistName, widget.playerProvider.allSongs);
    if (artist.songs.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ArtistDetailScreen(
        artist: artist,
        playerProvider: widget.playerProvider,
      ),
    );
  }

  void _showAlbumSheet(
    BuildContext context,
    String albumName,
    String artistName,
  ) {
    var album = buildAlbumGroup(
      albumName,
      artistName,
      widget.playerProvider.allSongs,
    );
    if (album.songs.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AlbumDetailScreen(
        album: album,
        playerProvider: widget.playerProvider,
      ),
    );
  }

  Widget _buildPresetChip(
    BuildContext context,
    String label,
    Duration duration,
    VoidCallback onTap,
  ) {
    var theme = Theme.of(context);
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<Duration?> _showCustomTimerDialog(BuildContext context) {
    var controller = TextEditingController();
    return showDialog<Duration?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Custom Sleep Timer'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              suffixText: 'minutes',
              hintText: 'Enter duration',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                var minutes = int.tryParse(controller.text);
                if (minutes != null && minutes > 0) {
                  Navigator.pop(context, Duration(minutes: minutes));
                }
              },
              child: const Text('Next'),
            ),
          ],
        );
      },
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
  List<LyricLine>? _lyricsLines;
  var _isSynchronized = false;
  var _isLoading = false;
  late ScrollController _scrollController;
  var _activeIndex = -1;
  DateTime? _lastUserScrollTime;

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
      _lyricsLines = null;
      _isSynchronized = false;
      _activeIndex = -1;
    });

    var lyricsResult = await LyricsService.parseLyricsForSong(
      widget.song.filePath,
    );

    if (!mounted) return;
    setState(() {
      if (lyricsResult != null) {
        _lyricsLines = lyricsResult.lines;
        _isSynchronized = lyricsResult.isSynchronized;
      }
      _isLoading = false;
    });
  }

  void _scrollToActiveIndex(
    int index,
    double viewportHeight, {
    bool immediate = false,
  }) {
    if (index < 0 || _lyricsLines == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      const itemHeight = 64.0;
      var targetScroll = index * itemHeight;

      if (immediate) {
        _scrollController.jumpTo(
          targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
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
      return const Center(child: CircularProgressIndicator());
    }

    var lyricsList = _lyricsLines;
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
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No lyrics found',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Place a .lrc or .txt file with the same name next to the audio file to load lyrics.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    var isDark = theme.brightness == Brightness.dark;
    var activeTextColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    if (!_isSynchronized) {
      // Unsynchronized plain text lyrics: freely scrollable
      return ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: lyricsList.length,
        itemBuilder: (context, index) {
          var line = lyricsList[index];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              line.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: activeTextColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
      );
    }

    // Synchronized lyrics: locked scroll centering
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
              var allowAutoScroll =
                  _lastUserScrollTime == null ||
                  DateTime.now().difference(_lastUserScrollTime!) >
                      const Duration(seconds: 4);
              if (allowAutoScroll) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToActiveIndex(activeIndex, viewportHeight);
                });
              }
            }

            var inactiveTextColor = isDark
                ? Colors.white.withValues(alpha: 0.4)
                : theme.colorScheme.onSurface.withValues(alpha: 0.4);

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  _lastUserScrollTime = DateTime.now();
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  vertical: viewportHeight / 2 - 32,
                  horizontal: 20,
                ),
                itemCount: lyricsList.length,
                itemBuilder: (context, index) {
                  var isCurrent = index == activeIndex;
                  var line = lyricsList[index];

                  return GestureDetector(
                    onTap: () {
                      _lastUserScrollTime = null;
                      widget.playerProvider.seek(line.time);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
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
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
