import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/routing/app_routes.dart';
import 'package:sonora/screens/album_detail_screen.dart';
import 'package:sonora/screens/artist_detail_screen.dart';
import 'package:sonora/screens/now_playing_screen.dart';
import 'package:sonora/screens/playlist_detail_screen.dart';
import 'package:sonora/screens/settings_screen.dart';
import 'package:sonora/utils/logger.dart';
import 'package:sonora/widgets/mini_player.dart';

class SonoraAppRouter {
  SonoraAppRouter({
    required this.refreshListenable,
    required this.loadingBuilder,
    required this.permissionBuilder,
    required this.playerProvider,
    required this.themeProvider,
    required this.buildOnboarding,
    required this.buildHome,
    required this.onConfigureFolder,
    required this.onResetApp,
    required this.onRetriggerSync,
    required this.onCreatePlaylist,
    required this.onDeletePlaylist,
    required this.onAddSongToPlaylist,
    required this.onRemoveSongFromPlaylist,
    required this.onReorderPlaylistSongs,
  });

  final Listenable refreshListenable;
  final WidgetBuilder loadingBuilder;
  final WidgetBuilder permissionBuilder;
  final PlayerProvider playerProvider;
  final ThemeProvider themeProvider;
  final Widget Function(BuildContext context) buildOnboarding;
  final Widget Function(BuildContext context) buildHome;
  final Future<void> Function() onConfigureFolder;
  final VoidCallback onResetApp;
  final Future<void> Function() onRetriggerSync;
  final Future<void> Function(String name) onCreatePlaylist;
  final Future<void> Function(String playlistId) onDeletePlaylist;
  final Future<void> Function(String playlistId, int songId)
  onAddSongToPlaylist;
  final Future<void> Function(String playlistId, int songId)
  onRemoveSongFromPlaylist;
  final Future<void> Function(String playlistId, List<int> reorderedIds)
  onReorderPlaylistSongs;

  late final router = GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      var path = state.uri.path;

      if (path != _lastLoggedPath) {
        Logger.youkoso(path);
        _lastLoggedPath = path;
      }

      if (_isLoading) {
        if (path != AppRoutes.loading) {
          Logger.meguru(path, AppRoutes.loading);
        }
        return path == AppRoutes.loading ? null : AppRoutes.loading;
      }

      if (_showOnboarding) {
        if (path != AppRoutes.onboarding) {
          Logger.meguru(path, AppRoutes.onboarding);
        }
        return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }

      if (!_hasPermission) {
        if (path != AppRoutes.permission) {
          Logger.meguru(path, AppRoutes.permission);
        }
        return path == AppRoutes.permission ? null : AppRoutes.permission;
      }

      if (path == AppRoutes.loading ||
          path == AppRoutes.onboarding ||
          path == AppRoutes.permission) {
        Logger.meguru(path, AppRoutes.home);
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => loadingBuilder(context),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => buildOnboarding(context),
      ),
      GoRoute(
        path: AppRoutes.permission,
        builder: (context, state) => permissionBuilder(context),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ListenableBuilder(
            listenable: playerProvider,
            builder: (context, _) {
              var currentSong = playerProvider.currentSong;

              return Scaffold(
                body: child,
                extendBody: true,
                bottomNavigationBar: currentSong == null
                    ? null
                    : _ShellMiniPlayer(
                        playerProvider: playerProvider,
                        currentSong: currentSong,
                        onOpenNowPlaying: () => _openNowPlayingSheet(context),
                      ),
              );
            },
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => buildHome(context),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => SettingsScreen(
              onConfigureFolder: onConfigureFolder,
              onResetApp: onResetApp,
              onRetriggerSync: onRetriggerSync,
              themeProvider: themeProvider,
              playerProvider: playerProvider,
            ),
          ),
          GoRoute(
            path: AppRoutes.album,
            builder: (context, state) {
              var albumName = state.uri.queryParameters['album'];
              var artistName = state.uri.queryParameters['artist'];
              if (albumName == null || artistName == null) {
                return const Scaffold(
                  body: Center(child: Text('Missing album data')),
                );
              }
              var latestAlbum = buildAlbumGroup(
                albumName,
                artistName,
                playerProvider.allSongs,
              );
              if (latestAlbum.songs.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Album not found')),
                );
              }
              return AlbumDetailScreen(
                album: latestAlbum,
                playerProvider: playerProvider,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.artist,
            builder: (context, state) {
              var artistName = state.uri.queryParameters['name'];
              if (artistName == null) {
                return const Scaffold(
                  body: Center(child: Text('Missing artist data')),
                );
              }
              var latestArtist = buildArtistGroup(
                artistName,
                playerProvider.allSongs,
              );
              if (latestArtist.songs.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Artist not found')),
                );
              }
              return ArtistDetailScreen(
                artist: latestArtist,
                playerProvider: playerProvider,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.playlist,
            builder: (context, state) {
              var playlistId = state.uri.queryParameters['id'];
              if (playlistId == null) {
                return const Scaffold(
                  body: Center(child: Text('Missing playlist data')),
                );
              }
              Playlist? latestPlaylist;
              for (var item in playerProvider.playlists) {
                if (item.id == playlistId) {
                  latestPlaylist = item;
                  break;
                }
              }
              if (latestPlaylist == null && playlistId != 'favorites') {
                return const Scaffold(
                  body: Center(child: Text('Playlist not found')),
                );
              }
              var resolvedPlaylist = latestPlaylist;
              if (resolvedPlaylist == null && playlistId == 'favorites') {
                var favoriteIds = playerProvider.allSongs
                    .where((song) => song.isFavorite)
                    .map((song) => song.id)
                    .toList();
                resolvedPlaylist = Playlist(
                  id: 'favorites',
                  name: 'Favorites',
                  songIds: favoriteIds,
                );
              }
              if (resolvedPlaylist == null) {
                return const Scaffold(
                  body: Center(child: Text('Playlist not found')),
                );
              }
              return PlaylistDetailScreen(
                playlist: resolvedPlaylist,
                songs: playerProvider.allSongs,
                playerProvider: playerProvider,
                onRemoveSong: onRemoveSongFromPlaylist,
                onReorderSongs: onReorderPlaylistSongs,
                playlists: playerProvider.playlists,
                onAddSongToPlaylist: onAddSongToPlaylist,
                onDeletePlaylist: onDeletePlaylist,
              );
            },
          ),
        ],
      ),
    ],
  );

  bool get _isLoading => _loading;
  bool get _showOnboarding => _onboarding;
  bool get _hasPermission => _permissionGranted;

  var _loading = true;
  var _onboarding = false;
  var _permissionGranted = true;
  var _lastLoggedPath = '';

  void updateGateState({
    required bool isLoading,
    required bool showOnboarding,
    required bool hasPermission,
  }) {
    _loading = isLoading;
    _onboarding = showOnboarding;
    _permissionGranted = hasPermission;
  }

  void _openNowPlayingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => NowPlayingScreen(playerProvider: playerProvider),
    );
  }
}

class _ShellMiniPlayer extends StatelessWidget {
  const _ShellMiniPlayer({
    required this.playerProvider,
    required this.currentSong,
    required this.onOpenNowPlaying,
  });

  final PlayerProvider playerProvider;
  final Song currentSong;
  final VoidCallback onOpenNowPlaying;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: playerProvider.audioHandler.player.positionStream,
      builder: (context, snapshot) {
        var position = snapshot.data ?? Duration.zero;
        var totalMs = currentSong.duration.inMilliseconds;
        var progress = totalMs > 0 ? position.inMilliseconds / totalMs : 0.0;

        return MiniPlayer(
          currentSong: currentSong,
          isPlaying: playerProvider.audioHandler.player.playing,
          progress: progress,
          onTap: onOpenNowPlaying,
          onPlayPause: playerProvider.playPause,
          onNext: playerProvider.next,
          onSwipeUp: onOpenNowPlaying,
          onSwipeDown: playerProvider.stop,
          onSwipeLeft: playerProvider.previous,
          onSwipeRight: playerProvider.next,
        );
      },
    );
  }
}
