import 'package:flutter/material.dart';

/// Enum representing different types of profile actions
enum ProfileActionType {
  // Public actions (available to all users)
  follow,
  unfollow,
  message,
  report,
  share,
  block,

  // Owner actions (only available to avatar owners)
  editAvatar,
  manageAvatars,
  viewAnalytics,
  switchAvatar,
  deleteAvatar,

  // Guest actions (available to unauthenticated users)
  viewProfile,
  login,
}

/// Extension to provide utility methods for ProfileActionType
extension ProfileActionTypeExtension on ProfileActionType {
  /// Returns true if this action is only available to owners
  bool get isOwnerOnly {
    switch (this) {
      case ProfileActionType.editAvatar:
      case ProfileActionType.manageAvatars:
      case ProfileActionType.viewAnalytics:
      case ProfileActionType.switchAvatar:
      case ProfileActionType.deleteAvatar:
        return true;
      default:
        return false;
    }
  }

  /// Returns true if this action requires authentication
  bool get requiresAuth {
    switch (this) {
      case ProfileActionType.viewProfile:
      case ProfileActionType.login:
        return false;
      default:
        return true;
    }
  }

  /// Returns the default label for this action type
  String get defaultLabel {
    switch (this) {
      case ProfileActionType.follow:
        return 'Follow';
      case ProfileActionType.unfollow:
        return 'Unfollow';
      case ProfileActionType.message:
        return 'Message';
      case ProfileActionType.report:
        return 'Report';
      case ProfileActionType.share:
        return 'Share';
      case ProfileActionType.block:
        return 'Block';
      case ProfileActionType.editAvatar:
        return 'Edit Avatar';
      case ProfileActionType.manageAvatars:
        return 'Manage Avatars';
      case ProfileActionType.viewAnalytics:
        return 'View Analytics';
      case ProfileActionType.switchAvatar:
        return 'Switch Avatar';
      case ProfileActionType.deleteAvatar:
        return 'Delete Avatar';
      case ProfileActionType.viewProfile:
        return 'View Profile';
      case ProfileActionType.login:
        return 'Login';
    }
  }

  /// Returns the default icon for this action type
  IconData get defaultIcon {
    switch (this) {
      case ProfileActionType.follow:
        return Icons.person_add;
      case ProfileActionType.unfollow:
        return Icons.person_remove;
      case ProfileActionType.message:
        return Icons.message;
      case ProfileActionType.report:
        return Icons.report;
      case ProfileActionType.share:
        return Icons.share;
      case ProfileActionType.block:
        return Icons.block;
      case ProfileActionType.editAvatar:
        return Icons.edit;
      case ProfileActionType.manageAvatars:
        return Icons.manage_accounts;
      case ProfileActionType.viewAnalytics:
        return Icons.analytics;
      case ProfileActionType.switchAvatar:
        return Icons.swap_horiz;
      case ProfileActionType.deleteAvatar:
        return Icons.delete;
      case ProfileActionType.viewProfile:
        return Icons.person;
      case ProfileActionType.login:
        return Icons.login;
    }
  }
}

/// Model representing a profile action that can be performed
class ProfileAction {
  final ProfileActionType type;
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback? onTap;
  final bool isEnabled;
  final String? tooltip;

  const ProfileAction({
    required this.type,
    required this.label,
    required this.icon,
    this.isPrimary = false,
    this.onTap,
    this.isEnabled = true,
    this.tooltip,
  });

  /// Creates a ProfileAction with default values from the action type
  factory ProfileAction.fromType(
    ProfileActionType type, {
    VoidCallback? onTap,
    bool isPrimary = false,
    bool isEnabled = true,
    String? customLabel,
    IconData? customIcon,
    String? tooltip,
  }) {
    return ProfileAction(
      type: type,
      label: customLabel ?? type.defaultLabel,
      icon: customIcon ?? type.defaultIcon,
      isPrimary: isPrimary,
      onTap: onTap,
      isEnabled: isEnabled,
      tooltip: tooltip,
    );
  }

  /// Creates a copy of this ProfileAction with updated properties
  ProfileAction copyWith({
    ProfileActionType? type,
    String? label,
    IconData? icon,
    bool? isPrimary,
    VoidCallback? onTap,
    bool? isEnabled,
    String? tooltip,
  }) {
    return ProfileAction(
      type: type ?? this.type,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      isPrimary: isPrimary ?? this.isPrimary,
      onTap: onTap ?? this.onTap,
      isEnabled: isEnabled ?? this.isEnabled,
      tooltip: tooltip ?? this.tooltip,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileAction &&
        other.type == type &&
        other.label == label &&
        other.icon == icon &&
        other.isPrimary == isPrimary &&
        other.isEnabled == isEnabled &&
        other.tooltip == tooltip;
  }

  @override
  int get hashCode {
    return type.hashCode ^
        label.hashCode ^
        icon.hashCode ^
        isPrimary.hashCode ^
        isEnabled.hashCode ^
        tooltip.hashCode;
  }

  @override
  String toString() {
    return 'ProfileAction(type: $type, label: $label, isPrimary: $isPrimary, isEnabled: $isEnabled)';
  }
}
