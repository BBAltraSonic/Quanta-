import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'content_service.dart';

/// Service for handling content uploads and management
class ContentUploadService {
  static final ContentUploadService _instance = ContentUploadService._internal();
  factory ContentUploadService() => _instance;
  ContentUploadService._internal();

  final AuthService _authService = AuthService();
  final ContentService _contentService = ContentService();
  
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
      if (false) {
        return _uploadContentDemo(
          avatarId: avatarId,
          caption: caption,
          mediaFile: mediaFile,
          externalMediaUrl: externalMediaUrl,
          type: type,
          hashtags: hashtags,
        );
      } else {
        return _uploadContentSupabase(
          avatarId: avatarId,
          caption: caption,
          mediaFile: mediaFile,
          externalMediaUrl: externalMediaUrl,
          type: type,
          hashtags: hashtags,
        );
      }
    } catch (e) {
      debugPrint('Error uploading content: $e');
      rethrow;
    }
  }

  /// Upload media file and get URL
  Future<String> uploadMediaFile(File file, PostType type) async {
    try {
      if (false) {
        return _uploadMediaFileDemo(file, type);
      } else {
        return _uploadMediaFileSupabase(file, type);
      }
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
      if (false) {
        return _importExternalContentDemo(
          avatarId: avatarId,
          caption: caption,
          sourceUrl: sourceUrl,
          sourcePlatform: sourcePlatform,
          type: type,
          metadata: metadata,
        );
      } else {
        return _importExternalContentSupabase(
          avatarId: avatarId,
          caption: caption,
          sourceUrl: sourceUrl,
          sourcePlatform: sourcePlatform,
          type: type,
          metadata: metadata,
        );
      }
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
  ValidationResult validateContent({
    required String caption,
    File? mediaFile,
    String? externalUrl,
    required PostType type,
  }) {
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
      final maxSize = type == PostType.video ? 100 * 1024 * 1024 : 10 * 1024 * 1024; // 100MB for video, 10MB for image
      
      if (fileSize > maxSize) {
        errors.add('File size exceeds limit (${type == PostType.video ? '100MB' : '10MB'})');
      }
      
      final extension = mediaFile.path.split('.').last.toLowerCase();
      final validExtensions = type == PostType.video 
          ? ['mp4', 'mov', 'avi', 'webm']
          : ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      
      if (!validExtensions.contains(extension)) {
        errors.add('Invalid file type. Supported: ${validExtensions.join(', ')}');
      }
    }
    
    if (externalUrl != null && !(Uri.tryParse(externalUrl)?.isAbsolute ?? false)) {
      errors.add('Invalid URL format');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  // Demo mode implementations
  Future<PostModel> _uploadContentDemo({
    required String avatarId,
    required String caption,
    File? mediaFile,
    String? externalMediaUrl,
    PostType type = PostType.image,
    List<String>? hashtags,
  }) async {
    // Simulate upload delay
    await Future.delayed(Duration(seconds: 2));
    
    String mediaUrl;
    if (mediaFile != null) {
      mediaUrl = await _uploadMediaFileDemo(mediaFile, type);
    } else if (externalMediaUrl != null) {
      mediaUrl = externalMediaUrl;
    } else {
      mediaUrl = 'assets/images/p.jpg'; // Fallback
    }
    
    final now = DateTime.now();
    final post = PostModel(
      id: 'post_${now.millisecondsSinceEpoch}',
      avatarId: avatarId,
      caption: caption,
      type: type,
      imageUrl: type == PostType.image ? mediaUrl : null,
      videoUrl: type == PostType.video ? mediaUrl : null,
      hashtags: hashtags ?? extractHashtags(caption),
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      viewsCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    
    return post;
  }

  Future<String> _uploadMediaFileDemo(File file, PostType type) async {
    // Simulate file upload
    await Future.delayed(Duration(milliseconds: 1500));
    
    // In demo mode, return a placeholder URL
    return type == PostType.video 
        ? 'https://example.com/demo_video.mp4'
        : 'https://example.com/demo_image.jpg';
  }

  Future<PostModel> _importExternalContentDemo({
    required String avatarId,
    required String caption,
    required String sourceUrl,
    required String sourcePlatform,
    PostType type = PostType.image,
    Map<String, dynamic>? metadata,
  }) async {
    // Simulate import delay
    await Future.delayed(Duration(seconds: 3));
    
    final now = DateTime.now();
    final post = PostModel(
      id: 'imported_${now.millisecondsSinceEpoch}',
      avatarId: avatarId,
      caption: '$caption\n\n📡 Imported from $sourcePlatform',
      type: type,
      imageUrl: type == PostType.image ? sourceUrl : null,
      videoUrl: type == PostType.video ? sourceUrl : null,
      hashtags: extractHashtags(caption)..add('#Imported'),
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      viewsCount: 0,
      createdAt: now,
      updatedAt: now,
      metadata: {
        'source': sourcePlatform,
        'originalUrl': sourceUrl,
        ...?metadata,
      },
    );
    
    return post;
  }

  // Supabase implementations (placeholders)
  Future<PostModel> _uploadContentSupabase({
    required String avatarId,
    required String caption,
    File? mediaFile,
    String? externalMediaUrl,
    PostType type = PostType.image,
    List<String>? hashtags,
  }) async {
    // TODO: Implement Supabase content upload
    throw UnimplementedError('Supabase content upload not implemented yet');
  }

  Future<String> _uploadMediaFileSupabase(File file, PostType type) async {
    // TODO: Implement Supabase file upload
    throw UnimplementedError('Supabase file upload not implemented yet');
  }

  Future<PostModel> _importExternalContentSupabase({
    required String avatarId,
    required String caption,
    required String sourceUrl,
    required String sourcePlatform,
    PostType type = PostType.image,
    Map<String, dynamic>? metadata,
  }) async {
    // TODO: Implement Supabase external content import
    throw UnimplementedError('Supabase external content import not implemented yet');
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
