import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Manages the app's theme mode (system, light, dark) and persists the choice.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      var appDir = await getApplicationDocumentsDirectory();
      var file = File('${appDir.path}/theme_prefs.json');
      if (file.existsSync()) {
        var json = jsonDecode(file.readAsStringSync());
        var mode = json['themeMode'] as String?;
        switch (mode) {
          case 'light':
            _themeMode = ThemeMode.light;
          case 'dark':
            _themeMode = ThemeMode.dark;
          default:
            _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {
      // Use default
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      var appDir = await getApplicationDocumentsDirectory();
      var file = File('${appDir.path}/theme_prefs.json');
      var modeString = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      };
      await file.writeAsString(jsonEncode({'themeMode': modeString}));
    } catch (_) {
      // Silently ignore write failures
    }
  }
}
