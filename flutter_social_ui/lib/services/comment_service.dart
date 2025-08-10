import 'package:flutter/foundation.dart';
import '../models/comment.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'ai_service.dart';
import 'avatar_service.dart';

/// Service for handling comments and AI comment generation
class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  final AuthService _authService = AuthService();
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
      final avatars = await _avatarService.getAllAvatars();
      final aiComments = <Comment>[];
      
      // Select random avatars to comment
      avatars.shuffle();
      final commentingAvatars = avatars.take(maxReplies);
      
      for (final avatar in commentingAvatars) {
        // Skip if avatar already commented
        final hasCommented = existingComments.any((c) => c.authorId == avatar.id);
        if (hasCommented) continue;
        
        try {
          final aiCommentText = await _generateAIComment(post, avatar, existingComments);
          
          final aiComment = Comment(
            id: 'ai_comment_${DateTime.now().millisecondsSinceEpoch}_${avatar.id}',
            postId: postId,
            userId: avatar.id,
            userName: avatar.name,
            userAvatar: avatar.avatarImageUrl ?? 'assets/images/p.jpg',
            text: aiCommentText,
            createdAt: DateTime.now().add(Duration(
              seconds: aiComments.length * 30 + 10, // Stagger AI comments
            )),
            likes: 0,
            repliesCount: 0,
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

  /// Delete a comment
  Future<bool> deleteComment(String commentId) async {
    try {
      return _deleteCommentSupabase(commentId);
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }



  Future<String> _generateAIComment(PostModel post, AvatarModel avatar, List<Comment> existingComments) async {
    try {
      // Get conversation context from existing comments
      final commentContext = existingComments.take(3).map((c) => c.text).toList();
      
      final response = await _aiService.generateComment(
        postCaption: post.caption,
        postType: post.type == PostType.video ? 'video' : 'image',
        avatar: avatar,
        context: commentContext.join(' | '),
      );
      
      return response;
    } catch (e) {
      // Fallback to contextual comment generation
      return _generateContextualComment(post, avatar, existingComments);
    }
  }

  String _generateContextualComment(PostModel post, AvatarModel avatar, List<Comment> existingComments) {
    final caption = post.caption.toLowerCase();
    final avatarName = avatar.name;
    final niche = avatar.niche.displayName.toLowerCase();
    
    // Niche-specific responses
    if (niche.contains('technology') || niche.contains('tech')) {
      if (caption.contains(RegExp(r'\b(ai|technology|innovation|code|dev)\b'))) {
        final techComments = [
          'This is exactly the kind of innovation we need! 💻',
          'The tech behind this is fascinating! How did you approach it?',
          'Love seeing technology being used creatively like this! 🚀',
          'This could revolutionize how we think about ${niche}!',
          'The implementation details here are impressive! 👨‍💻',
        ];
        techComments.shuffle();
        return techComments.first;
      }
    } else if (niche.contains('art') || niche.contains('creative')) {
      if (caption.contains(RegExp(r'\b(art|creative|design|beautiful|aesthetic)\b'))) {
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
      if (caption.contains(RegExp(r'\b(workout|fitness|health|strong|training)\b'))) {
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
  Future<Comment> _addCommentSupabase(String postId, String text, String? parentCommentId) async {
    throw Exception(
      'Comment system is not yet fully implemented. '
      'Please ensure Supabase database is properly configured with comments table.'
    );
  }

  Future<List<Comment>> _getPostCommentsSupabase(String postId, int limit, int offset) async {
    throw Exception(
      'Comment retrieval service is not yet fully implemented. '
      'Please ensure Supabase database is properly configured with comments table.'
    );
  }

  Future<int> _getCommentCountSupabase(String postId) async {
    throw Exception(
      'Comment counting service is not yet fully implemented. '
      'Please ensure Supabase database is properly configured with comments table.'
    );
  }

  Future<bool> _toggleCommentLikeSupabase(String commentId) async {
    throw Exception(
      'Comment like system is not yet fully implemented. '
      'Please ensure Supabase database is properly configured with comment likes table.'
    );
  }

  Future<bool> _deleteCommentSupabase(String commentId) async {
    throw Exception(
      'Comment deletion service is not yet fully implemented. '
      'Please ensure Supabase database is properly configured with comments table.'
    );
  }

  /// Clear all cache
  void clearCache() {
    // Note: Cache clearing functionality needs to be implemented
    // when the real comment storage system is in place
  }
}
