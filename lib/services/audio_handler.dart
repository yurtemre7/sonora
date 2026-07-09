import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Custom [AudioHandler] for Sonora that provides background audio playback,
/// media notification controls, and lock-screen integration.
///
/// Uses [just_audio] for the playback engine and [audio_service] for the
/// system media session (notification, lock screen, Bluetooth metadata).
class SonoraAudioHandler extends BaseAudioHandler with QueueHandler {
  final player = AudioPlayer();
  // ignore: deprecated_member_use
  final _playlist = ConcatenatingAudioSource(children: []);


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

    // When the current item index changes, update the active MediaItem.
    player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    // Handle natural completion of the playlist.
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
      }
    });
  }

  /// Maps [just_audio] playback events to the [audio_service] playback state
  /// broadcast, keeping the system notification and lock screen in sync.
  void _broadcastPlaybackState(PlaybackEvent event) {
    var playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      // Transport controls shown in the notification.
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      // System-level actions (e.g. seek bar in notification).
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      // Map just_audio processing states to audio_service equivalents.
      processingState: _mapProcessingState(player.processingState),
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
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
  // Playlist management
  // ---------------------------------------------------------------------------

  /// Loads a list of [MediaItem]s into the player as a concatenating playlist.
  ///
  /// [initialIndex] determines which track to start on (default 0).
  Future<void> loadPlaylist(
    List<MediaItem> items, {
    int initialIndex = 0,
  }) async {
    // Clear and build the playlist source.
    await _playlist.clear();
    for (var item in items) {
      await _playlist.add(AudioSource.uri(
        Uri.parse(item.id),
        tag: item,
      ));
    }

    // Set the playlist on the player and seek to the initial track.
    await player.setAudioSource(
      _playlist,
      initialIndex: initialIndex,
      initialPosition: Duration.zero,
    );

    // Update the queue broadcast so the system knows the full track list.
    queue.add(items);

    // Update the current media item.
    if (items.isNotEmpty && initialIndex < items.length) {
      mediaItem.add(items[initialIndex]);
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
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await player.seek(Duration.zero, index: index);
    mediaItem.add(queue.value[index]);
  }

  // ---------------------------------------------------------------------------
  // Shuffle & Repeat
  // ---------------------------------------------------------------------------

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    var enabled = shuffleMode == AudioServiceShuffleMode.all;
    await player.setShuffleModeEnabled(enabled);
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

  /// Updates the playlist source dynamically after the currently playing index.
  Future<void> updatePlaylistAfter(int index, List<MediaItem> remainingItems) async {
    // Remove all sources after current index
    while (_playlist.length > index + 1) {
      await _playlist.removeAt(index + 1);
    }
    // Append the new remaining sources
    for (var item in remainingItems) {
      await _playlist.add(AudioSource.uri(
        Uri.parse(item.id),
        tag: item,
      ));
    }
    
    // Synchronize audio service queue broadcast stream
    var fullQueue = List<MediaItem>.from(queue.value);
    if (fullQueue.length > index + 1) {
      fullQueue = fullQueue.sublist(0, index + 1);
    }
    fullQueue.addAll(remainingItems);
    queue.add(fullQueue);
  }
}
