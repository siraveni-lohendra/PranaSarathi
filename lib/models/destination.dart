class Destination {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const Destination({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory Destination.fromGooglePlace(Map<String, dynamic> json) {
    final location = Map<String, dynamic>.from(json['location'] ?? {});

    final displayName = Map<String, dynamic>.from(json['displayName'] ?? {});

    return Destination(
      id: json['id']?.toString() ?? '',
      name: displayName['text']?.toString() ?? 'Hospital',
      address: json['formattedAddress']?.toString() ?? '',
      latitude: (location['latitude'] as num).toDouble(),
      longitude: (location['longitude'] as num).toDouble(),
    );
  }
}
