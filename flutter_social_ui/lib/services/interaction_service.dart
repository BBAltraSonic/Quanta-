import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/comment.dart';
import '../config/app_config.dart';
import '../config/db_config.dart';
import 'auth_service.dart';
import 'error_handling_service.dart';

/// Service for handling social interactions like likes, comments, shares, and saves
class InteractionService {
  static final InteractionService _instance = InteractionService._internal();
  factory InteractionService() => _instance;
  InteractionService._internal();

  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Liked posts storage
  final Set<String> _likedPosts = {};
  
  // Saved posts storage
  final Set<String> _savedPosts = {};


  /// Like or unlike a post
  Future<bool> toggleLike(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      return _toggleLikeSupabase(postId, userId);
    } catch (e) {
      debugPrint('Error toggling like: $e');
      rethrow;
    }
  }

  /// Save or unsave a post
  Future<bool> toggleSave(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      return _toggleSaveSupabase(postId, userId);
    } catch (e) {
      debugPrint('Error toggling save: $e');
      rethrow;
    }
  }

  /// Share a post
  Future<void> sharePost(String postId, {String? message}) async {
    final userId = _authService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      await _sharePostSupabase(postId, userId, message);
    } catch (e) {
      debugPrint('Error sharing post: $e');
      rethrow;
    }
  }

  /// Add a comment to a post
  Future<Comment> addComment(String postId, String text, {String? parentCommentId}) async {
    final userId = _authService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      return _addCommentSupabase(postId, text, userId, parentCommentId);
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  /// Get comments for a post
  Future<List<Comment>> getComments(String postId, {int limit = 20, int offset = 0}) async {
    try {
      return _getCommentsSupabase(postId, limit, offset);
    } catch (e) {
      debugPrint('Error getting comments: $e');
      rethrow;
    }
  }

  /// Check if user has liked a post
  Future<bool> hasLiked(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      if (false) {
        return false; // _likedPosts is a Set, not a Map
      } else {
        return _hasLikedSupabase(postId, userId);
      }
    } catch (e) {
      debugPrint('Error checking like status: $e');
      return false;
    }
  }

  /// Check if user has saved a post
  Future<bool> hasSaved(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      if (false) {
        return false; // _savedPosts is a Set, not a Map
      } else {
        return _hasSavedSupabase(postId, userId);
      }
    } catch (e) {
      debugPrint('Error checking save status: $e');
      return false;
    }
  }



  // Real Supabase implementations
  Future<bool> _toggleLikeSupabase(String postId, String userId) async {
    try {
      // First check current status using RPC function
      final statusResult = await _supabase.rpc('get_post_interaction_status', params: {
        'target_post_id': postId,
      });

      if (!statusResult['success']) {
        debugPrint('❌ Failed to get interaction status: ${statusResult['error']}');
        return false;
      }

      final isCurrentlyLiked = statusResult['data']['user_liked'] as bool;

      if (isCurrentlyLiked) {
        // Unlike using RPC function
        final result = await _supabase.rpc('decrement_likes_count', params: {
          'target_post_id': postId,
        });

        if (!result['success']) {
          debugPrint('❌ Failed to unlike post: ${result['error']}');
          return false;
        }

        return false;
      } else {
        // Like using RPC function
        final result = await _supabase.rpc('increment_likes_count', params: {
          'target_post_id': postId,
        });

        if (!result['success']) {
          debugPrint('❌ Failed to like post: ${result['error']}');
          return false;
        }

        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle like: $e');
      return false;
    }
  }

  Future<bool> _toggleSaveSupabase(String postId, String userId) async {
    try {
      // Check if already saved
      final existingSave = await _supabase
          .from(DbConfig.savedPostsTable)
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingSave != null) {
        // Unsave
        await _supabase
            .from(DbConfig.savedPostsTable)
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        return false;
      } else {
        // Save
        await _supabase.from(DbConfig.savedPostsTable).insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle save: $e');
      return false;
    }
  }

  Future<void> _sharePostSupabase(String postId, String userId, String? message) async {
    try {
      // Record the share action
      await _supabase.from(DbConfig.sharesTable).insert({
        'post_id': postId,
        'user_id': userId,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('Post $postId shared by user $userId');
    } catch (e) {
      debugPrint('❌ Failed to share post: $e');
    }
  }

  Future<Comment> _addCommentSupabase(String postId, String text, String userId, String? parentCommentId) async {
    try {
      final response = await _supabase.from(DbConfig.commentsTable).insert({
        'post_id': postId,
        'user_id': userId,
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return Comment.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to add comment: $e');
      rethrow;
    }
  }

  Future<List<Comment>> _getCommentsSupabase(String postId, int limit, int offset) async {
    try {
      final response = await _supabase
          .from(DbConfig.commentsTable)
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true)
          .range(offset, offset + limit - 1);
      
      return response.map<Comment>((json) => Comment.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Failed to get comments: $e');
      return [];
    }
  }

  Future<bool> _hasLikedSupabase(String postId, String userId) async {
    try {
      final like = await _supabase
          .from(DbConfig.likesTable)
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

  Future<bool> _hasSavedSupabase(String postId, String userId) async {
    try {
      final save = await _supabase
          .from(DbConfig.savedPostsTable)
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      
      return save != null;
    } catch (e) {
      debugPrint('❌ Failed to check save status: $e');
      return false;
    }
  }

  /// Get interaction statistics for a post
  Future<Map<String, dynamic>> getPostStats(String postId) async {
    try {
      // TODO: Implement Supabase stats fetching
      return {
        'likes': 0,
        'saves': 0,
        'shares': 0,
        'comments': 0,
      };
    } catch (e) {
      debugPrint('Error getting post stats: $e');
      return {
        'likes': 0,
        'saves': 0,
        'shares': 0,
        'comments': 0,
      };
    }
  }


}
