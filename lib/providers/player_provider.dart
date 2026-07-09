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
  Future<void> playSong(Song song, List<Song> songList, {bool resetShuffle = true}) async {
    queue = List<Song>.from(songList);
    _originalQueue = List<Song>.from(songList);
    if (resetShuffle) {
      isShuffled = false;
    }

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

  /// Stops playback, clears the queue, and resets the active song index.
  Future<void> stop() async {
    await audioHandler.stop();
    queue = [];
    _originalQueue = [];
    currentIndex = -1;
    notifyListeners();
  }

  /// Seeks to [position] within the current track.
  Future<void> seek(Duration position) async {
    await audioHandler.seek(position);
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  /// Toggles shuffle mode on/off.
  ///
  /// Shuffles only the tracks after the currently playing song in the queue,
  /// preserving seamless active track playback. Restores original order after
  /// the current track when disabled.
  Future<void> toggleShuffle() async {
    if (currentSong == null) return;
    var current = currentSong!;

    if (isShuffled) {
      // Restore original order after current index.
      var origIndex = _originalQueue.indexWhere((s) => s.id == current.id);
      if (origIndex >= 0) {
        var newQueue = <Song>[];
        // Keep current song at its current index
        newQueue.addAll(queue.sublist(0, currentIndex + 1));
        
        // Find which songs from original queue are not yet in newQueue
        var remainingOriginal = _originalQueue.where((s) => !newQueue.any((nq) => nq.id == s.id)).toList();
        newQueue.addAll(remainingOriginal);
        
        queue = newQueue;
      }
      isShuffled = false;
    } else {
      // Shuffle only the songs after the current index.
      var remaining = queue.sublist(currentIndex + 1);
      remaining.shuffle();
      
      var newQueue = <Song>[];
      newQueue.addAll(queue.sublist(0, currentIndex + 1));
      newQueue.addAll(remaining);
      
      queue = newQueue;
      isShuffled = true;
    }

    // Update the audio handler's playlist source after current index
    var remainingMediaItems = queue.sublist(currentIndex + 1).map(_songToMediaItem).toList();
    await audioHandler.updatePlaylistAfter(currentIndex, remainingMediaItems);

    notifyListeners();
  }

  /// Plays a list of songs shuffled, picking a random track to start, and sets shuffle mode to enabled.
  Future<void> quickShuffle(List<Song> songsList) async {
    if (songsList.isEmpty) return;

    // Clone the list and shuffle it
    var shuffled = List<Song>.from(songsList)..shuffle();
    
    // Pick the first shuffled song as the starting track
    var startingSong = shuffled.first;

    // Force isShuffled to true immediately
    isShuffled = true;
    notifyListeners();

    // Load and play the playlist without resetting shuffle status
    await playSong(startingSong, shuffled, resetShuffle: false);
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
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= queue.length) return;

    queue.removeAt(index);
    await audioHandler.removeQueueItemAt(index);

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

  /// Reorders a song in the queue from [oldIndex] to [newIndex].
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex >= queue.length) return;

    var song = queue.removeAt(oldIndex);
    queue.insert(newIndex, song);
    await audioHandler.moveQueueItem(oldIndex, newIndex);

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
  Future<void> addToQueue(Song song) async {
    queue.add(song);
    await audioHandler.addQueueItem(_songToMediaItem(song));
    notifyListeners();
  }

  /// Inserts [song] immediately after the currently playing song.
  Future<void> playNext(Song song) async {
    var insertIndex = currentIndex + 1;
    if (insertIndex >= queue.length) {
      queue.add(song);
    } else {
      queue.insert(insertIndex, song);
    }
    await audioHandler.insertQueueItemAt(insertIndex, _songToMediaItem(song));
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
          lastModifiedMs: song.lastModifiedMs,
          fileSize: song.fileSize,
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
          lastModifiedMs: song.lastModifiedMs,
          fileSize: song.fileSize,
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
