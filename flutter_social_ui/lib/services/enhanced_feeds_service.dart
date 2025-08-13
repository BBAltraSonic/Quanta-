import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../models/user_model.dart';
import '../models/comment.dart';
import '../services/auth_service.dart';
import '../services/user_safety_service.dart';
import '../services/analytics_service.dart';
import '../config/db_config.dart';
import '../services/notification_service.dart' as notification_service;

/// Enhanced feeds service with comprehensive post interaction functionality
class EnhancedFeedsService {
  static final EnhancedFeedsService _instance = EnhancedFeedsService._internal();
  factory EnhancedFeedsService() => _instance;
  EnhancedFeedsService._internal();

  final AuthService _authService = AuthService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final notification_service.NotificationService _notificationService = notification_service.NotificationService();
  SupabaseClient get _supabase => Supabase.instance.client;
  
  // Realtime subscriptions
  final Map<String, RealtimeChannel> _realtimeSubscriptions = {};

  /// Get video posts for the feed with pagination and safety filtering
  Future<List<PostModel>> getVideoFeed({
    int page = 0,
    int limit = DbConfig.defaultPageSize,
    bool orderByTrending = true,
    bool applySafetyFiltering = true,
  }) async {
    try {
      // Base query without safety subqueries (to avoid SQL syntax errors)
      PostgrestFilterBuilder<PostgrestList> query = _supabase
          .from(DbConfig.postsTable)
          .select('*')
          .eq('is_active', true)
          .eq('status', DbConfig.publishedStatus);

      PostgrestTransformBuilder<PostgrestList> orderedQuery;
      if (orderByTrending) {
        // Order by engagement and recency for trending
        orderedQuery = query
            .order('likes_count', ascending: false)
            .order('views_count', ascending: false)
            .order('created_at', ascending: false);
      } else {
        orderedQuery = query.order('created_at', ascending: false);
      }

      final response = await orderedQuery
          .range(page * limit, (page + 1) * limit - 1);

      var posts = response.map<PostModel>((json) => PostModel.fromJson(json)).toList();

      // Apply client-side safety filtering
      if (applySafetyFiltering) {
        posts = await UserSafetyService().filterContent(posts);
      }
      
      debugPrint('📱 Retrieved ${posts.length} posts for feed (page $page, safety filtering: $applySafetyFiltering)');
      return posts;
    } catch (e) {
      debugPrint('❌ Failed to get video feed: $e');
      return [];
    }
  }

  /// Get posts for a specific user
  Future<List<PostModel>> getUserPosts({
    required String userId,
    int page = 1,
    int limit = 20,
    bool applySafetyFiltering = false,
  }) async {
    try {
      // Calculate offset for pagination
      final offset = (page - 1) * limit;
      
      final response = await _supabase
          .from(DbConfig.postsTable)
          .select('*')
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('status', DbConfig.publishedStatus)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      var posts = response.map<PostModel>((json) => PostModel.fromJson(json)).toList();

      // Apply safety filtering if requested
      if (applySafetyFiltering) {
        posts = await UserSafetyService().filterContent(posts);
      }
      
      debugPrint('📱 Retrieved ${posts.length} posts for user $userId (page $page)');
      return posts;
    } catch (e) {
      debugPrint('❌ Failed to get user posts: $e');
      return [];
    }
  }

  /// Get a specific post by ID
  Future<PostModel?> getPostById(String postId) async {
    try {
      final response = await _supabase
          .from(DbConfig.postsTable)
          .select('*')
          .eq('id', postId)
          .eq('is_active', true)
          .eq('status', DbConfig.publishedStatus)
          .single();

      return PostModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to get post by ID: $e');
      return null;
    }
  }

  /// Get avatar information for a post
  Future<AvatarModel?> getAvatarForPost(String avatarId) async {
    try {
      final response = await _supabase
          .from(DbConfig.avatarsTable)
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
          .from(DbConfig.usersTable)
          .select('*')
          .eq('id', userId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to get user: $e');
      return null;
    }
  }

  /// Toggle like on a post using secure RPC functions
  Future<bool> toggleLike(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // First check current status using RPC function
      final statusResult = await _supabase.rpc('get_post_interaction_status', params: {
        'target_post_id': postId,
      });

      if (!statusResult['success']) {
        throw Exception('Failed to get interaction status: ${statusResult['error']}');
      }

      final isCurrentlyLiked = statusResult['data']['user_liked'] as bool;

      if (isCurrentlyLiked) {
        // Unlike using RPC function
        final result = await _supabase.rpc('decrement_likes_count', params: {
          'target_post_id': postId,
        });

        if (!result['success']) {
          throw Exception('Failed to unlike post: ${result['error']}');
        }

        // Track analytics
        _analyticsService.trackLikeToggle(postId, false);

        return false;
      } else {
        // Like using RPC function
        final result = await _supabase.rpc('increment_likes_count', params: {
          'target_post_id': postId,
        });

        if (!result['success']) {
          throw Exception('Failed to like post: ${result['error']}');
        }

        // Create notification for post owner
        await _createLikeNotification(postId, userId);
        
        // Track analytics
        _analyticsService.trackLikeToggle(postId, true);
        
        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle like: $e');
      rethrow;
    }
  }

  /// Check if user has liked a post using secure RPC function
  Future<bool> hasLiked(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      final result = await _supabase.rpc('get_post_interaction_status', params: {
        'target_post_id': postId,
      });

      if (!result['success']) {
        debugPrint('❌ Failed to get interaction status: ${result['error']}');
        return false;
      }

      return result['data']['user_liked'] as bool;
    } catch (e) {
      debugPrint('❌ Failed to check like status: $e');
      return false;
    }
  }

  /// Get users who liked a post
  Future<List<UserModel>> getPostLikers(String postId, {int limit = 50}) async {
    try {
      final response = await _supabase
          .from(DbConfig.likesTable)
          .select('user_id, ${DbConfig.usersTable}(*)')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<UserModel>((item) => UserModel.fromJson(item[DbConfig.usersTable]))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get post likers: $e');
      return [];
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
          .from(DbConfig.followsTable)
          .select()
          .eq('avatar_id', avatarId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingFollow != null) {
        // Unfollow
        await _supabase
            .from(DbConfig.followsTable)
            .delete()
            .eq('avatar_id', avatarId)
            .eq('user_id', userId);
        
        // Track analytics
        _analyticsService.trackFollowToggle(avatarId, false);
        
        return false;
      } else {
        // Follow
        await _supabase.from(DbConfig.followsTable).insert({
          'avatar_id': avatarId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        // Create notification for avatar owner
        await _createFollowNotification(avatarId, userId);
        
        // Track analytics
        _analyticsService.trackFollowToggle(avatarId, true);
        
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
          .from(DbConfig.followsTable)
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

  /// Get comments for a post with pagination
  Future<List<Comment>> getComments(String postId, {int limit = 20, int offset = 0}) async {
    try {
      final response = await _supabase
          .from(DbConfig.commentsTable)
          .select('''
            *,
            users:user_id(username, display_name, profile_image_url),
            avatars:avatar_id(name, avatar_image_url)
          ''')
          .eq('post_id', postId)
          .isFilter('parent_comment_id', null) // Only top-level comments
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<Comment>((json) {
        final comment = Comment.fromJson(json);
        
        // Add user/avatar display info
        if (json['users'] != null) {
          final userData = json['users'] as Map<String, dynamic>;
          return comment.copyWith(
            // Note: Comment model needs to be updated to support display names
          );
        } else if (json['avatars'] != null) {
          final avatarData = json['avatars'] as Map<String, dynamic>;
          return comment.copyWith(
            // Note: Comment model needs to be updated to support avatar names
          );
        }
        
        return comment;
      }).toList();
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
      final response = await _supabase.from(DbConfig.commentsTable).insert({
        'post_id': postId,
        'user_id': userId,
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      // Update comments count
      await _incrementCommentsCount(postId);
      
      // Create notification for post owner
      await _createCommentNotification(postId, userId);
      
      // Track analytics
      final comment = Comment.fromJson(response);
      _analyticsService.trackCommentAdd(postId, comment.id!, commentLength: text.length);

      return comment;
    } catch (e) {
      debugPrint('❌ Failed to add comment: $e');
      return null;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String commentId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get comment to verify ownership and get post_id
      final comment = await _supabase
          .from(DbConfig.commentsTable)
          .select('post_id, user_id')
          .eq('id', commentId)
          .single();

      // Check if user owns the comment
      if (comment['user_id'] != userId) {
        throw Exception('Not authorized to delete this comment');
      }

      // Delete the comment
      await _supabase
          .from(DbConfig.commentsTable)
          .delete()
          .eq('id', commentId);

      // Decrement comments count
      await _decrementCommentsCount(comment['post_id']);

      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete comment: $e');
      return false;
    }
  }

  /// Subscribe to real-time comments for a post
  RealtimeChannel subscribeToComments(String postId, Function(Comment) onNewComment) {
    final channelName = 'comments:$postId';
    
    // Unsubscribe existing channel if any
    _realtimeSubscriptions[channelName]?.unsubscribe();
    
    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: DbConfig.commentsTable,
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
    
    _realtimeSubscriptions[channelName] = channel;
    return channel;
  }

  /// Toggle bookmark/save post
  Future<bool> toggleBookmark(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if already bookmarked
      final existingBookmark = await _supabase
          .from(DbConfig.savedPostsTable)
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingBookmark != null) {
        // Remove bookmark
        await _supabase
            .from(DbConfig.savedPostsTable)
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        
        // Track analytics
        _analyticsService.trackBookmarkToggle(postId, false);
        
        return false;
      } else {
        // Add bookmark
        await _supabase.from(DbConfig.savedPostsTable).insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        // Track analytics
        _analyticsService.trackBookmarkToggle(postId, true);
        
        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle bookmark: $e');
      rethrow;
    }
  }

  /// Check if post is bookmarked
  Future<bool> isBookmarked(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      final bookmark = await _supabase
          .from(DbConfig.savedPostsTable)
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return bookmark != null;
    } catch (e) {
      debugPrint('❌ Failed to check bookmark status: $e');
      return false;
    }
  }

  /// Share a post
  Future<bool> sharePost(String postId, {String? message, String? platform}) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Record the share
      await _supabase.from(DbConfig.sharesTable).insert({
        'post_id': postId,
        'user_id': userId,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update shares count
      await _incrementSharesCount(postId);
      
      // Track analytics
      _analyticsService.trackShareAttempt(postId, platform ?? 'unknown', successful: true);

      return true;
    } catch (e) {
      debugPrint('❌ Failed to share post: $e');
      return false;
    }
  }

  /// Report a post
  Future<bool> reportPost(String postId, String reportType, {String? reason, String? details}) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase.from(DbConfig.reportsTable).insert({
        'post_id': postId,
        'user_id': userId,
        'report_type': reportType,
        'reason': reason,
        'details': details,
        'status': DbConfig.pendingReport,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ Failed to report post: $e');
      return false;
    }
  }

  /// Block a user
  Future<bool> blockUser(String blockedUserId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (userId == blockedUserId) {
      throw Exception('Cannot block yourself');
    }

    try {
      await _supabase.from(DbConfig.userBlocksTable).insert({
        'blocker_user_id': userId,
        'blocked_user_id': blockedUserId,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ Failed to block user: $e');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String blockedUserId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from(DbConfig.userBlocksTable)
          .delete()
          .eq('blocker_user_id', userId)
          .eq('blocked_user_id', blockedUserId);

      return true;
    } catch (e) {
      debugPrint('❌ Failed to unblock user: $e');
      return false;
    }
  }

  /// Mute a user
  Future<bool> muteUser(String mutedUserId, {Duration? duration}) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (userId == mutedUserId) {
      throw Exception('Cannot mute yourself');
    }

    try {
      await _supabase.from(DbConfig.userMutesTable).upsert({
        'muter_user_id': userId,
        'muted_user_id': mutedUserId,
        'muted_at': DateTime.now().toIso8601String(),
        'duration_minutes': duration?.inMinutes,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ User muted: $mutedUserId for ${duration?.toString() ?? 'indefinitely'}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to mute user: $e');
      return false;
    }
  }

  /// Unmute a user
  Future<bool> unmuteUser(String mutedUserId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from(DbConfig.userMutesTable)
          .delete()
          .eq('muter_user_id', userId)
          .eq('muted_user_id', mutedUserId);

      debugPrint('✅ User unmuted: $mutedUserId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to unmute user: $e');
      return false;
    }
  }

  /// Check if a user is muted
  Future<bool> isUserMuted(String userId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return false;

    try {
      // Use the database function that includes automatic cleanup
      final response = await _supabase.rpc('is_user_muted', params: {
        'muter_id': currentUserId,
        'muted_id': userId,
      });

      return response == true;
    } catch (e) {
      debugPrint('❌ Error checking if user is muted: $e');
      return false;
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String userId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return false;

    try {
      // Use the database function for consistency
      final response = await _supabase.rpc('is_user_blocked', params: {
        'blocker_id': currentUserId,
        'blocked_id': userId,
      });

      return response == true;
    } catch (e) {
      debugPrint('❌ Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Record view event with analytics
  Future<void> recordViewEvent(String postId, {
    int? durationSeconds,
    double? watchPercentage,
  }) async {
    final userId = _authService.currentUserId;
    
    try {
      // Record detailed view event
      await _supabase.from(DbConfig.viewEventsTable).insert({
        'post_id': postId,
        'user_id': userId,
        'duration_seconds': durationSeconds ?? 0,
        'watch_percentage': watchPercentage ?? 0.0,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'user_agent': 'flutter_app',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      });

      // Update post view count if significant view
      if (durationSeconds != null && durationSeconds >= DbConfig.viewThresholdSeconds) {
        await incrementViewCount(postId);
      }
    } catch (e) {
      debugPrint('❌ Failed to record view event: $e');
    }
  }

  /// Update view count for a post using secure RPC function
  Future<void> incrementViewCount(String postId) async {
    try {
      final result = await _supabase.rpc('increment_view_count', params: {
        'target_post_id': postId,
      });

      if (!result['success']) {
        debugPrint('❌ RPC increment_view_count failed: ${result['error']}');
      }
    } catch (e) {
      debugPrint('❌ Failed to increment view count: $e');
    }
  }

  /// Get liked posts status for multiple posts (for efficient batch checking)
  Future<Map<String, bool>> getLikedStatusBatch(List<String> postIds) async {
    final userId = _authService.currentUserId;
    if (userId == null) return {};

    try {
      final response = await _supabase
          .from(DbConfig.likesTable)
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
          .from(DbConfig.followsTable)
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

  /// Get bookmarked status for multiple posts
  Future<Map<String, bool>> getBookmarkedStatusBatch(List<String> postIds) async {
    final userId = _authService.currentUserId;
    if (userId == null) return {};

    try {
      final response = await _supabase
          .from(DbConfig.savedPostsTable)
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);

      final bookmarkedPostIds = Set<String>.from(
        response.map((item) => item['post_id'] as String),
      );

      return Map.fromEntries(
        postIds.map((postId) => MapEntry(postId, bookmarkedPostIds.contains(postId))),
      );
    } catch (e) {
      debugPrint('❌ Failed to get bookmarked status batch: $e');
      return {};
    }
  }

  /// Private helper methods for database operations
  /// Note: Like count operations are now handled directly by the RPC functions
  /// in the toggleLike method for better atomicity and security.

  Future<void> _incrementCommentsCount(String postId) async {
    try {
      await _supabase.rpc('increment_comments_count', params: {
        'post_id': postId,
      });
    } catch (e) {
      debugPrint('❌ Failed to increment comments count: $e');
    }
  }

  Future<void> _decrementCommentsCount(String postId) async {
    try {
      await _supabase.rpc('decrement_comments_count', params: {
        'post_id': postId,
      });
    } catch (e) {
      debugPrint('❌ Failed to decrement comments count: $e');
    }
  }

  Future<void> _incrementSharesCount(String postId) async {
    try {
      // Use RPC to properly increment the counter
      await _supabase.rpc('increment_shares_count', params: {'post_id': postId});
    } catch (e) {
      debugPrint('❌ Failed to increment shares count: $e');
    }
  }

  /// Create notifications for interactions
  Future<void> _createLikeNotification(String postId, String likerId) async {
    try {
      // Get post owner
      final post = await _supabase
          .from(DbConfig.postsTable)
          .select('avatar_id')
          .eq('id', postId)
          .single();

      final avatar = await _supabase
          .from(DbConfig.avatarsTable)
          .select('owner_user_id, name')
          .eq('id', post['avatar_id'])
          .single();

      // Don't create notification if user likes their own post
      if (avatar['owner_user_id'] == likerId) return;

      await _supabase.from(DbConfig.notificationsTable).insert({
        'user_id': avatar['owner_user_id'],
        'type': DbConfig.likeNotification,
        'title': 'New Like',
        'message': 'Someone liked your ${avatar['name']} post',
        'related_post_id': postId,
        'related_user_id': likerId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Failed to create like notification: $e');
    }
  }

  Future<void> _createCommentNotification(String postId, String commenterId) async {
    try {
      // Get post owner
      final post = await _supabase
          .from(DbConfig.postsTable)
          .select('avatar_id')
          .eq('id', postId)
          .single();

      final avatar = await _supabase
          .from(DbConfig.avatarsTable)
          .select('owner_user_id, name')
          .eq('id', post['avatar_id'])
          .single();

      // Don't create notification if user comments on their own post
      if (avatar['owner_user_id'] == commenterId) return;

      await _supabase.from(DbConfig.notificationsTable).insert({
        'user_id': avatar['owner_user_id'],
        'type': DbConfig.commentNotification,
        'title': 'New Comment',
        'message': 'Someone commented on your ${avatar['name']} post',
        'related_post_id': postId,
        'related_user_id': commenterId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Failed to create comment notification: $e');
    }
  }

  Future<void> _createFollowNotification(String avatarId, String followerId) async {
    try {
      final avatar = await _supabase
          .from(DbConfig.avatarsTable)
          .select('owner_user_id, name')
          .eq('id', avatarId)
          .single();

      // Don't create notification if user follows their own avatar
      if (avatar['owner_user_id'] == followerId) return;

      await _supabase.from(DbConfig.notificationsTable).insert({
        'user_id': avatar['owner_user_id'],
        'type': DbConfig.followNotification,
        'title': 'New Follower',
        'message': 'Someone started following ${avatar['name']}',
        'related_avatar_id': avatarId,
        'related_user_id': followerId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Failed to create follow notification: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    // Unsubscribe from all realtime channels
    for (final channel in _realtimeSubscriptions.values) {
      channel.unsubscribe();
    }
    _realtimeSubscriptions.clear();
  }
}
