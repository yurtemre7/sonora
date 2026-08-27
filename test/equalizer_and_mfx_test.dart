import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/services/equalizer_service.dart';
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
          home: Scaffold(
            body: VolumeSlider(
              volume: 0.0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    testWidgets('Renders volume_mute icon when volume is low (< 1/3)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolumeSlider(
              volume: 0.2,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_mute_rounded), findsOneWidget);
    });

    testWidgets('Renders volume_down icon when volume is medium (1/3 <= v < 2/3)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolumeSlider(
              volume: 0.5,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_down_rounded), findsOneWidget);
    });

    testWidgets('Renders volume_up icon when volume is high (>= 2/3)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolumeSlider(
              volume: 0.85,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });
  });
}
