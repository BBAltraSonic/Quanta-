import 'package:flutter/foundation.dart';
import '../models/comment.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import 'comment_service.dart';
import 'auth_service.dart';
import 'avatar_service.dart';

/// Model for AI comment suggestions
class AICommentSuggestion {
  final String id;
  final String postId;
  final String avatarId;
  final String suggestedText;
  final DateTime createdAt;
  final bool isAccepted;
  final bool isDeclined;

  const AICommentSuggestion({
    required this.id,
    required this.postId,
    required this.avatarId,
    required this.suggestedText,
    required this.createdAt,
    this.isAccepted = false,
    this.isDeclined = false,
  });

  AICommentSuggestion copyWith({
    String? id,
    String? postId,
    String? avatarId,
    String? suggestedText,
    DateTime? createdAt,
    bool? isAccepted,
    bool? isDeclined,
  }) {
    return AICommentSuggestion(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      avatarId: avatarId ?? this.avatarId,
      suggestedText: suggestedText ?? this.suggestedText,
      createdAt: createdAt ?? this.createdAt,
      isAccepted: isAccepted ?? this.isAccepted,
      isDeclined: isDeclined ?? this.isDeclined,
    );
  }

  bool get isPending => !isAccepted && !isDeclined;
}

/// Service for managing AI comment suggestions
class AICommentSuggestionService {
  static final AICommentSuggestionService _instance = AICommentSuggestionService._internal();
  factory AICommentSuggestionService() => _instance;
  AICommentSuggestionService._internal();

  final CommentService _commentService = CommentService();
  final AuthService _authService = AuthService();
  final AvatarService _avatarService = AvatarService();

  // Cache for AI suggestions by post ID
  final Map<String, List<AICommentSuggestion>> _suggestionsCache = {};

  /// Generate AI comment suggestions for a post
  Future<List<AICommentSuggestion>> generateSuggestions({
    required String postId,
    required PostModel post,
    required List<Comment> existingComments,
    int maxSuggestions = 2,
  }) async {
    try {
      // Check if user owns any avatars that could comment
      final userAvatars = await _getUserOwnedAvatars();
      if (userAvatars.isEmpty) {
        return [];
      }

      // Generate AI comment replies using the existing service
      final aiComments = await _commentService.generateAICommentReplies(
        postId: postId,
        post: post,
        existingComments: existingComments,
        maxReplies: maxSuggestions,
      );

      // Convert to suggestions
      final suggestions = aiComments.map((comment) {
        return AICommentSuggestion(
          id: comment.id,
          postId: postId,
          avatarId: comment.avatarId!,
          suggestedText: comment.text,
          createdAt: comment.createdAt,
        );
      }).toList();

      // Cache the suggestions
      _suggestionsCache[postId] = suggestions;

      debugPrint('💡 Generated ${suggestions.length} AI comment suggestions for post $postId');
      return suggestions;
    } catch (e) {
      debugPrint('❌ Error generating AI comment suggestions: $e');
      return [];
    }
  }

  /// Get pending suggestions for a post
  List<AICommentSuggestion> getPendingSuggestions(String postId) {
    final suggestions = _suggestionsCache[postId] ?? [];
    return suggestions.where((s) => s.isPending).toList();
  }

  /// Accept an AI comment suggestion and post it as a real comment
  Future<Comment?> acceptSuggestion(AICommentSuggestion suggestion) async {
    try {
      // Post the comment using the suggestion text
      final comment = await _commentService.addComment(
        postId: suggestion.postId,
        text: suggestion.suggestedText,
      );

      // Mark suggestion as accepted
      _updateSuggestionStatus(suggestion, isAccepted: true);

      debugPrint('✅ Accepted AI comment suggestion: ${suggestion.id}');
      return comment;
    } catch (e) {
      debugPrint('❌ Error accepting AI comment suggestion: $e');
      return null;
    }
  }

  /// Decline an AI comment suggestion
  void declineSuggestion(AICommentSuggestion suggestion) {
    _updateSuggestionStatus(suggestion, isDeclined: true);
    debugPrint('❌ Declined AI comment suggestion: ${suggestion.id}');
  }

  /// Update suggestion status in cache
  void _updateSuggestionStatus(AICommentSuggestion suggestion, {bool? isAccepted, bool? isDeclined}) {
    final suggestions = _suggestionsCache[suggestion.postId];
    if (suggestions == null) return;

    final index = suggestions.indexWhere((s) => s.id == suggestion.id);
    if (index == -1) return;

    suggestions[index] = suggestion.copyWith(
      isAccepted: isAccepted ?? suggestion.isAccepted,
      isDeclined: isDeclined ?? suggestion.isDeclined,
    );
  }

  /// Check if user has AI suggestions available for a post
  Future<bool> hasSuggestionsForPost(String postId) async {
    try {
      final userAvatars = await _getUserOwnedAvatars();
      if (userAvatars.isEmpty) return false;

      final pendingSuggestions = getPendingSuggestions(postId);
      return pendingSuggestions.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get avatars owned by current user
  Future<List<AvatarModel>> _getUserOwnedAvatars() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return [];

      // For now, just get the user's main avatar
      // In the future, this could be expanded to support multiple avatars per user
      final avatar = await _avatarService.getUserAvatar();
      return avatar != null ? [avatar] : [];
    } catch (e) {
      debugPrint('Error getting user avatars: $e');
      return [];
    }
  }

  /// Clear suggestions cache
  void clearCache() {
    _suggestionsCache.clear();
  }

  /// Clear suggestions for a specific post
  void clearSuggestionsForPost(String postId) {
    _suggestionsCache.remove(postId);
  }

  /// Get avatar for suggestion
  Future<AvatarModel?> getAvatarForSuggestion(AICommentSuggestion suggestion) async {
    try {
      final userAvatars = await _getUserOwnedAvatars();
      return userAvatars.where((avatar) => avatar.id == suggestion.avatarId).firstOrNull;
    } catch (e) {
      debugPrint('Error getting avatar for suggestion: $e');
      return null;
    }
  }
}
