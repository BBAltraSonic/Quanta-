import 'package:uuid/uuid.dart';

enum PostType { image, video }
enum PostStatus { draft, published, archived, flagged }

class PostModel {
  final String id;
  final String avatarId;
  final PostType type;
  final String? videoUrl;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String caption;
  final List<String> hashtags;
  final PostStatus status;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final double engagementRate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  // Computed fields for convenience
  String get mediaUrl => type == PostType.video ? videoUrl! : imageUrl!;
  bool get hasMedia => (type == PostType.video && videoUrl != null) || 
                      (type == PostType.image && imageUrl != null);
  int get totalEngagement => likesCount + commentsCount + sharesCount;

  PostModel({
    required this.id,
    required this.avatarId,
    required this.type,
    this.videoUrl,
    this.imageUrl,
    this.thumbnailUrl,
    required this.caption,
    required this.hashtags,
    this.status = PostStatus.published,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.engagementRate = 0.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  // Create new post
  factory PostModel.create({
    required String avatarId,
    required PostType type,
    String? videoUrl,
    String? imageUrl,
    String? thumbnailUrl,
    required String caption,
    required List<String> hashtags,
    PostStatus status = PostStatus.published,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return PostModel(
      id: const Uuid().v4(),
      avatarId: avatarId,
      type: type,
      videoUrl: videoUrl,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption.trim(),
      hashtags: hashtags.map((tag) => _cleanHashtag(tag)).toList(),
      status: status,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
  }

  // From JSON (Supabase)
  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      avatarId: json['avatar_id'] as String,
      type: PostType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => PostType.image,
      ),
      videoUrl: json['video_url'] as String?,
      imageUrl: json['image_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String? ?? '',
      hashtags: (json['hashtags'] as List<dynamic>?)?.cast<String>() ?? [],
      status: PostStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PostStatus.published,
      ),
      viewsCount: json['views_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      sharesCount: json['shares_count'] as int? ?? 0,
      engagementRate: (json['engagement_rate'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // To JSON (Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatar_id': avatarId,
      'type': type.toString().split('.').last,
      'video_url': videoUrl,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'caption': caption,
      'hashtags': hashtags,
      'status': status.toString().split('.').last,
      'views_count': viewsCount,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': sharesCount,
      'engagement_rate': engagementRate,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Copy with method
  PostModel copyWith({
    String? caption,
    List<String>? hashtags,
    PostStatus? status,
    int? viewsCount,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    double? engagementRate,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return PostModel(
      id: id,
      avatarId: avatarId,
      type: type,
      videoUrl: videoUrl,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      status: status ?? this.status,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      engagementRate: engagementRate ?? this.engagementRate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      metadata: metadata ?? this.metadata,
    );
  }

  // Extract hashtags from text
  static List<String> extractHashtags(String text) {
    final regex = RegExp(r'#[a-zA-Z0-9_]+');
    final matches = regex.allMatches(text);
    return matches.map((match) => _cleanHashtag(match.group(0)!)).toList();
  }

  // Clean hashtag format
  static String _cleanHashtag(String hashtag) {
    String cleaned = hashtag.trim();
    if (!cleaned.startsWith('#')) {
      cleaned = '#$cleaned';
    }
    // Remove special characters except underscores
    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9_#]'), '');
    return cleaned.toLowerCase();
  }

  // Calculate engagement rate
  static double calculateEngagementRate(int likes, int comments, int shares, int views) {
    if (views == 0) return 0.0;
    final totalEngagement = likes + comments + shares;
    return (totalEngagement / views) * 100;
  }

  // Get trending score (for algorithm)
  double getTrendingScore() {
    final ageInHours = DateTime.now().difference(createdAt).inHours;
    final agePenalty = ageInHours > 24 ? 0.8 : 1.0; // Reduce score for older posts
    
    // Weight different engagement types
    final weightedEngagement = (likesCount * 1.0) + 
                              (commentsCount * 2.0) + 
                              (sharesCount * 3.0);
    
    final baseScore = (weightedEngagement / (viewsCount + 1)) * 100;
    return baseScore * agePenalty;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PostModel(id: $id, avatarId: $avatarId, type: $type, caption: ${caption.length > 50 ? '${caption.substring(0, 50)}...' : caption})';
  }
}

// Comments are now handled by the unified Comment model in lib/models/comment.dart
// This removes data duplication and ensures consistency across the app
