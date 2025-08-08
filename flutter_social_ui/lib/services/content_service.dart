import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../services/auth_service.dart';

class ContentService {
  static final ContentService _instance = ContentService._internal();
  factory ContentService() => _instance;
  ContentService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Upload limits and validation
  static const int maxVideoSizeMB = 100;
  static const int maxImageSizeMB = 10;
  static const int maxCaptionLength = 2000;
  static const int maxHashtags = 20;
  static const Duration maxVideoDuration = Duration(minutes: 3);
  static const List<String> allowedVideoTypes = ['mp4', 'mov', 'avi'];
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif'];

  // Create new post with media upload
  Future<PostModel?> createPost({
    required String avatarId,
    required PostType type,
    File? mediaFile,
    required String caption,
    List<String>? hashtags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Validate inputs
      await _validatePostData(type, mediaFile, caption, hashtags);

      String? mediaUrl;
      String? thumbnailUrl;

      // Upload media if provided
      if (mediaFile != null) {
        if (type == PostType.video) {
          final urls = await _uploadVideoWithThumbnail(mediaFile, avatarId);
          mediaUrl = urls['video'];
          thumbnailUrl = urls['thumbnail'];
        } else {
          mediaUrl = await _uploadImage(mediaFile, avatarId);
        }
      }

      // Extract hashtags from caption if not provided
      final finalHashtags = hashtags ?? PostModel.extractHashtags(caption);

      // Create post model
      final post = PostModel.create(
        avatarId: avatarId,
        type: type,
        videoUrl: type == PostType.video ? mediaUrl : null,
        imageUrl: type == PostType.image ? mediaUrl : null,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        hashtags: finalHashtags,
        metadata: metadata,
      );

      // Save to database
      final response = await _supabase
          .from('posts')
          .insert(post.toJson())
          .select()
          .single();

      final savedPost = PostModel.fromJson(response);

      // Update avatar stats
      await _updateAvatarPostCount(avatarId, increment: true);

      debugPrint('✅ Post created successfully: ${savedPost.id}');
      return savedPost;

    } catch (e) {
      debugPrint('❌ Error creating post: $e');
      rethrow;
    }
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
    try {
      var query = _supabase
          .from('posts')
          .select('*')
          .eq('is_active', true);

      // Apply filters
      if (avatarId != null) {
        query = query.eq('avatar_id', avatarId);
      }
      if (status != null) {
        query = query.eq('status', status.toString().split('.').last);
      }
      if (hashtags != null && hashtags.isNotEmpty) {
        query = query.overlaps('hashtags', hashtags);
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('caption.ilike.%$searchQuery%,hashtags.cs.{"#${searchQuery.toLowerCase()}"}');
      }

      // Apply ordering
      if (orderByTrending) {
        query = query.order('engagement_rate', ascending: false)
                    .order('created_at', ascending: false);
      } else {
        query = query.order('created_at', ascending: false);
      }

      final response = await query
          .range(offset, offset + limit - 1)
          .limit(limit);

      return response.map<PostModel>((json) => PostModel.fromJson(json)).toList();

    } catch (e) {
      debugPrint('❌ Error fetching feed posts: $e');
      return [];
    }
  }

  // Get specific post with avatar data
  Future<Map<String, dynamic>?> getPostWithAvatar(String postId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('''
            *,
            avatars:avatar_id (
              id, name, image_url, niche, personality_traits, owner_id
            )
          ''')
          .eq('id', postId)
          .eq('is_active', true)
          .single();

      return response;

    } catch (e) {
      debugPrint('❌ Error fetching post with avatar: $e');
      return null;
    }
  }

  // Update post engagement
  Future<void> updatePostEngagement(
    String postId, {
    int? likesIncrement,
    int? commentsIncrement,
    int? sharesIncrement,
    int? viewsIncrement,
  }) async {
    try {
      Map<String, dynamic> updates = {};

      if (likesIncrement != null) {
        updates['likes_count'] = 'likes_count + $likesIncrement';
      }
      if (commentsIncrement != null) {
        updates['comments_count'] = 'comments_count + $commentsIncrement';
      }
      if (sharesIncrement != null) {
        updates['shares_count'] = 'shares_count + $sharesIncrement';
      }
      if (viewsIncrement != null) {
        updates['views_count'] = 'views_count + $viewsIncrement';
      }

      if (updates.isNotEmpty) {
        updates['updated_at'] = DateTime.now().toIso8601String();

        await _supabase
            .from('posts')
            .update(updates)
            .eq('id', postId);

        // Recalculate engagement rate
        await _recalculateEngagementRate(postId);
      }

    } catch (e) {
      debugPrint('❌ Error updating post engagement: $e');
    }
  }

  // Add comment to post
  Future<CommentModel?> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
    bool isAiGenerated = false,
    String? avatarId,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null && avatarId == null) {
        throw Exception('Must be authenticated or specify avatar');
      }

      final comment = CommentModel.create(
        postId: postId,
        userId: user?.id,
        avatarId: avatarId,
        text: text,
        isAiGenerated: isAiGenerated,
        parentCommentId: parentCommentId,
      );

      final response = await _supabase
          .from('comments')
          .insert(comment.toJson())
          .select()
          .single();

      final savedComment = CommentModel.fromJson(response);

      // Update post comment count
      await updatePostEngagement(postId, commentsIncrement: 1);

      return savedComment;

    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      rethrow;
    }
  }

  // Get comments for post
  Future<List<CommentModel>> getPostComments(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('*')
          .eq('post_id', postId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<CommentModel>((json) => CommentModel.fromJson(json)).toList();

    } catch (e) {
      debugPrint('❌ Error fetching comments: $e');
      return [];
    }
  }

  // Delete post
  Future<bool> deletePost(String postId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      // Get post to check ownership
      final postResponse = await _supabase
          .from('posts')
          .select('avatar_id, video_url, image_url, thumbnail_url')
          .eq('id', postId)
          .single();

      final post = PostModel.fromJson(postResponse);

      // Check if user owns the avatar that created this post
      final avatarResponse = await _supabase
          .from('avatars')
          .select('owner_id')
          .eq('id', post.avatarId)
          .single();

      if (avatarResponse['owner_id'] != user.id) {
        throw Exception('Not authorized to delete this post');
      }

      // Soft delete the post
      await _supabase
          .from('posts')
          .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', postId);

      // Update avatar post count
      await _updateAvatarPostCount(post.avatarId, increment: false);

      // Note: We keep media files for potential recovery
      // In production, you might want to delete them after a grace period

      debugPrint('✅ Post deleted successfully: $postId');
      return true;

    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
      return false;
    }
  }

  // Get trending hashtags
  Future<List<Map<String, dynamic>>> getTrendingHashtags({int limit = 20}) async {
    try {
      final response = await _supabase
          .rpc('get_trending_hashtags', params: {'limit_count': limit});

      return List<Map<String, dynamic>>.from(response);

    } catch (e) {
      debugPrint('❌ Error fetching trending hashtags: $e');
      return [];
    }
  }

  // Private helper methods
  Future<void> _validatePostData(
    PostType type,
    File? mediaFile,
    String caption,
    List<String>? hashtags,
  ) async {
    // Validate caption
    if (caption.trim().isEmpty) {
      throw Exception('Caption cannot be empty');
    }
    if (caption.length > maxCaptionLength) {
      throw Exception('Caption too long (max $maxCaptionLength characters)');
    }

    // Validate hashtags
    if (hashtags != null && hashtags.length > maxHashtags) {
      throw Exception('Too many hashtags (max $maxHashtags)');
    }

    // Validate media file
    if (mediaFile != null) {
      final fileSizeMB = await mediaFile.length() / (1024 * 1024);
      final extension = mediaFile.path.split('.').last.toLowerCase();

      if (type == PostType.video) {
        if (fileSizeMB > maxVideoSizeMB) {
          throw Exception('Video file too large (max ${maxVideoSizeMB}MB)');
        }
        if (!allowedVideoTypes.contains(extension)) {
          throw Exception('Unsupported video format (allowed: ${allowedVideoTypes.join(', ')})');
        }
        await _validateVideoDuration(mediaFile);
      } else {
        if (fileSizeMB > maxImageSizeMB) {
          throw Exception('Image file too large (max ${maxImageSizeMB}MB)');
        }
        if (!allowedImageTypes.contains(extension)) {
          throw Exception('Unsupported image format (allowed: ${allowedImageTypes.join(', ')})');
        }
      }
    }
  }

  Future<void> _validateVideoDuration(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      
      final duration = controller.value.duration;
      await controller.dispose();

      if (duration > maxVideoDuration) {
        throw Exception('Video too long (max ${maxVideoDuration.inMinutes} minutes)');
      }
    } catch (e) {
      if (e.toString().contains('Video too long')) rethrow;
      debugPrint('⚠️ Could not validate video duration: $e');
    }
  }

  Future<String> _uploadImage(File imageFile, String avatarId) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileName = '${avatarId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'posts/images/$fileName';

      // Compress image if needed
      final compressedBytes = await _compressImage(bytes);

      final response = await _supabase.storage
          .from('content')
          .uploadBinary(filePath, compressedBytes);

      return _supabase.storage.from('content').getPublicUrl(filePath);

    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> _uploadVideoWithThumbnail(File videoFile, String avatarId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoFileName = '${avatarId}_${timestamp}.mp4';
      final thumbnailFileName = '${avatarId}_${timestamp}_thumb.jpg';
      
      final videoPath = 'posts/videos/$videoFileName';
      final thumbnailPath = 'posts/thumbnails/$thumbnailFileName';

      // Upload video
      final videoBytes = await videoFile.readAsBytes();
      await _supabase.storage
          .from('content')
          .uploadBinary(videoPath, videoBytes);

      final videoUrl = _supabase.storage.from('content').getPublicUrl(videoPath);

      // Generate and upload thumbnail
      final thumbnailBytes = await _generateVideoThumbnail(videoFile);
      if (thumbnailBytes != null) {
        await _supabase.storage
            .from('content')
            .uploadBinary(thumbnailPath, thumbnailBytes);

        final thumbnailUrl = _supabase.storage.from('content').getPublicUrl(thumbnailPath);
        return {'video': videoUrl, 'thumbnail': thumbnailUrl};
      }

      return {'video': videoUrl};

    } catch (e) {
      debugPrint('❌ Error uploading video: $e');
      rethrow;
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      // Resize if too large
      final resized = image.width > 1080 || image.height > 1080
          ? img.copyResize(image, width: 1080, height: 1080, interpolation: img.Interpolation.linear)
          : image;

      // Compress as JPEG with 85% quality
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));

    } catch (e) {
      debugPrint('⚠️ Image compression failed, using original: $e');
      return bytes;
    }
  }

  Future<Uint8List?> _generateVideoThumbnail(File videoFile) async {
    try {
      if (!kIsWeb) {
        final thumbnail = await VideoThumbnail.thumbnailData(
          video: videoFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 640,
          maxHeight: 640,
          quality: 75,
          timeMs: 1000, // 1 second into video
        );
        return thumbnail;
      }
      return null;

    } catch (e) {
      debugPrint('⚠️ Could not generate video thumbnail: $e');
      return null;
    }
  }

  Future<void> _updateAvatarPostCount(String avatarId, {required bool increment}) async {
    try {
      final change = increment ? 1 : -1;
      await _supabase
          .from('avatars')
          .update({
            'posts_count': 'posts_count + $change',
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', avatarId);

    } catch (e) {
      debugPrint('⚠️ Error updating avatar post count: $e');
    }
  }

  Future<void> _recalculateEngagementRate(String postId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('views_count, likes_count, comments_count, shares_count')
          .eq('id', postId)
          .single();

      final views = response['views_count'] as int;
      final likes = response['likes_count'] as int;
      final comments = response['comments_count'] as int;
      final shares = response['shares_count'] as int;

      final engagementRate = PostModel.calculateEngagementRate(likes, comments, shares, views);

      await _supabase
          .from('posts')
          .update({'engagement_rate': engagementRate})
          .eq('id', postId);

    } catch (e) {
      debugPrint('⚠️ Error recalculating engagement rate: $e');
    }
  }
}
