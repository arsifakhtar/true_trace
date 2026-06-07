// lib/screens/lost_mode_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/ble_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/loading_overlay.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';

class LostModeScreen extends StatefulWidget {
  const LostModeScreen({super.key});
  
  @override
  State<LostModeScreen> createState() => _LostModeScreenState();
}

class _LostModeScreenState extends State<LostModeScreen> {
  bool isLost = false;
  bool isAdvertising = false;
  String deviceId = "";
  String deviceToken = "";
  DateTime? lostModeActivatedAt;
  Timer? _pollTimer;
  Timer? _uptimeTimer;
  String uptime = "00:00:00";
  
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initDeviceInfo();
    _startPolling();
    _startUptimeTimer();
  }

  Future<void> _initDeviceInfo() async {
    final ble = Provider.of<BleService>(context, listen: false);
    deviceToken = await ble.buildDeviceToken();
    
    // Get actual Android ID for backend API calls
    // Get actual Android ID for backend API calls
    try {
      const androidIdPlugin = AndroidId();
      deviceId = await androidIdPlugin.getId() ?? "";
      if (deviceId.isEmpty) deviceId = deviceToken;
    } catch (e) {
      debugPrint("Failed to get androidId: $e");
      deviceId = deviceToken; // Fallback to token
    }
    
    // Check current advertising status
    isAdvertising = await ble.checkAdvertisingStatus();
    
    if (mounted) {
      setState(() {});
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStatus());
  }

  void _startUptimeTimer() {
    _uptimeTimer?.cancel();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isLost && lostModeActivatedAt != null) {
        final duration = DateTime.now().difference(lostModeActivatedAt!);
        setState(() {
          uptime = _formatDuration(duration);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  Future<void> _fetchStatus() async {
    if (deviceId.isEmpty) return;
    
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final resp = await api.getDeviceStatus(deviceId);
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final backendLost = data["isLost"] == true;
        final backendMessage = data["message"] as String?;
        
        if (backendLost != isLost) {
          setState(() {
            isLost = backendLost;
            if (backendLost) {
              lostModeActivatedAt = DateTime.now();
              if (backendMessage != null && _messageController.text.isEmpty) {
                 _messageController.text = backendMessage;
              }
            } else {
              lostModeActivatedAt = null;
              uptime = "00:00:00";
            }
          });
          
          if (mounted) {
            final ble = Provider.of<BleService>(context, listen: false);
            if (backendLost) {
              await ble.startAdvertising(deviceToken, backendMessage);
              await NotificationService.showLostModeNotification(
                deviceToken: deviceToken,
                activatedAt: DateTime.now(),
              );
              isAdvertising = true;
            } else {
              await ble.stopAdvertising();
              await NotificationService.cancelLostModeNotification();
              isAdvertising = false;
            }
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint("Status poll error: $e");
    }
  }

  Future<void> _toggleLostMode(bool value) async {
    if (deviceId.isEmpty) {
      if (mounted) {
        SnackbarHelper.showError(context, "Device ID not available");
      }
      return;
    }

    LoadingOverlay.show(context, message: value ? "Activating Lost Mode..." : "Deactivating Lost Mode...");

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = user == null ? "" : (await user.getIdToken() ?? "");
      final api = Provider.of<ApiService>(context, listen: false);
      
      final message = _messageController.text.trim();

      final resp = await api.setLostMode(deviceId, value, message.isNotEmpty ? message : null, idToken);

      LoadingOverlay.hide();

      if (resp.statusCode == 200) {
        setState(() {
          isLost = value;
          if (value) {
            lostModeActivatedAt = DateTime.now();
          } else {
            lostModeActivatedAt = null;
            uptime = "00:00:00";
          }
        });

        final ble = Provider.of<BleService>(context, listen: false);
        if (value) {
          await ble.startAdvertising(deviceToken, message.isNotEmpty ? message : null);
          await NotificationService.showLostModeNotification(
            deviceToken: deviceToken,
            activatedAt: DateTime.now(),
          );
          isAdvertising = true;
          if (mounted) {
            SnackbarHelper.showSuccess(context, "Lost Mode activated - Broadcasting signal");
          }
        } else {
          await ble.stopAdvertising();
          await NotificationService.cancelLostModeNotification();
          isAdvertising = false;
          if (mounted) {
            SnackbarHelper.showSuccess(context, "Lost Mode deactivated");
          }
        }
        setState(() {});
      } else {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            "Failed to toggle Lost Mode (${resp.statusCode})",
            onRetry: () => _toggleLostMode(value),
          );
        }
      }
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        SnackbarHelper.showError(
          context,
          "Network error: ${e.toString()}",
          onRetry: () => _toggleLostMode(value),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _uptimeTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BleService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lost Mode"),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          _buildStatusCard(),
          
          const SizedBox(height: 16),
          
          // Lost Mode Toggle
          _buildLostModeToggle(),
          
          const SizedBox(height: 16),
          
          // BLE Advertising Status
          _buildAdvertisingStatus(ble),
          
          if (isLost) ...[
            const SizedBox(height: 16),
            _buildUptimeCard(),
          ],
          
          const SizedBox(height: 16),
          
          // Device Info
          _buildDeviceInfo(),
          
          const SizedBox(height: 24),
          
          // Manual Controls (for testing)
          _buildManualControls(ble),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isLost ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isLost ? Icons.warning_rounded : Icons.check_circle_rounded,
              size: 64,
              color: isLost ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              isLost ? "DEVICE IN LOST MODE" : "Device Safe",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isLost ? Colors.red.shade900 : Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLost
                  ? "Broadcasting BLE signal to nearby finders"
                  : "Lost Mode is currently disabled",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isLost ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLostModeToggle() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Lost Mode",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLost
                            ? "Synced with web dashboard - Device is broadcasting"
                            : "Enable to start broadcasting lost signal",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isLost,
                  onChanged: _toggleLostMode,
                  activeColor: Colors.red,
                ),
              ],
            ),
            if (!isLost) ...[
              const Divider(height: 24),
              const Text(
                "Help Message (Optional)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "e.g., Call me at 555-0123",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 2,
                minLines: 1,
              ),
            ] else if (_messageController.text.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                "Broadcasting Message:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                _messageController.text,
                style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdvertisingStatus(BleService ble) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ble.isAdvertising ? Colors.blue.shade50 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.bluetooth_searching,
            color: ble.isAdvertising ? Colors.blue : Colors.grey,
          ),
        ),
        title: const Text(
          "BLE Advertising",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          ble.isAdvertising ? "Active - Broadcasting signal" : "Inactive",
          style: TextStyle(
            color: ble.isAdvertising ? Colors.blue.shade700 : Colors.grey.shade600,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ble.isAdvertising ? Colors.green : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            ble.isAdvertising ? "ON" : "OFF",
            style: TextStyle(
              color: ble.isAdvertising ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUptimeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  "Lost Mode Duration",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                uptime,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Hours : Minutes : Seconds",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Device Information",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.fingerprint, "Device Token", deviceToken.isEmpty ? "Loading..." : deviceToken),
            const Divider(height: 24),
            _buildInfoRow(Icons.devices, "Device ID", deviceId.isEmpty ? "Loading..." : deviceId),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualControls(BleService ble) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text(
                  "Manual Controls",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "For testing purposes only",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (ble.isAdvertising) {
                    await ble.stopAdvertising();
                    if (mounted) {
                      SnackbarHelper.showInfo(context, "BLE advertising stopped");
                    }
                  } else {
                    await ble.startAdvertising(deviceToken, _messageController.text);
                    if (mounted) {
                      SnackbarHelper.showInfo(context, "BLE advertising started");
                    }
                  }
                },
                icon: Icon(ble.isAdvertising ? Icons.stop : Icons.play_arrow),
                label: Text(ble.isAdvertising ? "Stop Advertising" : "Start Advertising"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: ble.isAdvertising ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

