import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's theme mode (system, light, dark) and persists the choice.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  final _prefs = SharedPreferencesAsync();

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      // 1. Try to load from SharedPreferencesAsync
      var mode = await _prefs.getString('theme_mode');
      if (mode != null) {
        _themeMode = _parseThemeMode(mode);
        notifyListeners();
        return;
      }

      // 2. Migration fallback: Check if legacy theme_prefs.json exists
      var appDir = await getApplicationDocumentsDirectory();
      var file = File('${appDir.path}/theme_prefs.json');
      if (file.existsSync()) {
        var json = jsonDecode(file.readAsStringSync());
        var legacyMode = json['themeMode'] as String?;
        if (legacyMode != null) {
          _themeMode = _parseThemeMode(legacyMode);
          notifyListeners();
          
          // Migrate to SharedPreferencesAsync and delete legacy file
          await _prefs.setString('theme_mode', legacyMode);
        }
        file.deleteSync();
      }
    } catch (_) {
      // Use default
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      var modeString = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      };
      await _prefs.setString('theme_mode', modeString);

      // Clean up legacy file if it exists
      var appDir = await getApplicationDocumentsDirectory();
      var file = File('${appDir.path}/theme_prefs.json');
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // Silently ignore failures
    }
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
