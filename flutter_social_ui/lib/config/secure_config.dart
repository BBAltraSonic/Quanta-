import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/environment.dart';

/// Secure configuration manager for production environments
class SecureConfig {
  static const String _productionFlag = 'ENVIRONMENT';
  static const String _productionValue = 'production';

  /// Check if running in production
  static bool get isProduction {
    final env = dotenv.env[_productionFlag] ?? 'development';
    return env.toLowerCase() == _productionValue;
  }

  /// Check if running in development
  static bool get isDevelopment => !isProduction;

  /// Get environment-specific configuration
  static Map<String, dynamic> getEnvironmentConfig() {
    return {
      'environment': dotenv.env[_productionFlag] ?? 'development',
      'debugMode': isDevelopment,
      'enableLogging': dotenv.env['ENABLE_LOGGING']?.toLowerCase() == 'true' ?? isDevelopment,
      'enableAnalytics': dotenv.env['ENABLE_ANALYTICS']?.toLowerCase() == 'true' ?? true,
      'enableCrashReporting': dotenv.env['ENABLE_CRASH_REPORTING']?.toLowerCase() == 'true' ?? isProduction,
    };
  }

  /// Validate all required environment variables
  static EnvironmentValidationResult validateEnvironment() {
    final errors = <String>[];
    final warnings = <String>[];

    // Required variables
    if (Environment.supabaseUrl.isEmpty) {
      errors.add('SUPABASE_URL is required but not set');
    } else if (!Environment.supabaseUrl.startsWith('https://')) {
      errors.add('SUPABASE_URL must be a valid HTTPS URL');
    }

    if (Environment.supabaseAnonKey.isEmpty) {
      errors.add('SUPABASE_ANON_KEY is required but not set');
    } else if (Environment.supabaseAnonKey.length < 10) {
      warnings.add('SUPABASE_ANON_KEY seems too short (should be a JWT token)');
    }

    // Optional AI services
    if (Environment.openRouterApiKey.isNotEmpty && Environment.openRouterApiKey.length < 20) {
      warnings.add('OPENROUTER_API_KEY seems too short');
    }

    if (Environment.huggingFaceApiKey.isNotEmpty && Environment.huggingFaceApiKey.length < 20) {
      warnings.add('HUGGINGFACE_API_KEY seems too short');
    }

    // Production-specific checks
    if (isProduction) {
      if (Environment.supabaseUrl.contains('localhost') || Environment.supabaseUrl.contains('127.0.0.1')) {
        warnings.add('Production environment should not use localhost URLs');
      }

      if (dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true') {
        warnings.add('DEBUG_MODE should be false in production');
      }
    }

    return EnvironmentValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Initialize secure configuration with validation
  static Future<SecureConfigResult> initialize() async {
    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");

      // Validate configuration
      final validation = validateEnvironment();

      if (!validation.isValid) {
        return SecureConfigResult.failure(
          'Environment validation failed: ${validation.errors.join(', ')}',
        );
      }

      // Log warnings in development
      if (isDevelopment && validation.warnings.isNotEmpty) {
        debugPrint('⚠️ Environment warnings: ${validation.warnings.join(', ')}');
      }

      return SecureConfigResult.success(
        environment: getEnvironmentConfig(),
        validation: validation,
      );
    } catch (e) {
      return SecureConfigResult.failure('Failed to load environment: $e');
    }
  }

  /// Get configuration value with fallback
  static String getConfig(String key, {String defaultValue = ''}) {
    return dotenv.env[key] ?? defaultValue;
  }

  /// Get boolean configuration value
  static bool getBoolConfig(String key, {bool defaultValue = false}) {
    final value = dotenv.env[key]?.toLowerCase();
    if (value == 'true' || value == '1') return true;
    if (value == 'false' || value == '0') return false;
    return defaultValue;
  }
}

/// Result of environment validation
class EnvironmentValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const EnvironmentValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}

/// Result of secure configuration initialization
class SecureConfigResult {
  final bool isSuccess;
  final String? errorMessage;
  final Map<String, dynamic>? environment;
  final EnvironmentValidationResult? validation;

  const SecureConfigResult._({
    required this.isSuccess,
    this.errorMessage,
    this.environment,
    this.validation,
  });

  factory SecureConfigResult.success({
    required Map<String, dynamic> environment,
    required EnvironmentValidationResult validation,
  }) {
    return const SecureConfigResult._(isSuccess: true);
  }

  factory SecureConfigResult.failure(String errorMessage) {
    return SecureConfigResult._(isSuccess: false, errorMessage: errorMessage);
  }
}