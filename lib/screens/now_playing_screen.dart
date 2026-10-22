import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/screens/album_detail_screen.dart';
import 'package:sonora/screens/artist_detail_screen.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/animated_favorite_button.dart';
import 'package:sonora/widgets/animated_vinyl.dart';
import 'package:sonora/widgets/artist_avatar.dart';
import 'package:sonora/widgets/audio_visualizer.dart';
import 'package:sonora/widgets/marquee_text.dart';
import 'package:sonora/widgets/mfx_bottom_sheet.dart';
import 'package:sonora/widgets/player_controls.dart';
import 'package:sonora/widgets/playlist_selector.dart';
import 'package:sonora/widgets/save_queue_dialog.dart';
import 'package:sonora/widgets/seek_bar.dart';
import 'package:sonora/widgets/sleep_timer_sheet.dart';
import 'package:sonora/widgets/song_info_bottom_sheet.dart';
import 'package:sonora/widgets/song_lyrics_overlay.dart';
import 'package:sonora/widgets/song_tile.dart';
import 'package:sonora/widgets/up_next_queue_view.dart';
import 'package:sonora/widgets/volume_slider.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key, required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

enum _ViewMode { player, upNext, lyrics, related }

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  var _showLyrics = false;
  var _showVolume = Platform.isWindows;
  var _viewMode = _ViewMode.player;
  var _lastIndex = -1;
  var _reverse = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.playerProvider,
        SettingsProvider.instance,
      ]),
      builder: (context, _) {
        var song = widget.playerProvider.currentSong;
        var currentIndex = widget.playerProvider.currentIndex;
        if (currentIndex != _lastIndex && _lastIndex != -1) {
          _reverse = currentIndex < _lastIndex;
        }
        _lastIndex = currentIndex;

        if (song == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) closeRoute(context);
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
              icon: Icon(
                _viewMode == _ViewMode.player
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.arrow_back_rounded,
              ),
              iconSize: _viewMode == _ViewMode.player ? 32 : 24,
              tooltip: _viewMode == _ViewMode.player
                  ? context.l10n.collapse
                  : context.l10n.back,
              onPressed: () {
                if (_viewMode == _ViewMode.player) {
                  closeRoute(context);
                } else {
                  setState(() => _viewMode = _ViewMode.player);
                }
              },
            ),
            title: Text(
              _viewMode == _ViewMode.player
                  ? context.l10n.nowPlaying
                  : _viewMode == _ViewMode.upNext
                  ? context.l10n.upNext
                  : _viewMode == _ViewMode.lyrics
                  ? context.l10n.lyrics
                  : context.l10n.related,
            ),
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
              if (_viewMode == _ViewMode.upNext)
                IconButton(
                  icon: const Icon(Icons.playlist_add),
                  tooltip: context.l10n.saveAsPlaylist,
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => SaveQueueDialogContent(
                        playerProvider: widget.playerProvider,
                      ),
                    );
                  },
                ),
              PopupMenuButton<int>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 1) showSongInfoBottomSheet(context, song);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 1,
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(context.l10n.songInfo),
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
                      return Column(
                        children: [
                          // Content area
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _viewMode == _ViewMode.player
                                  ? _buildPlayerContent(
                                      theme,
                                      song,
                                      constraints,
                                    )
                                  : _viewMode == _ViewMode.upNext
                                  ? UpNextQueueView(
                                      playerProvider: widget.playerProvider,
                                    )
                                  : _viewMode == _ViewMode.lyrics
                                  ? _buildLyricsContent(theme, song)
                                  : _buildRelatedContent(theme, song),
                            ),
                          ),

                          // Bottom action bar
                          _buildBottomBar(
                            theme,
                            hasLyrics: song.hasLyrics,
                            hasRelated: _hasRelatedSongs(song),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (SettingsProvider.instance.showVisualizer)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(32),
                      ),
                      child: SizedBox(
                        height: 80.0,
                        child: AudioVisualizer(
                          isPlaying: widget.playerProvider.isPlaying,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.8,
                          ),
                          barCount: 20,
                          height: 80.0,
                        ),
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

  Widget _buildPlayerContent(
    ThemeData theme,
    Song song,
    BoxConstraints constraints,
  ) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Album Art / Lyrics Stack Card
          GestureDetector(
            onTap: () => SettingsProvider.instance.setImmersiveMode(
              !SettingsProvider.instance.immersiveMode,
            ),
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -100) {
                  widget.playerProvider.next();
                } else if (details.primaryVelocity! > 100) {
                  widget.playerProvider.previous();
                }
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (SettingsProvider.instance.nowPlayingStyle == 'vinyl' &&
                    !_showLyrics)
                  AnimatedVinyl(
                    artworkPath: song.artworkPath,
                    isPlaying:
                        widget.playerProvider.audioHandler.player.playing,
                    size: SettingsProvider.instance.immersiveMode
                        ? min(constraints.maxWidth, constraints.maxHeight)
                        : min(MediaQuery.sizeOf(context).width * 0.75, 270.0),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    width:
                        SettingsProvider.instance.nowPlayingStyle ==
                            'minimalist'
                        ? min(MediaQuery.sizeOf(context).width * 0.55, 200.0)
                        : (SettingsProvider.instance.immersiveMode
                              ? constraints.maxWidth
                              : min(
                                  MediaQuery.sizeOf(context).width * 0.80,
                                  300.0,
                                )),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
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
                            child: PageTransitionSwitcher(
                              reverse: _reverse,
                              transitionBuilder:
                                  (child, animation, secondaryAnimation) {
                                    return SharedAxisTransition(
                                      fillColor: Colors.transparent,
                                      animation: animation,
                                      secondaryAnimation: secondaryAnimation,
                                      transitionType:
                                          SharedAxisTransitionType.horizontal,
                                      child: child,
                                    );
                                  },
                              child: AlbumArt(
                                key: ValueKey(song.id),
                                artworkPath: song.artworkPath,
                                size: double.infinity,
                                borderRadius: 28,
                              ),
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
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Song Info & Favorite Row
          Row(
            children: [
              Expanded(
                child: Column(
                  key: ValueKey(song.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      key: ValueKey('np_title_${song.displayTitle}'),
                      text: song.displayTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _showArtistSheet(context, song.artist),
                            child: MarqueeText(
                              key: ValueKey('np_artist_${song.artist}'),
                              text: song.artist,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '•',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AnimatedFavoriteButton(
                isFavorite: song.isFavorite,
                onToggle: () => widget.playerProvider.toggleFavorite(song.id),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons Row
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                if (song.hasLyrics)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _buildActionChip(
                      icon: _showLyrics
                          ? Icons.lyrics_rounded
                          : Icons.lyrics_outlined,
                      label: context.l10n.lyrics,
                      active: _showLyrics,
                      onPressed: () =>
                          setState(() => _showLyrics = !_showLyrics),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildActionChip(
                    icon: Icons.playlist_add_rounded,
                    label: context.l10n.playlists,
                    active: false,
                    onPressed: () => _showAddToPlaylistDialog(context, song),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildTimerChip(context),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildActionChip(
                    icon: Icons.auto_awesome,
                    label: context.l10n.mfx,
                    active: widget.playerProvider.isMfxActive,
                    onPressed: () =>
                        showMfxBottomSheet(context, widget.playerProvider),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildActionChip(
                    icon: _showVolume
                        ? Icons.volume_up_rounded
                        : Icons.volume_up_outlined,
                    label: '${(widget.playerProvider.volume * 100).round()}%',
                    active: _showVolume,
                    onPressed: () => setState(() {
                      _showVolume = !_showVolume;
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Seek Bar
          SeekBar(
            positionStream: widget.playerProvider.positionStream,
            totalDuration: song.duration,
            onSeek: widget.playerProvider.seek,
            isPlaying: widget.playerProvider.isPlaying,
          ),

          // Volume Slider
          if (_showVolume) ...[
            const SizedBox(height: 8),
            VolumeSlider(
              volume: widget.playerProvider.volume,
              onChanged: widget.playerProvider.setVolume,
            ),
          ],

          const SizedBox(height: 8),

          // Player Controls
          PlayerControls(
            isPlaying: widget.playerProvider.isPlaying,
            isCompleted: widget.playerProvider.isCompleted,
            isShuffled: widget.playerProvider.isShuffled,
            repeatMode: widget.playerProvider.repeatMode,
            onPlayPause: widget.playerProvider.playPause,
            onNext: widget.playerProvider.next,
            onPrevious: widget.playerProvider.previous,
            onShuffle: widget.playerProvider.toggleShuffle,
            onRepeat: widget.playerProvider.cycleRepeatMode,
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    var theme = Theme.of(context);

    if (active) {
      return Material(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.secondary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: onPressed,
    );
  }

  Widget _buildTimerChip(BuildContext context) {
    var theme = Theme.of(context);
    var timerActive = widget.playerProvider.sleepTimerDuration != null;

    if (timerActive) {
      return Material(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showSleepTimerSheet(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.stopInX(
                    _formatDuration(widget.playerProvider.sleepTimerDuration!),
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildActionChip(
      icon: Icons.timer_outlined,
      label: context.l10n.timer,
      active: false,
      onPressed: () => _showSleepTimerSheet(context),
    );
  }

  Widget _buildBottomBar(
    ThemeData theme, {
    required bool hasLyrics,
    required bool hasRelated,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          _bottomTab(
            theme,
            _ViewMode.upNext,
            context.l10n.upNextCaps,
            true,
            context.l10n.upNext,
          ),
          const SizedBox(width: 8),
          _bottomTab(
            theme,
            _ViewMode.lyrics,
            context.l10n.lyricsCaps,
            hasLyrics,
            hasLyrics ? context.l10n.lyrics : context.l10n.noLyricsAvailable,
          ),
          const SizedBox(width: 8),
          _bottomTab(
            theme,
            _ViewMode.related,
            context.l10n.relatedCaps,
            hasRelated,
            hasRelated ? context.l10n.related : context.l10n.noRelatedSongs,
          ),
        ],
      ),
    );
  }

  Widget _bottomTab(
    ThemeData theme,
    _ViewMode mode,
    String label,
    bool enabled,
    String tooltip,
  ) {
    var isActive = _viewMode == mode;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: TextButton(
          onPressed: enabled
              ? () => setState(() {
                  if (_viewMode == mode) {
                    _viewMode = _ViewMode.player;
                  } else {
                    _viewMode = mode;
                  }
                })
              : null,
          style: TextButton.styleFrom(
            foregroundColor: isActive
                ? theme.colorScheme.primary
                : enabled
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            backgroundColor: isActive
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsContent(ThemeData theme, Song song) {
    return SongLyricsOverlay(song: song, playerProvider: widget.playerProvider);
  }

  Widget _buildRelatedContent(ThemeData theme, Song song) {
    var allSongs = widget.playerProvider.allSongs;
    var sameAlbum = allSongs
        .where(
          (s) =>
              s.id != song.id &&
              s.album == song.album &&
              s.artist == song.artist,
        )
        .toList();
    var sameArtist = allSongs
        .where(
          (s) =>
              s.id != song.id &&
              s.artist == song.artist &&
              s.album != song.album,
        )
        .toList();

    return ListView(
      key: const ValueKey('related_view'),
      children: [
        if (sameAlbum.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.l10n.fromThisAlbum,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...sameAlbum.map(
            (s) => SongTile(
              hideMenu: true,
              song: s,
              onTap: () => _playRelatedSong(s, allSongs),
              showDivider: true,
              showHighlightBackground: false,
            ),
          ),
        ],
        if (sameArtist.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.l10n.moreByArtist(song.artist),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...sameArtist.map(
            (s) => SongTile(
              hideMenu: true,
              song: s,
              onTap: () => _playRelatedSong(s, allSongs),
              showDivider: true,
              showHighlightBackground: false,
            ),
          ),
        ],
      ],
    );
  }

  bool _hasRelatedSongs(Song song) {
    return widget.playerProvider.allSongs.any(
      (s) =>
          s.id != song.id && (s.artist == song.artist || s.album == song.album),
    );
  }

  Future<void> _playRelatedSong(Song song, List<Song> allSongs) async {
    if (mounted) {
      setState(() => _viewMode = _ViewMode.player);
    }
    await widget.playerProvider.playSong(song, allSongs);
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
    PlaylistSelectorBottomSheet.show(context, song, widget.playerProvider);
  }

  String _formatDuration(Duration d) {
    var minutes = d.inMinutes;
    var seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showSleepTimerSheet(BuildContext context) {
    showSleepTimerBottomSheet(context, widget.playerProvider);
  }

  void _showArtistSheet(BuildContext context, String artistName) {
    var artists = parseIndividualArtists(artistName);
    if (artists.isEmpty) return;

    if (artists.length == 1) {
      var artist = buildArtistGroup(
        artists.first,
        widget.playerProvider.allSongs,
      );
      if (artist.songs.isEmpty) return;
      _openArtistDetailModal(context, artist);
    } else {
      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          var theme = Theme.of(context);
          return Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Text(
                        context.l10n.artists,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ...artists.map((name) {
                      var group = buildArtistGroup(
                        name,
                        widget.playerProvider.allSongs,
                      );
                      return ListTile(
                        leading: ArtistAvatar(artist: group, radius: 20),
                        title: Text(group.name),
                        subtitle: Text(
                          '${group.songs.length} ${context.l10n.songs}',
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _openArtistDetailModal(context, group);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }

  void _openArtistDetailModal(BuildContext context, ArtistGroup artist) {
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
}
