import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Custom [AudioHandler] for Sonora that provides background audio playback,
/// media notification controls, and lock-screen integration.
///
/// Uses [just_audio] for the playback engine and [audio_service] for the
/// system media session (notification, lock screen, Bluetooth metadata).
///
/// Optimised for large libraries (10,000+ songs) using a sliding window strategy.
class SonoraAudioHandler extends BaseAudioHandler with QueueHandler {
  final player = AudioPlayer();

  // The full playlist (logical queue) of MediaItems.
  List<MediaItem> _rawPlaylist = [];

  // Sliding window bounds in the raw playlist.
  var _windowStart = 0; // global index of native index 0
  var _windowEnd = 0;   // global index after native index (native length - 1)

  // Window sizing parameters.
  static const _prependBuffer = 10;
  static const _appendBuffer = 30;

  // Prevent recursive triggers when updating player sources.
  var _isModifyingSources = false;

  SonoraAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // Configure the audio session for music playback.
    var session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
    ));

    // Broadcast playback state changes from just_audio to audio_service.
    player.playbackEventStream.listen(_broadcastPlaybackState);

    // Watch current index changes to update active MediaItem and slide the window.
    player.currentIndexStream.listen((localIndex) {
      if (localIndex == null || _isModifyingSources) return;
      if (_rawPlaylist.isEmpty) return;

      var globalIndex = _windowStart + localIndex;
      if (globalIndex >= 0 && globalIndex < _rawPlaylist.length) {
        mediaItem.add(_rawPlaylist[globalIndex]);
        _checkAndSlideWindow(localIndex);
      }
    });

    // Handle natural completion of the playlist.
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
      }
    });
  }

  /// Maps [just_audio] playback events to the [audio_service] playback state.
  void _broadcastPlaybackState(PlaybackEvent event) {
    var playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      processingState: _mapProcessingState(player.processingState),
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex != null ? _windowStart + event.currentIndex! : null,
    ));
  }

  /// Converts a [just_audio] [ProcessingState] to an [audio_service]
  /// [AudioProcessingState].
  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // ---------------------------------------------------------------------------
  // Sliding Window Management
  // ---------------------------------------------------------------------------

  /// Checks if we need to prepend or append items to the sliding window native player queue.
  Future<void> _checkAndSlideWindow(int localIndex) async {
    if (_isModifyingSources) return;

    var nativeLength = player.sequence.length;
    if (nativeLength == 0) return;

    var remainingAfter = nativeLength - 1 - localIndex;
    var remainingBefore = localIndex;

    // Slide forward (Append more upcoming tracks)
    if (remainingAfter < 10 && _windowEnd < _rawPlaylist.length) {
      _isModifyingSources = true;
      try {
        var chunkSize = min(20, _rawPlaylist.length - _windowEnd);
        var appendItems = _rawPlaylist.sublist(_windowEnd, _windowEnd + chunkSize);
        var sources = appendItems.map((item) => AudioSource.uri(
          Uri.parse(item.id),
          tag: item,
        )).toList();
        
        await player.addAudioSources(sources);
        _windowEnd += chunkSize;

        // Broadcast current window to audio_service
        queue.add(_rawPlaylist.sublist(_windowStart, _windowEnd));
      } finally {
        _isModifyingSources = false;
      }
    }

    // Slide backward (Prepend previous tracks)
    if (remainingBefore < 5 && _windowStart > 0) {
      _isModifyingSources = true;
      try {
        var chunkSize = min(15, _windowStart);
        var prependItems = _rawPlaylist.sublist(_windowStart - chunkSize, _windowStart);
        var sources = prependItems.map((item) => AudioSource.uri(
          Uri.parse(item.id),
          tag: item,
        )).toList();

        await player.insertAudioSources(0, sources);
        _windowStart -= chunkSize;

        // Broadcast current window to audio_service
        queue.add(_rawPlaylist.sublist(_windowStart, _windowEnd));
      } finally {
        _isModifyingSources = false;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Playlist management
  // ---------------------------------------------------------------------------

  /// Loads a list of [MediaItem]s using the sliding window strategy.
  Future<void> loadPlaylist(
    List<MediaItem> items, {
    int initialIndex = 0,
  }) async {
    _rawPlaylist = List<MediaItem>.from(items);

    if (_rawPlaylist.isEmpty) {
      _windowStart = 0;
      _windowEnd = 0;
      await player.stop();
      _isModifyingSources = true;
      try {
        await player.setAudioSources([]);
      } catch (_) {} finally {
        _isModifyingSources = false;
      }
      queue.add([]);
      mediaItem.add(null);
      return;
    }

    // Clamp initialIndex to bounds
    if (initialIndex < 0) initialIndex = 0;
    if (initialIndex >= _rawPlaylist.length) initialIndex = _rawPlaylist.length - 1;

    // Calculate window bounds around initialIndex
    _windowStart = max(0, initialIndex - _prependBuffer);
    _windowEnd = min(_rawPlaylist.length, initialIndex + _appendBuffer);

    var windowItems = _rawPlaylist.sublist(_windowStart, _windowEnd);
    var initialNativeIndex = initialIndex - _windowStart;

    var initialBatch = windowItems.map((item) => AudioSource.uri(
      Uri.parse(item.id),
      tag: item,
    )).toList();

    _isModifyingSources = true;
    try {
      await player.setAudioSources(
        initialBatch,
        initialIndex: initialNativeIndex,
        initialPosition: Duration.zero,
      );

      queue.add(windowItems);
      mediaItem.add(_rawPlaylist[initialIndex]);
    } catch (_) {
      // Just_audio throws 'Loading interrupted' when another load request overlaps.
      // This is expected during rapid skips/taps, so we handle it silently.
    } finally {
      _isModifyingSources = false;
    }
  }

  /// Updates the playlist source dynamically after the currently playing index.
  /// Used for shuffling/unshuffling remaining tracks.
  Future<void> updatePlaylistAfter(int index, List<MediaItem> remainingItems) async {
    // Update global playlist
    if (index >= 0 && index < _rawPlaylist.length) {
      _rawPlaylist = [
        ..._rawPlaylist.sublist(0, index + 1),
        ...remainingItems,
      ];
    } else {
      _rawPlaylist = List<MediaItem>.from(remainingItems);
    }

    var localIndex = index - _windowStart;
    var nativeLength = player.sequence.length;

    if (localIndex >= 0 && localIndex < nativeLength) {
      _isModifyingSources = true;
      try {
        // Remove all native sources after localIndex
        for (var i = nativeLength - 1; i > localIndex; i--) {
          await player.removeAudioSourceAt(i);
        }

        // Add next batch of remaining items to native playlist
        var chunkSize = min(30, remainingItems.length);
        var appendItems = remainingItems.sublist(0, chunkSize);
        var sources = appendItems.map((item) => AudioSource.uri(
          Uri.parse(item.id),
          tag: item,
        )).toList();

        await player.addAudioSources(sources);
        _windowEnd = _windowStart + localIndex + 1 + chunkSize;

        queue.add(_rawPlaylist.sublist(_windowStart, _windowEnd));
      } finally {
        _isModifyingSources = false;
      }
    } else {
      // Current index is outside window - force reload around index
      await loadPlaylist(_rawPlaylist, initialIndex: index);
    }
  }

  // ---------------------------------------------------------------------------
  // Custom Methods to Sync Queue Manipulations
  // ---------------------------------------------------------------------------

  /// Removes the logical item at [globalIndex] and updates the native playlist.
  @override
  Future<void> removeQueueItemAt(int globalIndex) async {
    if (globalIndex < 0 || globalIndex >= _rawPlaylist.length) return;

    _rawPlaylist.removeAt(globalIndex);

    // If removed item is within the native window
    if (globalIndex >= _windowStart && globalIndex < _windowEnd) {
      var localIndex = globalIndex - _windowStart;
      _isModifyingSources = true;
      try {
        await player.removeAudioSourceAt(localIndex);
        _windowEnd--;
        queue.add(_rawPlaylist.sublist(_windowStart, _windowEnd));
      } finally {
        _isModifyingSources = false;
      }
    } else if (globalIndex < _windowStart) {
      _windowStart--;
      _windowEnd--;
    }
  }

  /// Moves the logical item from [oldGlobalIndex] to [newGlobalIndex].
  Future<void> moveQueueItem(int oldGlobalIndex, int newGlobalIndex) async {
    if (oldGlobalIndex < 0 || oldGlobalIndex >= _rawPlaylist.length) return;
    if (newGlobalIndex < 0 || newGlobalIndex > _rawPlaylist.length) return;

    var item = _rawPlaylist.removeAt(oldGlobalIndex);
    var targetNewIndex = newGlobalIndex;
    if (targetNewIndex > oldGlobalIndex) targetNewIndex--;
    _rawPlaylist.insert(targetNewIndex, item);

    // If both old and new indices are within the native window
    if (oldGlobalIndex >= _windowStart && oldGlobalIndex < _windowEnd &&
        targetNewIndex >= _windowStart && targetNewIndex < _windowEnd) {
      var localOld = oldGlobalIndex - _windowStart;
      var localNew = targetNewIndex - _windowStart;
      _isModifyingSources = true;
      try {
        await player.moveAudioSource(localOld, localNew);
        queue.add(_rawPlaylist.sublist(_windowStart, _windowEnd));
      } finally {
        _isModifyingSources = false;
      }
    } else {
      // Re-initialize window around current playing song to be safe
      var currentItem = mediaItem.value;
      if (currentItem != null) {
        var currentGlobalIndex = _rawPlaylist.indexOf(currentItem);
        if (currentGlobalIndex >= 0) {
          await loadPlaylist(_rawPlaylist, initialIndex: currentGlobalIndex);
        }
      }
    }
  }

  /// Appends [item] to the logical queue and updates player if window is at the end.
  @override
  Future<void> addQueueItem(MediaItem item) async {
    _rawPlaylist.add(item);
    
    if (_windowEnd == _rawPlaylist.length - 1) {
      _isModifyingSources = true;
      try {
        await player.addAudioSource(AudioSource.uri(
          Uri.parse(item.id),
          tag: item,
        ));
        _windowEnd++;
        queue.add(_rawPlaylist.sublist(_windowStart, _windowEnd));
      } finally {
        _isModifyingSources = false;
      }
    }
  }

  /// Inserts [item] at [globalIndex] in the logical queue.
  Future<void> insertQueueItemAt(int globalIndex, MediaItem item) async {
    if (globalIndex < 0 || globalIndex > _rawPlaylist.length) return;
    _rawPlaylist.insert(globalIndex, item);

    if (globalIndex >= _windowStart && globalIndex <= _windowEnd) {
      var localIndex = globalIndex - _windowStart;
      _isModifyingSources = true;
      try {
        await player.insertAudioSource(localIndex, AudioSource.uri(
          Uri.parse(item.id),
          tag: item,
        ));
        _windowEnd++;
        queue.add(_rawPlaylist.sublist(_windowStart, _windowEnd));
      } finally {
        _isModifyingSources = false;
      }
    } else if (globalIndex < _windowStart) {
      _windowStart++;
      _windowEnd++;
    }
  }

  // ---------------------------------------------------------------------------
  // Transport controls
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    _rawPlaylist = [];
    _windowStart = 0;
    _windowEnd = 0;
    queue.add([]);
    mediaItem.add(null);
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (player.hasNext) {
      await player.seekToNext();
    } else if (_windowEnd < _rawPlaylist.length) {
      // Force loading next window centered on next index
      var nextIndex = _windowStart + (player.currentIndex ?? 0) + 1;
      await loadPlaylist(_rawPlaylist, initialIndex: nextIndex);
      await player.play();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else {
      if (player.hasPrevious) {
        await player.seekToPrevious();
      } else if (_windowStart > 0) {
        // Force loading previous window centered on previous index
        var prevIndex = _windowStart + (player.currentIndex ?? 0) - 1;
        await loadPlaylist(_rawPlaylist, initialIndex: prevIndex);
        await player.play();
      } else {
        // First song of the entire playlist, seek to 0
        await player.seek(Duration.zero);
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _rawPlaylist.length) return;

    if (index >= _windowStart && index < _windowEnd) {
      var localIndex = index - _windowStart;
      await player.seek(Duration.zero, index: localIndex);
      mediaItem.add(_rawPlaylist[index]);
    } else {
      // Outside window, force reload window centered on index
      await loadPlaylist(_rawPlaylist, initialIndex: index);
      await player.play();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    // Shuffling is managed logically at PlayerProvider level.
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await player.stop();
    await super.onTaskRemoved();
  }
}
