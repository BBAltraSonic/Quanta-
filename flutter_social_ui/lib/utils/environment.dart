import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  // Supabase Configuration
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  // AI Service Configuration
  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  
  static String get huggingFaceApiKey => dotenv.env['HUGGINGFACE_API_KEY'] ?? '';
  
  // App Configuration
  static const String appName = 'Quanta';
  static const String appVersion = '1.0.0';
  
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  
  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enablePushNotifications = true;
  static const bool enableOfflineMode = true;
  
  // Chat Configuration
  static const int maxChatMessagesPerDay = 50;
  static const int chatResponseTimeoutSeconds = 30;
  static const int maxMessageLength = 500;
  
  // Media Configuration
  static const int maxVideoLengthSeconds = 90;
  static const int maxVideoSizeMB = 100;
  static const int maxImageSizeMB = 10;
  
  // Validation
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && 
           supabaseAnonKey.isNotEmpty &&
           supabaseUrl.startsWith('https://') &&
           supabaseAnonKey.length > 10; // Basic validation
  }
  
  static void validateConfiguration() {
    if (supabaseUrl.isEmpty) {
      throw Exception(
        'SUPABASE_URL environment variable is required but not set. Please check your .env file.',
      );
    }
    if (supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY environment variable is required but not set. Please check your .env file.',
      );
    }
    if (!supabaseUrl.startsWith('https://')) {
      throw Exception(
        'SUPABASE_URL must be a valid HTTPS URL. Current value: $supabaseUrl',
      );
    }
    // AI services are completely optional - no validation required
  }
  
  // Comprehensive configuration validation
  static Map<String, dynamic> validateConfigurationDetailed() {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Check required fields
    if (supabaseUrl.isEmpty) {
      errors.add('SUPABASE_URL is missing');
    } else if (!supabaseUrl.startsWith('https://')) {
      errors.add('SUPABASE_URL must start with https://');
    }
    
    if (supabaseAnonKey.isEmpty) {
      errors.add('SUPABASE_ANON_KEY is missing');
    } else if (supabaseAnonKey.length < 10) {
      warnings.add('SUPABASE_ANON_KEY seems too short');
    }
    
    // Check optional AI services
    if (openRouterApiKey.isNotEmpty && openRouterApiKey.length < 20) {
      warnings.add('OPENROUTER_API_KEY seems too short');
    }
    
    if (huggingFaceApiKey.isNotEmpty && huggingFaceApiKey.length < 20) {
      warnings.add('HUGGINGFACE_API_KEY seems too short');
    }
    
    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
    };
  }
  
  // Check if AI services are available
  static bool get hasAIServices {
    return openRouterApiKey.isNotEmpty || huggingFaceApiKey.isNotEmpty;
  }
}
