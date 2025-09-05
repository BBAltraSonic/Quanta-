import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Log levels for different types of messages
enum LogLevel { debug, info, warning, error, critical }

/// Centralized logging service for the application
/// Provides structured logging with different levels and proper formatting
class LoggingService {
  static const String _tag = 'Quanta';

  /// Log a debug message (only in debug mode)
  static void debug(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      _log(
        LogLevel.debug,
        message,
        tag: tag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log an informational message
  static void info(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.info,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning message
  static void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.warning,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a critical error message
  static void critical(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.critical,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Internal logging method that handles the actual logging
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final String logTag = tag ?? _tag;
    final String levelPrefix = _getLevelPrefix(level);
    final String timestamp = DateTime.now().toIso8601String();

    // Format the log message
    String logMessage = '[$timestamp] $levelPrefix [$logTag] $message';

    if (error != null) {
      logMessage += '\nError: $error';
    }

    if (stackTrace != null) {
      logMessage += '\nStack trace:\n$stackTrace';
    }

    // Use developer.log for better integration with Flutter DevTools
    developer.log(
      message,
      time: DateTime.now(),
      level: _getLogLevel(level),
      name: logTag,
      error: error,
      stackTrace: stackTrace,
    );

    // In debug mode, also use debugPrint for console visibility
    if (kDebugMode) {
      debugPrint(logMessage);
    }
  }

  /// Get the appropriate log level for developer.log
  static int _getLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500; // FINE
      case LogLevel.info:
        return 800; // INFO
      case LogLevel.warning:
        return 900; // WARNING
      case LogLevel.error:
        return 1000; // SEVERE
      case LogLevel.critical:
        return 1200; // SHOUT
    }
  }

  /// Get the prefix for the log level
  static String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🐛 DEBUG';
      case LogLevel.info:
        return '📋 INFO';
      case LogLevel.warning:
        return '⚠️  WARNING';
      case LogLevel.error:
        return '❌ ERROR';
      case LogLevel.critical:
        return '🚨 CRITICAL';
    }
  }

  /// Log performance metrics
  static void performance(
    String operation,
    Duration duration, {
    String? tag,
    Map<String, dynamic>? metadata,
  }) {
    final String logTag = tag ?? _tag;
    String message =
        'Performance: $operation took ${duration.inMilliseconds}ms';

    if (metadata != null && metadata.isNotEmpty) {
      message += '\nMetadata: $metadata';
    }

    info(message, tag: '$logTag.Performance');
  }

  /// Log analytics events
  static void analytics(
    String event,
    Map<String, dynamic> parameters, {
    String? tag,
  }) {
    final String logTag = tag ?? _tag;
    info('Analytics: $event - $parameters', tag: '$logTag.Analytics');
  }

  /// Log network requests
  static void network(
    String method,
    String url,
    int statusCode,
    Duration duration, {
    String? tag,
    Object? error,
  }) {
    final String logTag = tag ?? _tag;
    String message =
        'Network: $method $url - $statusCode (${duration.inMilliseconds}ms)';

    if (statusCode >= 400) {
      error(message, tag: '$logTag.Network', error: error);
    } else {
      info(message, tag: '$logTag.Network');
    }
  }

  /// Log database operations
  static void database(
    String operation,
    String table,
    Duration duration, {
    String? tag,
    Object? error,
  }) {
    final String logTag = tag ?? _tag;
    String message =
        'Database: $operation on $table (${duration.inMilliseconds}ms)';

    if (error != null) {
      LoggingService.error(message, tag: '$logTag.Database', error: error);
    } else {
      info(message, tag: '$logTag.Database');
    }
  }

  /// Log user actions for debugging
  static void userAction(
    String action,
    Map<String, dynamic>? context, {
    String? tag,
  }) {
    final String logTag = tag ?? _tag;
    String message = 'User Action: $action';

    if (context != null && context.isNotEmpty) {
      message += ' - Context: $context';
    }

    debug(message, tag: '$logTag.UserAction');
  }

  /// Log security events
  static void security(
    String event,
    Map<String, dynamic>? details, {
    String? tag,
    Object? error,
  }) {
    final String logTag = tag ?? _tag;
    String message = 'Security: $event';

    if (details != null && details.isNotEmpty) {
      message += ' - Details: $details';
    }

    if (error != null) {
      LoggingService.error(message, tag: '$logTag.Security', error: error);
    } else {
      warning(message, tag: '$logTag.Security');
    }
  }
}
