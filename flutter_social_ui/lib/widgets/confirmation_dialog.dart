import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmButtonColor;
  final Color? cancelButtonColor;
  final IconData? icon;
  final bool isDangerous;

  const ConfirmationDialog({
    Key? key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.confirmButtonColor,
    this.cancelButtonColor,
    this.icon,
    this.isDangerous = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: isDangerous 
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: cancelButtonColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            cancelText ?? 'Cancel',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmButtonColor ?? 
              (isDangerous 
                ? theme.colorScheme.error 
                : theme.colorScheme.primary),
            foregroundColor: isDangerous 
              ? theme.colorScheme.onError
              : theme.colorScheme.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            confirmText ?? 'Confirm',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// Show a confirmation dialog for dangerous operations (like deleting account)
  static Future<bool?> showDangerous(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText ?? 'Delete',
        icon: icon ?? Icons.warning_amber,
        isDangerous: true,
      ),
    );
  }

  /// Show a confirmation dialog for regular operations
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText ?? 'Confirm',
        icon: icon ?? Icons.help_outline,
        isDangerous: false,
      ),
    );
  }

  /// Show an unsaved changes warning dialog
  static Future<bool?> showUnsavedChanges(
    BuildContext context, {
    String? message,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmationDialog(
        title: 'Unsaved Changes',
        message: message ?? 'You have unsaved changes. Do you want to discard them?',
        confirmText: 'Discard',
        cancelText: 'Keep Editing',
        icon: Icons.edit_note,
        isDangerous: true,
      ),
    );
  }
}

/// A helper class for showing various confirmation dialogs
class ConfirmationDialogs {
  static Future<bool?> confirmEmailChange(BuildContext context, String newEmail) {
    return ConfirmationDialog.show(
      context,
      title: 'Change Email Address',
      message: 'Are you sure you want to change your email to $newEmail? You may need to verify the new email address.',
      confirmText: 'Change Email',
      icon: Icons.email_outlined,
    );
  }

  static Future<bool?> confirmUsernameChange(BuildContext context, String newUsername) {
    return ConfirmationDialog.show(
      context,
      title: 'Change Username',
      message: 'Are you sure you want to change your username to @$newUsername? This action cannot be undone easily.',
      confirmText: 'Change Username',
      icon: Icons.alternate_email,
    );
  }

  static Future<bool?> confirmProfileImageChange(BuildContext context) {
    return ConfirmationDialog.show(
      context,
      title: 'Update Profile Picture',
      message: 'Your new profile picture will be visible to all users. Continue?',
      confirmText: 'Update Picture',
      icon: Icons.photo_camera_outlined,
    );
  }

  static Future<bool?> confirmAccountDeactivation(BuildContext context) {
    return ConfirmationDialog.showDangerous(
      context,
      title: 'Deactivate Account',
      message: 'This will temporarily hide your profile and posts from other users. You can reactivate your account anytime by logging in.',
      confirmText: 'Deactivate',
      icon: Icons.visibility_off_outlined,
    );
  }

  static Future<bool?> confirmPrivacyChange(BuildContext context, bool toPrivate) {
    return ConfirmationDialog.show(
      context,
      title: toPrivate ? 'Make Account Private' : 'Make Account Public',
      message: toPrivate 
        ? 'Your profile and posts will only be visible to approved followers.'
        : 'Your profile and posts will be visible to all users.',
      confirmText: toPrivate ? 'Make Private' : 'Make Public',
      icon: toPrivate ? Icons.lock_outline : Icons.public,
    );
  }
}
