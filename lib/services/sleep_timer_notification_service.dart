import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sonora/l10n/app_localizations.dart';

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

  /// Shows the countdown, or the "finishing song" text when [finishingSong].
  Future<void> updateTimerNotification(
    Duration remaining,
    AppLocalizations l10n, {
    bool finishingSong = false,
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

      var androidDetails = AndroidNotificationDetails(
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
            l10n.plusOneMin,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'end_timer',
            l10n.endTimer,
            showsUserInterface: true,
          ),
        ],
      );

      var notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: _notificationId,
        title: l10n.sleepTimer,
        body: finishingSong
            ? l10n.sleepTimerFinishingSong
            : l10n.sleepTimerRemaining(formatted),
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
