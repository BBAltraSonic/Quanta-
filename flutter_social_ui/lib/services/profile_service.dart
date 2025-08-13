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
      // Get user data from Supabase (including active_avatar_id)
      final userResponse = await _authService.supabase
          .from('users')
          .select('*, active_avatar_id')
          .eq('id', userId)
          .single();

      // Get user's avatars
      final avatarsResponse = await _authService.supabase
          .from('avatars')
          .select()
          .eq('owner_user_id', userId)
          .order('created_at', ascending: true);

      // Get user stats (following count)
      final followsResponse = await _authService.supabase
          .from('follows')
          .select('avatar_id')
          .eq('user_id', userId);
      
      final followingCount = (followsResponse as List).length;

      List<AvatarModel> avatars = (avatarsResponse as List)
          .map((avatar) => AvatarModel.fromJson(avatar))
          .toList();

      // Find the active avatar or use the first one
      AvatarModel? activeAvatar;
      if (userResponse['active_avatar_id'] != null) {
        activeAvatar = avatars.firstWhere(
          (avatar) => avatar.id == userResponse['active_avatar_id'],
          orElse: () => avatars.isNotEmpty ? avatars.first : AvatarModel(
            id: '',
            name: 'No Avatar',
            bio: 'Create your first avatar to get started!',
            niche: AvatarNiche.other,
            personalityTraits: [],
            personalityPrompt: '',
            ownerUserId: userId,
            followersCount: 0,
            likesCount: 0,
            postsCount: 0,
            engagementRate: 0.0,
            isActive: true,
            allowAutonomousPosting: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      } else if (avatars.isNotEmpty) {
        activeAvatar = avatars.first;
      }

      return {
        'user': UserModel.fromJson(userResponse),
        'avatars': avatars,
        'active_avatar': activeAvatar,
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

  // Get user stats
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userResponse = await _authService.supabase
          .from('users')
          .select('followers_count, posts_count')
          .eq('id', userId)
          .single();

      // Get following count
      final followsResponse = await _authService.supabase
          .from('follows')
          .select('avatar_id')
          .eq('user_id', userId);
      
      final followingCount = (followsResponse as List).length;

      return {
        'following_count': followingCount,
        'followers_count': userResponse['followers_count'] ?? 0,
        'posts_count': userResponse['posts_count'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error loading user stats: $e');
      return {
        'following_count': 0,
        'followers_count': 0,
        'posts_count': 0,
      };
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

  /// Get pinned post for an avatar
  Future<Map<String, dynamic>?> getPinnedPost(String avatarId) async {
    try {
      final avatarResponse = await _authService.supabase
          .from('avatars')
          .select('pinned_post_id')
          .eq('id', avatarId)
          .single();
      
      final pinnedPostId = avatarResponse['pinned_post_id'] as String?;
      if (pinnedPostId == null) return null;
      
      final postResponse = await _authService.supabase
          .from('posts')
          .select('*')
          .eq('id', pinnedPostId)
          .eq('is_active', true)
          .single();
      
      return postResponse;
    } catch (e) {
      debugPrint('Error loading pinned post: $e');
      return null;
    }
  }

  /// Set pinned post for an avatar
  Future<void> setPinnedPost(String avatarId, String? postId) async {
    try {
      await _authService.supabase
          .from('avatars')
          .update({'pinned_post_id': postId})
          .eq('id', avatarId);
    } catch (e) {
      throw Exception('Error setting pinned post: $e');
    }
  }

  /// Get collaborations for an avatar
  Future<List<Map<String, dynamic>>> getCollaborationPosts(String avatarId, {int limit = 10}) async {
    try {
      final response = await _authService.supabase
          .from('post_collaborations')
          .select('''
            posts:post_id(
              *,
              avatars:avatar_id(id, name, avatar_image_url)
            )
          ''')
          .eq('collaborator_avatar_id', avatarId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return response
          .map<Map<String, dynamic>>((item) => item['posts'] as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('Error loading collaboration posts: $e');
      return [];
    }
  }

  /// Add collaboration to a post
  Future<void> addCollaboration(String postId, String collaboratorAvatarId, String collaborationType) async {
    try {
      await _authService.supabase.from('post_collaborations').insert({
        'post_id': postId,
        'collaborator_avatar_id': collaboratorAvatarId,
        'collaboration_type': collaborationType,
      });
    } catch (e) {
      throw Exception('Error adding collaboration: $e');
    }
  }

  /// Remove collaboration from a post
  Future<void> removeCollaboration(String postId, String collaboratorAvatarId) async {
    try {
      await _authService.supabase
          .from('post_collaborations')
          .delete()
          .eq('post_id', postId)
          .eq('collaborator_avatar_id', collaboratorAvatarId);
    } catch (e) {
      throw Exception('Error removing collaboration: $e');
    }
  }


}
