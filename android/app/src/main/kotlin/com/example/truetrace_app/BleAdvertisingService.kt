package com.example.truetrace_app

import android.app.*
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.ParcelUuid
import androidx.core.app.NotificationCompat
import java.nio.charset.StandardCharsets
import java.util.*

class BleAdvertisingService : Service() {

    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var deviceToken: String = ""
    private var isAdvertising = false

    companion object {
        const val CHANNEL_ID = "BLE_ADVERTISING_CHANNEL"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START_ADVERTISING = "com.example.truetrace_app.START_ADVERTISING"
        const val ACTION_STOP_ADVERTISING = "com.example.truetrace_app.STOP_ADVERTISING"
        const val EXTRA_DEVICE_TOKEN = "device_token"
        
        // Custom UUID for TrueTrace
        val SERVICE_UUID: UUID = UUID.fromString("0000FFF0-0000-1000-8000-00805F9B34FB")
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
        bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_ADVERTISING -> {
                deviceToken = intent.getStringExtra(EXTRA_DEVICE_TOKEN) ?: ""
                startAdvertising()
            }
            ACTION_STOP_ADVERTISING -> {
                stopAdvertising()
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun startAdvertising() {
        if (isAdvertising) {
            return
        }

        try {
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setConnectable(false)
                .setTimeout(0)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .build()

            // Convert device token to bytes
            val tokenBytes = deviceToken.toByteArray(StandardCharsets.UTF_8).take(20).toByteArray()

            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceUuid(ParcelUuid(SERVICE_UUID))
                .addManufacturerData(0xFFFF, tokenBytes) // Use manufacturer ID 0xFFFF
                .build()

            advertiseCallback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                    super.onStartSuccess(settingsInEffect)
                    isAdvertising = true
                    updateNotification("Broadcasting Lost Mode Signal")
                }

                override fun onStartFailure(errorCode: Int) {
                    super.onStartFailure(errorCode)
                    isAdvertising = false
                    updateNotification("Failed to broadcast (Error: $errorCode)")
                }
            }

            bluetoothLeAdvertiser?.startAdvertising(settings, data, advertiseCallback)
            
            // Start as foreground service
            val notification = createNotification("Starting Lost Mode broadcast...")
            startForeground(NOTIFICATION_ID, notification)
            
        } catch (e: SecurityException) {
            updateNotification("Bluetooth permission denied")
        }
    }

    private fun stopAdvertising() {
        try {
            advertiseCallback?.let {
                bluetoothLeAdvertiser?.stopAdvertising(it)
            }
            isAdvertising = false
        } catch (e: SecurityException) {
            // Permission denied
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Lost Mode BLE Advertising",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Broadcasts BLE signal when device is lost"
            }
            
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(message: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("TrueTrace - Lost Mode Active")
            .setContentText(message)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(message: String) {
        val notification = createNotification(message)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopAdvertising()
    }
}
