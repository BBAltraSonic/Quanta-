import 'package:flutter/material.dart';
import '../config/app_config.dart';

enum ErrorType {
  network,
  authentication,
  permission,
  configuration,
  validation,
  unknown,
}

class AppError {
  final ErrorType type;
  final String message;
  final String? technicalDetails;
  final String? userFriendlyMessage;
  final dynamic originalError;

  AppError({
    required this.type,
    required this.message,
    this.technicalDetails,
    this.userFriendlyMessage,
    this.originalError,
  });

  String get displayMessage => userFriendlyMessage ?? message;
}

class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  static final List<AppError> _errorHistory = [];

  /// Convert a generic error to an AppError with user-friendly messaging
  static AppError handleError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return AppError(
        type: ErrorType.network,
        message: error.toString(),
        userFriendlyMessage: 'Network connection issue. Please check your internet connection and try again.',
        originalError: error,
      );
    }

    // Authentication errors
    if (errorString.contains('auth') || 
        errorString.contains('login') ||
        errorString.contains('unauthorized') ||
        errorString.contains('session')) {
      return AppError(
        type: ErrorType.authentication,
        message: error.toString(),
        userFriendlyMessage: 'Authentication failed. Please check your credentials and try again.',
        originalError: error,
      );
    }

    // Configuration errors
    if (errorString.contains('config') || 
        errorString.contains('supabase') ||
        errorString.contains('api key') ||
        errorString.contains('not configured')) {
      return AppError(
        type: ErrorType.configuration,
        message: error.toString(),
        userFriendlyMessage: 'App configuration issue. Please contact support or check your environment settings.',
        technicalDetails: AppConfig.configurationError,
        originalError: error,
      );
    }

    // Permission errors
    if (errorString.contains('permission') || 
        errorString.contains('access denied') ||
        errorString.contains('forbidden')) {
      return AppError(
        type: ErrorType.permission,
        message: error.toString(),
        userFriendlyMessage: 'Permission denied. Please check your account permissions.',
        originalError: error,
      );
    }

    // Validation errors
    if (errorString.contains('validation') || 
        errorString.contains('invalid') ||
        errorString.contains('required')) {
      return AppError(
        type: ErrorType.validation,
        message: error.toString(),
        userFriendlyMessage: 'Invalid input. Please check your information and try again.',
        originalError: error,
      );
    }

    // Default unknown error
    return AppError(
      type: ErrorType.unknown,
      message: error.toString(),
      userFriendlyMessage: 'An unexpected error occurred. Please try again or contact support if the issue persists.',
      originalError: error,
    );
  }

  /// Log an error (in production, this could send to analytics/crash reporting)
  static void logError(AppError error) {
    _errorHistory.add(error);
    
    // Keep only last 100 errors to prevent memory issues
    if (_errorHistory.length > 100) {
      _errorHistory.removeAt(0);
    }

    // In development, print to console
    if (AppConfig.isDevelopment) {
      print('🚨 ERROR [${error.type.name.toUpperCase()}]: ${error.message}');
      if (error.technicalDetails != null) {
        print('📋 Technical Details: ${error.technicalDetails}');
      }
      if (error.originalError != null) {
        print('🔍 Original Error: ${error.originalError}');
      }
    }

    // TODO: In production, send to crash reporting service
    // Examples: Firebase Crashlytics, Sentry, etc.
  }

  /// Show error dialog to user
  static void showErrorDialog(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    final appError = handleError(error);
    logError(appError);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            Icon(
              _getErrorIcon(appError.type),
              color: _getErrorColor(appError.type),
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Error',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appError.displayMessage,
              style: const TextStyle(color: Colors.white70),
            ),
            if (AppConfig.isDevelopment && appError.technicalDetails != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Technical Details (Development Mode):',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appError.technicalDetails!,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error snackbar for less critical errors
  static void showErrorSnackbar(BuildContext context, dynamic error) {
    final appError = handleError(error);
    logError(appError);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _getErrorColor(appError.type),
        content: Row(
          children: [
            Icon(
              _getErrorIcon(appError.type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                appError.displayMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.authentication:
        return Icons.lock_outline;
      case ErrorType.permission:
        return Icons.security;
      case ErrorType.configuration:
        return Icons.settings;
      case ErrorType.validation:
        return Icons.warning;
      case ErrorType.unknown:
        return Icons.error_outline;
    }
  }

  static Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.authentication:
        return Colors.red;
      case ErrorType.permission:
        return Colors.purple;
      case ErrorType.configuration:
        return Colors.blue;
      case ErrorType.validation:
        return Colors.amber;
      case ErrorType.unknown:
        return Colors.red;
    }
  }

  /// Get error history (useful for debugging)
  static List<AppError> getErrorHistory() => List.unmodifiable(_errorHistory);

  /// Clear error history
  static void clearErrorHistory() => _errorHistory.clear();
}



