// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  ApiService({required this.baseUrl});

  Future<http.Response> registerDevice(Map<String, dynamic> payload, String idToken) {
    return http.post(
      Uri.parse('$baseUrl/api/devices'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(payload),
    );
  }

  Future<http.Response> setLostMode(String deviceId, bool isLost, String? message, String idToken) {
    return http.post(
      Uri.parse('$baseUrl/api/set-lost'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'deviceId': deviceId, 
        'isLost': isLost,
        if (message != null) 'message': message,
      }),
    );
  }

  Future<http.Response> getDeviceStatus(String deviceId) {
    return http.get(
      Uri.parse('$baseUrl/api/device-status/$deviceId'),
    );
  }

  Future<http.Response> markLost(String deviceToken, String idToken) {
    return http.post(
      Uri.parse('$baseUrl/api/lost'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'deviceToken': deviceToken}),
    );
  }

  Future<http.Response> reportFound(String deviceToken, String finderMsg, String idToken, {bool isBackground = false}) {
    return http.post(
      Uri.parse('$baseUrl/api/found'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'deviceToken': deviceToken, 
        'message': finderMsg,
        'isBackground': isBackground,
      }),
    );
  }

  Future<http.Response> uploadTelemetry(String deviceId, Map<String, dynamic> telemetry, String idToken) {
    return http.post(
      Uri.parse('$baseUrl/api/telemetry'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'deviceId': deviceId, 'telemetry': telemetry}),
    );
  }
}
