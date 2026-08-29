import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/screens/settings/appearance_settings_screen.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/widgets/theme_color_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Widget buildTestableWidget({
    required Widget child,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ja')],
      locale: const Locale('en'),
      home: child,
    );
  }

  group('ThemeColorSelector Tests', () {
    testWidgets('Renders color options and triggers onColorSelected when enabled', (
      tester,
    ) async {
      Color? selected;
      var testColors = [
        const Color(0xFF7C4DFF),
        const Color(0xFFE91E63),
        const Color(0xFF00BCD4),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: ThemeColorSelector(
              colors: testColors,
              selectedColor: testColors[0],
              onColorSelected: (color) => selected = color,
            ),
          ),
        ),
      );

      expect(find.byType(ThemeColorSelector), findsOneWidget);
      var selectorPaints = find.descendant(
        of: find.byType(ThemeColorSelector),
        matching: find.byType(CustomPaint),
      );
      expect(selectorPaints, findsNWidgets(3));

      // Tap second color
      await tester.tap(selectorPaints.at(1));
      await tester.pump();

      expect(selected, equals(const Color(0xFFE91E63)));
    });

    testWidgets('Does not trigger onColorSelected when disabled', (
      tester,
    ) async {
      Color? selected;
      var testColors = [
        const Color(0xFF7C4DFF),
        const Color(0xFFE91E63),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: ThemeColorSelector(
              colors: testColors,
              selectedColor: testColors[0],
              enabled: false,
              disabledTooltip: 'Disabled by Material You',
              onColorSelected: (color) => selected = color,
            ),
          ),
        ),
      );

      var selectorPaints = find.descendant(
        of: find.byType(ThemeColorSelector),
        matching: find.byType(CustomPaint),
      );

      // Tap second color
      await tester.tap(selectorPaints.at(1), warnIfMissed: false);
      await tester.pump();

      expect(selected, isNull);
      expect(find.byType(Tooltip), findsOneWidget);
    });
  });

  group('AppearanceSettingsScreen Unified Buttons Tests', () {
    testWidgets('Renders unified SegmentedButtons and transitions smoothly across color modes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ryanheise.audio_session'),
            (MethodCall methodCall) async => null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ryanheise.just_audio.methods'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'init') {
                return {'id': 'test_player'};
              }
              return null;
            },
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ryanheise.just_audio.events'),
            (MethodCall methodCall) async => null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('de.yurtemre.sonora/mediastore'),
            (MethodCall methodCall) async => null,
          );

      var audioHandler = SonoraAudioHandler();
      var themeProvider = ThemeProvider();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );

      // Initially Album Art mode
      settingsProvider.useMaterialYou = false;
      settingsProvider.useDynamicTheme = true;

      await tester.pumpWidget(
        buildTestableWidget(
          child: AppearanceSettingsScreen(
            themeProvider: themeProvider,
            playerProvider: playerProvider,
            settingsProvider: settingsProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Section Headers
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Theme Colors & Accent'), findsOneWidget);
      expect(find.text('Display & Contrast'), findsOneWidget);
      expect(find.text('Player Screen Aesthetics'), findsOneWidget);
      expect(find.text('Personalization'), findsOneWidget);

      // Verify Theme Mode SegmentedButton
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      expect(find.text('System Default'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Tap Dark theme mode
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(themeProvider.themeMode, equals(ThemeMode.dark));

      // Verify ThemeColorSource SegmentedButton
      expect(find.byType(SegmentedButton<ThemeColorSource>), findsOneWidget);
      expect(find.text('Material You'), findsOneWidget);
      expect(find.text('Album Art'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // In Album Art mode, fallback color header and ThemeColorSelector are shown
      expect(find.text('Fallback Color (when no song is playing)'), findsOneWidget);
      expect(find.byType(ThemeColorSelector), findsOneWidget);

      // Switch to Material You
      await tester.tap(find.text('Material You'));
      await tester.pumpAndSettle();

      expect(settingsProvider.themeColorSource, equals(ThemeColorSource.materialYou));
      expect(settingsProvider.useMaterialYou, isTrue);
      expect(settingsProvider.useDynamicTheme, isFalse);
      expect(find.text('Theme colors are extracted from your system wallpaper (Android 12+)'), findsOneWidget);
      // ThemeColorSelector should not be displayed in Material You mode
      expect(find.byType(ThemeColorSelector), findsNothing);

      // Switch to Custom Accent Color
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(settingsProvider.themeColorSource, equals(ThemeColorSource.custom));
      expect(settingsProvider.useMaterialYou, isFalse);
      expect(settingsProvider.useDynamicTheme, isFalse);
      expect(find.text('Choose Accent Color'), findsOneWidget);
      expect(find.byType(ThemeColorSelector), findsOneWidget);
    });

    test('Re-applying Material You or resuming app re-extracts wallpaper color', () async {
      var currentMockColor = const Color(0xFF112233).toARGB32();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('de.yurtemre.sonora/mediastore'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getDynamicWallpaperColor') {
                return currentMockColor;
              }
              return null;
            },
          );

      var audioHandler = SonoraAudioHandler();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );

      // Initial Material You enable
      await settingsProvider.setUseMaterialYou(true);
      expect(settingsProvider.dynamicWallpaperColor, equals(const Color(0xFF112233)));

      // User changes Android system wallpaper to a new green color
      currentMockColor = const Color(0xFF448822).toARGB32();

      // 1. Re-applying the setting re-fetches the new color
      await settingsProvider.setUseMaterialYou(true);
      expect(settingsProvider.dynamicWallpaperColor, equals(const Color(0xFF448822)));

      // User changes Android system wallpaper again to a blue color
      currentMockColor = const Color(0xFF2255AA).toARGB32();

      // 2. App resume lifecycle event triggers automatic refresh
      playerProvider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(settingsProvider.dynamicWallpaperColor, equals(const Color(0xFF2255AA)));
    });
  });
}
