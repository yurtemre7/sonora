import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/routing/app_routes.dart';
import 'package:sonora/utils/logger.dart';

void goToHome(BuildContext context) {
  Logger.ikou(AppRoutes.home);
  context.go(AppRoutes.home);
}

void openSettings(BuildContext context) {
  Logger.ikou(AppRoutes.settings);
  context.push(AppRoutes.settings);
}

void openAlbum(BuildContext context, AlbumGroup album) {
  var location = Uri(
    path: AppRoutes.album,
    queryParameters: {'artist': album.artist, 'album': album.name},
  ).toString();
  Logger.ikou(location);
  context.push(location);
}

void openArtist(BuildContext context, ArtistGroup artist) {
  var location = Uri(
    path: AppRoutes.artist,
    queryParameters: {'name': artist.name},
  ).toString();
  Logger.ikou(location);
  context.push(location);
}

void openPlaylist(BuildContext context, Playlist playlist) {
  var location = Uri(
    path: AppRoutes.playlist,
    queryParameters: {'id': playlist.id},
  ).toString();
  Logger.ikou(location);
  context.push(location);
}

/// Pops the top-most route on the current navigator.
///
/// If a modal (e.g. the Now Playing sheet) is covering the current page,
/// it is dismissed first — only if no modal is present does this fall
/// through to go_router to pop the underlying named route.
Future<void> closeRoute(BuildContext context) async {
  // Navigator.maybePop handles modals (bottom sheets, dialogs) pushed onto
  // the local navigator first, before go_router sees the back event.
  var popped = await Navigator.of(context).maybePop();
  if (!popped && context.mounted && context.canPop()) {
    Logger.modoru('back');
    context.pop();
  }
}
