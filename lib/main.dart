import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'package:sonora/app.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/volume_service.dart';

late SonoraAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize audio service with our custom handler (does not block UI booting)
  audioHandler = await AudioService.init(
    builder: () => SonoraAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sonora.sonora.audio',
      androidNotificationChannelName: 'Sonora Music',
      androidNotificationOngoing: true,
    ),
  );

  // Ensure media volume is audible (handles muted phone)
  var volumeService = VolumeService();
  await volumeService.ensureMediaVolume();

  runApp(SonoraApp(audioHandler: audioHandler));
}
