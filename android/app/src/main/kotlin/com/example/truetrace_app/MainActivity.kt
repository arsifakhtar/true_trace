package com.example.truetrace_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // BLE advertising handler
        val bleHandler = BleMethodChannelHandler(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BleMethodChannelHandler.CHANNEL_NAME
        ).setMethodCallHandler(bleHandler)
        
        // Battery optimization handler
        val batteryHandler = BatteryOptimizationHandler(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BatteryOptimizationHandler.CHANNEL_NAME
        ).setMethodCallHandler(batteryHandler)
    }
}
