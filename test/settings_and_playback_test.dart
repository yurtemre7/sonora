import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/widgets/custom_scrollbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Customization Settings', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('default values for new settings', () {
      var settings = SettingsProvider();
      expect(settings.pauseOnDisconnect, isTrue);
      expect(settings.resumeOnConnect, isFalse);
      expect(settings.sleepTimerFadeOutSeconds, 10);
      expect(settings.sleepTimerFinishSong, isFalse);
      expect(settings.useMaterialYou, isFalse);
      expect(settings.ambientGlowIntensity, 'vibrant');
      expect(settings.nowPlayingStyle, 'modern');
    });

    test('updates sleepTimerFadeOutSeconds', () async {
      var settings = SettingsProvider();
      await settings.setSleepTimerFadeOutSeconds(30);
      expect(settings.sleepTimerFadeOutSeconds, 30);
    });

    test('updates sleepTimerFinishSong', () async {
      var settings = SettingsProvider();
      await settings.setSleepTimerFinishSong(true);
      expect(settings.sleepTimerFinishSong, isTrue);
    });

    test('updates useMaterialYou', () async {
      var settings = SettingsProvider();
      await settings.setUseMaterialYou(true);
      expect(settings.useMaterialYou, isTrue);
    });

    test('updates ambientGlowIntensity', () async {
      var settings = SettingsProvider();
      await settings.setAmbientGlowIntensity('immersive');
      expect(settings.ambientGlowIntensity, 'immersive');
    });

    test('updates nowPlayingStyle', () async {
      var settings = SettingsProvider();
      await settings.setNowPlayingStyle('vinyl');
      expect(settings.nowPlayingStyle, 'vinyl');
    });
  });

  group('CustomScrollbar Section Bubble', () {
    testWidgets('renders child and supports sectionGetter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollbar(
              sectionGetter: (percent) => percent < 0.5 ? 'A' : 'B',
              child: ListView.builder(
                itemCount: 100,
                itemBuilder: (context, index) => ListTile(
                  title: Text('Item $index'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
    });
  });
}
