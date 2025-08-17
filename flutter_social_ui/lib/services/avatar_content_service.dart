import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../services/auth_service.dart';
import '../config/db_config.dart';
import '../store/app_state.dart';

/// Service for managing avatar-specific content association and ownership
class AvatarContentService {
  static final AvatarContentService _instance =
      AvatarContentService._internal();
  factory AvatarContentService() => _instance;
  AvatarContentService._internal();

  final AuthService _authService = AuthService();
  final AppState _appState = AppState();
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Get posts for a specific avatar with pagination
  Future<List<PostModel>> getAvatarPosts({
    required String avatarId,
    int page = 1,
    int limit = 20,
    bool applySafetyFiltering = false,
  }) async {
    try {
      // Calculate offset for pagination
      final offset = (page - 1) * limit;

      // Query posts for the specific avatar
      final response = await _supabase
          .from(DbConfig.postsTable)
          .select('*')
          .eq('avatar_id', avatarId)
          .eq('is_active', true)
          .eq('status', DbConfig.publishedStatus)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = response
          .map<PostModel>((json) => PostModel.fromJson(json))
          .toList();

      // Update app state with avatar-specific posts
      for (final post in posts) {
        _appState.setPost(post);
        _appState.associateContentWithAvatar(avatarId, post.id);
      }

      debugPrint(
        '📱 Retrieved ${posts.length} posts for avatar $avatarId (page $page)',
      );
      return posts;
    } catch (e) {
      debugPrint('❌ Failed to get avatar posts: $e');
      return [];
    }
  }

  /// Create a post associated with a specific avatar
  Future<PostModel?> createAvatarPost({
    required String avatarId,
    required PostType type,
    String? videoUrl,
    String? imageUrl,
    String? thumbnailUrl,
    required String caption,
    required List<String> hashtags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify avatar ownership
      final avatar = await _getAvatar(avatarId);
      if (avatar == null) {
        throw Exception('Avatar not found');
      }

      if (avatar.ownerUserId != userId) {
        throw Exception('User does not own this avatar');
      }

      // Create the post
      final post = PostModel.create(
        avatarId: avatarId,
        type: type,
        videoUrl: videoUrl,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        hashtags: hashtags,
        metadata: {'created_by': userId, 'avatar_id': avatarId, ...?metadata},
      );

      // Insert into database
      final response = await _supabase
          .from(DbConfig.postsTable)
          .insert(post.toJson())
          .select()
          .single();

      final createdPost = PostModel.fromJson(response);

      // Update app state
      _appState.setPost(createdPost);
      _appState.associateContentWithAvatar(avatarId, createdPost.id);

      debugPrint('✅ Created post ${createdPost.id} for avatar $avatarId');
      return createdPost;
    } catch (e) {
      debugPrint('❌ Failed to create avatar post: $e');
      return null;
    }
  }

  /// Associate existing content with an avatar (for migration purposes)
  Future<bool> associateContentWithAvatar({
    required String postId,
    required String avatarId,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify avatar ownership
      final avatar = await _getAvatar(avatarId);
      if (avatar == null) {
        throw Exception('Avatar not found');
      }

      if (avatar.ownerUserId != userId) {
        throw Exception('User does not own this avatar');
      }

      // Update the post's avatar_id
      await _supabase
          .from(DbConfig.postsTable)
          .update({'avatar_id': avatarId})
          .eq('id', postId);

      // Update app state
      _appState.associateContentWithAvatar(avatarId, postId);

      debugPrint('✅ Associated post $postId with avatar $avatarId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to associate content with avatar: $e');
      return false;
    }
  }

  /// Transfer content ownership when an avatar is deleted
  Future<bool> transferAvatarContent({
    required String fromAvatarId,
    required String toAvatarId,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify ownership of both avatars
      final fromAvatar = await _getAvatar(fromAvatarId);
      final toAvatar = await _getAvatar(toAvatarId);

      if (fromAvatar == null || toAvatar == null) {
        throw Exception('One or both avatars not found');
      }

      if (fromAvatar.ownerUserId != userId || toAvatar.ownerUserId != userId) {
        throw Exception('User does not own one or both avatars');
      }

      // Get all posts for the source avatar
      final posts = await getAvatarPosts(avatarId: fromAvatarId, limit: 1000);

      // Transfer each post to the target avatar
      for (final post in posts) {
        await _supabase
            .from(DbConfig.postsTable)
            .update({'avatar_id': toAvatarId})
            .eq('id', post.id);

        // Update app state
        _appState.removeContentFromAvatar(fromAvatarId, post.id);
        _appState.associateContentWithAvatar(toAvatarId, post.id);
      }

      debugPrint(
        '✅ Transferred ${posts.length} posts from avatar $fromAvatarId to $toAvatarId',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Failed to transfer avatar content: $e');
      return false;
    }
  }

  /// Archive content when an avatar is deleted (alternative to transfer)
  Future<bool> archiveAvatarContent({required String avatarId}) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify avatar ownership
      final avatar = await _getAvatar(avatarId);
      if (avatar == null) {
        throw Exception('Avatar not found');
      }

      if (avatar.ownerUserId != userId) {
        throw Exception('User does not own this avatar');
      }

      // Archive all posts for the avatar
      await _supabase
          .from(DbConfig.postsTable)
          .update({'status': 'archived', 'is_active': false})
          .eq('avatar_id', avatarId);

      // Update app state - remove from active posts
      final posts = _appState.getAvatarPosts(avatarId);
      for (final post in posts) {
        _appState.removePost(post.id);
      }

      debugPrint('✅ Archived content for avatar $avatarId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to archive avatar content: $e');
      return false;
    }
  }

  /// Get content statistics for an avatar
  Future<Map<String, dynamic>> getAvatarContentStats(String avatarId) async {
    try {
      final response = await _supabase
          .from(DbConfig.postsTable)
          .select('id, likes_count, comments_count, shares_count, views_count')
          .eq('avatar_id', avatarId)
          .eq('is_active', true)
          .eq('status', DbConfig.publishedStatus);

      final posts = response
          .map<PostModel>((json) => PostModel.fromJson(json))
          .toList();

      final totalPosts = posts.length;
      final totalLikes = posts.fold<int>(
        0,
        (sum, post) => sum + post.likesCount,
      );
      final totalComments = posts.fold<int>(
        0,
        (sum, post) => sum + post.commentsCount,
      );
      final totalShares = posts.fold<int>(
        0,
        (sum, post) => sum + post.sharesCount,
      );
      final totalViews = posts.fold<int>(
        0,
        (sum, post) => sum + post.viewsCount,
      );

      final avgEngagement = totalPosts > 0
          ? (totalLikes + totalComments + totalShares) / totalPosts
          : 0.0;

      return {
        'totalPosts': totalPosts,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'totalViews': totalViews,
        'averageEngagement': avgEngagement,
      };
    } catch (e) {
      debugPrint('❌ Failed to get avatar content stats: $e');
      return {
        'totalPosts': 0,
        'totalLikes': 0,
        'totalComments': 0,
        'totalShares': 0,
        'totalViews': 0,
        'averageEngagement': 0.0,
      };
    }
  }

  /// Ensure content is properly associated with the active avatar during creation
  Future<void> ensureActiveAvatarAssociation() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      final activeAvatar = _appState.activeAvatar;
      if (activeAvatar == null) return;

      // Check for any posts that might not be properly associated
      final userPosts = _appState.getUserPosts(userId);
      for (final post in userPosts) {
        if (post.avatarId != activeAvatar.id) {
          // This post was created before avatar system - associate it
          await associateContentWithAvatar(
            postId: post.id,
            avatarId: activeAvatar.id,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to ensure active avatar association: $e');
    }
  }

  /// Get posts for multiple avatars (for user profile display)
  Future<List<PostModel>> getMultipleAvatarPosts({
    required List<String> avatarIds,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      if (avatarIds.isEmpty) return [];

      // Calculate offset for pagination
      final offset = (page - 1) * limit;

      // Query posts for multiple avatars
      final response = await _supabase
          .from(DbConfig.postsTable)
          .select('*')
          .inFilter('avatar_id', avatarIds)
          .eq('is_active', true)
          .eq('status', DbConfig.publishedStatus)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = response
          .map<PostModel>((json) => PostModel.fromJson(json))
          .toList();

      // Update app state
      for (final post in posts) {
        _appState.setPost(post);
        _appState.associateContentWithAvatar(post.avatarId, post.id);
      }

      debugPrint(
        '📱 Retrieved ${posts.length} posts for ${avatarIds.length} avatars (page $page)',
      );
      return posts;
    } catch (e) {
      debugPrint('❌ Failed to get multiple avatar posts: $e');
      return [];
    }
  }

  /// Validate content ownership before operations
  Future<bool> validateContentOwnership({
    required String postId,
    required String userId,
  }) async {
    try {
      // Get the post and its associated avatar
      final response = await _supabase
          .from(DbConfig.postsTable)
          .select('avatar_id')
          .eq('id', postId)
          .single();

      final avatarId = response['avatar_id'] as String;
      final avatar = await _getAvatar(avatarId);

      return avatar?.ownerUserId == userId;
    } catch (e) {
      debugPrint('❌ Failed to validate content ownership: $e');
      return false;
    }
  }

  /// Helper method to get avatar information
  Future<AvatarModel?> _getAvatar(String avatarId) async {
    try {
      // Check app state first
      final cachedAvatar = _appState.getAvatar(avatarId);
      if (cachedAvatar != null) {
        return cachedAvatar;
      }

      // Fetch from database
      final response = await _supabase
          .from(DbConfig.avatarsTable)
          .select('*')
          .eq('id', avatarId)
          .single();

      final avatar = AvatarModel.fromJson(response);
      _appState.setAvatar(avatar);
      return avatar;
    } catch (e) {
      debugPrint('❌ Failed to get avatar: $e');
      return null;
    }
  }

  /// Migrate existing user posts to their default avatar
  Future<bool> migrateUserPostsToDefaultAvatar({
    required String userId,
    required String defaultAvatarId,
  }) async {
    try {
      // Verify avatar ownership
      final avatar = await _getAvatar(defaultAvatarId);
      if (avatar == null || avatar.ownerUserId != userId) {
        throw Exception('Invalid avatar for migration');
      }

      // Find posts that don't have an avatar_id or have null avatar_id
      final response = await _supabase
          .from(DbConfig.postsTable)
          .select('id')
          .isFilter('avatar_id', null);

      final postIds = response.map((item) => item['id'] as String).toList();

      if (postIds.isNotEmpty) {
        // Update posts to associate with the default avatar
        await _supabase
            .from(DbConfig.postsTable)
            .update({'avatar_id': defaultAvatarId})
            .inFilter('id', postIds);

        // Update app state
        for (final postId in postIds) {
          _appState.associateContentWithAvatar(defaultAvatarId, postId);
        }

        debugPrint(
          '✅ Migrated ${postIds.length} posts to default avatar $defaultAvatarId',
        );
      }

      return true;
    } catch (e) {
      debugPrint('❌ Failed to migrate user posts: $e');
      return false;
    }
  }
}
