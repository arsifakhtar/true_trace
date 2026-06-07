// lib/services/battery_optimization_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static const platform = MethodChannel('com.example.truetrace_app/battery');

  /// Check if app is battery optimized
  static Future<bool> isBatteryOptimized() async {
    try {
      final result = await platform.invokeMethod('isBatteryOptimized');
      return result as bool;
    } catch (e) {
      debugPrint("Error checking battery optimization: $e");
      return false;
    }
  }

  /// Request to disable battery optimization
  static Future<void> requestDisableBatteryOptimization() async {
    try {
      await platform.invokeMethod('requestDisableBatteryOptimization');
    } catch (e) {
      debugPrint("Error requesting battery optimization: $e");
    }
  }

  /// Show dialog to prompt user
  static Future<void> showBatteryOptimizationDialog(BuildContext context) async {
    final isOptimized = await isBatteryOptimized();
    
    if (!isOptimized) {
      return; // Already whitelisted
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_alert, color: Colors.orange),
            SizedBox(width: 12),
            Text("Battery Optimization"),
          ],
        ),
        content: const Text(
          "For reliable BLE tracking, please disable battery optimization for TrueTrace.\n\n"
          "This ensures Lost Mode works even when your screen is off.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              requestDisableBatteryOptimization();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }
}
