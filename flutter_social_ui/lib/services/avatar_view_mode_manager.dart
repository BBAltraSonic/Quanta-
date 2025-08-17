import '../models/profile_view_mode.dart';
import '../models/profile_action.dart';

/// Service for managing avatar profile view modes and determining available actions
class AvatarViewModeManager {
  /// Determines the appropriate view mode based on avatar ownership and user authentication
  ///
  /// [avatarOwnerId] - The ID of the user who owns the avatar
  /// [currentUserId] - The ID of the currently authenticated user (null if not authenticated)
  ///
  /// Returns:
  /// - [ProfileViewMode.owner] if the current user owns the avatar
  /// - [ProfileViewMode.public] if the current user is authenticated but doesn't own the avatar
  /// - [ProfileViewMode.guest] if the current user is not authenticated
  ProfileViewMode determineViewMode(
    String avatarOwnerId,
    String? currentUserId,
  ) {
    if (currentUserId == null) {
      return ProfileViewMode.guest;
    }

    if (currentUserId == avatarOwnerId) {
      return ProfileViewMode.owner;
    }

    return ProfileViewMode.public;
  }

  /// Gets the list of available actions for a specific view mode
  ///
  /// [viewMode] - The current profile view mode
  /// [isFollowing] - Whether the current user is following this avatar (only relevant for public/guest views)
  /// [isBlocked] - Whether the current user has blocked this avatar (only relevant for public views)
  ///
  /// Returns a list of [ProfileActionType] that are available for the given view mode
  List<ProfileActionType> getAvailableActions(
    ProfileViewMode viewMode, {
    bool isFollowing = false,
    bool isBlocked = false,
  }) {
    switch (viewMode) {
      case ProfileViewMode.owner:
        return _getOwnerActions();
      case ProfileViewMode.public:
        return _getPublicActions(
          isFollowing: isFollowing,
          isBlocked: isBlocked,
        );
      case ProfileViewMode.guest:
        return _getGuestActions();
    }
  }

  /// Checks if a specific action can be performed in the given view mode
  ///
  /// [action] - The action to check
  /// [viewMode] - The current view mode
  /// [isFollowing] - Whether the current user is following this avatar
  /// [isBlocked] - Whether the current user has blocked this avatar
  ///
  /// Returns true if the action is allowed, false otherwise
  bool canPerformAction(
    ProfileActionType action,
    ProfileViewMode viewMode, {
    bool isFollowing = false,
    bool isBlocked = false,
  }) {
    final availableActions = getAvailableActions(
      viewMode,
      isFollowing: isFollowing,
      isBlocked: isBlocked,
    );
    return availableActions.contains(action);
  }

  /// Gets the primary action for a specific view mode
  ///
  /// [viewMode] - The current view mode
  /// [isFollowing] - Whether the current user is following this avatar
  ///
  /// Returns the primary action type, or null if no primary action is available
  ProfileActionType? getPrimaryAction(
    ProfileViewMode viewMode, {
    bool isFollowing = false,
  }) {
    switch (viewMode) {
      case ProfileViewMode.owner:
        return ProfileActionType.editAvatar;
      case ProfileViewMode.public:
        return isFollowing
            ? ProfileActionType.unfollow
            : ProfileActionType.follow;
      case ProfileViewMode.guest:
        return ProfileActionType.login;
    }
  }

  /// Validates that a user has permission to perform an action on an avatar
  ///
  /// [action] - The action to validate
  /// [avatarOwnerId] - The ID of the user who owns the avatar
  /// [currentUserId] - The ID of the currently authenticated user
  ///
  /// Throws [UnauthorizedActionException] if the action is not permitted
  void validateActionPermission(
    ProfileActionType action,
    String avatarOwnerId,
    String? currentUserId,
  ) {
    final viewMode = determineViewMode(avatarOwnerId, currentUserId);

    // Check for owner-only actions first (more specific error)
    if (action.isOwnerOnly && viewMode != ProfileViewMode.owner) {
      throw UnauthorizedActionException(
        'Action $action requires avatar ownership',
      );
    }

    // Check for authentication required actions (more specific error)
    if (action.requiresAuth && viewMode == ProfileViewMode.guest) {
      throw UnauthorizedActionException(
        'Action $action requires authentication',
      );
    }

    // General permission check
    if (!canPerformAction(action, viewMode)) {
      throw UnauthorizedActionException(
        'Action $action is not permitted in view mode $viewMode',
      );
    }
  }

  /// Gets the actions available to avatar owners
  List<ProfileActionType> _getOwnerActions() {
    return [
      ProfileActionType.editAvatar,
      ProfileActionType.manageAvatars,
      ProfileActionType.viewAnalytics,
      ProfileActionType.switchAvatar,
      ProfileActionType.share,
      ProfileActionType.deleteAvatar,
    ];
  }

  /// Gets the actions available to authenticated users viewing other avatars
  List<ProfileActionType> _getPublicActions({
    required bool isFollowing,
    required bool isBlocked,
  }) {
    final actions = <ProfileActionType>[
      ProfileActionType.share,
      ProfileActionType.report,
    ];

    // Add follow/unfollow based on current state
    if (isBlocked) {
      // If blocked, only allow unblocking (represented as unfollow for simplicity)
      actions.add(ProfileActionType.unfollow);
    } else if (isFollowing) {
      actions.addAll([
        ProfileActionType.unfollow,
        ProfileActionType.message,
        ProfileActionType.block,
      ]);
    } else {
      actions.addAll([
        ProfileActionType.follow,
        ProfileActionType.message,
        ProfileActionType.block,
      ]);
    }

    return actions;
  }

  /// Gets the actions available to guest (unauthenticated) users
  List<ProfileActionType> _getGuestActions() {
    return [
      ProfileActionType.viewProfile,
      ProfileActionType.share,
      ProfileActionType.login,
    ];
  }
}

/// Exception thrown when a user attempts to perform an unauthorized action
class UnauthorizedActionException implements Exception {
  final String message;

  const UnauthorizedActionException(this.message);

  @override
  String toString() => 'UnauthorizedActionException: $message';
}
