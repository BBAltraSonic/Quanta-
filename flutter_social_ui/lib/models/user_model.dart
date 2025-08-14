import 'package:uuid/uuid.dart';

enum UserRole { creator, admin }

// Note: Everyone is a creator by default in this social platform.
// The role field is mainly kept for admin privileges.
// Content permissions are based on ownership (_isOwnProfile), not roles.

class UserModel {
  final String id;
  final String email;
  final String username;
  final String? displayName;
  final String? profileImageUrl;
  final String? bio;
  final String? firstName;
  final String? lastName;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.profileImageUrl,
    this.bio,
    this.firstName,
    this.lastName,
    this.role = UserRole.creator,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  // Create a new user
  factory UserModel.create({
    required String email,
    required String username,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    String? firstName,
    String? lastName,
    UserRole role = UserRole.creator,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return UserModel(
      id: const Uuid().v4(),
      email: email,
      username: username,
      displayName: displayName,
      profileImageUrl: profileImageUrl,
      bio: bio,
      firstName: firstName,
      lastName: lastName,
      role: role,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
  }

  // From JSON (for Supabase data)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      bio: json['bio']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      role: UserRole.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (json['role']?.toString() ?? 'creator'),
        orElse: () => UserRole.creator,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // To JSON (for Supabase storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'display_name': displayName,
      'profile_image_url': profileImageUrl,
      'bio': bio,
      'first_name': firstName,
      'last_name': lastName,
      'role': role.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Copy with method for updates
  UserModel copyWith({
    String? email,
    String? username,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    String? firstName,
    String? lastName,
    UserRole? role,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, email: $email)';
  }
}
