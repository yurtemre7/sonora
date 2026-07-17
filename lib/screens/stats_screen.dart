import 'package:flutter/material.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/services/stats_service.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/confirm_delete_dialog.dart';
import 'package:sonora/widgets/song_tile.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _pageController = PageController();
  var _currentPage = 0;
  final _statsService = StatsService();

  @override
  void initState() {
    super.initState();
    _statsService.ensureLoaded();
    widget.playerProvider.addListener(_onPlayerUpdate);
  }

  @override
  void dispose() {
    widget.playerProvider.removeListener(_onPlayerUpdate);
    _pageController.dispose();
    super.dispose();
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _confirmResetStats(BuildContext context) async {
    var confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Reset Statistics?',
      message:
          'This will permanently delete all your listening statistics, including total time, play counts, and top charts. This cannot be undone.',
      confirmLabel: 'Reset',
    );
    if (confirmed == true && mounted) {
      await _statsService.reset();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var songs = widget.playerProvider.allSongs;
    var playlists = widget.playerProvider.playlists;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening Statistics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => closeRoute(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Reset Statistics',
            onPressed: () => _confirmResetStats(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.playerProvider,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  children: [
                    _buildOverviewPage(context, theme, songs),
                    _buildTopSongsPage(context, theme, songs),
                    _buildTopAlbumsPage(context, theme, songs),
                    _buildTopArtistsPage(context, theme, songs),
                    _buildTopPlaylistsPage(context, theme, playlists),
                  ],
                ),
              ),
              _buildBottomNav(theme),
            ],
          );
        },
      ),
    );
  }

  // ── Bottom Navigation ────────────────────────────────────────────────────

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _currentPage > 0
                ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              var isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _currentPage < 4
                ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
        ],
      ),
    );
  }

  // ── Page 1: Overview ─────────────────────────────────────────────────────

  Widget _buildOverviewPage(
    BuildContext context,
    ThemeData theme,
    List<Song> songs,
  ) {
    var stats = _statsService;
    var topSong = stats.topSongs(1, songs).firstOrNull;
    var firstSong = stats.firstPlayedSong(songs);
    var totalUnique = stats.totalUniqueSongsPlayed;
    var albumCount = stats.albumListenCount(songs);
    var artistCount = stats.artistListenCount(songs);
    var playlistCount = stats.playlistListenCount;
    var activeDay = stats.mostActiveDay;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero listening time card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  stats.totalListeningTimeFormatted,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                    fontFamily: 'Outfit',
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Listening Time',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Core metric cards (2x2 grid)
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.check_circle_rounded,
                  value: '${stats.completeSongListens}',
                  label: 'Complete\nListens',
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.album_rounded,
                  value: '$albumCount',
                  label: 'Albums',
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.mic_rounded,
                  value: '$artistCount',
                  label: 'Artists',
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.playlist_play_rounded,
                  value: '$playlistCount',
                  label: 'Playlists',
                  theme: theme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Fun facts section
          Text(
            'Fun Facts',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (firstSong != null)
            _buildFactRow(
              context,
              theme,
              Icons.emoji_events_rounded,
              'First Song Played',
              firstSong.displayTitle,
            ),
          if (firstSong != null) const SizedBox(height: 8),
          if (topSong != null)
            _buildFactRow(
              context,
              theme,
              Icons.trending_up_rounded,
              'Most Played Song',
              '${topSong.song.displayTitle} (${topSong.count}x)',
            ),
          if (topSong != null) const SizedBox(height: 8),
          _buildFactRow(
            context,
            theme,
            Icons.music_note_rounded,
            'Unique Songs Played',
            '$totalUnique songs',
          ),
          const SizedBox(height: 8),
          _buildFactRow(
            context,
            theme,
            Icons.calendar_today_rounded,
            'Most Active Day',
            activeDay,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFactRow(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 2: Top Songs ────────────────────────────────────────────────────

  Widget _buildTopSongsPage(
    BuildContext context,
    ThemeData theme,
    List<Song> songs,
  ) {
    var top = _statsService.topSongs(5, songs);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              'Most Played Songs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (top.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No listening data yet.\nStart playing music to see your top songs!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: top.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  var entry = top[index];
                  var song = entry.song;
                  var rankColors = [
                    const Color(0xFFFFD700),
                    const Color(0xFFC0C0C0),
                    const Color(0xFFCD7F32),
                    theme.colorScheme.outline,
                    theme.colorScheme.outline,
                  ];
                  var rankColor = rankColors[index % rankColors.length];
                  var currentSong = widget.playerProvider.currentSong;
                  var isCurrent =
                      currentSong != null && currentSong.id == song.id;

                  return Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '#${index + 1}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: rankColor,
                            fontFamily: 'Outfit',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SongTile(
                          song: song,
                          isCurrent: isCurrent,
                          showDivider: index < top.length - 1,
                          playerProvider: widget.playerProvider,
                          onTap: () => widget.playerProvider.playSong(
                            song,
                            widget.playerProvider.allSongs,
                          ),
                          onPlayNext: () => widget.playerProvider.playNext(song),
                          onAddToQueue: () => widget.playerProvider.addToQueue(song),
                          onToggleFavorite: () =>
                              widget.playerProvider.toggleFavorite(song.id),
                        ),
                      ),
                      Text(
                        '${entry.count}x',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Page 3: Top Albums ───────────────────────────────────────────────────

  Widget _buildTopAlbumsPage(
    BuildContext context,
    ThemeData theme,
    List<Song> songs,
  ) {
    var top = _statsService.topAlbums(5, songs);
    var songMap = <String, List<Song>>{};
    for (var song in songs) {
      var key = '${song.album}|||${song.artist}';
      songMap.putIfAbsent(key, () => []).add(song);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              'Most Played Albums',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (top.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No listening data yet.\nStart playing music to see your top albums!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: top.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  var entry = top[index];
                  var key = '${entry.album}|||${entry.artist}';
                  var albumSongs = songMap[key] ?? [];
                  var artworkPath = albumSongs.isNotEmpty
                      ? albumSongs.first.artworkPath
                      : null;

                  return _AlbumCard(
                    album: entry.album,
                    artist: entry.artist,
                    count: entry.count,
                    artworkPath: artworkPath,
                    theme: theme,
                    onTap: () {
                      if (albumSongs.isNotEmpty) {
                        var group = buildAlbumGroup(
                          entry.album,
                          entry.artist,
                          songs,
                        );
                        if (group.songs.isNotEmpty) {
                          openAlbum(context, group);
                        }
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Page 4: Top Artists ──────────────────────────────────────────────────

  Widget _buildTopArtistsPage(
    BuildContext context,
    ThemeData theme,
    List<Song> songs,
  ) {
    var top = _statsService.topArtists(5, songs);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              'Most Played Artists',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (top.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No listening data yet.\nStart playing music to see your top artists!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: top.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  var entry = top[index];
                  var rankColors = [
                    const Color(0xFFFFD700),
                    const Color(0xFFC0C0C0),
                    const Color(0xFFCD7F32),
                    theme.colorScheme.outline,
                    theme.colorScheme.outline,
                  ];

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '#${index + 1}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: rankColors[index % rankColors.length],
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          radius: 22,
                          child: Icon(
                            Icons.person_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.artist,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.count} plays',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          onPressed: () {
                            var group = buildArtistGroup(
                              entry.artist,
                              songs,
                            );
                            if (group.songs.isNotEmpty) {
                              openArtist(context, group);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Page 5: Top Playlists ────────────────────────────────────────────────

  Widget _buildTopPlaylistsPage(
    BuildContext context,
    ThemeData theme,
    List<Playlist> playlists,
  ) {
    var top = _statsService.topPlaylists(5, playlists);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              'Most Played Playlists',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (top.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No listening data yet.\nPlay music from playlists to see them here!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: top.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  var entry = top[index];
                  var rankColors = [
                    const Color(0xFFFFD700),
                    const Color(0xFFC0C0C0),
                    const Color(0xFFCD7F32),
                    theme.colorScheme.outline,
                    theme.colorScheme.outline,
                  ];

                  var songCount = entry.playlist.songIds.length;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '#${index + 1}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: rankColors[index % rankColors.length],
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.secondaryContainer,
                          radius: 22,
                          child: Icon(
                            Icons.playlist_play_rounded,
                            color: theme.colorScheme.onSecondaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.playlist.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$songCount songs · ${entry.count} plays',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          onPressed: () => openPlaylist(context, entry.playlist),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Metric Card Widget ─────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.theme,
  });

  final IconData icon;
  final String value;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Album Card Widget ──────────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.artist,
    required this.count,
    this.artworkPath,
    required this.theme,
    required this.onTap,
  });

  final String album;
  final String artist;
  final int count;
  final String? artworkPath;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              AlbumArt(
                artworkPath: artworkPath,
                size: 52,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${count}x',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
