class Hospital {
  const Hospital({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.distanceKm,
    this.estimatedMinutes,
    this.traumaLevel,
    this.availableBeds,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final double? distanceKm;
  final int? estimatedMinutes;
  final String? traumaLevel;
  final int? availableBeds;

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Hospital').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      estimatedMinutes: json['estimated_minutes'] as int?,
      traumaLevel: json['trauma_level'] as String?,
      availableBeds: json['available_beds'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'distance_km': distanceKm,
    'estimated_minutes': estimatedMinutes,
    'trauma_level': traumaLevel,
    'available_beds': availableBeds,
  };
}
