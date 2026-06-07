import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ble_service.dart';
import 'api_service.dart';
import 'notification_service.dart';
import '../firebase_options.dart';

class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'finder_mode_channel',
        initialNotificationTitle: 'TrueTrace Service',
        initialNotificationContent: 'Active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      
      // Request notification permission for Android 13+
      if (await Permission.notification.isDenied) {
          // We can't request permissions in background, assume granted or ignored
      }

      // Initialize Firebase with options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize dependencies
      final api = ApiService(baseUrl: "http://192.168.29.195:8080");
      // final battery = Battery(); // Commented out for crash isolation
      
      // Initialize BLE safely
      // BleService? ble;
      // try {
      //   ble = BleService();
      // } catch (e) {
      //   debugPrint("❌ BLE Init Failed in Background: $e");
      // }
      
      // Timer for periodic tasks (every 1 minute)
      Timer.periodic(const Duration(minutes: 1), (timer) async {
        // await _performTelemetryUpload(api, battery);
        debugPrint("💓 Background Service Heartbeat");
        // if (ble != null) {
        //   await _checkAndAdvertise(ble, api);
        // }
      });
      
      // Separate timer for scanning (every 2 minutes)
      Timer.periodic(const Duration(minutes: 2), (timer) async {
        // if (ble != null) {
        //   await _performScan(ble, api);
        // }
      });

      // Listen for stop command
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    } catch (e) {
      debugPrint("❌ Background Service Crash: $e");
    }
  }

  // static Future<void> _performTelemetryUpload(ApiService api, Battery battery) async {
  //   try {
  //     final user = FirebaseAuth.instance.currentUser;
  //     if (user == null) return;

  //     // Use AndroidId to match registration
  //     const androidIdPlugin = AndroidId();
  //     final androidId = await androidIdPlugin.getId() ?? "";
      
  //     final token = await user.getIdToken();

  //     if (token == null || androidId.isEmpty) return;

  //     final batteryLevel = await battery.batteryLevel;
      
  //     // Get Location (if permitted)
  //     Map<String, double>? gps;
  //     if (await Permission.location.isGranted) {
  //       try {
  //         final position = await Geolocator.getCurrentPosition();
  //         gps = {'lat': position.latitude, 'lng': position.longitude};
  //       } catch (e) {
  //         debugPrint("Bg Location Error: $e");
  //       }
  //     }

  //     await api.uploadTelemetry(
  //       androidId, 
  //       {
  //         'battery': batteryLevel,
  //         'isLocked': true, // Assume locked/background if this service is running
  //         'gps': gps
  //       }, 
  //       token
  //     );
  //     debugPrint("📡 Background Telemetry Sent: $batteryLevel%");
  //   } catch (e) {
  //     debugPrint("❌ Background Telemetry Failed: $e");
  //   }
  // }

  static Future<void> _checkAndAdvertise(BleService ble, ApiService api) async {
    try {
      const androidIdPlugin = AndroidId();
      final androidId = await androidIdPlugin.getId() ?? "";
      
      if (androidId.isNotEmpty) {
        final resp = await api.getDeviceStatus(androidId);
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final isLost = data["isLost"] == true;
          final message = data["message"] as String?;

          if (isLost) {
             // If lost, ensure we are advertising
             // We need the device token (BLE token)
             final token = await ble.buildDeviceToken();
             // Check if already advertising? BleService doesn't expose isAdvertising state across isolates easily
             // But calling startAdvertising again is usually safe or ignored
             await ble.startAdvertising(token, message);
             debugPrint("📢 Background Advertising STARTED (Lost Mode)");
          } else {
             await ble.stopAdvertising();
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Background Advertising Check Failed: $e");
    }
  }

  static Future<void> _performScan(BleService ble, ApiService api) async {
    // Check permissions first
    if (!await ble.hasScanPermissions()) {
        debugPrint("❌ Background Scan Skipped: Permissions missing");
        return;
    }

    debugPrint("🔄 Background Scan Started");
    
    // Scan for 10 seconds
    final foundDevices = <String>{};
    
    final subscription = ble.startFinderScan((device, token) async {
      if (token != null && token.length >= 20 && !foundDevices.contains(token)) {
        foundDevices.add(token);
        debugPrint("🔍 Found device in background: $token");
        
        // Notify User
        await NotificationService.showLocalNotification(
          id: token.hashCode,
          title: "Lost Device Detected!",
          body: "A lost device is nearby. Tap to report.",
          payload: token,
        );

        // Report to Backend
        try {
          final user = FirebaseAuth.instance.currentUser;
          final idToken = await user?.getIdToken() ?? "";
          if (idToken.isNotEmpty) {
             await api.reportFound(token, "Detected in background", idToken, isBackground: true);
          }
        } catch (e) {
          debugPrint("Failed to report background detection: $e");
        }
      }
    });

    await Future.delayed(const Duration(seconds: 10));
    await subscription?.cancel();
    debugPrint("✅ Background Scan Finished");
  }
}
