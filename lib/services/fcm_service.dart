
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _local.initialize(initSettings);

    FirebaseMessaging.onMessage.listen(_showNotification);

    await _fcm.requestPermission();
  }

  static Future<void> _showNotification(RemoteMessage msg) async {
    const androidDetails = AndroidNotificationDetails(
      "truetrace",
      "TrueTrace Alerts",
      channelDescription: "Notifications for device events",
      importance: Importance.max,
      priority: Priority.high,
    );

    const notif = NotificationDetails(android: androidDetails);

    await _local.show(
      0,
      msg.notification?.title ?? "TrueTrace",
      msg.notification?.body ?? "",
      notif,
    );
  }
}
