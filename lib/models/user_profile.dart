class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.permissions,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final Map<String, dynamic>? permissions;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'User').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'ambulance_driver').toString(),
      permissions: json['permissions'] is Map
          ? Map<String, dynamic>.from(json['permissions'] as Map)
          : null,
    );
  }
}
