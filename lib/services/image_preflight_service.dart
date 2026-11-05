import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/thumbnail_store.dart';
import 'package:sonora/widgets/album_art.dart';

/// Pre-flight image decoding and caching service.
///
/// Pre-warms and decodes artwork bitmaps in the background directly into
/// Flutter's [PaintingBinding.instance.imageCache] before widgets mount on screen.
/// This prevents scroll stutter, eliminates pop-in, and avoids on-demand
/// decode latency on flash storage.
class ImagePreflightService {
  ImagePreflightService._internal();
  static final instance = ImagePreflightService._internal();
  factory ImagePreflightService() => instance;

  // One token per loop: songs and albums preflight run concurrently and must
  // not cancel each other.
  var _songsToken = 0;
  var _albumsToken = 0;
  var _thumbsToken = 0;
  final _preflightedProviders = <String>{};

  /// Decodes and warms up an [ImageProvider] into Flutter's [imageCache].
  Future<void> preflightProvider(ImageProvider provider) {
    var completer = Completer<void>();
    var stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!completer.isCompleted) completer.complete();
        stream.removeListener(listener);
      },
      onError: (exception, stackTrace) {
        if (!completer.isCompleted) completer.complete();
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Creates any missing on-disk thumbnails for every cover in [songs], one at
  /// a time in the background. Tiles use them from the next provider lookup on.
  Future<void> generateThumbnails(List<Song> songs) async {
    var token = ++_thumbsToken;
    var seen = <String>{};
    for (var song in songs) {
      var path = song.artworkPath;
      if (path == null || path.isEmpty || !seen.add(path)) continue;
      if (ThumbnailStore.find(path) != null) continue;
      if (!AlbumArt.checkFileExists(path)) continue;
      if (token != _thumbsToken) return;
      await ThumbnailStore.ensure(path);
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  /// Preflights thumbnail artwork for [songs] (default size 48 -> cacheDim 128).
  ///
  /// Processes up to [maxItems] unique artwork paths in non-blocking batches
  /// of [chunkSize] to avoid UI jank.
  Future<void> preflightSongs(
    List<Song> songs, {
    int maxItems = 60,
    double size = 48,
    int chunkSize = 6,
    double devicePixelRatio = 2.0,
  }) async {
    var token = ++_songsToken;
    var targetDim = AlbumArt.computeCacheDim(size, devicePixelRatio);

    var uniquePaths = <String>[];
    var seen = <String>{};
    for (var song in songs) {
      var path = song.artworkPath;
      if (path != null && path.isNotEmpty && seen.add(path)) {
        var key = '$path@$targetDim';
        if (_preflightedProviders.contains(key)) continue;
        if (AlbumArt.checkFileExists(path)) {
          uniquePaths.add(path);
          if (uniquePaths.length >= maxItems) break;
        }
      }
    }

    if (uniquePaths.isEmpty) return;

    for (var i = 0; i < uniquePaths.length; i += chunkSize) {
      if (token != _songsToken) return;
      var end = (i + chunkSize < uniquePaths.length)
          ? i + chunkSize
          : uniquePaths.length;
      var batch = uniquePaths.sublist(i, end);

      var futures = <Future<void>>[];
      for (var path in batch) {
        var key = '$path@$targetDim';
        _preflightedProviders.add(key);
        var provider = AlbumArt.provider(path, cacheDim: targetDim);
        futures.add(preflightProvider(provider));
      }

      await Future.wait(futures);
      if (token != _songsToken) return;

      // Yield frame slot between batches so the UI remains fluid.
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  /// Preflights album cover artwork for [albums] (default size 200 -> cacheDim 384/512).
  Future<void> preflightAlbums(
    List<AlbumGroup> albums, {
    int maxItems = 30,
    double size = 200,
    int chunkSize = 4,
    double devicePixelRatio = 2.0,
  }) async {
    var token = ++_albumsToken;
    var targetDim = AlbumArt.computeCacheDim(size, devicePixelRatio);

    var uniquePaths = <String>[];
    var seen = <String>{};
    for (var album in albums) {
      if (album.songs.isEmpty) continue;
      var path = album.songs.first.artworkPath;
      if (path != null && path.isNotEmpty && seen.add(path)) {
        var key = '$path@$targetDim';
        if (_preflightedProviders.contains(key)) continue;
        if (AlbumArt.checkFileExists(path)) {
          uniquePaths.add(path);
          if (uniquePaths.length >= maxItems) break;
        }
      }
    }

    if (uniquePaths.isEmpty) return;

    for (var i = 0; i < uniquePaths.length; i += chunkSize) {
      if (token != _albumsToken) return;
      var end = (i + chunkSize < uniquePaths.length)
          ? i + chunkSize
          : uniquePaths.length;
      var batch = uniquePaths.sublist(i, end);

      var futures = <Future<void>>[];
      for (var path in batch) {
        var key = '$path@$targetDim';
        _preflightedProviders.add(key);
        var provider = AlbumArt.provider(path, cacheDim: targetDim);
        futures.add(preflightProvider(provider));
      }

      await Future.wait(futures);
      if (token != _albumsToken) return;

      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  /// Preflights upcoming queue tracks at higher resolution for instant Now Playing display.
  Future<void> preflightQueueUpcoming(
    List<Song> queue,
    int currentIndex, {
    int count = 5,
    double size = 400,
    double devicePixelRatio = 2.0,
  }) async {
    if (queue.isEmpty || currentIndex < 0) return;
    var targetDim = AlbumArt.computeCacheDim(size, devicePixelRatio);

    var start = currentIndex;
    var end = (currentIndex + count < queue.length)
        ? currentIndex + count
        : queue.length;

    for (var i = start; i < end; i++) {
      var path = queue[i].artworkPath;
      if (path != null && path.isNotEmpty) {
        var key = '$path@$targetDim';
        if (_preflightedProviders.add(key)) {
          if (AlbumArt.checkFileExists(path)) {
            var provider = AlbumArt.provider(path, cacheDim: targetDim);
            unawaited(preflightProvider(provider));
          }
        }
      }
    }
  }

  /// Cancels any active preflight loops.
  void cancel() {
    _songsToken++;
    _albumsToken++;
    _thumbsToken++;
  }

  /// Clears the recorded preflight cache (e.g. after sync or clear cache).
  void clearCache() {
    _songsToken++;
    _albumsToken++;
    _thumbsToken++;
    _preflightedProviders.clear();
    AlbumArt.clearFileCache();
  }
}
