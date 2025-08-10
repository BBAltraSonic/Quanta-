import '../models/post_model.dart';
import '../config/app_config.dart';
import 'content_service.dart';
import 'demo_content_service.dart';
import 'dart:io';

/// Wrapper that chooses between real ContentService and DemoContentService
/// based on AppConfig.demoMode setting
class ContentServiceWrapper {
  static final ContentServiceWrapper _instance =
      ContentServiceWrapper._internal();
  factory ContentServiceWrapper() => _instance;
  ContentServiceWrapper._internal();

  dynamic _service;
  bool _isInitialized = false;

  ContentServiceWrapper get instance => this;

  // Initialize the appropriate service
  Future<void> initialize() async {
    if (_isInitialized) {
      return; // Already initialized, skip
    }

    if (AppConfig.demoMode) {
      _service = DemoContentService();
    } else {
      _service = ContentService();
    }

    await _service.initialize();
    _isInitialized = true;
  }

  // Create new post with media upload
  Future<PostModel?> createPost({
    required String avatarId,
    required PostType type,
    File? mediaFile,
    required String caption,
    List<String>? hashtags,
    Map<String, dynamic>? metadata,
  }) async {
    return await _service.createPost(
      avatarId: avatarId,
      type: type,
      mediaFile: mediaFile,
      caption: caption,
      hashtags: hashtags,
      metadata: metadata,
    );
  }

  // Get posts for feed with pagination
  Future<List<PostModel>> getFeedPosts({
    int limit = 20,
    int offset = 0,
    String? avatarId,
    List<String>? hashtags,
    PostStatus? status,
    String? searchQuery,
    bool orderByTrending = true,
  }) async {
    return await _service.getFeedPosts(
      limit: limit,
      offset: offset,
      avatarId: avatarId,
      hashtags: hashtags,
      status: status,
      searchQuery: searchQuery,
      orderByTrending: orderByTrending,
    );
  }

  // Get specific post with avatar data
  Future<Map<String, dynamic>?> getPostWithAvatar(String postId) async {
    return await _service.getPostWithAvatar(postId);
  }

  // Update post engagement
  Future<void> updatePostEngagement(
    String postId, {
    int? likesIncrement,
    int? commentsIncrement,
    int? sharesIncrement,
    int? viewsIncrement,
  }) async {
    return await _service.updatePostEngagement(
      postId,
      likesIncrement: likesIncrement,
      commentsIncrement: commentsIncrement,
      sharesIncrement: sharesIncrement,
      viewsIncrement: viewsIncrement,
    );
  }

  // Add comment to post
  Future<CommentModel?> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
    bool isAiGenerated = false,
    String? avatarId,
  }) async {
    return await _service.addComment(
      postId: postId,
      text: text,
      parentCommentId: parentCommentId,
      isAiGenerated: isAiGenerated,
      avatarId: avatarId,
    );
  }

  // Get comments for post
  Future<List<CommentModel>> getPostComments(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return await _service.getPostComments(postId, limit: limit, offset: offset);
  }

  // Delete post
  Future<bool> deletePost(String postId) async {
    return await _service.deletePost(postId);
  }

  // Get trending hashtags
  Future<List<Map<String, dynamic>>> getTrendingHashtags({
    int limit = 20,
  }) async {
    return await _service.getTrendingHashtags(limit: limit);
  }
}
