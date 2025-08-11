import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../models/user_model.dart';
import '../models/comment.dart';
import '../services/auth_service.dart';

class FeedsService {
  static final FeedsService _instance = FeedsService._internal();
  factory FeedsService() => _instance;
  FeedsService._internal();

  final AuthService _authService = AuthService();
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Get video posts for the feed with pagination
  Future<List<PostModel>> getVideoFeed({
    int page = 0,
    int limit = 10,
    bool orderByTrending = true,
  }) async {
    try {
      // Get all posts (not just videos) since we have mixed content
      PostgrestFilterBuilder<PostgrestList> query = _supabase
          .from('posts')
          .select('*')
          .eq('is_active', true);

      PostgrestTransformBuilder<PostgrestList> orderedQuery;
      if (orderByTrending) {
        // Order by engagement and recency for trending
        orderedQuery = query.order('likes_count', ascending: false)
                           .order('created_at', ascending: false);
      } else {
        orderedQuery = query.order('created_at', ascending: false);
      }

      final response = await orderedQuery
          .range(page * limit, (page + 1) * limit - 1);

      return response.map<PostModel>((json) => PostModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Failed to get video feed: $e');
      return [];
    }
  }

  /// Get avatar information for a post
  Future<AvatarModel?> getAvatarForPost(String avatarId) async {
    try {
      final response = await _supabase
          .from('avatars')
          .select('*')
          .eq('id', avatarId)
          .single();

      return AvatarModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to get avatar: $e');
      return null;
    }
  }

  /// Get user information
  Future<UserModel?> getUser(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to get user: $e');
      return null;
    }
  }

  /// Get a specific post by ID
  Future<PostModel?> getPostById(String postId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .eq('id', postId)
          .eq('is_active', true)
          .single();

      return PostModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to get post by ID: $e');
      return null;
    }
  }

  /// Toggle like on a post
  Future<bool> toggleLike(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if already liked
      final existingLike = await _supabase
          .from('likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike - remove the like
        await _supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        
        // Update post likes count
        await _decrementLikesCount(postId);
        return false;
      } else {
        // Like - add the like
        await _supabase.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        // Update post likes count
        await _incrementLikesCount(postId);
        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle like: $e');
      rethrow;
    }
  }

  /// Check if user has liked a post
  Future<bool> hasLiked(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      final like = await _supabase
          .from('likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return like != null;
    } catch (e) {
      debugPrint('❌ Failed to check like status: $e');
      return false;
    }
  }

  /// Toggle follow for an avatar
  Future<bool> toggleFollow(String avatarId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if already following
      final existingFollow = await _supabase
          .from('follows')
          .select()
          .eq('avatar_id', avatarId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingFollow != null) {
        // Unfollow
        await _supabase
            .from('follows')
            .delete()
            .eq('avatar_id', avatarId)
            .eq('user_id', userId);
        
        return false;
      } else {
        // Follow
        await _supabase.from('follows').insert({
          'avatar_id': avatarId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle follow: $e');
      rethrow;
    }
  }

  /// Check if user is following an avatar
  Future<bool> isFollowing(String avatarId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      final follow = await _supabase
          .from('follows')
          .select()
          .eq('avatar_id', avatarId)
          .eq('user_id', userId)
          .maybeSingle();

      return follow != null;
    } catch (e) {
      debugPrint('❌ Failed to check follow status: $e');
      return false;
    }
  }

  /// Get comments for a post with real-time updates
  Future<List<Comment>> getComments(String postId, {int limit = 20, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('*')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<Comment>((json) => Comment.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Failed to get comments: $e');
      return [];
    }
  }

  /// Add a comment to a post
  Future<Comment?> addComment(String postId, String text) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase.from('comments').insert({
        'post_id': postId,
        'user_id': userId,
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      // Update comments count
      await _incrementCommentsCount(postId);

      return Comment.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to add comment: $e');
      return null;
    }
  }

  /// Subscribe to real-time comments for a post
  RealtimeChannel subscribeToComments(String postId, Function(Comment) onNewComment) {
    return _supabase
        .channel('comments:$postId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) {
            try {
              final comment = Comment.fromJson(payload.newRecord);
              onNewComment(comment);
            } catch (e) {
              debugPrint('Error processing new comment: $e');
            }
          },
        )
        .subscribe();
  }

  /// Update view count for a post
  Future<void> incrementViewCount(String postId) async {
    try {
      await _supabase.rpc('increment_view_count', params: {
        'post_id': postId,
      });
    } catch (e) {
      debugPrint('❌ Failed to increment view count: $e');
    }
  }

  /// Private helper methods
  Future<void> _incrementLikesCount(String postId) async {
    try {
      await _supabase.rpc('increment_likes_count', params: {
        'post_id': postId,
      });
    } catch (e) {
      debugPrint('❌ Failed to increment likes count: $e');
    }
  }

  Future<void> _decrementLikesCount(String postId) async {
    try {
      await _supabase.rpc('decrement_likes_count', params: {
        'post_id': postId,
      });
    } catch (e) {
      debugPrint('❌ Failed to decrement likes count: $e');
    }
  }

  Future<void> _incrementCommentsCount(String postId) async {
    try {
      await _supabase.rpc('increment_comments_count', params: {
        'post_id': postId,
      });
    } catch (e) {
      debugPrint('❌ Failed to increment comments count: $e');
    }
  }

  /// Get liked posts status for multiple posts (for efficient batch checking)
  Future<Map<String, bool>> getLikedStatusBatch(List<String> postIds) async {
    final userId = _authService.currentUserId;
    if (userId == null) return {};

    try {
      final response = await _supabase
          .from('likes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);

      final likedPostIds = Set<String>.from(
        response.map((item) => item['post_id'] as String),
      );

      return Map.fromEntries(
        postIds.map((postId) => MapEntry(postId, likedPostIds.contains(postId))),
      );
    } catch (e) {
      debugPrint('❌ Failed to get liked status batch: $e');
      return {};
    }
  }

  /// Get following status for multiple avatars (for efficient batch checking)
  Future<Map<String, bool>> getFollowingStatusBatch(List<String> avatarIds) async {
    final userId = _authService.currentUserId;
    if (userId == null) return {};

    try {
      final response = await _supabase
          .from('follows')
          .select('avatar_id')
          .eq('user_id', userId)
          .inFilter('avatar_id', avatarIds);

      final followingAvatarIds = Set<String>.from(
        response.map((item) => item['avatar_id'] as String),
      );

      return Map.fromEntries(
        avatarIds.map((avatarId) => MapEntry(avatarId, followingAvatarIds.contains(avatarId))),
      );
    } catch (e) {
      debugPrint('❌ Failed to get following status batch: $e');
      return {};
    }
  }

  /// Dispose resources
  void dispose() {
    // Clean up any subscriptions if needed
  }
}
