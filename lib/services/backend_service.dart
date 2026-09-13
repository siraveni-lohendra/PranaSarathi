import 'dart:convert';

import 'package:ambulance_flutter/models/hospital.dart';
import 'package:ambulance_flutter/models/location_point.dart';
import 'package:ambulance_flutter/services/api_client.dart';
import 'package:ambulance_flutter/services/app_config.dart';

class BackendService {
  BackendService() : _client = ApiClient(baseUrl: AppConfig.backendBaseUrl);

  final ApiClient _client;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final form = {'username': email, 'password': password};
    final response = await _client.post(
      '/auth/login',
      body: form,
      asForm: true,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Login failed: ${response.body}');
  }

  Future<List<Hospital>> listHospitals(String token) async {
    final response = await _client.get(
      '/ambulance/hospitals',
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as List;
      return decoded
          .map((item) => Hospital.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Unable to load hospitals: ${response.body}');
  }

  Future<Map<String, dynamic>> startEmergency({
    required String token,
    required String hospitalId,
    required LocationPoint currentLocation,
  }) async {
    final response = await _client.post(
      '/emergency/start',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'hospitalId': hospitalId,
        'currentLocation': currentLocation.toJson(),
        'emergencyLevel': 'Critical Emergency',
        'trafficFactor': 1.0,
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Unable to start emergency: ${response.body}');
  }

  Future<Map<String, dynamic>> sendTelemetry({
    required String token,
    required String sessionId,
    required LocationPoint currentLocation,
  }) async {
    final response = await _client.post(
      '/emergency/telemetry',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'sessionId': sessionId,
        'currentLocation': currentLocation.toJson(),
        'trafficFactor': 1.0,
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Unable to send telemetry: ${response.body}');
  }

  void dispose() => _client.dispose();
}
