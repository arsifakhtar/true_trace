import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';


class BleService extends ChangeNotifier {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  StreamSubscription<DiscoveredDevice>? _scanSub;

  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  /// -------------------------------------------------------
  /// DEVICE TOKEN
  /// -------------------------------------------------------
  Future<String> buildDeviceToken() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      // Use androidId as a stable identifier
      final rawId = info.data["androidId"]?.toString() ?? info.id;
      final raw = base64Encode(utf8.encode(rawId));
      return raw.padRight(20, "0").substring(0, 20);
    }
    return "unknown-device-id".padRight(20, "0").substring(0, 20);
  }

  /// -------------------------------------------------------
  /// SCANNING PERMISSIONS
  /// -------------------------------------------------------
  Future<bool> _checkScanPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.locationWhenInUse.isGranted;
  }

  Future<bool> hasScanPermissions() async {
    // Check if we have necessary permissions without requesting them
    if (Platform.isAndroid) {
       // On Android 12+ we need BLUETOOTH_SCAN
       if (await Permission.bluetoothScan.status.isDenied) return false;
       if (await Permission.bluetoothConnect.status.isDenied) return false;
    }
    // Location is often needed too
    return await Permission.locationWhenInUse.isGranted;
  }
  
  Future<bool> _checkAdvertisePermissions() async {
    await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].request();
    
    return await Permission.bluetoothAdvertise.isGranted &&
        await Permission.bluetoothConnect.isGranted;
  }

  /// -------------------------------------------------------
  /// FINDER MODE SCAN
  /// -------------------------------------------------------
  StreamSubscription<DiscoveredDevice>? startFinderScan(
      void Function(DiscoveredDevice device, String? token) onFound) {
    if (!_checkScanPermissionsSync()) { // We need a sync check or handle async better
       // For simplicity in this context, we assume permissions are checked or we just try
    }

    stopScan();

    // Scan for any device, or filter by service UUID if we had one.
    // For now, we scan all and try to extract token.
    _scanSub = _ble.scanForDevices(withServices: []).listen((device) {
      final token = _extractToken(device);
      if (token != null) {
         onFound(device, token);
      }
    }, onError: (e) {
      debugPrint("Scan error: $e");
    });
    
    return _scanSub;
  }
  
  bool _checkScanPermissionsSync() {
    // This is a placeholder. Permissions should be checked async before calling this.
    return true; 
  }

  /// -------------------------------------------------------
  /// EXTRACT TOKEN FROM ADVERTISEMENT
  /// -------------------------------------------------------
  String? _extractToken(DiscoveredDevice device) {
    try {
      // Check Manufacturer Data
      if (device.manufacturerData.isNotEmpty) {
        final raw = utf8.decode(device.manufacturerData, allowMalformed: true);
        // We expect a format, maybe just the token or JSON
        // For simplicity, let's assume the token is the first 20 chars
        if (raw.length >= 20) {
          return raw.substring(0, 20);
        }
      }
      // Also check Service Data if needed
    } catch (e) {
      // debugPrint("Token decode error: $e");
    }
    return null;
  }

  /// -------------------------------------------------------
  /// STOP SCAN
  /// -------------------------------------------------------
  void stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
  }

  /// -------------------------------------------------------
  /// ADVERTISING (via flutter_ble_peripheral)
  /// -------------------------------------------------------
  Future<void> startAdvertising(String token, String? message) async {
    if (!await _checkAdvertisePermissions()) {
      debugPrint("BLE Advertise permissions denied");
      return;
    }

    // Create advertisement data
    // We'll put the token in manufacturer data for now as it's a simple payload
    // If message is present, we might append it or put it in local name
    
    final manufacturerData = utf8.encode(token); 
    // Note: BLE payload is small (legacy ~31 bytes). 
    // Token is 20 bytes. We have little room for message.
    // We might need to rely on the backend for the message if it's long.
    // Or use Extended Advertising (not supported everywhere).
    
    final AdvertiseData advertiseData = AdvertiseData(
      includeDeviceName: true,
      manufacturerId: 0xFFFF, // Test ID
      manufacturerData: Uint8List.fromList(manufacturerData),
      // We can try to put a short message in the local name or service data
      // For now, let's stick to token.
    );

    try {
      await _peripheral.start(advertiseData: advertiseData);
      _isAdvertising = true;
      notifyListeners();
      debugPrint("BLE Advertising started with token: $token");
    } catch (e) {
      debugPrint("Failed to start advertising: $e");
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _peripheral.stop();
      _isAdvertising = false;
      notifyListeners();
      debugPrint("BLE Advertising stopped");
    } catch (e) {
      debugPrint("Failed to stop advertising: $e");
    }
  }

  Future<bool> checkAdvertisingStatus() async {
    return _peripheral.isAdvertising;
  }

  @override
  void dispose() {
    stopScan();
    stopAdvertising();
    super.dispose();
  }
}
