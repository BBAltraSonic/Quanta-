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
  
  // In-memory cache for demo mode
  final Map<String, List<Comment>> _postComments = {};
  final Map<String, int> _commentCounts = {};

  /// Add a comment to a post
  Future<Comment> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) async {
    try {
      if (false) {
        return _addCommentDemo(postId, text, parentCommentId);
      } else {
        return _addCommentSupabase(postId, text, parentCommentId);
      }
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
      if (false) {
        return _getPostCommentsDemo(postId, limit, offset);
      } else {
        return _getPostCommentsSupabase(postId, limit, offset);
      }
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
      if (false) {
        return _toggleCommentLikeDemo(commentId);
      } else {
        return _toggleCommentLikeSupabase(commentId);
      }
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
          
          // Add to demo storage
          if (false) {
            _postComments[postId] = _postComments[postId] ?? [];
            _postComments[postId]!.add(aiComment);
            _commentCounts[postId] = (_commentCounts[postId] ?? 0) + 1;
          }
          
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
      if (false) {
        return _deleteCommentDemo(commentId);
      } else {
        return _deleteCommentSupabase(commentId);
      }
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }

  // Demo mode implementations
  Comment _addCommentDemo(String postId, String text, String? parentCommentId) {
    final userId = _authService.currentUserId ?? 'demo-user-1';
    
    final comment = Comment(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      userId: userId ?? 'demo-user',
      userName: 'You',
      userAvatar: 'assets/images/We.jpg',
      text: text,
      createdAt: DateTime.now(),
      likes: 0,
      repliesCount: 0,
      parentCommentId: parentCommentId,
    );
    
    _postComments[postId] = _postComments[postId] ?? [];
    _postComments[postId]!.add(comment);
    _commentCounts[postId] = (_commentCounts[postId] ?? 0) + 1;
    
    return comment;
  }

  List<Comment> _getPostCommentsDemo(String postId, int limit, int offset) {
    final comments = _postComments[postId] ?? [];
    
    // Sort by creation time (newest first)
    comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, comments.length);
    
    if (startIndex >= comments.length) return [];
    
    return comments.sublist(startIndex, endIndex);
  }

  bool _toggleCommentLikeDemo(String commentId) {
    // Find comment and toggle like (simplified for demo)
    for (final comments in _postComments.values) {
      for (final comment in comments) {
        if (comment.id == commentId) {
          // In a real implementation, track user likes
          return true; // Assume liked
        }
      }
    }
    return false;
  }

  bool _deleteCommentDemo(String commentId) {
    for (final entry in _postComments.entries) {
      final comments = entry.value;
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        comments.removeAt(index);
        _commentCounts[entry.key] = (_commentCounts[entry.key] ?? 1) - 1;
        return true;
      }
    }
    return false;
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

  /// Initialize demo data
  void initializeDemoData() {
    // Sample comments for demo posts
    final demoComments = <String, List<Comment>>{
      'post-1': [
        Comment(
          id: 'comment-1-1',
          postId: 'post-1',
          userId: 'user-1',
          userName: 'Alex Chen',
          userAvatar: 'assets/images/p.jpg',
          text: 'This is absolutely amazing! 🔥',
          createdAt: DateTime.now().subtract(Duration(hours: 2)),
          likes: 12,
          repliesCount: 2,
        ),
        Comment(
          id: 'comment-1-2',
          postId: 'post-1',
          userId: 'avatar-2',
          userName: 'TechBot',
          userAvatar: 'assets/images/p.jpg',
          text: 'The innovation here is incredible! Love seeing technology push boundaries! 💻✨',
          createdAt: DateTime.now().subtract(Duration(hours: 1)),
          likes: 8,
          repliesCount: 0,
        ),
      ],
    };
    
    _postComments.addAll(demoComments);
    _commentCounts['post-1'] = 2;
  }

  // Supabase implementations (placeholders)
  Future<Comment> _addCommentSupabase(String postId, String text, String? parentCommentId) async {
    // TODO: Implement Supabase comment creation
    throw UnimplementedError('Supabase comment creation not implemented yet');
  }

  Future<List<Comment>> _getPostCommentsSupabase(String postId, int limit, int offset) async {
    // TODO: Implement Supabase comment retrieval
    throw UnimplementedError('Supabase comment retrieval not implemented yet');
  }

  Future<int> _getCommentCountSupabase(String postId) async {
    // TODO: Implement Supabase comment count
    throw UnimplementedError('Supabase comment count not implemented yet');
  }

  Future<bool> _toggleCommentLikeSupabase(String commentId) async {
    // TODO: Implement Supabase comment like toggle
    throw UnimplementedError('Supabase comment like toggle not implemented yet');
  }

  Future<bool> _deleteCommentSupabase(String commentId) async {
    // TODO: Implement Supabase comment deletion
    throw UnimplementedError('Supabase comment deletion not implemented yet');
  }

  /// Clear all cache
  void clearCache() {
    _postComments.clear();
    _commentCounts.clear();
  }
}
