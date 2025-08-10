import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../utils/environment.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final String baseUrl = Environment.apiBaseUrl;

  // Get user profile with avatars
  Future<Map<String, dynamic>> getUserProfileData(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'user': UserModel.fromJson(data['user']),
          'avatars': (data['avatars'] as List)
              .map((avatar) => AvatarModel.fromJson(avatar))
              .toList(),
          'stats': data['stats'] ?? {},
          'preferences': data['preferences'] ?? {},
        };
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<UserModel> updateUserProfile({
    required String userId,
    String? displayName,
    String? username,
    String? email,
    String? profileImageUrl,
  }) async {
    try {
      final body = {
        'display_name': displayName,
        'username': username,
        'email': email,
        'profile_image_url': profileImageUrl,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/user/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  // Upload profile image
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/profile-image'),
      );

      request.fields['user_id'] = userId;
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ));

      final response = await request.send();
      final responseData = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final data = json.decode(responseData.body);
        return data['image_url'];
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  // Get user's avatars
  Future<List<AvatarModel>> getUserAvatars(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/$userId/avatars'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['avatars'] as List)
            .map((avatar) => AvatarModel.fromJson(avatar))
            .toList();
      } else {
        throw Exception('Failed to load avatars: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading user avatars: $e');
      return [];
    }
  }

  // Set active avatar
  Future<void> setActiveAvatar(String userId, String avatarId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/$userId/active-avatar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'avatar_id': avatarId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to set active avatar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error setting active avatar: $e');
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/user/$userId/preferences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'preferences': preferences}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update preferences: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating preferences: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete account: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting account: $e');
    }
  }


}
