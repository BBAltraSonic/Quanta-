import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../utils/environment.dart';
import 'auth_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final AuthService _authService = AuthService();

  // Get user profile with avatars
  Future<Map<String, dynamic>> getUserProfileData(String userId) async {
    try {
      // Get user data from Supabase
      final userResponse = await _authService.supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      // Get user's avatars
      final avatarsResponse = await _authService.supabase
          .from('avatars')
          .select()
          .eq('owner_user_id', userId);

      // Get user stats
      final statsResponse = await _authService.supabase
          .from('follows')
          .select('avatar_id', const FetchOptions(count: CountOption.exact))
          .eq('user_id', userId);

      return {
        'user': UserModel.fromJson(userResponse),
        'avatars': (avatarsResponse as List)
            .map((avatar) => AvatarModel.fromJson(avatar))
            .toList(),
        'stats': {
          'following_count': statsResponse.count ?? 0,
          'followers_count': userResponse['followers_count'] ?? 0,
          'posts_count': userResponse['posts_count'] ?? 0,
        },
        'preferences': {},
      };
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
      final updateData = <String, dynamic>{};
      if (displayName != null) updateData['display_name'] = displayName;
      if (username != null) updateData['username'] = username;
      if (email != null) updateData['email'] = email;
      if (profileImageUrl != null) updateData['profile_image_url'] = profileImageUrl;

      final response = await _authService.supabase
          .from('users')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  // Upload profile image
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      final fileName = '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Supabase storage
      await _authService.supabase.storage
          .from('avatars')
          .upload(fileName, imageFile);

      // Get public URL
      final publicUrl = _authService.supabase.storage
          .from('avatars')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  // Get user's avatars
  Future<List<AvatarModel>> getUserAvatars(String userId) async {
    try {
      final response = await _authService.supabase
          .from('avatars')
          .select()
          .eq('owner_user_id', userId);

      return (response as List)
          .map((avatar) => AvatarModel.fromJson(avatar))
          .toList();
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
