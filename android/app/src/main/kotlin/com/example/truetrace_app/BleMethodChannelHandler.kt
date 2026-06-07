package com.example.truetrace_app

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class BleMethodChannelHandler(private val context: Context) : MethodCallHandler {
    
    companion object {
        const val CHANNEL_NAME = "com.example.truetrace_app/ble"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startAdvertising" -> {
                val deviceToken = call.argument<String>("deviceToken") ?: ""
                startAdvertising(deviceToken)
                result.success(true)
            }
            "stopAdvertising" -> {
                stopAdvertising()
                result.success(true)
            }
            "isAdvertising" -> {
                // You could track this state if needed
                result.success(false)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startAdvertising(deviceToken: String) {
        val intent = Intent(context, BleAdvertisingService::class.java).apply {
            action = BleAdvertisingService.ACTION_START_ADVERTISING
            putExtra(BleAdvertisingService.EXTRA_DEVICE_TOKEN, deviceToken)
        }
        context.startForegroundService(intent)
    }

    private fun stopAdvertising() {
        val intent = Intent(context, BleAdvertisingService::class.java).apply {
            action = BleAdvertisingService.ACTION_STOP_ADVERTISING
        }
        context.startService(intent)
    }
}
