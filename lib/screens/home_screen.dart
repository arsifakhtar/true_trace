import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telemetry_service.dart';
import '../services/api_service.dart';
import '../services/ble_service.dart';
import '../widgets/lost_mode_banner.dart';
import '../widgets/telemetry_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String androidId = "";
  String model = "";
  String manufacturer = "";
  String osVersion = "";
  bool loading = true;
  bool isLostMode = false;

  Timer? _telemetryTimer;

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
    _checkLostModeStatus();
    _startTelemetryUpload();
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  void _startTelemetryUpload() {
    _telemetryTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendTelemetry());
    // Also send immediately
    Future.delayed(const Duration(seconds: 2), _sendTelemetry);
  }

  Future<void> _sendTelemetry() async {
    if (!mounted) return;
    try {
      final telemetry = Provider.of<TelemetryService>(context, listen: false);
      final api = Provider.of<ApiService>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null && androidId.isNotEmpty) {
        final token = await user.getIdToken();
        if (token != null) {
          await api.uploadTelemetry(
            androidId, 
            {
              'battery': telemetry.batteryLevel,
              'isLocked': telemetry.isLocked,
              'gps': telemetry.currentPosition != null ? {
                'lat': telemetry.currentPosition!.latitude,
                'lng': telemetry.currentPosition!.longitude
              } : null
            }, 
            token
          );
          debugPrint("Telemetry sent successfully");
        }
      }
    } catch (e) {
      debugPrint("Telemetry upload failed: $e");
    }
  }

  Future<void> _loadDeviceData() async {
    try {
      const idPlugin = AndroidId();
      androidId = await idPlugin.getId() ?? "";

      final info = await DeviceInfoPlugin().androidInfo;
      model = info.model;
      manufacturer = info.manufacturer;
      osVersion = info.version.release;
    } catch (e) {
      debugPrint("Device info error: $e");
    }

    setState(() => loading = false);
  }

  Future<void> _checkLostModeStatus() async {
    if (!mounted) return;
    
    // 1. Check local BLE status
    final ble = Provider.of<BleService>(context, listen: false);
    bool localAdvertising = await ble.checkAdvertisingStatus();

    // 2. Check backend status
    try {
      if (androidId.isNotEmpty) {
        final api = Provider.of<ApiService>(context, listen: false);
        final resp = await api.getDeviceStatus(androidId);
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final backendLost = data["isLost"] == true;
          
          // If backend says LOST but we are NOT advertising, START advertising
          if (backendLost && !localAdvertising) {
             final token = await ble.buildDeviceToken();
             await ble.startAdvertising(token, data["message"]);
             localAdvertising = true;
          } 
          // If backend says SAFE but we ARE advertising, STOP advertising
          else if (!backendLost && localAdvertising) {
             await ble.stopAdvertising();
             localAdvertising = false;
          }
        }
      }
    } catch (e) {
      debugPrint("Sync status failed: $e");
    }

    if (mounted) {
      setState(() {
        isLostMode = localAdvertising;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = Provider.of<TelemetryService>(context);
    final ble = Provider.of<BleService>(context);

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("TrueTrace Home"),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              navigator.pushReplacementNamed("/login");
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDeviceData();
          await _checkLostModeStatus();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Lost Mode Banner (if active)
            if (ble.isAdvertising)
              Column(
                children: [
                  LostModeBanner(
                    onTap: () => Navigator.pushNamed(context, "/lost"),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Welcome Section
            _buildWelcomeCard(),

            const SizedBox(height: 16),

            // Telemetry Card
            TelemetryCard(
              batteryLevel: telemetry.batteryLevel,
              isLocked: telemetry.isLocked,
              lastUpdate: DateTime.now(),
              isOnline: true,
            ),

            const SizedBox(height: 16),

            // Device Information
            _buildDeviceInfoCard(),

            const SizedBox(height: 16),

            // Location Info (if available)
            if (telemetry.currentPosition != null)
              _buildLocationCard(telemetry),

            const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  "TrueTrace",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Your device is protected with BLE tracking technology",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.smartphone, "Model", model.isEmpty ? "Unknown" : model),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.business, "Manufacturer", manufacturer.isEmpty ? "Unknown" : manufacturer),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.android, "Android Version", osVersion.isEmpty ? "Unknown" : osVersion),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.fingerprint, "Device ID", androidId.isEmpty ? "Unknown" : "${androidId.substring(0, 16)}..."),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
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
                ),
              ),
              const SizedBox(height: 2),
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

  Widget _buildLocationCard(TelemetryService telemetry) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.location_on, color: Colors.green.shade700),
        ),
        title: const Text(
          "Current Location",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "${telemetry.currentPosition!.latitude.toStringAsFixed(4)}, "
          "${telemetry.currentPosition!.longitude.toStringAsFixed(4)}",
        ),
        trailing: IconButton(
          icon: const Icon(Icons.map),
          onPressed: () => Navigator.pushNamed(context, "/map"),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.phonelink_lock,
                label: "Lost Mode",
                color: Colors.red,
                onTap: () => Navigator.pushNamed(context, "/lost"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.search,
                label: "Finder Mode",
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, "/finder"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.map,
                label: "View Map",
                color: Colors.green,
                onTap: () => Navigator.pushNamed(context, "/map"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.edit,
                label: "Edit Details",
                color: Colors.orange,
                onTap: () => Navigator.pushNamed(context, "/register"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
