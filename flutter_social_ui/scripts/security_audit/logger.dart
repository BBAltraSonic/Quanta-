import 'package:quanta/services/logging_service.dart';

/// Script-specific logger for security audit tools
class SecurityLogger {
  static const String _tag = 'SecurityAudit';

  /// Log info message for security operations
  static void info(String message) {
    LoggingService.info(message, tag: _tag);
  }

  /// Log warning message for security operations
  static void warning(String message) {
    LoggingService.warning(message, tag: _tag);
  }

  /// Log error message for security operations
  static void error(String message, {Object? error}) {
    LoggingService.error(message, tag: _tag, error: error);
  }

  /// Log debug message for security operations
  static void debug(String message) {
    LoggingService.debug(message, tag: _tag);
  }

  /// Log critical message for security operations
  static void critical(String message, {Object? error}) {
    LoggingService.critical(message, tag: _tag, error: error);
  }

  /// Log security events
  static void security(String event, Map<String, dynamic>? details) {
    LoggingService.security(event, details, tag: _tag);
  }
}
