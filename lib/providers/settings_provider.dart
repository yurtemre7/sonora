import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/music_scanner.dart';

enum ThemeColorSource {
  materialYou,
  albumArt,
  custom,
}

class SettingsProvider extends ChangeNotifier {
  static final instance = SettingsProvider._internal();
  factory SettingsProvider() => instance;
  SettingsProvider._internal();

  var useDynamicTheme = true;
  var useMaterialYou = false;
  Color? dynamicWallpaperColor;
  var amoledDark = false;
  var dynamicThemeColor = const Color(0xFF7C4DFF);
  var ambientGlowIntensity = 'vibrant'; // 'off' | 'subtle' | 'vibrant' | 'immersive'
  var nowPlayingStyle = 'modern'; // 'modern' | 'vinyl' | 'minimalist'
  var showVisualizer = false;
  var immersiveMode = false;
  var preferLocalArtistImages = true;
  var sleepTimerDefaultMinutes = 5;
  var sleepTimerFadeOutSeconds = 10; // 0 (Off), 10, 30, 60
  var sleepTimerFinishSong = false;
  var defaultStartPage = 0;

  var songSortBy = 'title';
  var songSortAscending = true;
  var albumSortBy = 'name';
  var albumSortAscending = true;
  var artistSortBy = 'name';
  var artistSortAscending = true;
  var playlistSortBy = 'name';
  var playlistSortAscending = true;
  var favoritesSortBy = 'date';
  var favoritesSortAscending = false;

  var keepPlayingOnClose = false;
  var restoreLastPlayedSong = true;

  var pauseOnDuck = false;
  var pauseOnDisconnect = true;
  var resumeOnConnect = false;
  var filterTitleFeatures = false;
  var filterTitleArtist = false;
  var userName = 'User';
  var useGreetingTitle = false;
  var autoCheckUpdates = true;
  var appLocale = 'system';
  String? scanFolder;
  String? lastSyncTime;
  int? lastSyncDuration;
  String? lastPerfLog;

  var _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Locale? get currentLocale {
    if (appLocale == 'en') return const Locale('en');
    if (appLocale == 'de') return const Locale('de');
    if (appLocale == 'ja') return const Locale('ja');
    return null; // System default
  }

  Future<void> loadSettings() async {
    var prefs = SharedPreferencesAsync();
    var scanner = MusicScanner();

    appLocale = await prefs.getString('app_locale') ?? 'system';

    useDynamicTheme = await prefs.getBool('use_dynamic_theme') ?? true;
    useMaterialYou = await prefs.getBool('use_material_you') ?? false;
    amoledDark = await prefs.getBool('amoled_dark') ?? false;
    var colorValue = await prefs.getInt('dynamic_theme_color');
    if (colorValue != null) {
      dynamicThemeColor = Color(colorValue);
    }
    ambientGlowIntensity =
        await prefs.getString('ambient_glow_intensity') ?? 'vibrant';
    nowPlayingStyle =
        await prefs.getString('now_playing_style') ?? 'modern';
    showVisualizer = await prefs.getBool('show_visualizer') ?? false;
    immersiveMode = await prefs.getBool('immersive_mode') ?? false;
    preferLocalArtistImages =
        await prefs.getBool('prefer_local_artist_images') ?? true;
    sleepTimerDefaultMinutes =
        await prefs.getInt('sleep_timer_default_minutes') ?? 5;
    sleepTimerFadeOutSeconds =
        await prefs.getInt('sleep_timer_fade_out_seconds') ?? 10;
    sleepTimerFinishSong =
        await prefs.getBool('sleep_timer_finish_song') ?? false;
    defaultStartPage = await prefs.getInt('default_start_page') ?? 0;

    songSortBy = await prefs.getString('song_sort_by') ?? 'title';
    songSortAscending = await prefs.getBool('song_sort_ascending') ?? true;
    albumSortBy = await prefs.getString('album_sort_by') ?? 'name';
    albumSortAscending = await prefs.getBool('album_sort_ascending') ?? true;
    artistSortBy = await prefs.getString('artist_sort_by') ?? 'name';
    artistSortAscending = await prefs.getBool('artist_sort_ascending') ?? true;
    playlistSortBy = await prefs.getString('playlist_sort_by') ?? 'name';
    playlistSortAscending =
        await prefs.getBool('playlist_sort_ascending') ?? true;
    favoritesSortBy = await prefs.getString('favorites_sort_by') ?? 'date';
    favoritesSortAscending =
        await prefs.getBool('favorites_sort_ascending') ?? false;

    keepPlayingOnClose = await prefs.getBool('keep_playing_on_close') ?? false;
    restoreLastPlayedSong =
        await prefs.getBool('restore_last_played_song') ?? true;

    pauseOnDuck = await prefs.getBool('pause_on_duck') ?? false;
    pauseOnDisconnect =
        await prefs.getBool('pause_on_disconnect') ?? true;
    resumeOnConnect = await prefs.getBool('resume_on_connect') ?? false;
    filterTitleFeatures = await prefs.getBool('filter_title_features') ?? false;
    filterTitleArtist = await prefs.getBool('filter_title_artist') ?? false;
    userName = await prefs.getString('user_name') ?? 'User';
    useGreetingTitle = await prefs.getBool('use_greeting_title') ?? false;
    autoCheckUpdates = await prefs.getBool('auto_check_updates') ?? true;

    if (useMaterialYou) {
      dynamicWallpaperColor = await MusicScanner.getDynamicWallpaperColor();
    }

    scanFolder = await scanner.getScanFolder();
    lastSyncTime = await scanner.getLastSyncTime();
    lastSyncDuration = await scanner.getLastSyncDuration('last');

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setPauseOnDisconnect(
    bool value,
    SonoraAudioHandler audioHandler,
  ) async {
    pauseOnDisconnect = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('pause_on_disconnect', value);
    audioHandler.setPauseOnDisconnect(value);
  }

  Future<void> setResumeOnConnect(
    bool value,
    SonoraAudioHandler audioHandler,
  ) async {
    resumeOnConnect = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('resume_on_connect', value);
    audioHandler.setResumeOnConnect(value);
  }

  Future<void> setSleepTimerFadeOutSeconds(int seconds) async {
    sleepTimerFadeOutSeconds = seconds;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setInt('sleep_timer_fade_out_seconds', seconds);
  }

  Future<void> setSleepTimerFinishSong(bool value) async {
    sleepTimerFinishSong = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('sleep_timer_finish_song', value);
  }

  ThemeColorSource get themeColorSource {
    if (useMaterialYou) return ThemeColorSource.materialYou;
    if (useDynamicTheme) return ThemeColorSource.albumArt;
    return ThemeColorSource.custom;
  }

  Future<void> setThemeColorSource(ThemeColorSource source) async {
    var prefs = SharedPreferencesAsync();
    switch (source) {
      case ThemeColorSource.materialYou:
        useDynamicTheme = false;
        await prefs.setBool('use_dynamic_theme', false);
        await setUseMaterialYou(true);
        break;
      case ThemeColorSource.albumArt:
        useMaterialYou = false;
        await prefs.setBool('use_material_you', false);
        await setDynamicTheme(true);
        break;
      case ThemeColorSource.custom:
        useMaterialYou = false;
        useDynamicTheme = false;
        notifyListeners();
        await prefs.setBool('use_material_you', false);
        await prefs.setBool('use_dynamic_theme', false);
        break;
    }
  }

  Future<void> refreshDynamicWallpaperColor() async {
    var newColor = await MusicScanner.getDynamicWallpaperColor();
    if (newColor != dynamicWallpaperColor) {
      dynamicWallpaperColor = newColor;
      notifyListeners();
    }
  }

  Future<void> setUseMaterialYou(bool value) async {
    useMaterialYou = value;
    if (value) {
      dynamicWallpaperColor = await MusicScanner.getDynamicWallpaperColor();
    }
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('use_material_you', value);
  }

  Future<void> setAmbientGlowIntensity(String value) async {
    ambientGlowIntensity = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setString('ambient_glow_intensity', value);
  }

  Future<void> setNowPlayingStyle(String value) async {
    nowPlayingStyle = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setString('now_playing_style', value);
  }

  Future<void> setAutoCheckUpdates(bool value) async {
    autoCheckUpdates = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('auto_check_updates', value);
  }

  Future<void> setUserName(String name) async {
    userName = name;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setString('user_name', name);
  }

  Future<void> setUseGreetingTitle(bool value) async {
    useGreetingTitle = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('use_greeting_title', value);
  }

  Future<void> setKeepPlayingOnClose(bool value) async {
    keepPlayingOnClose = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('keep_playing_on_close', value);
  }

  Future<void> setRestoreLastPlayedSong(bool value) async {
    restoreLastPlayedSong = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('restore_last_played_song', value);
  }

  Future<void> setPauseOnDuck(
    bool value,
    SonoraAudioHandler audioHandler,
  ) async {
    pauseOnDuck = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('pause_on_duck', value);
    await audioHandler.setPauseOnDuck(value);
  }

  Future<void> setFilterTitleFeatures(bool value) async {
    filterTitleFeatures = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('filter_title_features', value);
  }

  Future<void> setFilterTitleArtist(bool value) async {
    filterTitleArtist = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('filter_title_artist', value);
  }

  Future<void> setAmoledDark(bool value) async {
    amoledDark = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('amoled_dark', value);
  }

  Future<void> setDynamicTheme(bool value) async {
    useDynamicTheme = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('use_dynamic_theme', value);
  }

  Future<void> setDynamicThemeColor(Color color) async {
    dynamicThemeColor = color;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setInt('dynamic_theme_color', color.toARGB32());
  }

  Future<void> setShowVisualizer(bool value) async {
    showVisualizer = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('show_visualizer', value);
  }

  Future<void> setImmersiveMode(bool value) async {
    immersiveMode = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('immersive_mode', value);
  }

  Future<void> setPreferLocalArtistImages(bool value) async {
    preferLocalArtistImages = value;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('prefer_local_artist_images', value);
  }

  Future<void> setSleepTimerDefaultMinutes(int minutes) async {
    sleepTimerDefaultMinutes = minutes;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setInt('sleep_timer_default_minutes', minutes);
  }

  Future<void> setDefaultStartPage(int pageIndex) async {
    defaultStartPage = pageIndex;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setInt('default_start_page', pageIndex);
  }

  Future<void> saveSortSettings({
    String? songSortBy,
    bool? songSortAscending,
    String? albumSortBy,
    bool? albumSortAscending,
    String? artistSortBy,
    bool? artistSortAscending,
    String? playlistSortBy,
    bool? playlistSortAscending,
    String? favoritesSortBy,
    bool? favoritesSortAscending,
  }) async {
    var prefs = SharedPreferencesAsync();
    if (songSortBy != null) {
      this.songSortBy = songSortBy;
      await prefs.setString('song_sort_by', songSortBy);
    }
    if (songSortAscending != null) {
      this.songSortAscending = songSortAscending;
      await prefs.setBool('song_sort_ascending', songSortAscending);
    }
    if (albumSortBy != null) {
      this.albumSortBy = albumSortBy;
      await prefs.setString('album_sort_by', albumSortBy);
    }
    if (albumSortAscending != null) {
      this.albumSortAscending = albumSortAscending;
      await prefs.setBool('album_sort_ascending', albumSortAscending);
    }
    if (artistSortBy != null) {
      this.artistSortBy = artistSortBy;
      await prefs.setString('artist_sort_by', artistSortBy);
    }
    if (artistSortAscending != null) {
      this.artistSortAscending = artistSortAscending;
      await prefs.setBool('artist_sort_ascending', artistSortAscending);
    }
    if (playlistSortBy != null) {
      this.playlistSortBy = playlistSortBy;
      await prefs.setString('playlist_sort_by', playlistSortBy);
    }
    if (playlistSortAscending != null) {
      this.playlistSortAscending = playlistSortAscending;
      await prefs.setBool('playlist_sort_ascending', playlistSortAscending);
    }

    if (favoritesSortBy != null) {
      this.favoritesSortBy = favoritesSortBy;
      await prefs.setString('favorites_sort_by', favoritesSortBy);
    }

    if (favoritesSortAscending != null) {
      this.favoritesSortAscending = favoritesSortAscending;
      await prefs.setBool('favorites_sort_ascending', favoritesSortAscending);
    }
    notifyListeners();
  }

  Future<void> setAppLocale(String localeCode) async {
    appLocale = localeCode;
    notifyListeners();
    var prefs = SharedPreferencesAsync();
    await prefs.setString('app_locale', localeCode);
  }

  Future<void> refreshSyncStats() async {
    var scanner = MusicScanner();
    var prefs = SharedPreferencesAsync();
    scanFolder = await scanner.getScanFolder();
    lastSyncTime = await scanner.getLastSyncTime();
    lastPerfLog = await prefs.getString('last_perf_log');
    lastSyncDuration = await scanner.getLastSyncDuration('last');
    notifyListeners();
  }
}
