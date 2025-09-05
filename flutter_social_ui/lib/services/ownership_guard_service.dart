import 'package:flutter/foundation.dart';
import '../utils/ownership_manager.dart';
import '../store/state_service_adapter.dart';




import '../widgets/ownership_aware_widgets.dart';

/// Service to guard actions based on ownership permissions
/// Prevents unauthorized backend calls and provides proper error handling
class OwnershipGuardService {
  static final OwnershipGuardService _instance = OwnershipGuardService._internal();
  factory OwnershipGuardService() => _instance;
  OwnershipGuardService._internal();

  final OwnershipManager _ownershipManager = OwnershipManager();
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();

  // ==================== OWNERSHIP VALIDATION ERRORS ====================

  /// Throws an exception for unauthorized actions
  void _throwUnauthorizedError(String action, String elementType) {
    throw UnauthorizedActionException(
      'You are not authorized to $action this $elementType. Only the owner can perform this action.',
      action: action,
      elementType: elementType,
    );
  }

  /// Throws an exception for unauthenticated users
  void _throwUnauthenticatedError(String action) {
    throw UnauthenticatedActionException(
      'You must be logged in to $action.',
      action: action,
    );
  }

  /// Throws an exception for invalid elements
  void _throwInvalidElementError(String action, String elementType) {
    throw InvalidElementException(
      'Cannot $action: $elementType not found or invalid.',
      action: action,
      elementType: elementType,
    );
  }

  // ==================== OWNERSHIP GUARDS FOR POSTS ====================

  /// Guard for post editing actions
  Future<void> guardPostEdit(String postId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('edit posts');
    }

    final post = _stateAdapter.getPost(postId);
    if (post == null) {
      _throwInvalidElementError('edit', 'post');
    }

    if (!_ownershipManager.canEdit(post)) {
      _throwUnauthorizedError('edit', 'post');
    }

    debugPrint('✅ Post edit authorized for post: $postId');
  }

  /// Guard for post deletion actions
  Future<void> guardPostDelete(String postId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('delete posts');
    }

    final post = _stateAdapter.getPost(postId);
    if (post == null) {
      _throwInvalidElementError('delete', 'post');
    }

    if (!_ownershipManager.canDelete(post)) {
      _throwUnauthorizedError('delete', 'post');
    }

    debugPrint('✅ Post deletion authorized for post: $postId');
  }

  /// Guard for viewing private post details
  Future<void> guardPostPrivateView(String postId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('view private post details');
    }

    final post = _stateAdapter.getPost(postId);
    if (post == null) {
      _throwInvalidElementError('view private details of', 'post');
    }

    if (!_ownershipManager.canViewPrivateDetails(post)) {
      _throwUnauthorizedError('view private details of', 'post');
    }

    debugPrint('✅ Private post view authorized for post: $postId');
  }

  // ==================== OWNERSHIP GUARDS FOR COMMENTS ====================

  /// Guard for comment editing actions
  Future<void> guardCommentEdit(String commentId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('edit comments');
    }

    final comment = _stateAdapter.getComment(commentId);
    if (comment == null) {
      _throwInvalidElementError('edit', 'comment');
    }

    if (!_ownershipManager.canEdit(comment)) {
      _throwUnauthorizedError('edit', 'comment');
    }

    debugPrint('✅ Comment edit authorized for comment: $commentId');
  }

  /// Guard for comment deletion actions
  Future<void> guardCommentDelete(String commentId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('delete comments');
    }

    final comment = _stateAdapter.getComment(commentId);
    if (comment == null) {
      _throwInvalidElementError('delete', 'comment');
    }

    if (!_ownershipManager.canDelete(comment)) {
      _throwUnauthorizedError('delete', 'comment');
    }

    debugPrint('✅ Comment deletion authorized for comment: $commentId');
  }

  // ==================== OWNERSHIP GUARDS FOR AVATARS ====================

  /// Guard for avatar editing actions
  Future<void> guardAvatarEdit(String avatarId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('edit avatars');
    }

    final avatar = _stateAdapter.getAvatar(avatarId);
    if (avatar == null) {
      _throwInvalidElementError('edit', 'avatar');
    }

    if (!_ownershipManager.canEdit(avatar)) {
      _throwUnauthorizedError('edit', 'avatar');
    }

    debugPrint('✅ Avatar edit authorized for avatar: $avatarId');
  }

  /// Guard for avatar deletion actions
  Future<void> guardAvatarDelete(String avatarId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('delete avatars');
    }

    final avatar = _stateAdapter.getAvatar(avatarId);
    if (avatar == null) {
      _throwInvalidElementError('delete', 'avatar');
    }

    if (!_ownershipManager.canDelete(avatar)) {
      _throwUnauthorizedError('delete', 'avatar');
    }

    debugPrint('✅ Avatar deletion authorized for avatar: $avatarId');
  }

  /// Guard for avatar settings modifications
  Future<void> guardAvatarSettings(String avatarId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('modify avatar settings');
    }

    final avatar = _stateAdapter.getAvatar(avatarId);
    if (avatar == null) {
      _throwInvalidElementError('modify settings of', 'avatar');
    }

    if (!_ownershipManager.canModifySettings(avatar)) {
      _throwUnauthorizedError('modify settings of', 'avatar');
    }

    debugPrint('✅ Avatar settings modification authorized for avatar: $avatarId');
  }

  // ==================== OWNERSHIP GUARDS FOR PROFILES ====================

  /// Guard for profile editing actions
  Future<void> guardProfileEdit(String userId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('edit profiles');
    }

    if (!_ownershipManager.isOwnProfile(userId)) {
      _throwUnauthorizedError('edit', 'profile');
    }

    debugPrint('✅ Profile edit authorized for user: $userId');
  }

  /// Guard for viewing private profile details
  Future<void> guardProfilePrivateView(String userId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('view private profile details');
    }

    if (!_ownershipManager.isOwnProfile(userId)) {
      _throwUnauthorizedError('view private details of', 'profile');
    }

    debugPrint('✅ Private profile view authorized for user: $userId');
  }

  // ==================== INTERACTION GUARDS ====================

  /// Guard for following actions (ensures can't follow own avatars)
  Future<void> guardFollowAction(String avatarId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('follow users');
    }

    final avatar = _stateAdapter.getAvatar(avatarId);
    if (avatar == null) {
      _throwInvalidElementError('follow', 'avatar');
    }

    if (!_ownershipManager.canFollowElement(avatar)) {
      throw SelfActionException(
        'You cannot follow your own avatar.',
        action: 'follow',
        elementType: 'avatar',
      );
    }

    debugPrint('✅ Follow action authorized for avatar: $avatarId');
  }

  /// Guard for reporting actions (ensures can't report own content)
  Future<void> guardReportAction(dynamic element, String elementType) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('report content');
    }

    if (element == null) {
      _throwInvalidElementError('report', elementType);
    }

    if (!_ownershipManager.canReportElement(element)) {
      throw SelfActionException(
        'You cannot report your own $elementType.',
        action: 'report',
        elementType: elementType,
      );
    }

    debugPrint('✅ Report action authorized for $elementType');
  }

  /// Guard for blocking actions (ensures can't block self)
  Future<void> guardBlockAction(String userId) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError('block users');
    }

    if (_ownershipManager.isOwnProfile(userId)) {
      throw SelfActionException(
        'You cannot block yourself.',
        action: 'block',
        elementType: 'user',
      );
    }

    debugPrint('✅ Block action authorized for user: $userId');
  }

  // ==================== GENERIC OWNERSHIP GUARDS ====================

  /// Generic guard for any ownership-based action
  Future<void> guardOwnershipAction({
    required dynamic element,
    required String action,
    required String elementType,
    required OwnershipPermission permission,
  }) async {
    if (!_stateAdapter.isAuthenticated) {
      _throwUnauthenticatedError(action);
    }

    if (element == null) {
      _throwInvalidElementError(action, elementType);
    }

    bool hasPermission = false;
    switch (permission) {
      case OwnershipPermission.canEdit:
        hasPermission = _ownershipManager.canEdit(element);
        break;
      case OwnershipPermission.canDelete:
        hasPermission = _ownershipManager.canDelete(element);
        break;
      case OwnershipPermission.canViewPrivateDetails:
        hasPermission = _ownershipManager.canViewPrivateDetails(element);
        break;
      case OwnershipPermission.canModifySettings:
        hasPermission = _ownershipManager.canModifySettings(element);
        break;
      case OwnershipPermission.canFollow:
        hasPermission = _ownershipManager.canFollowElement(element);
        break;
      case OwnershipPermission.canReport:
        hasPermission = _ownershipManager.canReportElement(element);
        break;
      case OwnershipPermission.isOwned:
        hasPermission = _ownershipManager.isOwnElement(element);
        break;
      case OwnershipPermission.isOther:
        hasPermission = _ownershipManager.isOtherElement(element);
        break;
    }

    if (!hasPermission) {
      _throwUnauthorizedError(action, elementType);
    }

    debugPrint('✅ $action action authorized for $elementType');
  }

  // ==================== SAFE EXECUTION WRAPPERS ====================

  /// Execute an action safely with ownership validation
  Future<T> executeWithOwnershipGuard<T>({
    required Future<T> Function() action,
    required dynamic element,
    required String actionName,
    required String elementType,
    required OwnershipPermission permission,
  }) async {
    try {
      await guardOwnershipAction(
        element: element,
        action: actionName,
        elementType: elementType,
        permission: permission,
      );
      
      return await action();
    } catch (e) {
      if (e is OwnershipException) {
        debugPrint('🚫 Ownership guard blocked action: ${e.message}');
        rethrow;
      } else {
        debugPrint('❌ Action failed after ownership validation: $e');
        rethrow;
      }
    }
  }

  /// Execute an owner-only action safely
  Future<T> executeOwnerOnlyAction<T>({
    required Future<T> Function() action,
    required dynamic element,
    required String actionName,
    required String elementType,
  }) async {
    return executeWithOwnershipGuard<T>(
      action: action,
      element: element,
      actionName: actionName,
      elementType: elementType,
      permission: OwnershipPermission.isOwned,
    );
  }

  /// Execute an other-user action safely
  Future<T> executeOtherUserAction<T>({
    required Future<T> Function() action,
    required dynamic element,
    required String actionName,
    required String elementType,
  }) async {
    return executeWithOwnershipGuard<T>(
      action: action,
      element: element,
      actionName: actionName,
      elementType: elementType,
      permission: OwnershipPermission.isOther,
    );
  }
}

// ==================== CUSTOM EXCEPTIONS ====================

/// Base class for ownership-related exceptions
abstract class OwnershipException implements Exception {
  const OwnershipException(this.message, {this.action, this.elementType});
  
  final String message;
  final String? action;
  final String? elementType;
  
  @override
  String toString() => 'OwnershipException: $message';
}

/// Exception thrown when user is not authorized to perform an action
class UnauthorizedActionException extends OwnershipException {
  const UnauthorizedActionException(String message, {String? action, String? elementType})
      : super(message, action: action, elementType: elementType);
  
  @override
  String toString() => 'UnauthorizedActionException: $message';
}

/// Exception thrown when user is not authenticated
class UnauthenticatedActionException extends OwnershipException {
  const UnauthenticatedActionException(String message, {String? action})
      : super(message, action: action);
  
  @override
  String toString() => 'UnauthenticatedActionException: $message';
}

/// Exception thrown when trying to perform an action on an invalid element
class InvalidElementException extends OwnershipException {
  const InvalidElementException(String message, {String? action, String? elementType})
      : super(message, action: action, elementType: elementType);
  
  @override
  String toString() => 'InvalidElementException: $message';
}

/// Exception thrown when trying to perform an action on own content when not allowed
class SelfActionException extends OwnershipException {
  const SelfActionException(String message, {String? action, String? elementType})
      : super(message, action: action, elementType: elementType);
  
  @override
  String toString() => 'SelfActionException: $message';
}

