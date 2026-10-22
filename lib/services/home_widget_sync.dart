import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the Android "Now playing" home screen widget shows.
@immutable
class HomeWidgetState {
  final String title;
  final String? artist;
  final String? artPath;
  final bool isPlaying;

  const HomeWidgetState({
    required this.title,
    this.artist,
    this.artPath,
    this.isPlaying = false,
  });

  /// The widget state for [item], or `null` (empty widget) when nothing is
  /// loaded.
  static HomeWidgetState? from(MediaItem? item, {required bool playing}) {
    if (item == null) return null;
    var artUri = item.artUri;
    String? artPath;
    if (artUri != null && artUri.isScheme('file')) {
      try {
        artPath = artUri.toFilePath();
      } catch (_) {}
    }
    return HomeWidgetState(
      title: item.title,
      artist: item.artist,
      artPath: artPath,
      isPlaying: playing,
    );
  }

  Map<String, Object?> toMap() => {
    'title': title,
    'artist': artist,
    'artPath': artPath,
    'isPlaying': isPlaying,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetState &&
      other.title == title &&
      other.artist == artist &&
      other.artPath == artPath &&
      other.isPlaying == isPlaying;

  @override
  int get hashCode => Object.hash(title, artist, artPath, isPlaying);
}

/// Pushes the now playing state to the native Android home screen widget.
///
/// Only sends when the state actually changes, so position ticks and other
/// playback state updates cost nothing. Does nothing off Android.
class HomeWidgetSync {
  HomeWidgetSync({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel(channelName),
      enabled = enabled ?? (!kIsWeb && Platform.isAndroid);

  static const channelName = 'de.yurtemre.sonora/home_widget';

  final MethodChannel _channel;
  final bool enabled;

  // Starts out empty, so a fresh start with nothing loaded keeps the last
  // track the widget persisted until playback is restored or stopped.
  HomeWidgetState? _last;

  /// Sends [state] (`null` for the empty widget) unless it was the last one
  /// sent.
  Future<void> update(HomeWidgetState? state) async {
    if (!enabled || state == _last) return;
    var previous = _last;
    _last = state;
    try {
      await _channel.invokeMethod<void>('update', state?.toMap());
    } catch (_) {
      // Not attached natively yet (e.g. a background engine): retry on the
      // next change.
      if (_last == state) _last = previous;
    }
  }
}
