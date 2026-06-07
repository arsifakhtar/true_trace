// lib/services/permission_service.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class PermissionService {
  static Future<bool> requestBlePermissions() async {
    LocationPermission loc = await Geolocator.checkPermission();
    if (loc == LocationPermission.denied || loc == LocationPermission.deniedForever) {
      loc = await Geolocator.requestPermission();
      if (loc == LocationPermission.denied || loc == LocationPermission.deniedForever) {
        return false;
      }
    }

    final scan = await Permission.bluetoothScan.request();
    final conn = await Permission.bluetoothConnect.request();
    final advert = await Permission.bluetoothAdvertise.request();

    return scan.isGranted && conn.isGranted && advert.isGranted;
  }
}
