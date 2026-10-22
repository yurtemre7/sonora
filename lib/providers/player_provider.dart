import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/mfx_preset.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/models/song_activity.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/image_preflight_service.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/services/position_ticker.dart';
import 'package:sonora/services/sleep_timer_notification_service.dart';
import 'package:sonora/services/stats_service.dart';
import 'package:sonora/theme/app_theme.dart';
import 'package:sonora/utils/color_extractor.dart';

part 'player_mfx.dart';
part 'player_queue.dart';
part 'player_library.dart';
part 'player_persistence.dart';
part 'player_theme.dart';
part 'player_sleep_timer.dart';

/// Repeat mode for playlist playback.
enum RepeatMode { off, all, one }

/// Central application state for the music player.
///
/// Manages the current queue, playback controls, shuffle/repeat state, and
/// synchronises with the underlying [SonoraAudioHandler].
class PlayerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final SonoraAudioHandler audioHandler;
  final SettingsProvider settingsProvider;

  // ── State fields ──────────────────────────────────────────────────────────
  Map<String, int> favoriteAlbums = {};
  Map<String, int> favoriteArtists = {};

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
  var _hasRestoredLastPlayed = false;
  var _isExtractingColors = false;
  bool get isExtractingColors => _isExtractingColors;

  var _volume = 1.0;
  var _speed = 1.0;

  // Experimental MFX
  MfxPreset? _mfxPreset;
  var _isSlowed = false;
  var _isSuperSlowed = false;
  var _isNightcore = false;
  var _isSpedUp = false;
  var _isSuperSpedUp = false;
  var _isReverbEnabled = false;
  var _isLofiEnabled = false;
  var _isBassBoostEnabled = false;
  var _isCustomEqEnabled = false;
  var _isBluetoothMfxPatchEnabled = false;
  List<double>? _customEqGains;
  Timer? _sleepTimer;
  Duration? sleepTimerDuration;
  Duration? sleepTimerOriginalDuration;
  var _isFadingOut = false;
  var _originalVolumeBeforeFade = 1.0;
  var _lastExtractedSongId = -1;
  var defaultThemeColor = const Color(0xFF7C4DFF);
  var _playRequestToken = 0;
  String? _playlistContext;
  final statsService = StatsService();

  /// One-shot timer armed for the next listen milestone of the current
  /// playthrough. No periodic work runs for stats while music plays.
  Timer? _listenTimer;
  int? _listenSongId;
  var _recentRecorded = false;
  var _listenCounted = false;

  /// Decouples dynamic theme color changes from general playback state
  /// notifications. Only fires when the seed color actually changes.
  final themeColorNotifier = ValueNotifier<Color>(const Color(0xFF7C4DFF));

  // Sleep timer
  var sleepTimerFinishSongActive = false;
  var _isFinishingCurrentSong = false;
  int? _finishSongTargetSongId;
  Timer? _finishSongTimer;

  // Artwork that produced no usable theme color
  Set<String>? _colorlessArtwork;

  // ── Stream subscriptions ──────────────────────────────────────────────────

  StreamSubscription<MediaItem?>? _mediaItemSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<ProcessingState>? _processingSub;
  StreamSubscription<PositionDiscontinuity>? _discontinuitySub;
  StreamSubscription<double>? _speedSub;

  // ── Constructor ───────────────────────────────────────────────────────────

  PlayerProvider({required this.audioHandler, required this.settingsProvider}) {
    _volume = Platform.isWindows ? 0.1 : 1.0;
    _listenToMediaItem();
    _listenToPlaybackState();
    _initCustomCallbacks();
    loadSettings();
    statsService.ensureLoaded();
    WidgetsBinding.instance.addObserver(this);
  }

  void _initCustomCallbacks() {
    audioHandler.onCustomAction = (action) {
      if (action == 'extendSleepTimer') {
        extendSleepTimer(const Duration(minutes: 1));
      } else if (action == 'stopSleepTimer') {
        stopSleepTimer();
      } else if (action == 'closePlayer') {
        queue = [];
        _originalQueue = [];
        currentIndex = -1;
        _playlistContext = null;
        _resetListenSession();
        unawaited(_clearLastPlayedState());
        notifyListeners();
      }
    };
    SleepTimerNotificationService.onAddOneMin = () {
      extendSleepTimer(const Duration(minutes: 1));
    };
    SleepTimerNotificationService.onEndTimer = () {
      stopSleepTimer();
    };

    // Android Auto: bridge media browser playback requests to PlayerProvider.
    audioHandler.onPlayFromBrowser = (mediaItems, startIndex) {
      // Resolve MediaItems back to Song objects from the library.
      var songs = <Song>[];
      for (var item in mediaItems) {
        var song = allSongs
            .where((s) => Uri.file(s.filePath).toString() == item.id)
            .firstOrNull;
        if (song != null) songs.add(song);
      }
      if (songs.isEmpty) return;

      var targetIndex = startIndex.clamp(0, songs.length - 1);
      playSong(songs[targetIndex], songs);
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

  late final _positionTicker = PositionTicker(
    position: () => audioHandler.player.position,
    isPlaying: () => audioHandler.player.playing,
    playerEvents: audioHandler.player.playerEventStream,
    discontinuities: audioHandler.player.positionDiscontinuityStream,
    foreground: _isAppVisible(WidgetsBinding.instance.lifecycleState),
  );

  /// Current playback position stream, shared by every widget. Ticks every
  /// 200ms while playing and stops entirely while the app is in the
  /// background, so no UI work wakes the CPU when nobody can see it.
  Stream<Duration> get positionStream => _positionTicker.stream;

  static bool _isAppVisible(AppLifecycleState? state) =>
      state != AppLifecycleState.hidden &&
      state != AppLifecycleState.paused &&
      state != AppLifecycleState.detached;

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
  Future<void> playSong(
    Song song,
    List<Song> songList, {
    String? playlistId,
  }) async {
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
    if (isCompleted && queue.isNotEmpty) {
      await audioHandler.skipToQueueItem(0);
      await audioHandler.play();
    } else if (isPlaying) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  /// Skips to the next track in the queue.
  Future<void> next() async {
    if (currentIndex < queue.length - 1) {
      if (currentSong != null) {
        statsService.recordSongSkip(currentSong!.id);
      }
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
    _resetListenSession();
    await _clearLastPlayedState();
    notifyListeners();
  }

  /// Seeks to [position] within the current track.
  Future<void> seek(Duration position) async {
    if (position < const Duration(seconds: 3) &&
        audioHandler.player.position > const Duration(seconds: 3)) {
      if (currentSong != null) {
        statsService.recordSongRestart(currentSong!.id);
      }
    }
    await audioHandler.seek(position);
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
        if (_listenSongId != queue[index].id) {
          _resetListenSession(queue[index].id);
          _armListenTimer();
        }
        if (_lastExtractedSongId != queue[index].id) {
          _extractThemeColorForSong(queue[index]);
          // Re-apply MFX when a new track loads to ensure AndroidEqualizer and speed persist securely across tracks
          _applyMfx();
        }
        if (index != currentIndex) {
          currentIndex = index;
          notifyListeners();
        }
        _saveLastPlayedState();
      }
    });
  }

  /// Listens to playback state changes so the UI stays in sync.
  /// Subscribes to playing and processing state separately (not position)
  /// to avoid notifying listeners on every position update.
  /// Listen stats are driven by one-shot timers re-armed only on events
  /// (play/pause, seek, loop, speed change), never by polling.
  void _listenToPlaybackState() {
    var player = audioHandler.player;
    _playingSub = player.playingStream.listen((isPlaying) {
      notifyListeners();
      _saveLastPlayedState();
      _armListenTimer();
    });
    _processingSub = player.processingStateStream.listen((state) {
      notifyListeners();
    });
    _discontinuitySub = player.positionDiscontinuityStream.listen((event) {
      if (event.reason == PositionDiscontinuityReason.autoAdvance) {
        // Next track or a repeat-one loop: a fresh playthrough begins.
        _resetListenSession();
      } else if (player.position < const Duration(seconds: 3)) {
        // Seeking back to the start counts as listening again.
        _resetListenSession(_listenSongId);
      }
      _armListenTimer();
    });
    _speedSub = player.speedStream.listen((_) => _armListenTimer());
  }

  void _resetListenSession([int? songId]) {
    _listenTimer?.cancel();
    _listenTimer = null;
    _listenSongId = songId;
    _recentRecorded = false;
    _listenCounted = false;
  }

  /// The position that counts a song as completely listened.
  static Duration _completeListenThreshold(Duration songDuration) =>
      songDuration * 0.8;

  /// Schedules a single wake-up for the earliest pending milestone of this
  /// playthrough: the Recent activity threshold or the 80% complete-listen
  /// mark.
  void _armListenTimer() {
    _listenTimer?.cancel();
    _listenTimer = null;

    var player = audioHandler.player;
    var song = currentSong;
    if (song == null || !player.playing || song.duration <= Duration.zero) {
      return;
    }
    if (_listenSongId != song.id) _resetListenSession(song.id);

    var pending = [
      if (!_recentRecorded) qualifyingRecentPlayThreshold(song.duration),
      if (!_listenCounted) _completeListenThreshold(song.duration),
    ];
    if (pending.isEmpty) return;
    var milestone = pending.reduce((a, b) => a < b ? a : b);

    var speed = player.speed > 0 ? player.speed : 1.0;
    var remaining = milestone - player.position;
    var delay = remaining > Duration.zero
        ? remaining * (1 / speed)
        : Duration.zero;
    _listenTimer = Timer(delay, _onListenMilestone);
  }

  void _onListenMilestone() {
    _listenTimer = null;
    var player = audioHandler.player;
    var song = currentSong;
    if (song == null || song.id != _listenSongId || !player.playing) return;

    // Small tolerance for timer/decoder jitter.
    var position = player.position + const Duration(milliseconds: 500);
    if (!_recentRecorded &&
        position >= qualifyingRecentPlayThreshold(song.duration)) {
      _recentRecorded = true;
      statsService.recordSongPlayed(song.id);
    }
    if (!_listenCounted &&
        position >= _completeListenThreshold(song.duration)) {
      _listenCounted = true;
      statsService.recordCompleteListen(song.id, playlistId: _playlistContext);
    }
    _armListenTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _positionTicker.setForeground(_isAppVisible(state));
    if (state == AppLifecycleState.resumed) {
      if (settingsProvider.useMaterialYou) {
        settingsProvider.refreshDynamicWallpaperColor();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      statsService.flush();
      _saveLastPlayedState();
    }
  }

  /// Lets the part-file extensions notify listeners without tripping the
  /// protected-member lint.
  void _notify() => notifyListeners();

  @override
  void dispose() {
    _isExtractingColors = false;
    stopSleepTimer();
    _mediaItemSub?.cancel();
    _playingSub?.cancel();
    _processingSub?.cancel();
    _discontinuitySub?.cancel();
    _speedSub?.cancel();
    _listenTimer?.cancel();
    _positionTicker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    themeColorNotifier.dispose();
    statsService.flush();
    super.dispose();
  }
}
