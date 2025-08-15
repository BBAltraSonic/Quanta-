import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../models/comment.dart';
import '../services/auth_service.dart';
import '../store/state_service_adapter.dart';

/// Centralized ownership detection and management utility
/// Provides reliable methods to determine element ownership across all data types
class OwnershipManager {
  static final OwnershipManager _instance = OwnershipManager._internal();
  factory OwnershipManager() => _instance;
  OwnershipManager._internal();

  final AuthService _authService = AuthService();
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();

  /// Get the current authenticated user ID
  String? get currentUserId => _authService.currentUserId;

  /// Check if the current user is authenticated
  bool get isAuthenticated => currentUserId != null;

  // ==================== PROFILE OWNERSHIP ====================

  /// Check if the current user owns a specific user profile
  bool isOwnProfile(String? userId) {
    if (!isAuthenticated || userId == null) return false;
    return currentUserId == userId;
  }

  /// Check if the current user owns a UserModel profile
  bool isOwnUserModel(UserModel? user) {
    if (user?.id == null) return false;
    return isOwnProfile(user!.id);
  }

  // ==================== POST OWNERSHIP ====================

  /// Check if the current user owns a specific post
  bool isOwnPost(PostModel? post) {
    if (!isAuthenticated || post == null) return false;
    
    // Check direct ownership via user_id if available
    if (post.userId != null) {
      return currentUserId == post.userId;
    }
    
    // Check ownership via avatar_id
    if (post.avatarId != null) {
      return isOwnAvatar(post.avatarId);
    }
    
    return false;
  }

  /// Check ownership by post ID (uses cached data or fetches if needed)
  bool isOwnPostById(String? postId) {
    if (!isAuthenticated || postId == null) return false;
    
    // Try to get from cached posts first
    final cachedPost = _stateAdapter.getCachedPost(postId);
    if (cachedPost != null) {
      return isOwnPost(cachedPost);
    }
    
    // If not cached, we can't determine ownership reliably
    // This should trigger a fetch in the calling code
    debugPrint('⚠️ Post $postId not in cache - ownership check may be unreliable');
    return false;
  }

  // ==================== AVATAR OWNERSHIP ====================

  /// Check if the current user owns a specific avatar
  bool isOwnAvatar(String? avatarId) {
    if (!isAuthenticated || avatarId == null) return false;
    
    // Try to get from cached avatars first
    final cachedAvatar = _stateAdapter.getCachedAvatar(avatarId);
    if (cachedAvatar != null) {
      return isOwnAvatarModel(cachedAvatar);
    }
    
    // If not cached, we can't determine ownership reliably
    debugPrint('⚠️ Avatar $avatarId not in cache - ownership check may be unreliable');
    return false;
  }

  /// Check if the current user owns an AvatarModel
  bool isOwnAvatarModel(AvatarModel? avatar) {
    if (!isAuthenticated || avatar == null) return false;
    return currentUserId == avatar.ownerUserId;
  }

  // ==================== COMMENT OWNERSHIP ====================

  /// Check if the current user owns a specific comment
  bool isOwnComment(Comment? comment) {
    if (!isAuthenticated || comment == null) return false;
    
    // Check direct ownership via user_id
    if (comment.userId != null) {
      return currentUserId == comment.userId;
    }
    
    // Check ownership via avatar_id if user_id is not available
    if (comment.avatarId != null) {
      return isOwnAvatar(comment.avatarId);
    }
    
    return false;
  }

  /// Check comment ownership by ID (uses cached data)
  bool isOwnCommentById(String? commentId) {
    if (!isAuthenticated || commentId == null) return false;
    
    // Try to get from cached comments first
    final cachedComment = _stateAdapter.getCachedComment(commentId);
    if (cachedComment != null) {
      return isOwnComment(cachedComment);
    }
    
    debugPrint('⚠️ Comment $commentId not in cache - ownership check may be unreliable');
    return false;
  }

  // ==================== GENERIC OWNERSHIP HELPERS ====================

  /// Generic ownership check that works with any object that has a userId property
  bool isOwnElement(dynamic element) {
    if (!isAuthenticated || element == null) return false;
    
    // Handle different types of elements
    if (element is PostModel) return isOwnPost(element);
    if (element is UserModel) return isOwnUserModel(element);
    if (element is AvatarModel) return isOwnAvatarModel(element);
    if (element is Comment) return isOwnComment(element);
    
    // Handle raw maps/JSON objects
    if (element is Map<String, dynamic>) {
      return _isOwnElementFromMap(element);
    }
    
    // Try reflection-based approach for other objects
    try {
      final userId = element.userId;
      if (userId is String) {
        return currentUserId == userId;
      }
    } catch (e) {
      // Fallback - try different property names
      try {
        final ownerId = element.ownerId ?? element.owner_id;
        if (ownerId is String) {
          return currentUserId == ownerId;
        }
      } catch (e2) {
        debugPrint('⚠️ Could not determine ownership for element: $element');
      }
    }
    
    return false;
  }

  /// Helper to check ownership from Map data
  bool _isOwnElementFromMap(Map<String, dynamic> data) {
    // Common user ID fields to check
    final userIdFields = [
      'user_id', 'userId', 'owner_id', 'ownerId', 
      'owner_user_id', 'ownerUserId', 'id'
    ];
    
    for (final field in userIdFields) {
      final userId = data[field];
      if (userId is String && userId.isNotEmpty) {
        if (currentUserId == userId) return true;
      }
    }
    
    // Check avatar ownership for posts
    final avatarId = data['avatar_id'] ?? data['avatarId'];
    if (avatarId is String && avatarId.isNotEmpty) {
      return isOwnAvatar(avatarId);
    }
    
    return false;
  }

  // ==================== OPPOSITE STATE HELPERS ====================

  /// Check if the element belongs to someone else (not the current user)
  bool isOtherElement(dynamic element) {
    if (!isAuthenticated) return false;
    return !isOwnElement(element);
  }

  /// Specific helpers for opposite states
  bool isOtherProfile(String? userId) => !isOwnProfile(userId);
  bool isOtherPost(PostModel? post) => !isOwnPost(post);
  bool isOtherAvatar(String? avatarId) => !isOwnAvatar(avatarId);
  bool isOtherComment(Comment? comment) => !isOwnComment(comment);

  // ==================== PERMISSION HELPERS ====================

  /// Check if the current user can edit an element
  bool canEdit(dynamic element) {
    return isOwnElement(element);
  }

  /// Check if the current user can delete an element
  bool canDelete(dynamic element) {
    return isOwnElement(element);
  }

  /// Check if the current user can view private details of an element
  bool canViewPrivateDetails(dynamic element) {
    return isOwnElement(element);
  }

  /// Check if the current user can modify settings for an element
  bool canModifySettings(dynamic element) {
    return isOwnElement(element);
  }

  /// Check if the current user can follow/unfollow the element owner
  bool canFollowElement(dynamic element) {
    return isAuthenticated && isOtherElement(element);
  }

  /// Check if the current user can report or block the element owner
  bool canReportElement(dynamic element) {
    return isAuthenticated && isOtherElement(element);
  }

  // ==================== OWNERSHIP STATE FOR SPECIFIC CONTEXTS ====================

  /// Get ownership state for a specific element with detailed context
  OwnershipState getOwnershipState(dynamic element) {
    if (!isAuthenticated) {
      return OwnershipState.unauthenticated;
    }
    
    if (isOwnElement(element)) {
      return OwnershipState.owned;
    } else if (element != null) {
      return OwnershipState.other;
    } else {
      return OwnershipState.unknown;
    }
  }

  // ==================== CACHE WARMING FOR RELIABLE OWNERSHIP CHECKS ====================

  /// Warm up ownership cache for better reliability
  void warmOwnershipCache() {
    // This can be called when the user logs in to pre-populate
    // ownership data for better offline reliability
    debugPrint('🔄 Warming up ownership cache...');
    
    // The StateServiceAdapter should handle caching user's own content
    // This is mainly a placeholder for future enhancements
  }

  // ==================== DEBUGGING AND LOGGING ====================

  /// Debug helper to log ownership information for an element
  void debugOwnership(dynamic element, {String? context}) {
    if (!kDebugMode) return;
    
    final state = getOwnershipState(element);
    final elementType = element.runtimeType.toString();
    
    debugPrint('''
🔍 Ownership Debug${context != null ? ' ($context)' : ''}:
  Element Type: $elementType
  Current User: $currentUserId
  Ownership State: $state
  Can Edit: ${canEdit(element)}
  Can Delete: ${canDelete(element)}
  Can Follow: ${canFollowElement(element)}
    ''');
  }
}

/// Enumeration of possible ownership states
enum OwnershipState {
  /// User is not authenticated
  unauthenticated,
  
  /// Current user owns the element
  owned,
  
  /// Another user owns the element
  other,
  
  /// Ownership cannot be determined (element is null or invalid)
  unknown,
}

/// Extension to provide convenient boolean checks on OwnershipState
extension OwnershipStateExtension on OwnershipState {
  bool get isOwned => this == OwnershipState.owned;
  bool get isOther => this == OwnershipState.other;
  bool get isUnauthenticated => this == OwnershipState.unauthenticated;
  bool get isUnknown => this == OwnershipState.unknown;
  bool get canInteract => isOwned || isOther;
}
