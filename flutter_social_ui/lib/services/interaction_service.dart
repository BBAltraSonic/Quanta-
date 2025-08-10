import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/comment.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'simple_supabase_service.dart';
import 'error_handling_service.dart';

/// Service for handling social interactions like likes, comments, shares, and saves
class InteractionService {
  static final InteractionService _instance = InteractionService._internal();
  factory InteractionService() => _instance;
  InteractionService._internal();

  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // In-memory cache for demo mode
  final Map<String, Set<String>> _likedPosts = {};
  final Map<String, Set<String>> _savedPosts = {};
  final Map<String, List<Comment>> _postComments = {};
  final Map<String, Set<String>> _sharedPosts = {};

  /// Like or unlike a post
  Future<bool> toggleLike(String postId) async {
    final userId = _authService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      if (false) {
        return _toggleLikeDemo(postId, userId);
      } else {
        return _toggleLikeSupabase(postId, userId);
      }
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
      if (false) {
        return _toggleSaveDemo(postId, userId);
      } else {
        return _toggleSaveSupabase(postId, userId);
      }
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
      if (false) {
        _sharePostDemo(postId, userId, message);
      } else {
        await _sharePostSupabase(postId, userId, message);
      }
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
      if (false) {
        return _addCommentDemo(postId, text, userId, parentCommentId);
      } else {
        return _addCommentSupabase(postId, text, userId, parentCommentId);
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  /// Get comments for a post
  Future<List<Comment>> getComments(String postId, {int limit = 20, int offset = 0}) async {
    try {
      if (false) {
        return _getCommentsDemo(postId, limit, offset);
      } else {
        return _getCommentsSupabase(postId, limit, offset);
      }
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
        return _likedPosts[postId]?.contains(userId) ?? false;
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
        return _savedPosts[postId]?.contains(userId) ?? false;
      } else {
        return _hasSavedSupabase(postId, userId);
      }
    } catch (e) {
      debugPrint('Error checking save status: $e');
      return false;
    }
  }

  // Demo mode implementations
  bool _toggleLikeDemo(String postId, String userId) {
    _likedPosts[postId] ??= <String>{};
    final hasLiked = _likedPosts[postId]!.contains(userId);
    
    if (hasLiked) {
      _likedPosts[postId]!.remove(userId);
      return false;
    } else {
      _likedPosts[postId]!.add(userId);
      return true;
    }
  }

  bool _toggleSaveDemo(String postId, String userId) {
    _savedPosts[postId] ??= <String>{};
    final hasSaved = _savedPosts[postId]!.contains(userId);
    
    if (hasSaved) {
      _savedPosts[postId]!.remove(userId);
      return false;
    } else {
      _savedPosts[postId]!.add(userId);
      return true;
    }
  }

  void _sharePostDemo(String postId, String userId, String? message) {
    _sharedPosts[postId] ??= <String>{};
    _sharedPosts[postId]!.add(userId);
    debugPrint('Demo: Post $postId shared by $userId with message: $message');
  }

  Comment _addCommentDemo(String postId, String text, String userId, String? parentCommentId) {
    _postComments[postId] ??= <Comment>[];
    
    final comment = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      postId: postId,
      userId: userId,
      userName: 'Demo User',
      userAvatar: 'assets/images/p.jpg',
      text: text,
      createdAt: DateTime.now(),
      likes: 0,
      hasLiked: false,
      repliesCount: 0,
      parentCommentId: parentCommentId,
    );
    
    _postComments[postId]!.insert(0, comment);
    return comment;
  }

  List<Comment> _getCommentsDemo(String postId, int limit, int offset) {
    final comments = _postComments[postId] ?? <Comment>[];
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, comments.length);
    
    if (startIndex >= comments.length) return <Comment>[];
    return comments.sublist(startIndex, endIndex);
  }

  // Real Supabase implementations
  Future<bool> _toggleLikeSupabase(String postId, String userId) async {
    try {
      // Check if already liked
      final existingLike = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        return false;
      } else {
        // Like
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
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
          .from('saved_posts')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingSave != null) {
        // Unsave
        await _supabase
            .from('saved_posts')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        return false;
      } else {
        // Save
        await _supabase.from('saved_posts').insert({
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
      await _supabase.from('post_shares').insert({
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
      final response = await _supabase.from('comments').insert({
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
          .from('comments')
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
          .from('post_likes')
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
          .from('saved_posts')
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
      if (false) {
        return {
          'likes': _likedPosts[postId]?.length ?? 0,
          'saves': _savedPosts[postId]?.length ?? 0,
          'shares': _sharedPosts[postId]?.length ?? 0,
          'comments': _postComments[postId]?.length ?? 0,
        };
      } else {
        // TODO: Implement Supabase stats fetching
        return {
          'likes': 0,
          'saves': 0,
          'shares': 0,
          'comments': 0,
        };
      }
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

  /// Clear cache (useful for demo mode)
  void clearCache() {
    _likedPosts.clear();
    _savedPosts.clear();
    _postComments.clear();
    _sharedPosts.clear();
  }
}
