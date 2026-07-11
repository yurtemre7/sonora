import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/utils/color_extractor.dart';

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
  List<Playlist> playlists = [];
  List<Song> _originalQueue = [];
  var currentIndex = -1;
  var isShuffled = false;
  RepeatMode repeatMode = RepeatMode.off;

  // Phase 3 State properties
  var useDynamicTheme = true;
  var dynamicThemeColor = const Color(0xFF7C4DFF);
  var showVisualizer = false;

  Timer? _sleepTimer;
  Duration? sleepTimerDuration;
  Duration? sleepTimerOriginalDuration;
  var sleepTimerExtendMinutes = 5;
  var _isFadingOut = false;
  var _originalVolumeBeforeFade = 1.0;
  var _lastExtractedSongId = -1;

  // ── Stream subscriptions ──────────────────────────────────────────────────

  StreamSubscription<MediaItem?>? _mediaItemSub;
  StreamSubscription<PlaybackState>? _playbackStateSub;

  // ── Constructor ───────────────────────────────────────────────────────────

  PlayerProvider({required this.audioHandler}) {
    _listenToMediaItem();
    _listenToPlaybackState();
    _initCustomCallbacks();
    loadSettings();
  }

  void _initCustomCallbacks() {
    audioHandler.onCustomAction = (action) {
      if (action == 'extendSleepTimer') {
        extendSleepTimer(Duration(minutes: sleepTimerExtendMinutes));
      }
    };
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
        var remainingOriginal = _originalQueue
            .where((s) => !newQueue.any((nq) => nq.id == s.id))
            .toList();
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
    var remainingMediaItems = queue
        .sublist(currentIndex + 1)
        .map(_songToMediaItem)
        .toList();
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

    // Load and play the shuffled playlist. playSong resets isShuffled to false,
    // so we set it to true afterward.
    await playSong(startingSong, shuffled);
    _originalQueue = List<Song>.from(
      songsList,
    ); // Preserve original order for unshuffling!
    isShuffled = true;
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
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= queue.length) return;

    var removedId = queue[index].id;
    queue.removeAt(index);
    _originalQueue.removeWhere((s) => s.id == removedId);
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

    // Find the updated song from scanner result
    var updatedSong = updatedSongs.where((s) => s.id == songId).firstOrNull;

    allSongs = List<Song>.from(updatedSongs);

    if (updatedSong != null) {
      // Update queue with the exact song from scanner
      for (var i = 0; i < queue.length; i++) {
        if (queue[i].id == songId) {
          queue[i] = updatedSong;
        }
      }

      // Update original queue
      for (var i = 0; i < _originalQueue.length; i++) {
        if (_originalQueue[i].id == songId) {
          _originalQueue[i] = updatedSong;
        }
      }
    }

    // Refresh the playlists list so that the Favorites count and item inclusions are in sync!
    playlists = await scanner.getPlaylists();

    notifyListeners();
  }

  /// Converts a [Song] to a [MediaItem] for the audio handler.
  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: Uri.file(song.filePath).toString(),
      title: song.displayTitle,
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
      if (index >= 0) {
        var oldIndex = currentIndex;
        currentIndex = index;
        if (oldIndex != index || _lastExtractedSongId != queue[index].id) {
          _extractThemeColorForSong(queue[index]);
        }
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

  // ── Playlist management APIs ────────────────────────────────────────────────

  void updatePlaylists(List<Playlist> newPlaylists) {
    playlists = List<Playlist>.from(newPlaylists);
    notifyListeners();
  }

  Future<void> loadPlaylists() async {
    var scanner = MusicScanner();
    playlists = await scanner.getPlaylists();
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    var scanner = MusicScanner();
    await scanner.createPlaylist(name);
    await loadPlaylists();
  }

  Future<void> deletePlaylist(String id) async {
    var scanner = MusicScanner();
    await scanner.deletePlaylist(id);
    await loadPlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, int songId) async {
    var scanner = MusicScanner();
    await scanner.addSongToPlaylist(playlistId, songId);
    await loadPlaylists();
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    var scanner = MusicScanner();
    await scanner.removeSongFromPlaylist(playlistId, songId);
    await loadPlaylists();
  }

  Future<void> reorderPlaylistSongs(
    String playlistId,
    List<int> reorderedIds,
  ) async {
    var scanner = MusicScanner();
    var list = await scanner.getPlaylists();
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == playlistId) {
        list[i] = Playlist(
          id: list[i].id,
          name: list[i].name,
          songIds: reorderedIds,
        );
        break;
      }
    }
    await scanner.savePlaylists(list);
    playlists = list;
    notifyListeners();
  }

  // ── Phase 3: Dynamic Theme, Visualizer & Sleep Timer Actions ────────────────

  Future<void> loadSettings() async {
    var prefs = SharedPreferencesAsync();
    useDynamicTheme = await prefs.getBool('use_dynamic_theme') ?? true;
    showVisualizer = await prefs.getBool('show_visualizer') ?? false;
    sleepTimerExtendMinutes =
        await prefs.getInt('sleep_timer_extend_minutes') ?? 5;

    if (useDynamicTheme && currentSong != null) {
      _extractThemeColorForSong(currentSong!);
    }
    notifyListeners();
  }

  Future<void> toggleDynamicTheme(bool enabled) async {
    useDynamicTheme = enabled;
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('use_dynamic_theme', enabled);

    if (enabled && currentSong != null) {
      _extractThemeColorForSong(currentSong!);
    } else {
      dynamicThemeColor = const Color(0xFF7C4DFF);
    }
    notifyListeners();
  }

  Future<void> toggleVisualizer(bool enabled) async {
    showVisualizer = enabled;
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('show_visualizer', enabled);
    notifyListeners();
  }

  Future<void> setSleepTimerExtendMinutes(int minutes) async {
    sleepTimerExtendMinutes = minutes.clamp(1, 30);
    var prefs = SharedPreferencesAsync();
    await prefs.setInt('sleep_timer_extend_minutes', sleepTimerExtendMinutes);
    _updateMediaNotificationControls();
    notifyListeners();
  }

  Future<void> _extractThemeColorForSong(Song song) async {
    if (!useDynamicTheme) {
      dynamicThemeColor = const Color(0xFF7C4DFF);
      notifyListeners();
      return;
    }
    _lastExtractedSongId = song.id;

    if (song.artworkPath == null) {
      dynamicThemeColor = const Color(0xFF7C4DFF);
      notifyListeners();
      return;
    }

    var color = await ColorExtractor.extractDominantColor(song.artworkPath!);
    if (color != null) {
      dynamicThemeColor = color;
    } else {
      dynamicThemeColor = const Color(0xFF7C4DFF);
    }
    notifyListeners();
  }

  void _updateMediaNotificationControls() {
    audioHandler.updateSleepTimerState(
      active: sleepTimerDuration != null,
      label: '+$sleepTimerExtendMinutes min',
    );
  }

  void startSleepTimer(Duration duration) {
    stopSleepTimer();

    sleepTimerOriginalDuration = duration;
    sleepTimerDuration = duration;
    _isFadingOut = false;

    _updateMediaNotificationControls();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (sleepTimerDuration == null) {
        timer.cancel();
        return;
      }

      var remaining = sleepTimerDuration! - const Duration(seconds: 1);
      if (remaining.isNegative || remaining == Duration.zero) {
        sleepTimerDuration = Duration.zero;
        timer.cancel();
        _sleepTimer = null;

        await audioHandler.stop();
        await audioHandler.player.setVolume(1.0);

        sleepTimerDuration = null;
        sleepTimerOriginalDuration = null;
        _isFadingOut = false;

        queue = [];
        _originalQueue = [];
        currentIndex = -1;

        _updateMediaNotificationControls();
        notifyListeners();
      } else {
        sleepTimerDuration = remaining;

        if (remaining.inSeconds <= 10) {
          if (!_isFadingOut) {
            _isFadingOut = true;
            _originalVolumeBeforeFade = audioHandler.player.volume;
          }
          var fraction = remaining.inSeconds / 10.0;
          await audioHandler.player.setVolume(
            _originalVolumeBeforeFade * fraction,
          );
        }

        notifyListeners();
      }
    });

    notifyListeners();
  }

  void stopSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepTimerDuration = null;
    sleepTimerOriginalDuration = null;
    if (_isFadingOut) {
      audioHandler.player.setVolume(_originalVolumeBeforeFade);
      _isFadingOut = false;
    }
    _updateMediaNotificationControls();
    notifyListeners();
  }

  void extendSleepTimer(Duration extension) {
    if (sleepTimerDuration == null) {
      startSleepTimer(extension);
      return;
    }
    sleepTimerDuration = sleepTimerDuration! + extension;
    sleepTimerOriginalDuration =
        (sleepTimerOriginalDuration ?? Duration.zero) + extension;
    if (_isFadingOut) {
      _isFadingOut = false;
      audioHandler.player.setVolume(_originalVolumeBeforeFade);
    }
    _updateMediaNotificationControls();
    notifyListeners();
  }
}
