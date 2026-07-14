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

void closeRoute(BuildContext context) {
  if (context.canPop()) {
    Logger.modoru('back');
    context.pop();
  }
}
