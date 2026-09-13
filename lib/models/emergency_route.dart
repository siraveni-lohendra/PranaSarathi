import 'package:ambulance_flutter/models/location_point.dart';

class EmergencyRoute {
  const EmergencyRoute({
    required this.summary,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    this.trafficLevel = 'NORMAL',
    this.trafficDelaySeconds = 0,
  });

  final String summary;
  final double distanceMeters;
  final double durationSeconds;
  final List<LocationPoint> polyline;
  final String trafficLevel;
  final double trafficDelaySeconds;

  factory EmergencyRoute.fromJson(Map<String, dynamic> json) {
    final polylineList = (json['polyline'] as List? ?? const <dynamic>[])
        .map(
          (entry) => entry is Map<String, dynamic>
              ? LocationPoint.fromJson(entry)
              : LocationPoint(
                  latitude: (entry[0] as num).toDouble(),
                  longitude: (entry[1] as num).toDouble(),
                ),
        )
        .toList();

    return EmergencyRoute(
      summary: (json['summary'] ?? 'Route').toString(),
      distanceMeters:
          (json['distance_meters'] ?? json['distanceMeters'] ?? 0.0) as double,
      durationSeconds:
          (json['duration_seconds'] ?? json['durationSeconds'] ?? 0.0)
              as double,
      polyline: polylineList,
      trafficLevel: (json['traffic'] is Map && json['traffic']['level'] != null)
          ? (json['traffic']['level'] as String).toUpperCase()
          : 'NORMAL',
      trafficDelaySeconds:
          (json['traffic'] is Map && json['traffic']['delay_seconds'] != null)
          ? (json['traffic']['delay_seconds'] as num).toDouble()
          : 0.0,
    );
  }
}
