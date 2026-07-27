import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sonora/app.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/sleep_timer_notification_service.dart';
import 'package:sonora/services/volume_service.dart';

late SonoraAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cap Flutter image cache to 50 MB / 150 images to prevent RAM inflation during heavy scrolling
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 150;

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Initialize audio service with our custom handler (does not block UI booting)
  audioHandler = await AudioService.init(
    builder: () => SonoraAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'de.yurtemre.sonora.audio',
      androidNotificationChannelName: 'Sonora Music',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_launcher_monochrome',
    ),
  );

  // Initialize sleep timer notifications
  await SleepTimerNotificationService().initialize();

  // Ensure media volume is audible (handles muted phone)
  var volumeService = VolumeService();
  await volumeService.ensureMediaVolume();

  runApp(SonoraApp(audioHandler: audioHandler));
}
