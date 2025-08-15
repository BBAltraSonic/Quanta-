import 'package:flutter/material.dart';
import '../utils/ownership_manager.dart';
import '../store/state_service_adapter.dart';

/// Widget that conditionally renders content based on ownership state
/// Shows different UI for owned vs other elements
class OwnershipAwareWidget extends StatelessWidget {
  const OwnershipAwareWidget({
    Key? key,
    required this.element,
    required this.ownedBuilder,
    required this.otherBuilder,
    this.unauthenticatedBuilder,
    this.unknownBuilder,
    this.loadingBuilder,
  }) : super(key: key);

  /// The element to check ownership for (post, user, avatar, comment, etc.)
  final dynamic element;
  
  /// Builder for when the current user owns the element
  final Widget Function(BuildContext context, dynamic element) ownedBuilder;
  
  /// Builder for when another user owns the element
  final Widget Function(BuildContext context, dynamic element) otherBuilder;
  
  /// Builder for when the user is not authenticated (optional)
  final Widget Function(BuildContext context, dynamic element)? unauthenticatedBuilder;
  
  /// Builder for when ownership cannot be determined (optional)
  final Widget Function(BuildContext context, dynamic element)? unknownBuilder;
  
  /// Builder for when content is loading (optional)
  final Widget Function(BuildContext context)? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    final stateAdapter = StateServiceAdapter();
    
    // Handle loading state
    if (element == null && loadingBuilder != null) {
      return loadingBuilder!(context);
    }
    
    final ownershipState = stateAdapter.getOwnershipState(element);
    
    switch (ownershipState) {
      case OwnershipState.owned:
        return ownedBuilder(context, element);
        
      case OwnershipState.other:
        return otherBuilder(context, element);
        
      case OwnershipState.unauthenticated:
        if (unauthenticatedBuilder != null) {
          return unauthenticatedBuilder!(context, element);
        }
        // Fallback to other builder for unauthenticated users
        return otherBuilder(context, element);
        
      case OwnershipState.unknown:
        if (unknownBuilder != null) {
          return unknownBuilder!(context, element);
        }
        // Fallback to a basic container
        return const SizedBox.shrink();
    }
  }
}

/// Simplified ownership-aware widget with just owned and other states
class SimpleOwnershipWidget extends StatelessWidget {
  const SimpleOwnershipWidget({
    Key? key,
    required this.element,
    required this.ownedChild,
    required this.otherChild,
    this.fallbackChild,
  }) : super(key: key);

  final dynamic element;
  final Widget ownedChild;
  final Widget otherChild;
  final Widget? fallbackChild;

  @override
  Widget build(BuildContext context) {
    final stateAdapter = StateServiceAdapter();
    
    if (stateAdapter.isOwnElement(element)) {
      return ownedChild;
    } else if (stateAdapter.isOtherElement(element)) {
      return otherChild;
    } else {
      return fallbackChild ?? const SizedBox.shrink();
    }
  }
}

/// Widget that shows action buttons based on ownership permissions
class OwnershipActionButtons extends StatelessWidget {
  const OwnershipActionButtons({
    Key? key,
    required this.element,
    this.onEdit,
    this.onDelete,
    this.onSettings,
    this.onFollow,
    this.onUnfollow,
    this.onReport,
    this.onBlock,
    this.onShare,
    this.style,
  }) : super(key: key);

  final dynamic element;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSettings;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onShare;
  final OwnershipActionStyle? style;

  @override
  Widget build(BuildContext context) {
    final stateAdapter = StateServiceAdapter();
    final actionStyle = style ?? OwnershipActionStyle.defaultStyle();
    
    return OwnershipAwareWidget(
      element: element,
      ownedBuilder: (context, element) => _buildOwnedActions(context, actionStyle),
      otherBuilder: (context, element) => _buildOtherActions(context, actionStyle),
    );
  }

  Widget _buildOwnedActions(BuildContext context, OwnershipActionStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null) ...[
          _ActionButton(
            icon: style.editIcon,
            onPressed: onEdit!,
            style: style,
            type: ActionType.edit,
          ),
          if (style.spacing > 0) SizedBox(width: style.spacing),
        ],
        if (onDelete != null) ...[
          _ActionButton(
            icon: style.deleteIcon,
            onPressed: onDelete!,
            style: style,
            type: ActionType.delete,
          ),
          if (style.spacing > 0) SizedBox(width: style.spacing),
        ],
        if (onSettings != null) ...[
          _ActionButton(
            icon: style.settingsIcon,
            onPressed: onSettings!,
            style: style,
            type: ActionType.settings,
          ),
          if (style.spacing > 0) SizedBox(width: style.spacing),
        ],
        if (onShare != null)
          _ActionButton(
            icon: style.shareIcon,
            onPressed: onShare!,
            style: style,
            type: ActionType.share,
          ),
      ],
    );
  }

  Widget _buildOtherActions(BuildContext context, OwnershipActionStyle style) {
    final stateAdapter = StateServiceAdapter();
    final avatarId = _getAvatarIdFromElement(element);
    final isFollowing = avatarId != null ? stateAdapter.isFollowingAvatar(avatarId) : false;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onFollow != null && onUnfollow != null) ...[
          _ActionButton(
            icon: isFollowing ? style.unfollowIcon : style.followIcon,
            onPressed: isFollowing ? onUnfollow! : onFollow!,
            style: style,
            type: isFollowing ? ActionType.unfollow : ActionType.follow,
          ),
          if (style.spacing > 0) SizedBox(width: style.spacing),
        ],
        if (onReport != null) ...[
          _ActionButton(
            icon: style.reportIcon,
            onPressed: onReport!,
            style: style,
            type: ActionType.report,
          ),
          if (style.spacing > 0) SizedBox(width: style.spacing),
        ],
        if (onBlock != null) ...[
          _ActionButton(
            icon: style.blockIcon,
            onPressed: onBlock!,
            style: style,
            type: ActionType.block,
          ),
          if (style.spacing > 0) SizedBox(width: style.spacing),
        ],
        if (onShare != null)
          _ActionButton(
            icon: style.shareIcon,
            onPressed: onShare!,
            style: style,
            type: ActionType.share,
          ),
      ],
    );
  }

  String? _getAvatarIdFromElement(dynamic element) {
    try {
      if (element?.avatarId is String) return element.avatarId;
      if (element?.id is String) return element.id;
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Private action button widget
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.style,
    required this.type,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final OwnershipActionStyle style;
  final ActionType type;

  @override
  Widget build(BuildContext context) {
    final color = _getColorForType(type, style);
    
    if (style.buttonStyle == ActionButtonStyle.icon) {
      return IconButton(
        icon: Icon(icon, size: style.iconSize),
        onPressed: onPressed,
        color: color,
        tooltip: _getTooltipForType(type),
      );
    } else {
      return ElevatedButton.icon(
        icon: Icon(icon, size: style.iconSize),
        label: Text(_getLabelForType(type)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: color,
          textStyle: style.textStyle,
        ),
      );
    }
  }

  Color? _getColorForType(ActionType type, OwnershipActionStyle style) {
    switch (type) {
      case ActionType.edit:
        return style.editColor;
      case ActionType.delete:
        return style.deleteColor;
      case ActionType.settings:
        return style.settingsColor;
      case ActionType.follow:
        return style.followColor;
      case ActionType.unfollow:
        return style.unfollowColor;
      case ActionType.report:
        return style.reportColor;
      case ActionType.block:
        return style.blockColor;
      case ActionType.share:
        return style.shareColor;
    }
  }

  String _getTooltipForType(ActionType type) {
    switch (type) {
      case ActionType.edit:
        return 'Edit';
      case ActionType.delete:
        return 'Delete';
      case ActionType.settings:
        return 'Settings';
      case ActionType.follow:
        return 'Follow';
      case ActionType.unfollow:
        return 'Unfollow';
      case ActionType.report:
        return 'Report';
      case ActionType.block:
        return 'Block';
      case ActionType.share:
        return 'Share';
    }
  }

  String _getLabelForType(ActionType type) {
    switch (type) {
      case ActionType.edit:
        return 'Edit';
      case ActionType.delete:
        return 'Delete';
      case ActionType.settings:
        return 'Settings';
      case ActionType.follow:
        return 'Follow';
      case ActionType.unfollow:
        return 'Unfollow';
      case ActionType.report:
        return 'Report';
      case ActionType.block:
        return 'Block';
      case ActionType.share:
        return 'Share';
    }
  }
}

/// Conditional visibility widget based on ownership permissions
class OwnershipVisibility extends StatelessWidget {
  const OwnershipVisibility({
    Key? key,
    required this.element,
    required this.child,
    this.permission = OwnershipPermission.canEdit,
    this.reverse = false,
  }) : super(key: key);

  final dynamic element;
  final Widget child;
  final OwnershipPermission permission;
  final bool reverse; // If true, shows when permission is NOT granted

  @override
  Widget build(BuildContext context) {
    final stateAdapter = StateServiceAdapter();
    bool hasPermission = false;
    
    switch (permission) {
      case OwnershipPermission.canEdit:
        hasPermission = stateAdapter.canEdit(element);
        break;
      case OwnershipPermission.canDelete:
        hasPermission = stateAdapter.canDelete(element);
        break;
      case OwnershipPermission.canViewPrivateDetails:
        hasPermission = stateAdapter.canViewPrivateDetails(element);
        break;
      case OwnershipPermission.canModifySettings:
        hasPermission = stateAdapter.canModifySettings(element);
        break;
      case OwnershipPermission.canFollow:
        hasPermission = stateAdapter.canFollowElement(element);
        break;
      case OwnershipPermission.canReport:
        hasPermission = stateAdapter.canReportElement(element);
        break;
      case OwnershipPermission.isOwned:
        hasPermission = stateAdapter.isOwnElement(element);
        break;
      case OwnershipPermission.isOther:
        hasPermission = stateAdapter.isOtherElement(element);
        break;
    }
    
    final shouldShow = reverse ? !hasPermission : hasPermission;
    return Visibility(
      visible: shouldShow,
      child: child,
    );
  }
}

/// Mixin for widgets that need ownership-aware functionality
mixin OwnershipAwareMixin<T extends StatefulWidget> on State<T> {
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();
  
  /// Check ownership of an element
  bool isOwnElement(dynamic element) => _stateAdapter.isOwnElement(element);
  bool isOtherElement(dynamic element) => _stateAdapter.isOtherElement(element);
  
  /// Check permissions
  bool canEdit(dynamic element) => _stateAdapter.canEdit(element);
  bool canDelete(dynamic element) => _stateAdapter.canDelete(element);
  bool canViewPrivateDetails(dynamic element) => _stateAdapter.canViewPrivateDetails(element);
  bool canModifySettings(dynamic element) => _stateAdapter.canModifySettings(element);
  bool canFollowElement(dynamic element) => _stateAdapter.canFollowElement(element);
  bool canReportElement(dynamic element) => _stateAdapter.canReportElement(element);
  
  /// Get ownership state
  OwnershipState getOwnershipState(dynamic element) => _stateAdapter.getOwnershipState(element);
  
  /// Show ownership-aware dialog
  void showOwnershipAwareDialog({
    required dynamic element,
    required Widget Function(BuildContext, dynamic) ownedDialog,
    required Widget Function(BuildContext, dynamic) otherDialog,
    Widget Function(BuildContext, dynamic)? unauthenticatedDialog,
  }) {
    final ownershipState = getOwnershipState(element);
    
    Widget dialogBuilder(BuildContext context) {
      switch (ownershipState) {
        case OwnershipState.owned:
          return ownedDialog(context, element);
        case OwnershipState.other:
          return otherDialog(context, element);
        case OwnershipState.unauthenticated:
          if (unauthenticatedDialog != null) {
            return unauthenticatedDialog(context, element);
          }
          return otherDialog(context, element);
        case OwnershipState.unknown:
          return const AlertDialog(
            title: Text('Error'),
            content: Text('Unable to determine ownership.'),
          );
      }
    }
    
    showDialog(
      context: context,
      builder: dialogBuilder,
    );
  }
}

/// Style configuration for ownership action buttons
class OwnershipActionStyle {
  const OwnershipActionStyle({
    this.buttonStyle = ActionButtonStyle.icon,
    this.iconSize = 24.0,
    this.spacing = 8.0,
    this.textStyle,
    this.editIcon = Icons.edit,
    this.deleteIcon = Icons.delete,
    this.settingsIcon = Icons.settings,
    this.followIcon = Icons.person_add,
    this.unfollowIcon = Icons.person_remove,
    this.reportIcon = Icons.report,
    this.blockIcon = Icons.block,
    this.shareIcon = Icons.share,
    this.editColor,
    this.deleteColor,
    this.settingsColor,
    this.followColor,
    this.unfollowColor,
    this.reportColor,
    this.blockColor,
    this.shareColor,
  });

  final ActionButtonStyle buttonStyle;
  final double iconSize;
  final double spacing;
  final TextStyle? textStyle;
  
  // Icons
  final IconData editIcon;
  final IconData deleteIcon;
  final IconData settingsIcon;
  final IconData followIcon;
  final IconData unfollowIcon;
  final IconData reportIcon;
  final IconData blockIcon;
  final IconData shareIcon;
  
  // Colors
  final Color? editColor;
  final Color? deleteColor;
  final Color? settingsColor;
  final Color? followColor;
  final Color? unfollowColor;
  final Color? reportColor;
  final Color? blockColor;
  final Color? shareColor;

  factory OwnershipActionStyle.defaultStyle() {
    return const OwnershipActionStyle(
      deleteColor: Colors.red,
      reportColor: Colors.orange,
      blockColor: Colors.red,
      followColor: Colors.blue,
    );
  }
}

/// Enums for action types and permissions
enum ActionType { edit, delete, settings, follow, unfollow, report, block, share }
enum ActionButtonStyle { icon, button }
enum OwnershipPermission {
  canEdit,
  canDelete,
  canViewPrivateDetails,
  canModifySettings,
  canFollow,
  canReport,
  isOwned,
  isOther,
}
