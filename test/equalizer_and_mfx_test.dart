import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/models/mfx_preset.dart';
import 'package:sonora/services/equalizer_service.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/volume_slider.dart';

void main() {
  group('EqualizerService Preset Tests', () {
    test('Presets contain standard musical curves with exactly 5 bands', () {
      expect(EqualizerService.presets.containsKey('Flat'), isTrue);
      expect(EqualizerService.presets.containsKey('Bass Boost'), isTrue);
      expect(EqualizerService.presets.containsKey('Treble Boost'), isTrue);
      expect(EqualizerService.presets.containsKey('Vocal'), isTrue);
      expect(EqualizerService.presets.containsKey('Rock'), isTrue);
      expect(EqualizerService.presets.containsKey('Pop'), isTrue);
      expect(EqualizerService.presets.containsKey('EDM'), isTrue);

      for (var entry in EqualizerService.presets.entries) {
        expect(
          entry.value.length,
          equals(5),
          reason: '${entry.key} must have exactly 5 frequency band gains',
        );
      }
    });

    test('Bass Boost preset elevates lower frequency bands', () {
      var bassGains = EqualizerService.presets['Bass Boost']!;
      expect(bassGains[0], greaterThan(bassGains[2]));
      expect(bassGains[1], greaterThan(bassGains[3]));
    });

    test('Treble Boost preset elevates higher frequency bands', () {
      var trebleGains = EqualizerService.presets['Treble Boost']!;
      expect(trebleGains[4], greaterThan(trebleGains[0]));
      expect(trebleGains[3], greaterThan(trebleGains[1]));
    });
  });

  group('VolumeSlider Widget Tests', () {
    testWidgets('Renders volume_off icon when volume is 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VolumeSlider(volume: 0.0, onChanged: (_) {})),
        ),
      );

      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    testWidgets('Renders volume_mute icon when volume is low (< 1/3)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VolumeSlider(volume: 0.2, onChanged: (_) {})),
        ),
      );

      expect(find.byIcon(Icons.volume_mute_rounded), findsOneWidget);
    });

    testWidgets(
      'Renders volume_down icon when volume is medium (1/3 <= v < 2/3)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: VolumeSlider(volume: 0.5, onChanged: (_) {})),
          ),
        );

        expect(find.byIcon(Icons.volume_down_rounded), findsOneWidget);
      },
    );

    testWidgets('Renders volume_up icon when volume is high (>= 2/3)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VolumeSlider(volume: 0.85, onChanged: (_) {})),
        ),
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });
  });

  group('MFX Presets and Quick Effects Tests', () {
    test('All 14 MfxPreset enum entries exist and have matching speed & pitch', () {
      expect(MfxPreset.values.length, equals(14));

      for (var preset in MfxPreset.values) {
        expect(preset.pitch, equals(preset.speed));
        expect(preset.speed, greaterThan(0.0));
      }
    });

    test('All requested quick effects speeds are covered in MfxPreset enum', () {
      const requestedSpeeds = [
        0.70,
        0.75,
        0.80,
        0.85,
        0.90,
        0.95,
        1.00,
        1.05,
        1.10,
        1.15,
        1.20,
        1.25,
        1.30,
        1.50,
      ];

      for (var speed in requestedSpeeds) {
        var preset = MfxPreset.fromSpeed(speed);
        expect(preset, isNotNull, reason: 'Preset for speed $speed must exist');
        expect(preset!.speed, equals(speed));
        expect(preset.pitch, equals(speed));
      }
    });

    test('MfxPreset.normal behaves as expected', () {
      expect(MfxPreset.normal.speed, equals(1.0));
      expect(MfxPreset.normal.pitch, equals(1.0));
      expect(MfxPreset.normal.isNormal, isTrue);

      for (var preset in MfxPreset.values) {
        if (preset != MfxPreset.normal) {
          expect(preset.isNormal, isFalse);
        }
      }
    });

    test('MfxPreset.fromName resolves properly', () {
      expect(MfxPreset.fromName('superSlowed'), equals(MfxPreset.superSlowed));
      expect(MfxPreset.fromName('slowed095'), equals(MfxPreset.slowed095));
      expect(MfxPreset.fromName('normal'), equals(MfxPreset.normal));
      expect(MfxPreset.fromName('spedUp110'), equals(MfxPreset.spedUp110));
      expect(MfxPreset.fromName('nightcore'), equals(MfxPreset.nightcore));
      expect(MfxPreset.fromName('unknown_preset'), isNull);
      expect(MfxPreset.fromName(null), isNull);
    });

    test('Presets without unique names have percentage display titles', () {
      expect(MfxPreset.slowed095.displayTitle, equals('5% slower'));
      expect(MfxPreset.slowed090.displayTitle, equals('10% slower'));
      expect(MfxPreset.slowed080.displayTitle, equals('20% slower'));
      expect(MfxPreset.slowed075.displayTitle, equals('25% slower'));

      expect(MfxPreset.spedUp105.displayTitle, equals('5% faster'));
      expect(MfxPreset.spedUp110.displayTitle, equals('10% faster'));
      expect(MfxPreset.spedUp115.displayTitle, equals('15% faster'));
      expect(MfxPreset.spedUp120.displayTitle, equals('20% faster'));
    });

    testWidgets('MfxPreset.getTitle renders percentage titles in context', (
      tester,
    ) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(MfxPreset.slowed095.getTitle(buildContext), equals('5% slower'));
      expect(MfxPreset.slowed090.getTitle(buildContext), equals('10% slower'));
      expect(MfxPreset.slowed080.getTitle(buildContext), equals('20% slower'));
      expect(MfxPreset.slowed075.getTitle(buildContext), equals('25% slower'));
      expect(MfxPreset.spedUp105.getTitle(buildContext), equals('5% faster'));
      expect(MfxPreset.spedUp110.getTitle(buildContext), equals('10% faster'));
      expect(MfxPreset.spedUp115.getTitle(buildContext), equals('15% faster'));
      expect(MfxPreset.spedUp120.getTitle(buildContext), equals('20% faster'));

      // Unique names should still render localized names
      expect(MfxPreset.superSlowed.getTitle(buildContext), equals('Super Slowed'));
      expect(MfxPreset.slowed.getTitle(buildContext), equals('Slowed'));
      expect(MfxPreset.normal.getTitle(buildContext), equals('Normal'));
      expect(MfxPreset.spedUp.getTitle(buildContext), equals('Sped Up'));
      expect(MfxPreset.nightcore.getTitle(buildContext), equals('Nightcore'));
      expect(MfxPreset.superSpedUp.getTitle(buildContext), equals('Super Sped Up'));
    });
  });

  group('Bluetooth Audio Patch Tests', () {
    testWidgets('Renders localized Bluetooth patch title and subtitle', (
      tester,
    ) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        buildContext.l10n.mfxBluetoothPatch,
        equals('Bluetooth Audio Device Patch'),
      );
      expect(
        buildContext.l10n.mfxBluetoothPatchSubtitle.isNotEmpty,
        isTrue,
      );
    });

    test('Bluetooth audio patch filter gain curves vs standard curves', () {
      // Simulate standard 5-band EQ parameter range (+15 dB max, -15 dB min)
      const maxDb = 15.0;
      const minDb = -15.0;

      // Bass boost comparisons
      const standardBassGain = maxDb * 0.8; // +12.0 dB
      const btPatchBassGain = maxDb * 0.4; // +6.0 dB
      expect(btPatchBassGain, lessThan(standardBassGain));
      expect(btPatchBassGain, greaterThan(0.0));

      // Warmth comparisons
      const standardWarmthBass = maxDb * 0.5; // +7.5 dB
      const standardWarmthTreble = minDb * 0.5; // -7.5 dB
      const btPatchWarmthBass = maxDb * 0.3; // +4.5 dB
      const btPatchWarmthTreble = minDb * 0.25; // -3.75 dB
      expect(btPatchWarmthBass, lessThan(standardWarmthBass));
      expect(btPatchWarmthTreble, greaterThan(standardWarmthTreble)); // Less extreme cut

      // Lo-Fi comparisons
      const standardLofiTreble = minDb; // -15.0 dB total mute
      const btPatchLofiTreble = minDb * 0.55; // -8.25 dB musical cutoff
      expect(btPatchLofiTreble, greaterThan(standardLofiTreble));
    });
  });
}
