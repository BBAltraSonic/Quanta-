import 'package:flutter/material.dart';

/// Base error widget with common styling and structure
abstract class BaseErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;
  final IconData icon;
  final String title;
  final List<Widget>? additionalActions;

  const BaseErrorWidget({
    super.key,
    required this.message,
    required this.icon,
    required this.title,
    this.onRetry,
    this.onRefresh,
    this.additionalActions,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final actions = <Widget>[];

    if (onRetry != null) {
      actions.add(
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    if (onRefresh != null) {
      actions.add(
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.sync),
          label: const Text('Refresh'),
        ),
      );
    }

    if (additionalActions != null) {
      actions.addAll(additionalActions!);
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: actions,
    );
  }
}

/// Avatar not found error widget
class AvatarNotFoundWidget extends BaseErrorWidget {
  const AvatarNotFoundWidget({
    super.key,
    required String message,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.person_off,
         title: 'Avatar Not Found',
         onRetry: onRetry,
       );
}

/// Permission denied error widget
class PermissionDeniedWidget extends BaseErrorWidget {
  const PermissionDeniedWidget({
    super.key,
    required String message,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.lock,
         title: 'Access Denied',
         onRetry: onRetry,
       );
}

/// Network error widget
class NetworkErrorWidget extends BaseErrorWidget {
  const NetworkErrorWidget({
    super.key,
    required String message,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.wifi_off,
         title: 'Connection Error',
         onRetry: onRetry,
       );
}

/// Cache error widget with refresh option
class CacheErrorWidget extends BaseErrorWidget {
  const CacheErrorWidget({
    super.key,
    required String message,
    VoidCallback? onRefresh,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.cached,
         title: 'Data Loading Issue',
         onRetry: onRetry,
         onRefresh: onRefresh,
       );
}

/// State synchronization error widget
class StateSyncErrorWidget extends BaseErrorWidget {
  const StateSyncErrorWidget({
    super.key,
    required String message,
    VoidCallback? onRefresh,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.sync_problem,
         title: 'Sync Error',
         onRetry: onRetry,
         onRefresh: onRefresh,
       );
}

/// Database error widget
class DatabaseErrorWidget extends BaseErrorWidget {
  const DatabaseErrorWidget({
    super.key,
    required String message,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.storage,
         title: 'Server Error',
         onRetry: onRetry,
       );
}

/// Authentication required widget
class AuthenticationRequiredWidget extends BaseErrorWidget {
  const AuthenticationRequiredWidget({super.key, required String message})
    : super(
        message: message,
        icon: Icons.login,
        title: 'Login Required',
        additionalActions: const [
          // Login button will be added by the parent widget
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to login screen
                Navigator.of(context).pushNamed('/login');
              },
              icon: const Icon(Icons.login),
              label: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar ownership error widget
class AvatarOwnershipErrorWidget extends BaseErrorWidget {
  const AvatarOwnershipErrorWidget({
    super.key,
    required String message,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.person_remove,
         title: 'Ownership Error',
         onRetry: onRetry,
       );
}

/// Invalid avatar data widget
class InvalidAvatarDataWidget extends BaseErrorWidget {
  const InvalidAvatarDataWidget({
    super.key,
    required String message,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.error_outline,
         title: 'Invalid Data',
         onRetry: onRetry,
       );
}

/// Rate limit error widget
class RateLimitErrorWidget extends BaseErrorWidget {
  const RateLimitErrorWidget({
    super.key,
    required String message,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.hourglass_empty,
         title: 'Rate Limited',
         onRetry: onRetry,
       );
}

/// Generic error widget for unknown errors
class GenericErrorWidget extends BaseErrorWidget {
  const GenericErrorWidget({
    super.key,
    required String message,
    VoidCallback? onRetry,
  }) : super(
         message: message,
         icon: Icons.error,
         title: 'Something Went Wrong',
         onRetry: onRetry,
       );
}

/// Compact error widget for inline display
class CompactErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;

  const CompactErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              iconSize: 18,
              color: Theme.of(context).colorScheme.error,
              tooltip: 'Retry',
            ),
          ],
        ],
      ),
    );
  }
}

/// Error banner widget for top-level notifications
class ErrorBannerWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;
  final bool isVisible;

  const ErrorBannerWidget({
    super.key,
    required this.message,
    this.onDismiss,
    this.onRetry,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            if (onRetry != null) ...[
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (onDismiss != null) ...[
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                iconSize: 18,
                color: Theme.of(context).colorScheme.error,
                tooltip: 'Dismiss',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
