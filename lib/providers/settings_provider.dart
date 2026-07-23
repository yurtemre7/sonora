import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/music_scanner.dart';

class SettingsProvider extends ChangeNotifier {
  static final instance = SettingsProvider._internal();
  factory SettingsProvider() => instance;
  SettingsProvider._internal();

  var useDynamicTheme = true;
  var amoledDark = false;
  var dynamicThemeColor = const Color(0xFF7C4DFF);
  var showVisualizer = false;
  var immersiveMode = false;
  var preferLocalArtistImages = true;
  var sleepTimerDefaultMinutes = 5;
  var defaultStartPage = 0;

  var songSortBy = 'title';
  var songSortAscending = true;
  var albumSortBy = 'name';
  var albumSortAscending = true;
  var artistSortBy = 'name';
  var artistSortAscending = true;
  var playlistSortBy = 'name';
  var playlistSortAscending = true;

  var keepPlayingOnClose = false;
  var pauseOnDuck = false;
  var filterTitleFeatures = false;
  var filterTitleArtist = false;
  var userName = 'User';
  var useGreetingTitle = false;
  var autoCheckUpdates = true;
  String? scanFolder;
  String? lastSyncTime;
  int? lastSyncDuration;

  var _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> loadSettings() async {
    var prefs = SharedPreferencesAsync();
    var scanner = MusicScanner();

    useDynamicTheme = await prefs.getBool('use_dynamic_theme') ?? true;
    amoledDark = await prefs.getBool('amoled_dark') ?? false;
    var colorValue = await prefs.getInt('dynamic_theme_color');
    if (colorValue != null) {
      dynamicThemeColor = Color(colorValue);
    }
    showVisualizer = await prefs.getBool('show_visualizer') ?? false;
    immersiveMode = await prefs.getBool('immersive_mode') ?? false;
    preferLocalArtistImages =
        await prefs.getBool('prefer_local_artist_images') ?? true;
    sleepTimerDefaultMinutes =
        await prefs.getInt('sleep_timer_default_minutes') ?? 5;
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

    keepPlayingOnClose = await prefs.getBool('keep_playing_on_close') ?? false;
    pauseOnDuck = await prefs.getBool('pause_on_duck') ?? false;
    filterTitleFeatures = await prefs.getBool('filter_title_features') ?? false;
    filterTitleArtist = await prefs.getBool('filter_title_artist') ?? false;
    userName = await prefs.getString('user_name') ?? 'User';
    useGreetingTitle = await prefs.getBool('use_greeting_title') ?? false;
    autoCheckUpdates = await prefs.getBool('auto_check_updates') ?? true;

    scanFolder = await scanner.getScanFolder();
    lastSyncTime = await scanner.getLastSyncTime();
    lastSyncDuration = await scanner.getLastSyncDuration('sequential');

    _isLoaded = true;
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> refreshSyncStats() async {
    var scanner = MusicScanner();
    scanFolder = await scanner.getScanFolder();
    lastSyncTime = await scanner.getLastSyncTime();
    lastSyncDuration = await scanner.getLastSyncDuration('sequential');
    notifyListeners();
  }
}
