import 'package:flutter/services.dart';

class NativeBle {
  static const MethodChannel _channel = MethodChannel("truetrace_ble_channel");

  static Future<void> startAdvertising(String token) async {
    await _channel.invokeMethod("startAdvertising", {"token": token});
  }

  static Future<void> stopAdvertising() async {
    await _channel.invokeMethod("stopAdvertising");
  }
}
