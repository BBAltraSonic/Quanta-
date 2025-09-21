import 'package:quanta/services/logging_service.dart';

/// Script-specific logger for optimization tools
class ScriptLogger {
  static const String _tag = 'OptimizationScript';

  /// Log info message for script operations
  static void info(String message) {
    LoggingService.info(message, tag: _tag);
  }

  /// Log warning message for script operations
  static void warning(String message) {
    LoggingService.warning(message, tag: _tag);
  }

  /// Log error message for script operations
  static void error(String message, {Object? error}) {
    LoggingService.error(message, tag: _tag, error: error);
  }

  /// Log debug message for script operations
  static void debug(String message) {
    LoggingService.debug(message, tag: _tag);
  }

  /// Log critical message for script operations
  static void critical(String message, {Object? error}) {
    LoggingService.critical(message, tag: _tag, error: error);
  }

  /// Log performance metrics for script operations
  static void performance(String operation, Duration duration) {
    LoggingService.performance(operation, duration, tag: _tag);
  }
}
