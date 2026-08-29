import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('SettingsProvider Persistence & Loading Tests', () {
    test('Default values load correctly on fresh start', () async {
      var settings = SettingsProvider();
      await settings.loadSettings();

      expect(settings.useDynamicTheme, isTrue);
      expect(settings.useMaterialYou, isFalse);
      expect(settings.themeColorSource, equals(ThemeColorSource.albumArt));
      expect(settings.amoledDark, isFalse);
      expect(settings.nowPlayingStyle, equals('modern'));
      expect(settings.showVisualizer, isFalse);
      expect(settings.immersiveMode, isFalse);
      expect(settings.preferLocalArtistImages, isTrue);
      expect(settings.sleepTimerDefaultMinutes, equals(5));
      expect(settings.sleepTimerFadeOutSeconds, equals(10));
      expect(settings.sleepTimerFinishSong, isFalse);
      expect(settings.defaultStartPage, equals(0));
      expect(settings.keepPlayingOnClose, isFalse);
      expect(settings.restoreLastPlayedSong, isTrue);
      expect(settings.userName, equals('User'));
      expect(settings.useGreetingTitle, isFalse);
      expect(settings.autoCheckUpdates, isTrue);
      expect(settings.appLocale, equals('system'));
    });

    test('ThemeColorSource.materialYou persists and reloads accurately', () async {
      var settings1 = SettingsProvider();
      await settings1.setThemeColorSource(ThemeColorSource.materialYou);

      expect(settings1.useMaterialYou, isTrue);
      expect(settings1.useDynamicTheme, isFalse);
      expect(settings1.themeColorSource, equals(ThemeColorSource.materialYou));

      // Simulate app restart
      var settings2 = SettingsProvider();
      await settings2.loadSettings();

      expect(settings2.useMaterialYou, isTrue);
      expect(settings2.useDynamicTheme, isFalse);
      expect(settings2.themeColorSource, equals(ThemeColorSource.materialYou));
    });

    test('ThemeColorSource.albumArt persists and reloads accurately', () async {
      var settings1 = SettingsProvider();
      await settings1.setThemeColorSource(ThemeColorSource.albumArt);

      expect(settings1.useMaterialYou, isFalse);
      expect(settings1.useDynamicTheme, isTrue);
      expect(settings1.themeColorSource, equals(ThemeColorSource.albumArt));

      // Simulate app restart
      var settings2 = SettingsProvider();
      await settings2.loadSettings();

      expect(settings2.useMaterialYou, isFalse);
      expect(settings2.useDynamicTheme, isTrue);
      expect(settings2.themeColorSource, equals(ThemeColorSource.albumArt));
    });

    test('ThemeColorSource.custom persists and reloads accurately', () async {
      var settings1 = SettingsProvider();
      await settings1.setThemeColorSource(ThemeColorSource.custom);

      expect(settings1.useMaterialYou, isFalse);
      expect(settings1.useDynamicTheme, isFalse);
      expect(settings1.themeColorSource, equals(ThemeColorSource.custom));

      // Simulate app restart
      var settings2 = SettingsProvider();
      await settings2.loadSettings();

      expect(settings2.useMaterialYou, isFalse);
      expect(settings2.useDynamicTheme, isFalse);
      expect(settings2.themeColorSource, equals(ThemeColorSource.custom));
    });

    test('All preference setters persist across restart', () async {
      var settings1 = SettingsProvider();
      await settings1.setAmoledDark(true);
      await settings1.setNowPlayingStyle('vinyl');
      await settings1.setShowVisualizer(true);
      await settings1.setImmersiveMode(true);
      await settings1.setPreferLocalArtistImages(false);
      await settings1.setSleepTimerDefaultMinutes(15);
      await settings1.setSleepTimerFadeOutSeconds(30);
      await settings1.setSleepTimerFinishSong(true);
      await settings1.setDefaultStartPage(2);
      await settings1.setKeepPlayingOnClose(true);
      await settings1.setRestoreLastPlayedSong(false);
      await settings1.setFilterTitleFeatures(true);
      await settings1.setFilterTitleArtist(true);
      await settings1.setUserName('Alice');
      await settings1.setUseGreetingTitle(true);
      await settings1.setAutoCheckUpdates(false);
      await settings1.setAppLocale('de');

      // Reload into new instance
      var settings2 = SettingsProvider();
      await settings2.loadSettings();

      expect(settings2.amoledDark, isTrue);
      expect(settings2.nowPlayingStyle, equals('vinyl'));
      expect(settings2.showVisualizer, isTrue);
      expect(settings2.immersiveMode, isTrue);
      expect(settings2.preferLocalArtistImages, isFalse);
      expect(settings2.sleepTimerDefaultMinutes, equals(15));
      expect(settings2.sleepTimerFadeOutSeconds, equals(30));
      expect(settings2.sleepTimerFinishSong, isTrue);
      expect(settings2.defaultStartPage, equals(2));
      expect(settings2.keepPlayingOnClose, isTrue);
      expect(settings2.restoreLastPlayedSong, isFalse);
      expect(settings2.filterTitleFeatures, isTrue);
      expect(settings2.filterTitleArtist, isTrue);
      expect(settings2.userName, equals('Alice'));
      expect(settings2.useGreetingTitle, isTrue);
      expect(settings2.autoCheckUpdates, isFalse);
      expect(settings2.appLocale, equals('de'));
      expect(settings2.currentLocale, equals(const Locale('de')));
    });
  });

  group('ThemeProvider Persistence Tests', () {
    test('ThemeProvider loads and persists light, dark, and system modes', () async {
      var themeProvider = ThemeProvider();
      expect(themeProvider.themeMode, equals(ThemeMode.system));

      await themeProvider.setThemeMode(ThemeMode.dark);
      expect(themeProvider.themeMode, equals(ThemeMode.dark));

      // Reload
      var reloadedTheme = ThemeProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reloadedTheme.themeMode, equals(ThemeMode.dark));

      await reloadedTheme.setThemeMode(ThemeMode.light);
      expect(reloadedTheme.themeMode, equals(ThemeMode.light));

      var reloadedLight = ThemeProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reloadedLight.themeMode, equals(ThemeMode.light));
    });
  });
}
