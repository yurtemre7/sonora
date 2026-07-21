import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/music_scanner.dart';

class SettingsProvider extends ChangeNotifier {
  static final instance = SettingsProvider._internal();
  factory SettingsProvider() => instance;
  SettingsProvider._internal();

  var keepPlayingOnClose = false;
  var pauseOnDuck = false;
  var filterTitleFeatures = false;
  var filterTitleArtist = false;
  String? scanFolder;
  String? lastSyncTime;
  int? lastSyncDuration;

  var _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> loadSettings() async {
    var prefs = SharedPreferencesAsync();
    var scanner = MusicScanner();

    keepPlayingOnClose = await prefs.getBool('keep_playing_on_close') ?? false;
    pauseOnDuck = await prefs.getBool('pause_on_duck') ?? false;
    filterTitleFeatures = await prefs.getBool('filter_title_features') ?? false;
    filterTitleArtist = await prefs.getBool('filter_title_artist') ?? false;

    scanFolder = await scanner.getScanFolder();
    lastSyncTime = await scanner.getLastSyncTime();
    lastSyncDuration = await scanner.getLastSyncDuration('sequential');

    _isLoaded = true;
    notifyListeners();
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

  Future<void> refreshSyncStats() async {
    var scanner = MusicScanner();
    scanFolder = await scanner.getScanFolder();
    lastSyncTime = await scanner.getLastSyncTime();
    lastSyncDuration = await scanner.getLastSyncDuration('sequential');
    notifyListeners();
  }
}
