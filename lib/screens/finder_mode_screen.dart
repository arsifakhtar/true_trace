// lib/screens/finder_mode_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';

import '../services/ble_service.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/loading_overlay.dart';

class DetectedDevice {
  final String token;
  final int rssi;
  final DateTime detectedAt;
  String distance;
  bool reported;

  DetectedDevice({
    required this.token,
    required this.rssi,
    required this.detectedAt,
    this.distance = "Unknown",
    this.reported = false,
  });
}

class FinderModeScreen extends StatefulWidget {
  const FinderModeScreen({super.key});

  @override
  State<FinderModeScreen> createState() => _FinderModeScreenState();
}

class _FinderModeScreenState extends State<FinderModeScreen> {
  bool scanning = false;
  final Map<String, DetectedDevice> detectedDevices = {};
  final Set<String> reportedTokens = {};
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  String _calculateDistance(int rssi) {
    // RSSI to distance estimation (rough approximation)
    // Formula: distance = 10 ^ ((Measured Power - RSSI) / (10 * N))
    // Measured Power typically -59 dBm at 1 meter
    // N (path loss exponent) typically 2-4 for indoor environments
    
    const measuredPower = -59;
    const pathLossExponent = 2.5;
    
    if (rssi == 0) {
      return "Unknown";
    }
    
    final distance = pow(10, (measuredPower - rssi) / (10 * pathLossExponent));
    
    if (distance < 1) {
      return "Very Close (<1m)";
    } else if (distance < 3) {
      return "Near (${distance.toStringAsFixed(1)}m)";
    } else if (distance < 10) {
      return "Medium (${distance.toStringAsFixed(1)}m)";
    } else {
      return "Far (${distance.toStringAsFixed(0)}m)";
    }
  }

  Future<void> _startScanning() async {
    setState(() {
      scanning = true;
      detectedDevices.clear();
    });

    final ble = Provider.of<BleService>(context, listen: false);
    
    ble.startFinderScan((device, token) {
      if (token != null && token.length >= 20) {
        setState(() {
          if (!detectedDevices.containsKey(token)) {
            final detectedDevice = DetectedDevice(
              token: token,
              rssi: device.rssi,
              detectedAt: DateTime.now(),
              distance: _calculateDistance(device.rssi),
              reported: reportedTokens.contains(token),
            );
            
            detectedDevices[token] = detectedDevice;
            
            // Auto-vibrate on first detection
            if (!reportedTokens.contains(token)) {
              _vibrateOnDetection();
            }
          } else {
            // Update RSSI and distance for existing device
            detectedDevices[token]!.distance = _calculateDistance(device.rssi);
          }
        });
      }
    });

    SnackbarHelper.showInfo(context, "Scanning for lost devices...");
  }

  void _stopScanning() {
    final ble = Provider.of<BleService>(context, listen: false);
    ble.stopScan();
    setState(() => scanning = false);
    SnackbarHelper.showInfo(context, "Scan stopped");
  }

  Future<void> _vibrateOnDetection() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }
  }

  Future<void> _reportFound(String token) async {
    if (currentPosition == null) {
      SnackbarHelper.showWarning(context, "Location not available");
      return;
    }

    LoadingOverlay.show(context, message: "Reporting found device...");

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = user == null ? "" : await user.getIdToken() ?? "";
      
      final api = Provider.of<ApiService>(context, listen: false);
      final response = await api.reportFound(
        token,
        "Detected at ${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}",
        idToken,
      );

      LoadingOverlay.hide();

      if (response.statusCode == 200) {
        setState(() {
          reportedTokens.add(token);
          if (detectedDevices.containsKey(token)) {
            detectedDevices[token]!.reported = true;
          }
        });
        
        _vibrateOnDetection();
        SnackbarHelper.showSuccess(
          context,
          "✅ Alert sent to device owner! Thank you for helping.",
        );
      } else {
        SnackbarHelper.showError(
          context,
          "Failed to report (${response.statusCode})",
          onRetry: () => _reportFound(token),
        );
      }
    } catch (e) {
      LoadingOverlay.hide();
      SnackbarHelper.showError(
        context,
        "Network error: ${e.toString()}",
        onRetry: () => _reportFound(token),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Finder Mode"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Card
          _buildHeaderCard(),
          
          // Scan Control
          _buildScanControl(),
          
          // Background Scan Toggle
          _buildBackgroundScanToggle(),
          
          // Detected Devices List
          Expanded(
            child: detectedDevices.isEmpty
                ? _buildEmptyState()
                : _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: scanning ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              scanning ? "Scanning for Lost Devices..." : "Ready to Scan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scanning ? Colors.blue.shade900 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              scanning
                  ? "Keep your device nearby to detect lost phones"
                  : "Tap the button below to start scanning",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            if (detectedDevices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "${detectedDevices.length} device(s) detected",
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: scanning ? _stopScanning : _startScanning,
          icon: Icon(scanning ? Icons.stop : Icons.play_arrow),
          label: Text(scanning ? "Stop Scanning" : "Start Scanning"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: scanning ? Colors.red : Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundScanToggle() {
    return FutureBuilder<bool>(
      future: FlutterBackgroundService().isRunning(),
      builder: (context, snapshot) {
        final isRunning = snapshot.data ?? false;
        return SwitchListTile(
          title: const Text("Background Scanning"),
          subtitle: const Text("Scan periodically even when app is closed"),
          value: isRunning,
          onChanged: (value) async {
            final service = FlutterBackgroundService();
            if (value) {
              await service.startService();
            } else {
              service.invoke("stopService");
            }
            setState(() {});
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              scanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              scanning
                  ? "Searching for lost devices..."
                  : "No devices detected yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              scanning
                  ? "Walk around to detect nearby lost devices"
                  : "Start scanning to help find lost devices",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    final devices = detectedDevices.values.toList()
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return _buildDeviceCard(device);
      },
    );
  }

  Widget _buildDeviceCard(DetectedDevice device) {
    final timeAgo = _getTimeAgo(device.detectedAt);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: device.reported ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    device.reported ? Icons.check_circle : Icons.phonelink_lock,
                    color: device.reported ? Colors.green : Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.reported ? "Reported Device" : "Lost Device Detected",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Detected $timeAgo",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.signal_cellular_alt,
                    "Distance",
                    device.distance,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    Icons.fingerprint,
                    "Token",
                    "${device.token.substring(0, 8)}...",
                    Colors.purple,
                  ),
                ),
              ],
            ),
            if (!device.reported) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _reportFound(device.token),
                  icon: const Icon(Icons.send),
                  label: const Text("Report Found to Owner"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Owner has been notified. Thank you!",
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    
    if (difference.inSeconds < 60) {
      return "just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return "${difference.inDays}d ago";
    }
  }
}
