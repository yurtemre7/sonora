import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'package:sonora/models/song.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/music_scanner.dart';

/// Repeat mode for playlist playback.
enum RepeatMode { off, all, one }

/// Central application state for the music player.
///
/// Manages the current queue, playback controls, shuffle/repeat state, and
/// synchronises with the underlying [SonoraAudioHandler].
class PlayerProvider extends ChangeNotifier {
  final SonoraAudioHandler audioHandler;

  // ── State fields ──────────────────────────────────────────────────────────

  List<Song> allSongs = [];
  List<Song> queue = [];
  List<Song> _originalQueue = [];
  var currentIndex = -1;
  var isShuffled = false;
  RepeatMode repeatMode = RepeatMode.off;

  // ── Stream subscriptions ──────────────────────────────────────────────────

  StreamSubscription<MediaItem?>? _mediaItemSub;
  StreamSubscription<PlaybackState>? _playbackStateSub;

  // ── Constructor ───────────────────────────────────────────────────────────

  PlayerProvider({required this.audioHandler}) {
    _listenToMediaItem();
    _listenToPlaybackState();
  }

  // ── Derived getters ───────────────────────────────────────────────────────

  /// The currently playing song, or `null` if nothing is loaded.
  Song? get currentSong {
    if (currentIndex < 0 || currentIndex >= queue.length) return null;
    return queue[currentIndex];
  }

  /// Whether the player is currently playing audio.
  bool get isPlaying => audioHandler.player.playing;

  /// Current playback position stream.
  Stream<Duration> get positionStream => audioHandler.player.positionStream;

  /// Current buffered position stream.
  Stream<Duration> get bufferedPositionStream =>
      audioHandler.player.bufferedPositionStream;

  /// Current duration of the active track.
  Duration? get currentDuration => audioHandler.player.duration;

  // ── Playback controls ─────────────────────────────────────────────────────

  /// Starts playing [song] within the context of [songList].
  ///
  /// Builds a new queue from [songList], locates [song] within it, loads the
  /// playlist into the audio handler, and begins playback.
  Future<void> playSong(Song song, List<Song> songList) async {
    queue = List<Song>.from(songList);
    _originalQueue = List<Song>.from(songList);
    isShuffled = false;

    var index = queue.indexWhere((s) => s.id == song.id);
    currentIndex = index >= 0 ? index : 0;

    var mediaItems = queue.map(_songToMediaItem).toList();
    await audioHandler.loadPlaylist(mediaItems, initialIndex: currentIndex);
    await audioHandler.play();
    notifyListeners();
  }

  /// Toggles between play and pause.
  Future<void> playPause() async {
    if (isPlaying) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  /// Skips to the next track in the queue.
  Future<void> next() async {
    await audioHandler.skipToNext();
  }

  /// Skips to the previous track in the queue.
  Future<void> previous() async {
    await audioHandler.skipToPrevious();
  }

  /// Seeks to [position] within the current track.
  Future<void> seek(Duration position) async {
    await audioHandler.seek(position);
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  /// Toggles shuffle mode on/off.
  ///
  /// When enabling shuffle, the queue is randomised but the currently playing
  /// song is moved to the front. When disabling, the original queue order is
  /// restored while keeping the same song playing.
  Future<void> toggleShuffle() async {
    if (isShuffled) {
      // Restore original order.
      var current = currentSong;
      queue = List<Song>.from(_originalQueue);
      if (current != null) {
        currentIndex = queue.indexWhere((s) => s.id == current.id);
        if (currentIndex < 0) currentIndex = 0;
      }
      await audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
    } else {
      // Shuffle, keeping current song at front.
      var current = currentSong;
      queue.shuffle();
      if (current != null) {
        queue.remove(current);
        queue.insert(0, current);
        currentIndex = 0;
      }
      await audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
    }

    isShuffled = !isShuffled;

    // Reload the playlist with the new order.
    var mediaItems = queue.map(_songToMediaItem).toList();
    await audioHandler.loadPlaylist(mediaItems, initialIndex: currentIndex);
    if (isPlaying) await audioHandler.play();

    notifyListeners();
  }

  // ── Repeat ────────────────────────────────────────────────────────────────

  /// Cycles the repeat mode: off → all → one → off.
  Future<void> cycleRepeatMode() async {
    switch (repeatMode) {
      case RepeatMode.off:
        repeatMode = RepeatMode.all;
        await audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case RepeatMode.all:
        repeatMode = RepeatMode.one;
        await audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case RepeatMode.one:
        repeatMode = RepeatMode.off;
        await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
    notifyListeners();
  }

  // ── Queue manipulation ────────────────────────────────────────────────────

  /// Removes the song at [index] from the queue.
  void removeFromQueue(int index) {
    if (index < 0 || index >= queue.length) return;

    queue.removeAt(index);

    // Adjust currentIndex if needed.
    if (index < currentIndex) {
      currentIndex--;
    } else if (index == currentIndex) {
      // If the removed song was playing, clamp to bounds.
      if (currentIndex >= queue.length) {
        currentIndex = queue.isEmpty ? -1 : queue.length - 1;
      }
    }

    notifyListeners();
  }

  /// Moves a song in the queue from [oldIndex] to [newIndex].
  void moveInQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex > queue.length) return;

    // Adjust for the standard ReorderableListView offset.
    if (newIndex > oldIndex) newIndex--;

    var song = queue.removeAt(oldIndex);
    queue.insert(newIndex, song);

    // Keep currentIndex tracking the same song.
    if (oldIndex == currentIndex) {
      currentIndex = newIndex;
    } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
      currentIndex--;
    } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
      currentIndex++;
    }

    notifyListeners();
  }

  /// Appends [song] to the end of the queue.
  void addToQueue(Song song) {
    queue.add(song);
    notifyListeners();
  }

  /// Inserts [song] immediately after the currently playing song.
  void playNext(Song song) {
    var insertIndex = currentIndex + 1;
    if (insertIndex >= queue.length) {
      queue.add(song);
    } else {
      queue.insert(insertIndex, song);
    }
    notifyListeners();
  }

  /// Sets all songs and updates the queue with the list.
  void updateSongs(List<Song> songs) {
    allSongs = List<Song>.from(songs);
    queue = List<Song>.from(songs);
    _originalQueue = List<Song>.from(songs);
    notifyListeners();
  }

  /// Toggles a song's favorite status in the cache index and favorite playlist.
  Future<void> toggleFavorite(int songId) async {
    var scanner = MusicScanner();
    var updatedSongs = await scanner.toggleFavoriteSong(songId);
    
    // Update local state arrays keeping references
    allSongs = List<Song>.from(updatedSongs);
    
    // Update queue songs matching songId
    for (var i = 0; i < queue.length; i++) {
      if (queue[i].id == songId) {
        var song = queue[i];
        queue[i] = Song(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          duration: song.duration,
          filePath: song.filePath,
          artworkPath: song.artworkPath,
          format: song.format,
          bitrate: song.bitrate,
          samplerate: song.samplerate,
          isFavorite: !song.isFavorite,
        );
      }
    }
    
    // Update original queue matching songId
    for (var i = 0; i < _originalQueue.length; i++) {
      if (_originalQueue[i].id == songId) {
        var song = _originalQueue[i];
        _originalQueue[i] = Song(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          duration: song.duration,
          filePath: song.filePath,
          artworkPath: song.artworkPath,
          format: song.format,
          bitrate: song.bitrate,
          samplerate: song.samplerate,
          isFavorite: !song.isFavorite,
        );
      }
    }

    notifyListeners();
  }

  /// Converts a [Song] to a [MediaItem] for the audio handler.
  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: Uri.file(song.filePath).toString(),
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: song.artworkPath != null ? Uri.file(song.artworkPath!) : null,
    );
  }

  /// Listens to changes in the currently active [MediaItem] to keep
  /// [currentIndex] synchronised with the audio handler.
  void _listenToMediaItem() {
    _mediaItemSub = audioHandler.mediaItem.listen((item) {
      if (item == null) return;

      var index = queue.indexWhere(
        (s) => Uri.file(s.filePath).toString() == item.id,
      );
      if (index >= 0 && index != currentIndex) {
        currentIndex = index;
        notifyListeners();
      }
    });
  }

  /// Listens to playback state changes so the UI stays in sync.
  void _listenToPlaybackState() {
    _playbackStateSub = audioHandler.playbackState.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _mediaItemSub?.cancel();
    _playbackStateSub?.cancel();
    super.dispose();
  }
}
