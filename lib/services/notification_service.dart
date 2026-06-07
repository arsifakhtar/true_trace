// lib/services/notification_service.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String lostModeChannelId = 'lost_mode_channel';
  static const String lostModeChannelName = 'Lost Mode Alerts';
  static const int lostModeNotificationId = 2001;

  /// Initialize notification service
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Initialize FCM
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions for Android 13+
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
    }

    // Create notification channel for Android
    await _createNotificationChannels();
  }

  static Future<void> _createNotificationChannels() async {
    const lostModeChannel = AndroidNotificationChannel(
      lostModeChannelId,
      lostModeChannelName,
      description: 'Critical alerts when device enters Lost Mode',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(lostModeChannel);
  }

  /// Show big "Lost Mode Active" notification
  static Future<void> showLostModeNotification({
    required String deviceToken,
    required DateTime activatedAt,
  }) async {
    final timeString = _formatTime(activatedAt);

    final androidDetails = AndroidNotificationDetails(
      lostModeChannelId,
      lostModeChannelName,
      channelDescription: 'Critical alerts when device enters Lost Mode',
      importance: Importance.max,
      priority: Priority.max,
      styleInformation: BigTextStyleInformation(
        'Your device has been marked as LOST and is now broadcasting a BLE signal. '
        'Activated at $timeString. Anyone nearby with the TrueTrace Finder app may detect your device. '
        'Tap to view Lost Mode details.',
        htmlFormatBigText: true,
        contentTitle: '🔴 DEVICE IN LOST MODE',
        htmlFormatContentTitle: true,
      ),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]), // SOS pattern
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true, // Cannot be dismissed
      autoCancel: false,
      color: Colors.red,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      lostModeNotificationId,
      '🔴 DEVICE IN LOST MODE',
      'Activated at $timeString - Broadcasting signal',
      notificationDetails,
      payload: 'lost_mode',
    );
  }

  /// Cancel Lost Mode notification
  static Future<void> cancelLostModeNotification() async {
    await _notifications.cancel(lostModeNotificationId);
  }

  /// Show finder detected notification (Backend triggered or local)
  static Future<void> showFinderDetectedNotification({
    required String location,
    required DateTime detectedAt,
  }) async {
    final timeString = _formatTime(detectedAt);

    final androidDetails = AndroidNotificationDetails(
      lostModeChannelId,
      lostModeChannelName,
      channelDescription: 'A finder has detected your lost device',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        'A finder has detected your device at $location. '
        'Detection time: $timeString. '
        'Tap to view location on map.',
        htmlFormatBigText: true,
        contentTitle: '✅ Lost Device Found!',
        htmlFormatContentTitle: true,
      ),
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      lostModeNotificationId + 1,
      '✅ Lost Device Found!',
      'Detected at $location',
      notificationDetails,
      payload: 'finder_detected',
    );
  }

  /// Show generic local notification (used by Background Service)
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'finder_mode_channel',
      'Finder Mode Alerts',
      channelDescription: 'Notifications for detected devices in Finder Mode',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint("Got foreground message: ${message.data}");
    if (message.data['type'] == 'lost_mode_enable') {
      await showLostModeNotification(
        deviceToken: message.data['deviceId'] ?? 'unknown',
        activatedAt: DateTime.now(),
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling background message: ${message.data}");
  
  if (message.data['type'] == 'lost_mode_enable') {
    await NotificationService.showLostModeNotification(
      deviceToken: message.data['deviceId'] ?? 'unknown',
      activatedAt: DateTime.now(),
    );
  }
}
