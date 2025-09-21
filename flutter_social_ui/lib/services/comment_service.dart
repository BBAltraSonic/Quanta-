import 'package:flutter/foundation.dart';
import '../models/comment.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../config/db_config.dart';

import 'auth_service.dart';
import 'ai_service.dart';
import 'avatar_service.dart';
import 'ownership_guard_service.dart';

/// Service for handling comments and AI comment generation
class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  final AuthService _authService = AuthService();
  final OwnershipGuardService _ownershipGuard = OwnershipGuardService();

  // Comment counts cache for demo mode
  final Map<String, int> _commentCounts = {};
  final AIService _aiService = AIService();
  final AvatarService _avatarService = AvatarService();

  /// Add a comment to a post
  Future<Comment> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) async {
    try {
      return _addCommentSupabase(postId, text, parentCommentId);
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  /// Get comments for a post
  Future<List<Comment>> getPostComments({
    required String postId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return _getPostCommentsSupabase(postId, limit, offset);
    } catch (e) {
      debugPrint('Error getting post comments: $e');
      return [];
    }
  }

  /// Get comment count for a post
  Future<int> getCommentCount(String postId) async {
    try {
      if (false) {
        return _commentCounts[postId] ?? 0;
      } else {
        return _getCommentCountSupabase(postId);
      }
    } catch (e) {
      debugPrint('Error getting comment count: $e');
      return 0;
    }
  }

  /// Like or unlike a comment
  Future<bool> toggleCommentLike(String commentId) async {
    try {
      return _toggleCommentLikeSupabase(commentId);
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      return false;
    }
  }

  /// Generate AI comment replies for avatars
  Future<List<Comment>> generateAICommentReplies({
    required String postId,
    required PostModel post,
    required List<Comment> existingComments,
    int maxReplies = 3,
  }) async {
    try {
      final avatars = await _avatarService.getUserAvatar(); // Get user's avatar
      final avatarList = avatars != null ? [avatars] : <AvatarModel>[];
      final aiComments = <Comment>[];

      // Select random avatars to comment
      avatarList.shuffle();
      final commentingAvatars = avatarList.take(maxReplies);

      for (final avatar in commentingAvatars) {
        // Skip if avatar already commented
        final hasCommented = existingComments.any(
          (c) => c.authorId == avatar.id,
        );
        if (hasCommented) continue;

        try {
          final aiCommentText = await _generateAIComment(
            post,
            avatar,
            existingComments,
          );

          final aiComment = Comment.create(
            postId: postId,
            text: aiCommentText,
            authorId: avatar.id,
            authorType: CommentAuthorType.avatar,
            avatarId: avatar.id,
            isAiGenerated: true,
          );

          aiComments.add(aiComment);
        } catch (e) {
          debugPrint('Error generating AI comment for ${avatar.name}: $e');
        }
      }

      return aiComments;
    } catch (e) {
      debugPrint('Error generating AI comment replies: $e');
      return [];
    }
  }

  /// Edit a comment
  Future<Comment?> editComment(String commentId, String newText) async {
    try {
      // Guard comment edit to ensure only the comment owner can edit
      await _ownershipGuard.guardCommentEdit(commentId);

      return _editCommentSupabase(commentId, newText);
    } catch (e) {
      debugPrint('Error editing comment: $e');
      return null;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String commentId) async {
    try {
      // Guard comment deletion to ensure only the comment owner can delete
      await _ownershipGuard.guardCommentDelete(commentId);

      return _deleteCommentSupabase(commentId);
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }

  /// Get replies for a comment
  Future<List<Comment>> getCommentReplies({
    required String commentId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return _getCommentRepliesSupabase(commentId, limit, offset);
    } catch (e) {
      debugPrint('Error getting comment replies: $e');
      return [];
    }
  }

  /// Check if current user has liked a comment
  Future<bool> hasUserLikedComment(String commentId) async {
    try {
      return _hasUserLikedCommentSupabase(commentId);
    } catch (e) {
      debugPrint('Error checking comment like status: $e');
      return false;
    }
  }

  Future<String> _generateAIComment(
    PostModel post,
    AvatarModel avatar,
    List<Comment> existingComments,
  ) async {
    try {
      // Get conversation context from existing comments
      final commentContext = existingComments
          .take(3)
          .map((c) => c.text)
          .toList();

      final response = await _aiService.generateComment(
        avatar: avatar,
        postContent: post.caption,
        postType: post.type == PostType.video ? 'video' : 'image',
      );

      return response;
    } catch (e) {
      // Fallback to contextual comment generation
      return _generateContextualComment(post, avatar, existingComments);
    }
  }

  String _generateContextualComment(
    PostModel post,
    AvatarModel avatar,
    List<Comment> existingComments,
  ) {
    final caption = post.caption.toLowerCase();
    final avatarName = avatar.name;
    final niche = avatar.niche.displayName.toLowerCase();

    // Niche-specific responses
    if (niche.contains('technology') || niche.contains('tech')) {
      if (caption.contains(
        RegExp(r'\b(ai|technology|innovation|code|dev)\b'),
      )) {
        final techComments = [
          'This is exactly the kind of innovation we need! 💻',
          'The tech behind this is fascinating! How did you approach it?',
          'Love seeing technology being used creatively like this! 🚀',
          'This could revolutionize how we think about $niche!',
          'The implementation details here are impressive! 👨‍💻',
        ];
        techComments.shuffle();
        return techComments.first;
      }
    } else if (niche.contains('art') || niche.contains('creative')) {
      if (caption.contains(
        RegExp(r'\b(art|creative|design|beautiful|aesthetic)\b'),
      )) {
        final artComments = [
          'The creativity here is absolutely stunning! 🎨',
          'I love how you\'ve approached the composition! 💫',
          'This speaks to me on so many levels! Beautiful work! ✨',
          'The artistic vision here is incredible! 🌟',
          'You\'ve captured something truly special here! 🎭',
        ];
        artComments.shuffle();
        return artComments.first;
      }
    } else if (niche.contains('fitness') || niche.contains('health')) {
      if (caption.contains(
        RegExp(r'\b(workout|fitness|health|strong|training)\b'),
      )) {
        final fitnessComments = [
          'This is so motivating! Keep crushing those goals! 💪',
          'Your dedication to fitness is inspiring! 🏋️‍♀️',
          'Love the energy in this! What\'s your next challenge? 🔥',
          'This is exactly the motivation I needed today! 💯',
          'Your fitness journey is amazing to follow! 🌟',
        ];
        fitnessComments.shuffle();
        return fitnessComments.first;
      }
    }

    // General engagement comments based on post type
    if (post.type == PostType.video) {
      final videoComments = [
        'This video is absolutely captivating! 🎬',
        'I could watch this on repeat! Amazing content! 🔄',
        'The storytelling here is phenomenal! 📽️',
        'This deserves way more views! Incredible work! 🌟',
        'You\'ve got such a unique perspective! Love this! ✨',
        'The production quality is outstanding! 🎥',
      ];
      videoComments.shuffle();
      return videoComments.first;
    } else {
      final imageComments = [
        'This image tells such a powerful story! 📸',
        'The composition is absolutely perfect! 🖼️',
        'I can\'t stop looking at this! Beautiful! 😍',
        'You have such an eye for detail! Amazing! 👁️',
        'This is art in its purest form! 🎨',
        'The emotion captured here is incredible! 💫',
      ];
      imageComments.shuffle();
      return imageComments.first;
    }
  }

  // Supabase implementations
  Future<Comment> _addCommentSupabase(
    String postId,
    String text,
    String? parentCommentId,
  ) async {
    // Verify authentication state
    final user = _authService.currentUser;
    final session = _authService.supabase.auth.currentSession;

    if (user == null || session == null) {
      throw Exception('User not authenticated');
    }

    // Double-check the user ID matches the session
    if (user.id != session.user.id) {
      throw Exception('Authentication state mismatch');
    }

    final response = await _authService.supabase
        .from(DbConfig.commentsTable)
        .insert({
          'post_id': postId,
          'user_id': user.id,
          'text': text,
          'parent_comment_id': parentCommentId,
        })
        .select()
        .single();

    return Comment.fromJson(response);
  }

  Future<List<Comment>> _getPostCommentsSupabase(
    String postId,
    int limit,
    int offset,
  ) async {
    try {
      debugPrint('🔍 Loading comments for post: $postId');

      // Get top-level comments first - simplified query to isolate the issue
      final response = await _authService.supabase
          .from(DbConfig.commentsTable)
          .select('*')
          .eq('post_id', postId)
          .isFilter('parent_comment_id', null) // Only top-level comments
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('📊 Raw response from database: $response');

      if (response.isEmpty) {
        debugPrint('📝 No comments found for post $postId');
        return [];
      }

      // Build comment objects with minimal processing first
      List<Comment> comments = [];
      for (final json in response) {
        try {
          debugPrint('🔧 Processing comment JSON: $json');

          // Validate required fields
          if (json['id'] == null) {
            debugPrint('⚠️ Skipping comment with null ID');
            continue;
          }

          if (json['text'] == null) {
            debugPrint('⚠️ Skipping comment with null text');
            continue;
          }

          final comment = Comment.fromJson({
            ...json,
            'replies_count': 0, // Start simple, no replies count for now
          });

          comments.add(
            comment.copyWith(hasLiked: false),
          ); // Start simple, no likes check
          debugPrint('✅ Successfully created comment: ${comment.id}');
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing comment JSON: $e');
          debugPrint('📍 Stack trace: $stackTrace');
          debugPrint('📄 Problematic JSON: $json');
          // Skip this comment and continue with others
          continue;
        }
      }

      debugPrint('✅ Successfully loaded ${comments.length} comments');
      return comments;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _getPostCommentsSupabase: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int> _getCommentCountSupabase(String postId) async {
    final response = await _authService.supabase
        .from(DbConfig.commentsTable)
        .select('id')
        .eq('post_id', postId)
        .count();

    return response.count;
  }

  Future<bool> _toggleCommentLikeSupabase(String commentId) async {
    final user = _authService.currentUser;
    final session = _authService.supabase.auth.currentSession;

    if (user == null || session == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if user already liked this comment
      final existingLike = await _authService.supabase
          .from(DbConfig.commentLikesTable)
          .select('id')
          .eq('user_id', user.id)
          .eq('comment_id', commentId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike the comment
        await _authService.supabase
            .from(DbConfig.commentLikesTable)
            .delete()
            .eq('user_id', user.id)
            .eq('comment_id', commentId);
        return false; // Unliked
      } else {
        // Like the comment
        await _authService.supabase.from(DbConfig.commentLikesTable).insert({
          'user_id': user.id,
          'comment_id': commentId,
        });
        return true; // Liked
      }
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      rethrow;
    }
  }

  Future<Comment?> _editCommentSupabase(
    String commentId,
    String newText,
  ) async {
    final user = _authService.currentUser;
    final session = _authService.supabase.auth.currentSession;

    if (user == null || session == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Update the comment text
      final response = await _authService.supabase
          .from(DbConfig.commentsTable)
          .update({
            'text': newText,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', commentId)
          .eq('user_id', user.id) // Ensure only owner can edit
          .select()
          .single();

      return Comment.fromJson(response);
    } catch (e) {
      debugPrint('Error editing comment: $e');
      rethrow;
    }
  }

  Future<bool> _deleteCommentSupabase(String commentId) async {
    final user = _authService.currentUser;
    final session = _authService.supabase.auth.currentSession;

    if (user == null || session == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Verify user owns this comment before deleting
      final comment = await _authService.supabase
          .from(DbConfig.commentsTable)
          .select('user_id')
          .eq('id', commentId)
          .single();

      if (comment['user_id'] != user.id) {
        throw Exception('Unauthorized: You can only delete your own comments');
      }

      // Delete the comment (cascade will handle comment_likes)
      await _authService.supabase
          .from(DbConfig.commentsTable)
          .delete()
          .eq('id', commentId)
          .eq('user_id', user.id); // Double check for security

      return true;
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }

  Future<List<Comment>> _getCommentRepliesSupabase(
    String commentId,
    int limit,
    int offset,
  ) async {
    final response = await _authService.supabase
        .from(DbConfig.commentsTable)
        .select()
        .eq('parent_comment_id', commentId)
        .order('created_at', ascending: true) // Replies should be chronological
        .limit(limit)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) => Comment.fromJson(json)).toList();
  }

  Future<bool> _hasUserLikedCommentSupabase(String commentId) async {
    final user = _authService.currentUser;
    if (user == null) return false;

    try {
      final response = await _authService.supabase
          .from(DbConfig.commentLikesTable)
          .select('id')
          .eq('user_id', user.id)
          .eq('comment_id', commentId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking comment like: $e');
      return false;
    }
  }

  /// Clear all cache
  void clearCache() {
    // Note: Cache clearing functionality needs to be implemented
    // when the real comment storage system is in place
  }
}
