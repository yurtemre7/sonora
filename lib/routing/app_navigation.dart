import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';

import 'package:sonora/routing/app_routes.dart';

void goToHome(BuildContext context) {
  context.go(AppRoutes.home);
}

void openSettings(BuildContext context) {
  context.push(AppRoutes.settings);
}

void openAlbum(BuildContext context, AlbumGroup album) {
  context.push(AppRoutes.album, extra: album);
}

void openArtist(BuildContext context, ArtistGroup artist) {
  context.push(AppRoutes.artist, extra: artist);
}

void openPlaylist(BuildContext context, Playlist playlist) {
  context.push(AppRoutes.playlist, extra: playlist);
}

void closeRoute(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  }
}
