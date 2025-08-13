import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:storage_client/storage_client.dart';

import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../config/db_config.dart';
import '../utils/environment.dart';
import 'auth_service.dart';


/// Service for handling content uploads and management
class ContentUploadService {
  static final ContentUploadService _instance = ContentUploadService._internal();
  factory ContentUploadService() => _instance;
  ContentUploadService._internal();

  final AuthService _authService = AuthService();

  /// Initialize the service
  Future<void> initialize() async {
    // Initialize any required dependencies
    // For now, this is a placeholder that doesn't throw an error
    return;
  }
  
  /// Create a new post
  Future<PostModel?> createPost({
    required String avatarId,
    required PostType type,
    File? mediaFile,
    required String caption,
    List<String>? hashtags,
  }) async {
    try {
      return await _uploadContentSupabase(
        avatarId: avatarId,
        caption: caption,
        mediaFile: mediaFile,
        type: type,
        hashtags: hashtags ?? [],
      );
    } catch (e) {
      debugPrint('Error creating post: $e');
      return null;
    }
  }

  /// Upload content for an avatar
  Future<PostModel> uploadContent({
    required String avatarId,
    required String caption,
    File? mediaFile,
    String? externalMediaUrl,
    PostType type = PostType.image,
    List<String>? hashtags,
  }) async {
    try {
      return _uploadContentSupabase(
        avatarId: avatarId,
        caption: caption,
        mediaFile: mediaFile,
        externalMediaUrl: externalMediaUrl,
        type: type,
        hashtags: hashtags,
      );
    } catch (e) {
      debugPrint('Error uploading content: $e');
      rethrow;
    }
  }

  /// Upload media file and get URL
  /// Note: avatarId-scoped paths are required by storage RLS policies.
  /// Prefer using createPost/importExternalContent which handle this.
  Future<String> uploadMediaFile(File file, PostType type) async {
    try {
      throw Exception('Use createPost() or importExternalContent(); avatarId is required for storage path.');
    } catch (e) {
      debugPrint('Error uploading media file: $e');
      rethrow;
    }
  }

  /// Import content from external sources (Hugging Face, Runway, etc.)
  Future<PostModel> importExternalContent({
    required String avatarId,
    required String caption,
    required String sourceUrl,
    required String sourcePlatform,
    PostType type = PostType.image,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return _importExternalContentSupabase(
        avatarId: avatarId,
        caption: caption,
        sourceUrl: sourceUrl,
        sourcePlatform: sourcePlatform,
        type: type,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('Error importing external content: $e');
      rethrow;
    }
  }

  /// Get supported external platforms
  List<ExternalPlatform> getSupportedPlatforms() {
    return [
      ExternalPlatform(
        id: 'huggingface',
        name: 'Hugging Face',
        description: 'AI-generated images and models',
        icon: '🤗',
        supportedTypes: [PostType.image, PostType.video],
      ),
      ExternalPlatform(
        id: 'runway',
        name: 'Runway ML',
        description: 'AI video generation and editing',
        icon: '🎬',
        supportedTypes: [PostType.video, PostType.image],
      ),
      ExternalPlatform(
        id: 'midjourney',
        name: 'Midjourney',
        description: 'AI art generation',
        icon: '🎨',
        supportedTypes: [PostType.image],
      ),
      ExternalPlatform(
        id: 'stable_diffusion',
        name: 'Stable Diffusion',
        description: 'Open-source AI image generation',
        icon: '🌌',
        supportedTypes: [PostType.image],
      ),
      ExternalPlatform(
        id: 'dall_e',
        name: 'DALL-E',
        description: 'OpenAI\'s image generation',
        icon: '🖼️',
        supportedTypes: [PostType.image],
      ),
    ];
  }

  /// Extract hashtags from caption
  List<String> extractHashtags(String caption) {
    final hashtagRegex = RegExp(r'#\w+');
    final matches = hashtagRegex.allMatches(caption);
    return matches.map((match) => match.group(0)!).toList();
  }

  /// Suggest hashtags based on content and avatar niche
  List<String> suggestHashtags(String caption, AvatarModel avatar) {
    final suggestions = <String>[];
    final lowerCaption = caption.toLowerCase();
    final niche = avatar.niche.displayName.toLowerCase();
    
    // Add niche-specific hashtags
    suggestions.add('#${niche.replaceAll(' ', '')}');
    
    // Content-based suggestions
    if (lowerCaption.contains(RegExp(r'\b(ai|artificial|intelligence)\b'))) {
      suggestions.addAll(['#AI', '#ArtificialIntelligence', '#MachineLearning']);
    }
    
    if (lowerCaption.contains(RegExp(r'\b(art|creative|design)\b'))) {
      suggestions.addAll(['#Art', '#Creative', '#Design', '#Digital']);
    }
    
    if (lowerCaption.contains(RegExp(r'\b(tech|technology|innovation)\b'))) {
      suggestions.addAll(['#Tech', '#Technology', '#Innovation', '#Future']);
    }
    
    if (lowerCaption.contains(RegExp(r'\b(video|animation|motion)\b'))) {
      suggestions.addAll(['#Video', '#Animation', '#Motion', '#Visual']);
    }
    
    // General popular hashtags
    suggestions.addAll(['#Avatar', '#Virtual', '#Digital', '#Content']);
    
    // Remove duplicates and return limited set
    return suggestions.toSet().take(10).toList();
  }

  /// Validate content before upload
  Future<ValidationResult> validateContent({
    required String caption,
    File? mediaFile,
    String? externalUrl,
    required PostType type,
  }) async {
    final errors = <String>[];
    
    // Caption validation
    if (caption.trim().isEmpty) {
      errors.add('Caption is required');
    } else if (caption.length > 2000) {
      errors.add('Caption must be less than 2000 characters');
    }
    
    // Media validation
    if (mediaFile == null && externalUrl == null) {
      errors.add('Either upload a file or provide an external URL');
    }
    
    if (mediaFile != null) {
      final fileSize = mediaFile.lengthSync();
      final maxSize = type == PostType.video 
          ? Environment.maxVideoSizeMB * 1024 * 1024 
          : Environment.maxImageSizeMB * 1024 * 1024;
      
      if (fileSize > maxSize) {
        errors.add('File size exceeds limit (${type == PostType.video ? '${Environment.maxVideoSizeMB}MB' : '${Environment.maxImageSizeMB}MB'})');
      }
      
      final extension = mediaFile.path.split('.').last.toLowerCase();
      final validExtensions = type == PostType.video 
          ? ['mp4', 'mov', 'avi', 'webm']
          : ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      
      if (!validExtensions.contains(extension)) {
        errors.add('Invalid file type. Supported: ${validExtensions.join(', ')}');
      }
      
      // Note: Video duration validation removed (no compression service)
    }
    
    if (externalUrl != null && !(Uri.tryParse(externalUrl)?.isAbsolute ?? false)) {
      errors.add('Invalid URL format');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  // Supabase implementations
  Future<PostModel> _uploadContentSupabase({
    required String avatarId,
    required String caption,
    File? mediaFile,
    String? externalMediaUrl,
    PostType type = PostType.image,
    List<String>? hashtags,
  }) async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Validate content first
      final validation = await validateContent(
        caption: caption,
        mediaFile: mediaFile,
        externalUrl: externalMediaUrl,
        type: type,
      );

      if (!validation.isValid) {
        throw Exception('Content validation failed: ${validation.errors.join(', ')}');
      }

      String? mediaUrl;
      String? thumbnailUrl;

      // Upload media file if provided
      if (mediaFile != null) {
        mediaUrl = await _uploadMediaFileSupabase(
          avatarId: avatarId,
          file: mediaFile,
          type: type,
        );
        
        // Generate thumbnail for videos
        if (type == PostType.video) {
          thumbnailUrl = await _generateAndUploadThumbnail(mediaFile, avatarId);
        }
      } else if (externalMediaUrl != null) {
        mediaUrl = externalMediaUrl;
      }

      if (mediaUrl == null) {
        throw Exception('No media URL available');
      }

      // Create post record in database
      const uuid = Uuid();
      final postId = uuid.v4();
      
      final postData = {
        'id': postId,
        'avatar_id': avatarId,
        'type': type == PostType.video ? DbConfig.videoType : DbConfig.imageType,
        'status': DbConfig.publishedStatus,
        'caption': caption,
        'hashtags': hashtags ?? [],
        'video_url': type == PostType.video ? mediaUrl : null,
        'image_url': type == PostType.image ? mediaUrl : null,
        'thumbnail_url': thumbnailUrl,
        'views_count': 0,
        'likes_count': 0,
        'comments_count': 0,
        'shares_count': 0,
        'engagement_rate': 0.0,
        'is_active': true,
        'metadata': {
          'uploaded_by': userId,
          'original_filename': mediaFile?.path.split('/').last,
        },
      };

      final response = await _authService.supabase
          .from(DbConfig.postsTable)
          .insert(postData)
          .select()
          .single();

      // Convert response to PostModel
      return PostModel.fromJson(response);
    } catch (e) {
      debugPrint('Error uploading content to Supabase: $e');
      rethrow;
    }
  }

  /// Upload media file to Supabase storage and return public URL
  Future<String> _uploadMediaFileSupabase({
    required String avatarId,
    required File file,
    required PostType type,
  }) async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('Starting upload for ${type.name} file: ${file.path}');
      debugPrint('File size: ${file.lengthSync()} bytes');

      // Generate unique filename
      const uuid = Uuid();
      final fileId = uuid.v4();
      final extension = path.extension(file.path).toLowerCase();
      final fileName = '$fileId$extension';
      final storagePath = '$avatarId/$fileName';

      debugPrint('Upload path: $storagePath');

      // Determine content type
      String contentType;
      if (type == PostType.video) {
        switch (extension) {
          case '.mp4':
            contentType = 'video/mp4';
            break;
          case '.mov':
            contentType = 'video/quicktime';
            break;
          case '.avi':
            contentType = 'video/x-msvideo';
            break;
          case '.webm':
            contentType = 'video/webm';
            break;
          default:
            contentType = 'video/mp4';
        }
      } else {
        switch (extension) {
          case '.jpg':
          case '.jpeg':
            contentType = 'image/jpeg';
            break;
          case '.png':
            contentType = 'image/png';
            break;
          case '.gif':
            contentType = 'image/gif';
            break;
          case '.webp':
            contentType = 'image/webp';
            break;
          default:
            contentType = 'application/octet-stream';
        }
      }

      // Upload to Supabase storage with proper content type
      final bytes = await file.readAsBytes();
      debugPrint('Read ${bytes.length} bytes from file');
      
      await _authService.supabase.storage
          .from(DbConfig.postsBucket)
          .uploadBinary(
            storagePath, 
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true, // Allow overwriting if needed
            ),
          );

      // Get public URL
      final publicUrl = _authService.supabase.storage
          .from(DbConfig.postsBucket)
          .getPublicUrl(storagePath);

      debugPrint('Upload successful! Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading media file: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Generate and upload video thumbnail with better error handling
  Future<String?> _generateAndUploadThumbnail(File videoFile, String avatarId) async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        debugPrint('User not authenticated for thumbnail upload');
        return null;
      }

      debugPrint('Generating thumbnail for video: ${videoFile.path}');
      
      // Generate thumbnail with error handling
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720,
        maxWidth: 405, // Match the log dimensions
        quality: 75,
        timeMs: 1000, // Get thumbnail at 1 second
      );

      if (thumbnailBytes == null) {
        debugPrint('Failed to generate thumbnail - thumbnailBytes is null');
        return null;
      }

      debugPrint('Generated thumbnail: ${thumbnailBytes.length} bytes');

      // Generate unique filename for thumbnail
      const uuid = Uuid();
      final fileId = uuid.v4();
      final fileName = '${fileId}_thumbnail.jpg';
      final storagePath = '$avatarId/$fileName';

      debugPrint('Uploading thumbnail to: $storagePath');

      // Upload thumbnail to storage with retry
      try {
        await _authService.supabase.storage
            .from(DbConfig.postsBucket)
            .uploadBinary(storagePath, thumbnailBytes);
      } catch (uploadError) {
        debugPrint('Thumbnail upload failed: $uploadError');
        // Try alternative upload method
        await _authService.supabase.storage
            .from(DbConfig.postsBucket)
            .uploadBinary(storagePath, thumbnailBytes, fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ));
      }

      // Get public URL
      final publicUrl = _authService.supabase.storage
          .from(DbConfig.postsBucket)
          .getPublicUrl(storagePath);

      debugPrint('Thumbnail uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error generating/uploading thumbnail: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return null;
    }
  }


  Future<PostModel> _importExternalContentSupabase({
    required String avatarId,
    required String caption,
    required String sourceUrl,
    required String sourcePlatform,
    PostType type = PostType.image,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Validate URL
      final uri = Uri.tryParse(sourceUrl);
      if (uri == null || !uri.isAbsolute) {
        throw Exception('Invalid URL format');
      }

      // Validate platform support
      final supportedPlatforms = getSupportedPlatforms();
      final platform = supportedPlatforms.firstWhere(
        (p) => p.id == sourcePlatform,
        orElse: () => throw Exception('Unsupported platform: $sourcePlatform'),
      );

      if (!platform.supportedTypes.contains(type)) {
        throw Exception('Platform $sourcePlatform does not support ${type.name} content');
      }

      // Create post record with external URL
      const uuid = Uuid();
      final postId = uuid.v4();
      
      final postData = {
        'id': postId,
        'avatar_id': avatarId,
        'type': type == PostType.video ? DbConfig.videoType : DbConfig.imageType,
        'status': DbConfig.publishedStatus,
        'caption': caption,
        'hashtags': extractHashtags(caption),
        'video_url': type == PostType.video ? sourceUrl : null,
        'image_url': type == PostType.image ? sourceUrl : null,
        'thumbnail_url': null, // External content doesn't have thumbnails generated
        'views_count': 0,
        'likes_count': 0,
        'comments_count': 0,
        'shares_count': 0,
        'engagement_rate': 0.0,
        'is_active': true,
        'metadata': {
          'uploaded_by': userId,
          'source_platform': sourcePlatform,
          'source_url': sourceUrl,
          'is_external': true,
          ...?metadata,
        },
      };

      final response = await _authService.supabase
          .from(DbConfig.postsTable)
          .insert(postData)
          .select()
          .single();

      // Convert response to PostModel
      return PostModel.fromJson(response);
    } catch (e) {
      debugPrint('Error importing external content: $e');
      rethrow;
    }
  }
}

/// External platform configuration
class ExternalPlatform {
  final String id;
  final String name;
  final String description;
  final String icon;
  final List<PostType> supportedTypes;

  ExternalPlatform({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.supportedTypes,
  });
}

/// Content validation result
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({
    required this.isValid,
    required this.errors,
  });
}
