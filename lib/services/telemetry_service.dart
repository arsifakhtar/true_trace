import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:android_id/android_id.dart';

class TelemetryService extends ChangeNotifier with WidgetsBindingObserver {
  final Battery _battery = Battery();

  int batteryLevel = 0;
  bool isLocked = false;
  Position? currentPosition;

  Timer? _periodicTimer;

  TelemetryService() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    batteryLevel = await _battery.batteryLevel;
    notifyListeners();

    _battery.onBatteryStateChanged.listen((_) async {
      batteryLevel = await _battery.batteryLevel;
      notifyListeners();
    });

    await _getLocationOnce();

    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
          (_) async {
        batteryLevel = await _battery.batteryLevel;
        await _getLocationOnce();
        notifyListeners();
      },
    );
  }

  Future<void> _getLocationOnce() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return;
    }

    currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isLocked = (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused);
    notifyListeners();
  }

  Future<String> getDeviceId() async {
    const androidIdPlugin = AndroidId();
    return await androidIdPlugin.getId() ?? "";
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    super.dispose();
  }
}
