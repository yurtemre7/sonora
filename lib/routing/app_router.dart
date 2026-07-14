import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/routing/app_routes.dart';
import 'package:sonora/screens/album_detail_screen.dart';
import 'package:sonora/screens/artist_detail_screen.dart';
import 'package:sonora/screens/playlist_detail_screen.dart';
import 'package:sonora/screens/settings_screen.dart';

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

      if (_isLoading) {
        return path == AppRoutes.loading ? null : AppRoutes.loading;
      }

      if (_showOnboarding) {
        return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }

      if (!_hasPermission) {
        return path == AppRoutes.permission ? null : AppRoutes.permission;
      }

      if (path == AppRoutes.loading ||
          path == AppRoutes.onboarding ||
          path == AppRoutes.permission) {
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
          var album = state.extra;
          if (album is! AlbumGroup) {
            return const Scaffold(
              body: Center(child: Text('Missing album data')),
            );
          }
          var latestAlbum = buildAlbumGroup(
            album.name,
            album.artist,
            playerProvider.allSongs,
          );
          return AlbumDetailScreen(
            album: latestAlbum.songs.isNotEmpty ? latestAlbum : album,
            playerProvider: playerProvider,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.artist,
        builder: (context, state) {
          var artist = state.extra;
          if (artist is! ArtistGroup) {
            return const Scaffold(
              body: Center(child: Text('Missing artist data')),
            );
          }
          var latestArtist = buildArtistGroup(
            artist.name,
            playerProvider.allSongs,
          );
          return ArtistDetailScreen(
            artist: latestArtist.songs.isNotEmpty ? latestArtist : artist,
            playerProvider: playerProvider,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.playlist,
        builder: (context, state) {
          var playlist = state.extra;
          if (playlist is! Playlist) {
            return const Scaffold(
              body: Center(child: Text('Missing playlist data')),
            );
          }
          Playlist? latestPlaylist;
          for (var item in playerProvider.playlists) {
            if (item.id == playlist.id) {
              latestPlaylist = item;
              break;
            }
          }
          var resolvedPlaylist = latestPlaylist ?? playlist;
          return PlaylistDetailScreen(
            playlist: resolvedPlaylist,
            songs: playerProvider.allSongs,
            playerProvider: playerProvider,
            onRemoveSong: onRemoveSongFromPlaylist,
            onReorderSongs: onReorderPlaylistSongs,
            playlists: playerProvider.playlists,
            onAddSongToPlaylist: onAddSongToPlaylist,
          );
        },
      ),
    ],
  );

  bool get _isLoading => _loading;
  bool get _showOnboarding => _onboarding;
  bool get _hasPermission => _permissionGranted;

  var _loading = true;
  var _onboarding = false;
  var _permissionGranted = true;

  void updateGateState({
    required bool isLoading,
    required bool showOnboarding,
    required bool hasPermission,
  }) {
    _loading = isLoading;
    _onboarding = showOnboarding;
    _permissionGranted = hasPermission;
  }
}
