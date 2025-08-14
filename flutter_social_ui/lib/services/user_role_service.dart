import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Service for managing user permissions based on ownership
/// 
/// SIMPLIFIED SOCIAL MEDIA MODEL:
/// - Everyone is a creator by default and can create content
/// - Permissions are based on OWNERSHIP:
///   * Own content: can edit, delete, view analytics
///   * Others' content: can like, comment, share (typical social media)
/// - "Fan" status is automatic when you follow someone
/// - Only role distinction: admin for moderation privileges
class UserRoleService {
  static final UserRoleService _instance = UserRoleService._internal();
  factory UserRoleService() => _instance;
  UserRoleService._internal();

  final AuthService _authService = AuthService();
  SupabaseClient get _supabase => _authService.supabase;

  /// Check if current user is a creator (has avatars)
  Future<bool> isCreator([String? userId]) async {
    final targetUserId = userId ?? _authService.currentUserId;
    if (targetUserId == null) return false;

    try {
      // Check if user has created any avatars
      final avatars = await _supabase
          .from('avatars')
          .select('id')
          .eq('owner_user_id', targetUserId)
          .limit(1);

      return avatars.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Failed to check creator status: $e');
      return false;
    }
  }

  /// Check if current user is a fan (follows avatars but doesn't create content)
  Future<bool> isFan([String? userId]) async {
    final targetUserId = userId ?? _authService.currentUserId;
    if (targetUserId == null) return false;

    try {
      // Check if user follows avatars but hasn't created any
      final follows = await _supabase
          .from('follows')
          .select('id')
          .eq('user_id', targetUserId)
          .limit(1);

      final hasAvatars = await isCreator(targetUserId);

      return follows.isNotEmpty && !hasAvatars;
    } catch (e) {
      debugPrint('❌ Failed to check fan status: $e');
      return false;
    }
  }

  /// Get user role based on database record
  Future<UserRole> getUserRole([String? userId]) async {
    final targetUserId = userId ?? _authService.currentUserId;
    if (targetUserId == null) return UserRole.creator;

    try {
      // Check the user's role in the database
      final user = await _supabase
          .from('users')
          .select('role')
          .eq('id', targetUserId)
          .single();

      final dbRole = user['role'] as String?;
      if (dbRole != null) {
        // Convert string to enum
        return UserRole.values.firstWhere(
          (role) => role.toString().split('.').last == dbRole,
          orElse: () => UserRole.creator,
        );
      }

      // Default: everyone is a creator
      return UserRole.creator;
    } catch (e) {
      debugPrint('❌ Failed to get user role: $e');
      return UserRole.creator;
    }
  }

  /// Update user role in database
  Future<bool> updateUserRole(String userId, UserRole role) async {
    try {
      await _supabase
          .from('users')
          .update({
            'role': role.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      return true;
    } catch (e) {
      debugPrint('❌ Failed to update user role: $e');
      return false;
    }
  }

  /// Promote user to creator (when they create their first avatar)
  Future<bool> promoteToCreator(String userId) async {
    return await updateUserRole(userId, UserRole.creator);
  }

  /// Check permissions for various actions based on user role
  Future<bool> canCreateAvatars([String? userId]) async {
    // EVERYONE can create avatars regardless of role
    return true;
  }

  Future<bool> canCreatePosts([String? userId]) async {
    // EVERYONE can create posts regardless of role
    return true;
  }

  Future<bool> canModerateContent([String? userId]) async {
    final role = await getUserRole(userId);
    return role == UserRole.admin;
  }

  Future<bool> canViewAnalytics(String targetUserId, [String? viewerUserId]) async {
    final viewerId = viewerUserId ?? _authService.currentUserId;
    if (viewerId == null) return false;

    // Users can always view their own analytics
    if (targetUserId == viewerId) return true;

    // Admins can view any analytics
    final role = await getUserRole(viewerId);
    return role == UserRole.admin;
  }

  /// Get user activity summary
  Future<Map<String, dynamic>> getUserActivitySummary([String? userId]) async {
    final targetUserId = userId ?? _authService.currentUserId;
    if (targetUserId == null) return {};

    try {
      // Get user's avatars
      final avatars = await _supabase
          .from('avatars')
          .select('id, followers_count, posts_count')
          .eq('owner_user_id', targetUserId);

      // Get user's follows
      final follows = await _supabase
          .from('follows')
          .select('id')
          .eq('user_id', targetUserId);

      // Get user's likes
      final likes = await _supabase
          .from('post_likes')
          .select('id')
          .eq('user_id', targetUserId);

      // Get user's comments
      final comments = await _supabase
          .from('post_comments')
          .select('id')
          .eq('user_id', targetUserId);

      final totalFollowers = (avatars as List)
          .fold<int>(0, (sum, avatar) => sum + (avatar['followers_count'] as int? ?? 0));
      
      final totalPosts = (avatars as List)
          .fold<int>(0, (sum, avatar) => sum + (avatar['posts_count'] as int? ?? 0));

      return {
        'avatars_count': avatars.length,
        'total_followers': totalFollowers,
        'total_posts': totalPosts,
        'following_count': (follows as List).length,
        'likes_given': (likes as List).length,
        'comments_made': (comments as List).length,
        'is_creator': avatars.length > 0,
        'is_fan': follows.length > 0 && avatars.length == 0,
        'role': await getUserRole(targetUserId),
      };
    } catch (e) {
      debugPrint('❌ Failed to get user activity summary: $e');
      return {};
    }
  }

  /// Check if user should see creator features in UI
  Future<bool> shouldShowCreatorFeatures([String? userId]) async {
    final role = await getUserRole(userId);
    return role == UserRole.creator || role == UserRole.admin;
  }

  /// Check if user should see fan-specific features in UI
  Future<bool> shouldShowFanFeatures([String? userId]) async {
    final activity = await getUserActivitySummary(userId);
    
    // Show fan features if user is primarily consuming content (follows others but hasn't created)
    return activity['is_fan'] == true;
  }

  /// Get appropriate dashboard for user based on role
  Future<String> getPreferredDashboard([String? userId]) async {
    final activity = await getUserActivitySummary(userId);
    
    if (activity['is_creator'] == true) {
      return 'creator_dashboard';
    } else if (activity['is_fan'] == true) {
      return 'fan_dashboard';
    } else {
      return 'explore_dashboard';
    }
  }

  /// Auto-assign role based on user activity
  /// Note: In this simplified model, everyone defaults to creator.
  /// This method mainly exists for admin role assignments.
  Future<void> autoAssignRole(String userId) async {
    try {
      // In the simplified model, everyone is a creator by default
      // Only admins get a different role, which would be set manually
      await updateUserRole(userId, UserRole.creator);
    } catch (e) {
      debugPrint('❌ Failed to auto-assign role: $e');
    }
  }
}
