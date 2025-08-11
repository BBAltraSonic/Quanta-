import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
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

      // Get user stats (following count)
      final followsResponse = await _authService.supabase
          .from('follows')
          .select('avatar_id')
          .eq('user_id', userId);
      
      final followingCount = (followsResponse as List).length;

      return {
        'user': UserModel.fromJson(userResponse),
        'avatars': (avatarsResponse as List)
            .map((avatar) => AvatarModel.fromJson(avatar))
            .toList(),
        'stats': {
          'following_count': followingCount,
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
      await _authService.supabase
          .from('users')
          .update({'active_avatar_id': avatarId})
          .eq('id', userId);
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
      await _authService.supabase
          .from('users')
          .update({'preferences': preferences})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Error updating preferences: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount(String userId) async {
    try {
      // Delete user's avatars first
      await _authService.supabase
          .from('avatars')
          .delete()
          .eq('owner_user_id', userId);
      
      // Delete user
      await _authService.supabase
          .from('users')
          .delete()
          .eq('id', userId);
    } catch (e) {
      throw Exception('Error deleting account: $e');
    }
  }


}
