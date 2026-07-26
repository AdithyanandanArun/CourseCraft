class AppProfile {
  const AppProfile({
    required this.id,
    required this.role,
    required this.displayName,
    required this.spaceId,
  });

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      role: map['role'] as String,
      displayName: (map['display_name'] as String?)?.trim() ?? '',
      spaceId: map['space_id'] as String?,
    );
  }

  final String id;
  final String role;
  final String displayName;
  final String? spaceId;

  bool get isStudent => role == 'student';
}
