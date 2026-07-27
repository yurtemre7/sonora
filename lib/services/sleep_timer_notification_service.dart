import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId != null) {
    SleepTimerNotificationService.handleAction(notificationResponse.actionId!);
  }
}

class SleepTimerNotificationService {
  static final _instance = SleepTimerNotificationService._internal();

  factory SleepTimerNotificationService() => _instance;

  SleepTimerNotificationService._internal();

  final _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const _notificationId = 8888;
  static const _channelId = 'de.yurtemre.sonora.sleep_timer';
  static const _channelName = 'Sleep Timer';
  static const _channelDescription =
      'Ongoing notification for active sleep timer countdown';

  static VoidCallback? onAddOneMin;
  static VoidCallback? onEndTimer;

  var _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInitializationSettings = AndroidInitializationSettings(
      '@drawable/ic_launcher_monochrome',
    );

    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId != null) {
          handleAction(response.actionId!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    var androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    _initialized = true;
  }

  static void handleAction(String actionId) {
    if (actionId == 'add_1_min') {
      onAddOneMin?.call();
    } else if (actionId == 'end_timer') {
      onEndTimer?.call();
    }
  }

  Future<void> updateTimerNotification(Duration remaining) async {
    if (!_initialized) await initialize();

    var minutes = remaining.inMinutes;
    var seconds = remaining.inSeconds.remainder(60);
    var hours = remaining.inHours;

    String formatted;
    if (hours > 0) {
      var remainingMin = minutes.remainder(60);
      formatted =
          '${hours.toString().padLeft(2, '0')}:${remainingMin.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      formatted =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    var androidDetails = const AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      icon: '@drawable/ic_launcher_monochrome',
      actions: [
        AndroidNotificationAction(
          'add_1_min',
          'Add 1 min',
        ),
        AndroidNotificationAction(
          'end_timer',
          'End timer',
        ),
      ],
    );

    var notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: _notificationId,
      title: 'Sleep Timer',
      body: '$formatted remaining',
      notificationDetails: notificationDetails,
    );
  }

  Future<void> cancelNotification() async {
    try {
      await _notificationsPlugin.cancel(id: _notificationId);
    } catch (_) {}
  }
}
