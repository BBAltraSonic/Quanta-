import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';

/// Demo content service that works without Supabase
/// This is used when AppConfig.demoMode is true
class DemoContentService {
  static final DemoContentService _instance = DemoContentService._internal();
  factory DemoContentService() => _instance;
  DemoContentService._internal();

  // Demo data storage
  final List<PostModel> _demoPosts = [];
  final List<CommentModel> _demoComments = [];

  // Initialize demo content service
  Future<void> initialize() async {
    debugPrint('🎭 Initializing Demo Content Service');
    _generateDemoContent();
  }

  // Create new post (demo version)
  Future<PostModel?> createPost({
    required String avatarId,
    required PostType type,
    File? mediaFile,
    required String caption,
    List<String>? hashtags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('🎭 Demo create post: $caption');

      // Create demo post
      final post = PostModel.create(
        avatarId: avatarId,
        type: type,
        videoUrl: type == PostType.video ? 'https://demo.video.url' : null,
        imageUrl: type == PostType.image ? 'https://demo.image.url' : null,
        thumbnailUrl: type == PostType.video
            ? 'https://demo.thumbnail.url'
            : null,
        caption: caption,
        hashtags: hashtags ?? PostModel.extractHashtags(caption),
        metadata: metadata,
      );

      _demoPosts.insert(0, post); // Add to beginning for newest first

      debugPrint('✅ Demo post created successfully: ${post.id}');
      return post;
    } catch (e) {
      debugPrint('❌ Demo error creating post: $e');
      rethrow;
    }
  }

  // Get posts for feed with pagination (demo version)
  Future<List<PostModel>> getFeedPosts({
    int limit = 20,
    int offset = 0,
    String? avatarId,
    List<String>? hashtags,
    PostStatus? status,
    String? searchQuery,
    bool orderByTrending = true,
  }) async {
    try {
      debugPrint('🎭 Demo get feed posts');

      var posts = List<PostModel>.from(_demoPosts);

      // Apply filters
      if (avatarId != null) {
        posts = posts.where((p) => p.avatarId == avatarId).toList();
      }
      if (status != null) {
        posts = posts.where((p) => p.status == status).toList();
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        posts = posts
            .where(
              (p) =>
                  p.caption.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  p.hashtags.any(
                    (h) => h.toLowerCase().contains(searchQuery.toLowerCase()),
                  ),
            )
            .toList();
      }

      // Apply pagination
      final start = offset;
      final end = (offset + limit).clamp(0, posts.length);

      return posts.sublist(start, end);
    } catch (e) {
      debugPrint('❌ Demo error fetching feed posts: $e');
      return [];
    }
  }

  // Get specific post with avatar data (demo version)
  Future<Map<String, dynamic>?> getPostWithAvatar(String postId) async {
    try {
      debugPrint('🎭 Demo get post with avatar: $postId');

      final post = _demoPosts.firstWhere(
        (p) => p.id == postId,
        orElse: () =>
            _demoPosts.isNotEmpty ? _demoPosts.first : _createDemoPost(),
      );

      return {
        ...post.toJson(),
        'avatars': {
          'id': post.avatarId,
          'name': 'Demo Avatar',
          'image_url': 'https://demo.avatar.url',
          'niche': 'Demo Niche',
          'personality_traits': ['friendly', 'creative'],
          'owner_id': 'demo-owner-id',
        },
      };
    } catch (e) {
      debugPrint('❌ Demo error fetching post with avatar: $e');
      return null;
    }
  }

  // Update post engagement (demo version)
  Future<void> updatePostEngagement(
    String postId, {
    int? likesIncrement,
    int? commentsIncrement,
    int? sharesIncrement,
    int? viewsIncrement,
  }) async {
    try {
      debugPrint('🎭 Demo update post engagement: $postId');

      final postIndex = _demoPosts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final post = _demoPosts[postIndex];
        final updatedPost = post.copyWith(
          likesCount: post.likesCount + (likesIncrement ?? 0),
          commentsCount: post.commentsCount + (commentsIncrement ?? 0),
          sharesCount: post.sharesCount + (sharesIncrement ?? 0),
          viewsCount: post.viewsCount + (viewsIncrement ?? 0),
        );
        _demoPosts[postIndex] = updatedPost;
      }
    } catch (e) {
      debugPrint('❌ Demo error updating post engagement: $e');
    }
  }

  // Add comment to post (demo version)
  Future<CommentModel?> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
    bool isAiGenerated = false,
    String? avatarId,
  }) async {
    try {
      debugPrint('🎭 Demo add comment: $text');

      final comment = CommentModel.create(
        postId: postId,
        userId: 'demo-user-id',
        avatarId: avatarId,
        text: text,
        isAiGenerated: isAiGenerated,
        parentCommentId: parentCommentId,
      );

      _demoComments.add(comment);

      // Update post comment count
      await updatePostEngagement(postId, commentsIncrement: 1);

      return comment;
    } catch (e) {
      debugPrint('❌ Demo error adding comment: $e');
      rethrow;
    }
  }

  // Get comments for post (demo version)
  Future<List<CommentModel>> getPostComments(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      debugPrint('🎭 Demo get post comments: $postId');

      final comments = _demoComments.where((c) => c.postId == postId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final start = offset;
      final end = (offset + limit).clamp(0, comments.length);

      return comments.sublist(start, end);
    } catch (e) {
      debugPrint('❌ Demo error fetching comments: $e');
      return [];
    }
  }

  // Delete post (demo version)
  Future<bool> deletePost(String postId) async {
    try {
      debugPrint('🎭 Demo delete post: $postId');

      _demoPosts.removeWhere((p) => p.id == postId);
      return true; // In demo mode, always return success
    } catch (e) {
      debugPrint('❌ Demo error deleting post: $e');
      return false;
    }
  }

  // Get trending hashtags (demo version)
  Future<List<Map<String, dynamic>>> getTrendingHashtags({
    int limit = 20,
  }) async {
    try {
      debugPrint('🎭 Demo get trending hashtags');

      return [
        {'hashtag': '#ai', 'count': 150},
        {'hashtag': '#avatar', 'count': 120},
        {'hashtag': '#demo', 'count': 100},
        {'hashtag': '#flutter', 'count': 80},
        {'hashtag': '#social', 'count': 60},
      ];
    } catch (e) {
      debugPrint('❌ Demo error fetching trending hashtags: $e');
      return [];
    }
  }

  // Generate demo content
  void _generateDemoContent() {
    debugPrint('🎭 Generating demo content');

    // Create some demo posts
    final demoPosts = [
      _createDemoPost(
        caption:
            'Welcome to Quanta! 🚀 This is a demo post showcasing our AI avatar platform. #ai #avatar #demo',
        type: PostType.image,
      ),
      _createDemoPost(
        caption:
            'Check out this amazing AI-generated content! The future is here. #ai #future #tech',
        type: PostType.image,
      ),
      _createDemoPost(
        caption:
            'Creating engaging content has never been easier with AI avatars! #content #creation #ai',
        type: PostType.video,
      ),
    ];

    _demoPosts.addAll(demoPosts);

    // Create some demo comments
    for (final post in demoPosts) {
      _demoComments.addAll([
        CommentModel.create(
          postId: post.id,
          userId: 'demo-user-1',
          text: 'This is amazing! Love the concept.',
          isAiGenerated: false,
        ),
        CommentModel.create(
          postId: post.id,
          userId: 'demo-user-2',
          text: 'Great work on this platform! 👏',
          isAiGenerated: false,
        ),
      ]);
    }
  }

  PostModel _createDemoPost({String? caption, PostType type = PostType.image}) {
    return PostModel.create(
      avatarId: 'demo-avatar-id',
      type: type,
      videoUrl: type == PostType.video ? 'https://demo.video.url' : null,
      imageUrl: type == PostType.image ? 'https://demo.image.url' : null,
      thumbnailUrl: type == PostType.video
          ? 'https://demo.thumbnail.url'
          : null,
      caption:
          caption ??
          'This is a demo post in the Quanta AI Avatar Platform! #demo #ai',
      hashtags: ['#demo', '#ai', '#avatar'],
    );
  }
}
