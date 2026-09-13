import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPoint {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    this.accuracy,
    this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double? speed;
  final double? heading;
  final double? accuracy;
  final DateTime? timestamp;

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: (json['latitude'] ?? json['lat'] ?? 0.0) as double,
      longitude: (json['longitude'] ?? json['lng'] ?? 0.0) as double,
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'speed': speed,
    'heading': heading,
    'accuracy': accuracy,
    'timestamp': timestamp?.toIso8601String(),
  };

  LatLng toLatLng() => LatLng(latitude, longitude);
}
