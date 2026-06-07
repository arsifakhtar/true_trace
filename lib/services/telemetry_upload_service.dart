// lib/services/telemetry_upload_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:workmanager/workmanager.dart';  // DISABLED DUE TO COMPATIBILITY
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Background telemetry upload service using WorkManager
class TelemetryUploadService {
  static const String uploadTaskName = "telemetryUpload";
  static const String backendUrl = "http://192.168.29.195:8080";

  /// Initialize WorkManager for background tasks - DISABLED
  static Future<void> initialize() async {
    // await Workmanager().initialize(
    //   callbackDispatcher,
    //   isInDebugMode: true,
    // );
    debugPrint("⚠️ WorkManager disabled due to compatibility issues");
  }

  /// Register periodic telemetry upload (every 15 minutes) - DISABLED
  static Future<void> registerPeriodicUpload() async {
    // await Workmanager().registerPeriodicTask(
    //   "telemetry-upload",
    //   uploadTaskName,
    //   frequency: const Duration(minutes: 15),
    //   constraints: Constraints(
    //     networkType: NetworkType.connected,
    //   ),
    //   backoffPolicy: BackoffPolicy.exponential,
    //   backoffPolicyDelay: const Duration(seconds: 30),
    // );
    debugPrint("⚠️ Telemetry upload registration disabled");
  }

  /// Cancel periodic upload - DISABLED
  static Future<void> cancelPeriodicUpload() async {
    // await Workmanager().cancelByUniqueName("telemetry-upload");
    debugPrint("⚠️ Telemetry upload cancellation disabled");
  }

  /// Manual telemetry upload (for testing)
  static Future<void> uploadNow() async {
    await uploadTelemetry();
  }

  /// Internal upload function
  static Future<void> uploadTelemetry() async {
    try {
      // Get device ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('deviceId') ?? '';
      
      if (deviceId.isEmpty) {
        debugPrint("⚠️ No device ID found, skipping telemetry upload");
        return;
      }

      // Collect telemetry data
      final battery = Battery();
      final batteryLevel = await battery.batteryLevel;
      
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint("⚠️ Location error: $e");
      }

      // Prepare payload
      final payload = {
        'deviceId': deviceId,
        'battery': batteryLevel,
        'isLocked': false, // Would need native check
        'gps': position != null
            ? {
                'lat': position.latitude,
                'lng': position.longitude,
              }
            : null,
        'network': 'wifi', // Simplified
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Upload to backend
      final response = await http.post(
        Uri.parse('$backendUrl/api/telemetry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint("✅ Telemetry uploaded successfully");
      } else {
        debugPrint("⚠️ Telemetry upload failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Telemetry upload error: $e");
    }
  }
}

/// WorkManager callback dispatcher (must be top-level function) - DISABLED
// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     debugPrint("🔄 Background task started: $task");
//     
//     try {
//       await TelemetryUploadService.uploadTelemetry();
//       return Future.value(true);
//     } catch (e) {
//       debugPrint("❌ Background task failed: $e");
//       return Future.value(false);
//     }
//   });
// }
