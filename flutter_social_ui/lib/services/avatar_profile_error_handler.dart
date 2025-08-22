import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/error_widgets.dart';

/// Specific error types for avatar profile operations
enum AvatarProfileErrorType {
  avatarNotFound,
  permissionDenied,
  networkError,
  cacheError,
  stateSyncError,
  databaseError,
  authenticationRequired,
  avatarOwnershipError,
  invalidAvatarData,
  rateLimitExceeded,
}

/// Avatar profile specific exception
class AvatarProfileException implements Exception {
  final AvatarProfileErrorType type;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AvatarProfileException({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AvatarProfileException: $message';
}

/// Error handler for avatar profile operations
class AvatarProfileErrorHandler {
  static final AvatarProfileErrorHandler _instance =
      AvatarProfileErrorHandler._internal();
  factory AvatarProfileErrorHandler() => _instance;
  AvatarProfileErrorHandler._internal();

  /// Handle avatar profile errors and return appropriate widgets
  Widget handleError(
    dynamic error, {
    VoidCallback? onRetry,
    VoidCallback? onRefresh,
    String? context,
  }) {
    if (error is AvatarProfileException) {
      return _handleAvatarProfileException(
        error,
        onRetry: onRetry,
        onRefresh: onRefresh,
      );
    }

    // Handle common Flutter/Dart exceptions
    if (error is FormatException) {
      return _handleInvalidDataError(error, onRetry: onRetry);
    }

    if (error is TimeoutException) {
      return _handleNetworkError(error, onRetry: onRetry);
    }

    // Handle generic errors
    return _handleGenericError(error, onRetry: onRetry, context: context);
  }

  /// Handle specific avatar profile exceptions
  Widget _handleAvatarProfileException(
    AvatarProfileException exception, {
    VoidCallback? onRetry,
    VoidCallback? onRefresh,
  }) {
    switch (exception.type) {
      case AvatarProfileErrorType.avatarNotFound:
        return AvatarNotFoundWidget(
          message: exception.message,
          onRetry: onRetry,
        );

      case AvatarProfileErrorType.permissionDenied:
        return PermissionDeniedWidget(
          message: exception.message,
          onRetry: onRetry,
        );

      case AvatarProfileErrorType.networkError:
        return NetworkErrorWidget(message: exception.message, onRetry: onRetry);

      case AvatarProfileErrorType.cacheError:
        return CacheErrorWidget(
          message: exception.message,
          onRefresh: onRefresh,
          onRetry: onRetry,
        );

      case AvatarProfileErrorType.stateSyncError:
        return StateSyncErrorWidget(
          message: exception.message,
          onRefresh: onRefresh,
          onRetry: onRetry,
        );

      case AvatarProfileErrorType.databaseError:
        return DatabaseErrorWidget(
          message: exception.message,
          onRetry: onRetry,
        );

      case AvatarProfileErrorType.authenticationRequired:
        return AuthenticationRequiredWidget(message: exception.message);

      case AvatarProfileErrorType.avatarOwnershipError:
        return AvatarOwnershipErrorWidget(
          message: exception.message,
          onRetry: onRetry,
        );

      case AvatarProfileErrorType.invalidAvatarData:
        return InvalidAvatarDataWidget(
          message: exception.message,
          onRetry: onRetry,
        );

      case AvatarProfileErrorType.rateLimitExceeded:
        return RateLimitErrorWidget(
          message: exception.message,
          onRetry: onRetry,
        );
    }
  }

  /// Handle invalid data format errors
  Widget _handleInvalidDataError(
    FormatException error, {
    VoidCallback? onRetry,
  }) {
    return InvalidAvatarDataWidget(
      message: 'Invalid avatar data format: ${error.message}',
      onRetry: onRetry,
    );
  }

  /// Handle network timeout errors
  Widget _handleNetworkError(TimeoutException error, {VoidCallback? onRetry}) {
    return NetworkErrorWidget(
      message:
          'Network request timed out: ${error.message ?? 'Please check your connection'}',
      onRetry: onRetry,
    );
  }

  /// Handle generic errors
  Widget _handleGenericError(
    dynamic error, {
    VoidCallback? onRetry,
    String? context,
  }) {
    final errorMessage = error?.toString() ?? 'An unexpected error occurred';
    final contextMessage = context != null
        ? 'Error in $context: $errorMessage'
        : errorMessage;

    return GenericErrorWidget(message: contextMessage, onRetry: onRetry);
  }

  /// Create specific avatar profile exceptions
  static AvatarProfileException avatarNotFound(
    String avatarId, [
    dynamic originalError,
  ]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.avatarNotFound,
      message: 'Avatar with ID "$avatarId" was not found',
      originalError: originalError,
    );
  }

  static AvatarProfileException permissionDenied(
    String operation, [
    dynamic originalError,
  ]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.permissionDenied,
      message: 'Permission denied for operation: $operation',
      originalError: originalError,
    );
  }

  static AvatarProfileException networkError(
    String operation, [
    dynamic originalError,
  ]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.networkError,
      message: 'Network error during $operation',
      originalError: originalError,
    );
  }

  static AvatarProfileException cacheError(
    String operation, [
    dynamic originalError,
  ]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.cacheError,
      message: 'Cache error during $operation',
      originalError: originalError,
    );
  }

  static AvatarProfileException stateSyncError(
    String details, [
    dynamic originalError,
  ]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.stateSyncError,
      message: 'State synchronization error: $details',
      originalError: originalError,
    );
  }

  static AvatarProfileException databaseError(
    String operation, [
    dynamic originalError,
  ]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.databaseError,
      message: 'Database error during $operation',
      originalError: originalError,
    );
  }

  static AvatarProfileException authenticationRequired([
    dynamic originalError,
  ]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.authenticationRequired,
      message: 'Authentication required to access avatar profile',
      originalError: originalError,
    );
  }

  static AvatarProfileException avatarOwnershipError(
    String avatarId, [
    dynamic originalError,
  ]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.avatarOwnershipError,
      message: 'User does not own avatar "$avatarId"',
      originalError: originalError,
    );
  }

  static AvatarProfileException invalidAvatarData(
    String details, [
    dynamic originalError,
  ]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.invalidAvatarData,
      message: 'Invalid avatar data: $details',
      originalError: originalError,
    );
  }

  static AvatarProfileException rateLimitExceeded([dynamic originalError]) {
    return AvatarProfileException(
      type: AvatarProfileErrorType.rateLimitExceeded,
      message: 'Rate limit exceeded. Please try again later.',
      originalError: originalError,
    );
  }

  /// Log errors for debugging
  void logError(dynamic error, {String? context, StackTrace? stackTrace}) {
    if (kDebugMode) {
      final contextStr = context != null ? '[$context] ' : '';
      debugPrint('${contextStr}Avatar Profile Error: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Check if error is recoverable
  bool isRecoverableError(dynamic error) {
    if (error is AvatarProfileException) {
      switch (error.type) {
        case AvatarProfileErrorType.networkError:
        case AvatarProfileErrorType.cacheError:
        case AvatarProfileErrorType.stateSyncError:
        case AvatarProfileErrorType.databaseError:
        case AvatarProfileErrorType.rateLimitExceeded:
          return true;
        case AvatarProfileErrorType.avatarNotFound:
        case AvatarProfileErrorType.permissionDenied:
        case AvatarProfileErrorType.authenticationRequired:
        case AvatarProfileErrorType.avatarOwnershipError:
        case AvatarProfileErrorType.invalidAvatarData:
          return false;
      }
    }
    return true; // Assume generic errors are recoverable
  }

  /// Get user-friendly error message
  String getUserFriendlyMessage(dynamic error) {
    if (error is AvatarProfileException) {
      switch (error.type) {
        case AvatarProfileErrorType.avatarNotFound:
          return 'This avatar could not be found. It may have been deleted or moved.';
        case AvatarProfileErrorType.permissionDenied:
          return 'You don\'t have permission to access this avatar.';
        case AvatarProfileErrorType.networkError:
          return 'Network connection issue. Please check your internet connection.';
        case AvatarProfileErrorType.cacheError:
          return 'Data loading issue. Try refreshing the page.';
        case AvatarProfileErrorType.stateSyncError:
          return 'Data synchronization issue. Try refreshing the page.';
        case AvatarProfileErrorType.databaseError:
          return 'Server issue. Please try again in a moment.';
        case AvatarProfileErrorType.authenticationRequired:
          return 'Please log in to access this avatar profile.';
        case AvatarProfileErrorType.avatarOwnershipError:
          return 'You can only manage your own avatars.';
        case AvatarProfileErrorType.invalidAvatarData:
          return 'Avatar data is corrupted or invalid.';
        case AvatarProfileErrorType.rateLimitExceeded:
          return 'Too many requests. Please wait a moment before trying again.';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
