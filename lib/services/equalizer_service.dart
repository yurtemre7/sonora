import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing equalizer band parameters, preset gains, and preference storage.
class EqualizerService {
  static final _instance = EqualizerService._internal();

  factory EqualizerService() => _instance;

  EqualizerService._internal();

  final equalizer = AndroidEqualizer();
  final _prefs = SharedPreferencesAsync();

  static const presets = <String, List<double>>{
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [4.0, 3.0, 0.0, 0.0, 0.0],
    'Treble Boost': [0.0, 0.0, 1.0, 3.0, 4.0],
    'Vocal': [-1.0, 2.0, 4.0, 2.0, -1.0],
    'Rock': [3.0, 1.0, -1.0, 1.0, 3.0],
    'Pop': [-1.0, 2.0, 3.0, 1.0, -1.0],
    'EDM': [4.0, 2.0, 0.0, 2.0, 3.0],
  };

  var _currentPreset = 'Flat';
  String get currentPreset => _currentPreset;

  Future<void> initialize() async {
    try {
      var savedPreset = await _prefs.getString('eq_current_preset');
      if (savedPreset != null && presets.containsKey(savedPreset)) {
        _currentPreset = savedPreset;
      }
      var savedGains = await _prefs.getStringList('eq_custom_gains');
      if (savedGains != null && savedGains.length == 5) {
        var gains = savedGains.map((e) => double.tryParse(e) ?? 0.0).toList();
        await applyCustomGains(gains);
      } else if (presets.containsKey(_currentPreset)) {
        await applyPreset(_currentPreset);
      }
    } catch (_) {}
  }

  Future<void> applyPreset(String presetName) async {
    if (!presets.containsKey(presetName)) return;
    _currentPreset = presetName;
    await _prefs.setString('eq_current_preset', presetName);

    var bandGains = presets[presetName]!;
    await applyCustomGains(bandGains);
  }

  Future<void> applyCustomGains(List<double> gains) async {
    try {
      var parameters = await equalizer.parameters;
      var bands = parameters.bands;
      for (var i = 0; i < bands.length && i < gains.length; i++) {
        var band = bands[i];
        var gain = gains[i].clamp(
          parameters.minDecibels,
          parameters.maxDecibels,
        );
        await band.setGain(gain);
      }
      await _prefs.setStringList(
        'eq_custom_gains',
        gains.map((g) => g.toString()).toList(),
      );
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      await equalizer.setEnabled(enabled);
      await _prefs.setBool('eq_enabled', enabled);
    } catch (_) {}
  }
}
