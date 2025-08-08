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

// Enhanced comment model for posts
class CommentModel {
  final String id;
  final String postId;
  final String? userId;
  final String? avatarId;
  final String text;
  final bool isAiGenerated;
  final String? parentCommentId;
  final int likesCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed properties
  bool get isReply => parentCommentId != null;
  bool get isFromAvatar => avatarId != null;
  bool get isFromUser => userId != null;

  CommentModel({
    required this.id,
    required this.postId,
    this.userId,
    this.avatarId,
    required this.text,
    this.isAiGenerated = false,
    this.parentCommentId,
    this.likesCount = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommentModel.create({
    required String postId,
    String? userId,
    String? avatarId,
    required String text,
    bool isAiGenerated = false,
    String? parentCommentId,
  }) {
    final now = DateTime.now();
    return CommentModel(
      id: const Uuid().v4(),
      postId: postId,
      userId: userId,
      avatarId: avatarId,
      text: text.trim(),
      isAiGenerated: isAiGenerated,
      parentCommentId: parentCommentId,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String?,
      avatarId: json['avatar_id'] as String?,
      text: json['text'] as String,
      isAiGenerated: json['is_ai_generated'] as bool? ?? false,
      parentCommentId: json['parent_comment_id'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'avatar_id': avatarId,
      'text': text,
      'is_ai_generated': isAiGenerated,
      'parent_comment_id': parentCommentId,
      'likes_count': likesCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CommentModel copyWith({
    String? text,
    int? likesCount,
    bool? isActive,
  }) {
    return CommentModel(
      id: id,
      postId: postId,
      userId: userId,
      avatarId: avatarId,
      text: text ?? this.text,
      isAiGenerated: isAiGenerated,
      parentCommentId: parentCommentId,
      likesCount: likesCount ?? this.likesCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CommentModel(id: $id, postId: $postId, isFromAvatar: $isFromAvatar)';
  }
}
