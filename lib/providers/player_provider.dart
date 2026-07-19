import 'dart:async';
import 'dart:io' show Platform;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/services/stats_service.dart';
import 'package:sonora/theme/app_theme.dart';
import 'package:sonora/utils/color_extractor.dart';

/// Repeat mode for playlist playback.
enum RepeatMode { off, all, one }

/// Central application state for the music player.
///
/// Manages the current queue, playback controls, shuffle/repeat state, and
/// synchronises with the underlying [SonoraAudioHandler].
class PlayerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final SonoraAudioHandler audioHandler;

  // ── State fields ──────────────────────────────────────────────────────────

  var uniqueThemeCount = 0;
  List<Song> allSongs = [];
  List<Song> queue = [];
  List<Playlist> playlists = [];
  List<AlbumGroup> cachedAlbums = [];
  List<ArtistGroup> cachedArtists = [];
  List<Song> _originalQueue = [];
  var currentIndex = -1;
  var isShuffled = false;
  RepeatMode repeatMode = RepeatMode.off;
  var _isExtractingColors = false;
  bool get isExtractingColors => _isExtractingColors;

  // Phase 3 State properties
  var useDynamicTheme = true;
  var dynamicThemeColor = const Color(0xFF7C4DFF);
  var showVisualizer = false;
  var immersiveMode = false;

  // Sort preferences (loaded eagerly before HomeScreen mounts)
  var songSortBy = 'title';
  var songSortAscending = true;
  var albumSortBy = 'name';
  var albumSortAscending = true;
  var artistSortBy = 'name';
  var artistSortAscending = true;
  var playlistSortBy = 'name';
  var playlistSortAscending = true;

  var _volume = 1.0;
  Timer? _sleepTimer;
  Duration? sleepTimerDuration;
  Duration? sleepTimerOriginalDuration;
  var sleepTimerDefaultMinutes = 5;
  var _isFadingOut = false;
  var _originalVolumeBeforeFade = 1.0;
  var _lastExtractedSongId = -1;
  var _playRequestToken = 0;
  Timer? _statsTimer;
  String? _playlistContext;
  final statsService = StatsService();

  /// Decouples dynamic theme color changes from general playback state
  /// notifications. Only fires when the seed color actually changes.
  final themeColorNotifier = ValueNotifier<Color>(const Color(0xFF7C4DFF));

  // ── Stream subscriptions ──────────────────────────────────────────────────

  StreamSubscription<MediaItem?>? _mediaItemSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<ProcessingState>? _processingSub;

  // ── Constructor ───────────────────────────────────────────────────────────

  PlayerProvider({required this.audioHandler}) {
    _volume = Platform.isWindows ? 0.1 : 1.0;
    _listenToMediaItem();
    _listenToPlaybackState();
    _initCustomCallbacks();
    loadSettings();
    statsService.ensureLoaded();
    WidgetsBinding.instance.addObserver(this);
  }

  // ── Volume ────────────────────────────────────────────────────────────────

  double get volume => _volume;

  Future<void> setVolume(double value) async {
    _volume = (value.clamp(0.0, 1.0) * 100).round() / 100;
    await audioHandler.player.setVolume(_volume);
    var prefs = SharedPreferencesAsync();
    await prefs.setDouble('volume', _volume);
    notifyListeners();
  }

  void _initCustomCallbacks() {
    audioHandler.onCustomAction = (action) {
      if (action == 'extendSleepTimer') {
        extendSleepTimer(const Duration(minutes: 1));
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

  /// Whether the playback has completed its queue.
  bool get isCompleted =>
      audioHandler.player.processingState == ProcessingState.completed;

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
  Future<void> playSong(Song song, List<Song> songList, {String? playlistId}) async {
    _playlistContext = playlistId;
    await _loadAndPlay(
      song: song,
      songList: songList,
      originalQueue: songList,
      shuffled: false,
    );
  }

  /// Toggles between play and pause.
  Future<void> playPause() async {
    if (isPlaying) {
      await audioHandler.pause();
    } else {
      if (isCompleted && queue.isNotEmpty) {
        await audioHandler.skipToQueueItem(0);
      }
      await audioHandler.play();
    }
  }

  /// Skips to the next track in the queue.
  Future<void> next() async {
    if (currentSong != null) {
      statsService.recordSongSkip(currentSong!.id);
    }
    await audioHandler.skipToNext();
  }

  /// Skips to the previous track in the queue.
  Future<void> previous() async {
    if (audioHandler.player.position > const Duration(seconds: 3)) {
      if (currentSong != null) {
        statsService.recordSongRestart(currentSong!.id);
      }
    }
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

    notifyListeners();

    // Update the audio handler's playlist source after current index
    var remainingMediaItems = queue
        .sublist(currentIndex + 1)
        .map(_songToMediaItem)
        .toList();
    try {
      await audioHandler.updatePlaylistAfter(currentIndex, remainingMediaItems);
    } on PlayerInterruptedException {
      await audioHandler.loadPlaylist(
        queue.map(_songToMediaItem).toList(),
        initialIndex: currentIndex,
      );
      if (isPlaying) {
        await audioHandler.play();
      }
    }

    notifyListeners();
  }

  /// Plays a list of songs shuffled, picking a random track to start, and sets shuffle mode to enabled.
  Future<void> quickShuffle(List<Song> songsList, {String? playlistId}) async {
    if (songsList.isEmpty) return;

    _playlistContext = playlistId;

    // Clone the list and shuffle it
    var shuffled = List<Song>.from(songsList)..shuffle();

    // Pick the first shuffled song as the starting track
    var startingSong = shuffled.first;

    statsService.recordShuffleSessionStart();

    await _loadAndPlay(
      song: startingSong,
      songList: shuffled,
      originalQueue: songsList,
      shuffled: true,
    );
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

  Future<void> _loadAndPlay({
    required Song song,
    required List<Song> songList,
    required List<Song> originalQueue,
    required bool shuffled,
  }) async {
    var requestToken = ++_playRequestToken;

    queue = List<Song>.from(songList);
    _originalQueue = List<Song>.from(originalQueue);
    isShuffled = shuffled;

    var index = queue.indexWhere((s) => s.id == song.id);
    currentIndex = index >= 0 ? index : 0;

    notifyListeners();

    var mediaItems = queue.map(_songToMediaItem).toList();
    try {
      await audioHandler.loadPlaylist(mediaItems, initialIndex: currentIndex);
      if (requestToken != _playRequestToken) return;

      await audioHandler.play();
      if (requestToken != _playRequestToken) return;
    } on PlayerInterruptedException {
      if (requestToken != _playRequestToken) return;
      rethrow;
    }

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
  ///
  /// If a song is currently playing, the active queue is preserved and only
  /// [allSongs] is refreshed. The audio handler's internal playlist is patched
  /// in-place so that [skipToQueueItem] always lands on the correct track even
  /// after a resync that may have changed library metadata.
  void updateSongs(List<Song> songs) {
    allSongs = List<Song>.from(songs);
    _refreshLibrarySnapshots();
    if (currentIndex < 0 || queue.isEmpty) {
      // Nothing playing — replace queue entirely.
      queue = List<Song>.from(songs);
      _originalQueue = List<Song>.from(songs);
    } else {
      // A song is playing — keep the queue intact but refresh the audio
      // handler's raw playlist metadata so index-based skips stay correct.
      audioHandler.syncQueueMetadata(queue.map(_songToMediaItem).toList());
    }
    notifyListeners();
    _startBackgroundColorExtraction();

    // Purge stale stats entries for songs that no longer exist in the library
    statsService.syncWithLibrary(allSongs.map((s) => s.id).toSet());
  }

  void _refreshLibrarySnapshots() {
    cachedAlbums = buildAlbumGroups(allSongs);
    cachedArtists = buildArtistGroups(allSongs, cachedAlbums);
    uniqueThemeCount = AppTheme.precomputeThemes(allSongs);
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
    allSongs = List<Song>.from(updatedSongs);
    _refreshLibrarySnapshots();

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
        if (_lastExtractedSongId != queue[index].id) {
          _extractThemeColorForSong(queue[index]);
        }
        if (index != currentIndex) {
          currentIndex = index;
          notifyListeners();
        }
      }
    });
  }

  /// Listens to playback state changes so the UI stays in sync.
  /// Subscribes to playing and processing state separately (not position)
  /// to avoid notifying listeners on every position update (~5/sec).
  /// Also tracks listening time via a periodic timer while playing and
  /// records completed songs via the processing state.
  void _listenToPlaybackState() {
    _playingSub = audioHandler.player.playingStream.listen((isPlaying) {
      notifyListeners();
      if (isPlaying) {
        _statsTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
          var song = currentSong;
          if (song != null && song.duration.inMilliseconds > 0) {
            statsService.addListeningTime(
              1000,
              song.id,
              song.duration.inMilliseconds,
              playlistId: _playlistContext,
            );
          }
        });
      } else {
        _statsTimer?.cancel();
        _statsTimer = null;
      }
    });
    _processingSub = audioHandler.player.processingStateStream.listen((state) {
      notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      statsService.flush();
    }
  }

  @override
  void dispose() {
    _isExtractingColors = false;
    stopSleepTimer();
    _mediaItemSub?.cancel();
    _playingSub?.cancel();
    _processingSub?.cancel();
    _statsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    themeColorNotifier.dispose();
    statsService.flush();
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
    immersiveMode = await prefs.getBool('now_playing_immersive_mode') ?? false;
    sleepTimerDefaultMinutes =
        await prefs.getInt('sleep_timer_default_minutes') ?? 5;
    _volume = await prefs.getDouble('volume') ?? _volume;
    audioHandler.player.setVolume(_volume);

    if (useDynamicTheme && currentSong != null) {
      _extractThemeColorForSong(currentSong!);
    }
    notifyListeners();
  }

  Future<void> loadSortSettings() async {
    var scanner = MusicScanner();
    var songs = await scanner.getTabSortSettings('songs');
    var albums = await scanner.getTabSortSettings('albums');
    var artists = await scanner.getTabSortSettings('artists');
    var playlists = await scanner.getTabSortSettings('playlists');
    songSortBy = songs['sortBy'] as String;
    songSortAscending = songs['sortAscending'] as bool;
    albumSortBy = albums['sortBy'] as String;
    albumSortAscending = albums['sortAscending'] as bool;
    artistSortBy = artists['sortBy'] as String;
    artistSortAscending = artists['sortAscending'] as bool;
    playlistSortBy = playlists['sortBy'] as String;
    playlistSortAscending = playlists['sortAscending'] as bool;
  }

  Future<void> toggleDynamicTheme(bool enabled) async {
    useDynamicTheme = enabled;
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('use_dynamic_theme', enabled);

    if (enabled && currentSong != null) {
      _extractThemeColorForSong(currentSong!);
    } else {
      var defaultColor = const Color(0xFF7C4DFF);
      if (dynamicThemeColor != defaultColor) {
        dynamicThemeColor = defaultColor;
        themeColorNotifier.value = defaultColor;
      }
    }
    notifyListeners();
  }

  Future<void> toggleVisualizer(bool enabled) async {
    showVisualizer = enabled;
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('show_visualizer', enabled);
    notifyListeners();
  }

  Future<void> toggleImmersiveMode(bool enabled) async {
    immersiveMode = enabled;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('now_playing_immersive_mode', enabled);
  }

  Future<void> setSleepTimerDefaultMinutes(int minutes) async {
    sleepTimerDefaultMinutes = minutes.clamp(1, 60);
    var prefs = SharedPreferencesAsync();
    await prefs.setInt('sleep_timer_default_minutes', sleepTimerDefaultMinutes);
    notifyListeners();
  }

  Future<void> _extractThemeColorForSong(Song song) async {
    if (!useDynamicTheme) {
      _applyThemeColor(const Color(0xFF7C4DFF));
      return;
    }
    _lastExtractedSongId = song.id;

    if (song.artworkPath == null) {
      _applyThemeColor(const Color(0xFF7C4DFF));
      return;
    }

    // Use cached dominant color if available — avoids artwork I/O entirely.
    if (song.dominantColor != null) {
      _applyThemeColor(Color(song.dominantColor!));
      return;
    }

    var color = await ColorExtractor.extractDominantColor(song.artworkPath!);
    var newColor = color ?? const Color(0xFF7C4DFF);
    _applyThemeColor(newColor);

    // Cache the extracted color for future plays.
    if (color != null) {
      var songColor = color.toARGB32();
      _cacheDominantColor(song.id, songColor);
    }
  }

  void _applyThemeColor(Color color) {
    if (dynamicThemeColor == color) return;
    dynamicThemeColor = color;
    themeColorNotifier.value = color;
  }

  void _cacheDominantColorInMemory(int songId, int color) {
    for (var i = 0; i < allSongs.length; i++) {
      if (allSongs[i].id == songId) {
        allSongs[i] = allSongs[i].copyWith(dominantColor: color);
        break;
      }
    }
    for (var i = 0; i < queue.length; i++) {
      if (queue[i].id == songId) {
        queue[i] = queue[i].copyWith(dominantColor: color);
        break;
      }
    }
    for (var i = 0; i < _originalQueue.length; i++) {
      if (_originalQueue[i].id == songId) {
        _originalQueue[i] = _originalQueue[i].copyWith(dominantColor: color);
        break;
      }
    }
  }

  void _cacheDominantColor(int songId, int color) {
    _cacheDominantColorInMemory(songId, color);
    _refreshLibrarySnapshots();
    // Persist so the cache survives app restarts.
    MusicScanner().saveDominantColor(songId, color);
  }

  void _startBackgroundColorExtraction() {
    if (_isExtractingColors) return;
    _isExtractingColors = true;

    Future(() async {
      var songsToProcess = allSongs
          .where((s) => s.artworkPath != null && s.dominantColor == null)
          .toList();

      var processedCount = 0;
      var dirty = false;

      for (var song in songsToProcess) {
        if (!_isExtractingColors) break;

        try {
          var color = await ColorExtractor.extractDominantColor(
            song.artworkPath!,
          );
          if (color != null) {
            var songColor = color.toARGB32();
            _cacheDominantColorInMemory(song.id, songColor);
            processedCount++;
            dirty = true;

            // Notify UI and refresh snapshots in batches of 20 to keep UI 100% fluid
            if (processedCount % 20 == 0) {
              _refreshLibrarySnapshots();
              notifyListeners();
              // Bulk save current progress to disk in a single write operation
              await MusicScanner().saveAllSongsMetadata(allSongs);
              dirty = false;
            }
          }
        } catch (_) {}

        // 50ms stagger yields control to event loop to guarantee 0% layout lag
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (dirty) {
        _refreshLibrarySnapshots();
        await MusicScanner().saveAllSongsMetadata(allSongs);
      }
      notifyListeners();
      _isExtractingColors = false;
    });
  }

  void _updateMediaNotificationControls() {
    audioHandler.updateSleepTimerState(
      active: sleepTimerDuration != null,
      label: '+1 min',
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
        await audioHandler.player.setVolume(_volume);

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
