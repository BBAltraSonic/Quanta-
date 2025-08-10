import 'package:uuid/uuid.dart';

enum CommentAuthorType { user, avatar }

class Comment {
  final String id;
  final String postId;
  final String? userId;
  final String? avatarId;
  final String authorId; // Either userId or avatarId
  final CommentAuthorType authorType;
  final String text;
  final bool isAiGenerated;
  final String? parentCommentId;
  final int likesCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // For UI display
  final String? userName;
  final String? userAvatar;
  bool hasLiked;
  
  // Computed properties for backward compatibility
  int get likes => likesCount;
  set likes(int value) {} // Setter for compatibility (use copyWith instead)
  
  int get repliesCount => 0; // TODO: Implement replies counting

  Comment({
    required this.id,
    required this.postId,
    this.userId,
    this.avatarId,
    required this.authorId,
    required this.authorType,
    required this.text,
    this.isAiGenerated = false,
    this.parentCommentId,
    this.likesCount = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userAvatar,
    this.hasLiked = false,
  });

  // Create new comment
  factory Comment.create({
    required String postId,
    required String text,
    required String authorId,
    required CommentAuthorType authorType,
    String? userId,
    String? avatarId,
    bool isAiGenerated = false,
    String? parentCommentId,
  }) {
    final now = DateTime.now();
    return Comment(
      id: const Uuid().v4(),
      postId: postId,
      userId: userId,
      avatarId: avatarId,
      authorId: authorId,
      authorType: authorType,
      text: text.trim(),
      isAiGenerated: isAiGenerated,
      parentCommentId: parentCommentId,
      createdAt: now,
      updatedAt: now,
    );
  }

  // From JSON (Supabase)
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String?,
      avatarId: json['avatar_id'] as String?,
      authorId: json['user_id'] ?? json['avatar_id'] ?? '',
      authorType: json['user_id'] != null 
          ? CommentAuthorType.user 
          : CommentAuthorType.avatar,
      text: json['text'] as String,
      isAiGenerated: json['is_ai_generated'] as bool? ?? false,
      parentCommentId: json['parent_comment_id'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // To JSON (Supabase)
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

  Comment copyWith({
    String? text,
    int? likesCount,
    bool? hasLiked,
    bool? isActive,
  }) {
    return Comment(
      id: id,
      postId: postId,
      userId: userId,
      avatarId: avatarId,
      authorId: authorId,
      authorType: authorType,
      text: text ?? this.text,
      isAiGenerated: isAiGenerated,
      parentCommentId: parentCommentId,
      likesCount: likesCount ?? this.likesCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      userName: userName,
      userAvatar: userAvatar,
      hasLiked: hasLiked ?? this.hasLiked,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Comment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Comment(id: $id, postId: $postId, authorType: $authorType)';
  }
}


