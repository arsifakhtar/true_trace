package com.example.truetrace_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BatteryOptimizationHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    
    companion object {
        const val CHANNEL_NAME = "com.example.truetrace_app/battery"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isBatteryOptimized" -> {
                result.success(isBatteryOptimized())
            }
            "requestDisableBatteryOptimization" -> {
                requestDisableBatteryOptimization()
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isBatteryOptimized(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return !powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun requestDisableBatteryOptimization() {
        val intent = Intent().apply {
            action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            data = Uri.parse("package:${context.packageName}")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }
}
