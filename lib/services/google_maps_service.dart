import 'dart:convert';

import 'package:ambulance_flutter/services/app_config.dart';
import 'package:http/http.dart' as http;

class GoogleMapsService {
  static const String _placesUrl =
      'https://places.googleapis.com/v1/places:searchText';

  static const String _routesUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  Future<List<Map<String, dynamic>>> searchHospitals(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final apiKey = AppConfig.googleMapsApiKey;

    if (apiKey.trim().isEmpty) {
      throw Exception('Google Maps API key is missing');
    }

    final body = <String, dynamic>{
      'textQuery': query,
      'includedType': 'hospital',
      'languageCode': 'en',
      'maxResultCount': 10,
    };

    if (latitude != null && longitude != null) {
      body['locationBias'] = {
        'circle': {
          'center': {'latitude': latitude, 'longitude': longitude},
          'radius': 10000.0,
        },
      };
    }

    final response = await http.post(
      Uri.parse(_placesUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Hospital search failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    return List<Map<String, dynamic>>.from(data['places'] ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> calculateRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final apiKey = AppConfig.googleMapsApiKey;

    if (apiKey.trim().isEmpty) {
      throw Exception('Google Maps API key is missing');
    }

    final body = {
      'origin': {
        'location': {
          'latLng': {'latitude': originLatitude, 'longitude': originLongitude},
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destinationLatitude,
            'longitude': destinationLongitude,
          },
        },
      },
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
      'polylineQuality': 'HIGH_QUALITY',
      'polylineEncoding': 'ENCODED_POLYLINE',
    };

    final response = await http.post(
      Uri.parse(_routesUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Route calculation failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    final routes = data['routes'];

    if (routes == null || routes.isEmpty) {
      throw Exception('No route found');
    }

    return Map<String, dynamic>.from(routes.first);
  }
}
