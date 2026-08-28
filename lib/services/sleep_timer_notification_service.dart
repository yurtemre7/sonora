import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _initialized = true;
      return;
    }

    try {
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
      );

      _initialized = true;
    } catch (e) {
      debugPrint('SleepTimerNotificationService initialize: $e');
    }
  }

  static void handleAction(String actionId) {
    if (actionId == 'add_1_min') {
      onAddOneMin?.call();
    } else if (actionId == 'end_timer') {
      onEndTimer?.call();
    }
  }

  Future<void> updateTimerNotification(
    Duration remaining, {
    String? customBody,
  }) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    try {
      if (!_initialized) await initialize();
      if (!_initialized) return;

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
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'end_timer',
            'End timer',
            showsUserInterface: true,
          ),
        ],
      );

      var notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: _notificationId,
        title: 'Sleep Timer',
        body: customBody ?? '$formatted remaining',
        notificationDetails: notificationDetails,
      );
    } catch (_) {}
  }

  Future<void> cancelNotification() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await _notificationsPlugin.cancel(id: _notificationId);
    } catch (_) {}
  }
}
