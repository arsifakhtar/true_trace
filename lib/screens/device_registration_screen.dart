// lib/screens/device_registration_screen.dart

import 'dart:convert';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/telemetry_service.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key});

  @override
  State<DeviceRegistrationScreen> createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  final TextEditingController _phone = TextEditingController();

  String androidId = "";
  String model = "";
  String manufacturer = "";
  String osVersion = "";
  int sdk = 0;

  String deviceToken = "";
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _collectDeviceInfo();
  }

  // --------------------------------------------------------------------------
  // COLLECT DEVICE INFO (WORKS ON ALL ANDROID VERSIONS)
  // --------------------------------------------------------------------------
  Future<void> _collectDeviceInfo() async {
    try {
      // Get Android ID (works on Realme / Oppo / Android 13+)
      const androidIdPlugin = AndroidId();
      androidId = await androidIdPlugin.getId() ?? "";

      final info = await DeviceInfoPlugin().androidInfo;

      model = info.model;
      manufacturer = info.manufacturer;
      osVersion = info.version.release;
      sdk = info.version.sdkInt;

      if (androidId.isEmpty) {
        androidId = "unknown_device_id";
      }

      // Generate safe 20-character deviceToken
      final raw = base64Encode(utf8.encode(androidId));
      deviceToken = raw.padRight(20, "0").substring(0, 20);
    } catch (e) {
      debugPrint("ERROR getting device info: $e");
    }

    setState(() {});
  }

  // --------------------------------------------------------------------------
  // REGISTER DEVICE TO BACKEND
  // --------------------------------------------------------------------------
  Future<void> _registerToServer() async {
    setState(() => loading = true);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first")),
      );
      setState(() => loading = false);
      return;
    }

    final idToken = await user.getIdToken();
    if (!mounted) return;
    final api = Provider.of<ApiService>(context, listen: false);

    // Get FCM Token
    String? fcmToken = "";
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
    }

    final payload = {
      "androidId": androidId,
      "model": model,
      "manufacturer": manufacturer,
      "osVersion": osVersion,
      "sdkInt": sdk,
      "imei": null,
      "fcmToken": fcmToken ?? "",
      "deviceToken": deviceToken,
      "publicPhone": _phone.text.trim(),
      "deviceId": androidId,
    };

    final resp = await api.registerDevice(payload, idToken ?? "");

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Device Registered")));
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/lost");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error registering device: ${resp.statusCode}")),
        );
      }
    }

    setState(() => loading = false);
  }

  // --------------------------------------------------------------------------
  // UI HELPERS
  // --------------------------------------------------------------------------
  Widget _infoTile(String label, String value) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(value.isEmpty ? "-" : value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = Provider.of<TelemetryService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Device"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoTile("Device ID", androidId),
          _infoTile("Model", model),
          _infoTile("Manufacturer", manufacturer),
          _infoTile("OS Version", osVersion),
          _infoTile("SDK", sdk.toString()),
          _infoTile("Device Token", deviceToken),
          _infoTile("Battery", "${telemetry.batteryLevel}%"),
          _infoTile("Phone Locked", telemetry.isLocked ? "Yes" : "No"),

          const SizedBox(height: 20),

          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: "Public Phone Number (Finder Will See This)",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: loading ? null : _registerToServer,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: loading
                ? const CircularProgressIndicator()
                : const Text("Register Device"),
          ),

          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, "/map"),
            child: const Text("Open Map"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }
}
