import '../utils/environment.dart';

class AppConfig {
  // Supabase Configuration - Now uses Environment variables
  static String get supabaseUrl => Environment.supabaseUrl;
  static String get supabaseAnonKey => Environment.supabaseAnonKey;

  // AI Service Configuration - Delegated to Environment class
  static String get openRouterApiKey => Environment.openRouterApiKey;

  // App Configuration
  static const String appName = 'Quanta';
  static const String appVersion = '1.0.0';
  static const bool isDevelopment = false; // PRODUCTION MODE ENABLED

  // Feature Flags  
  static const bool enableAI = true;
  static const bool enableSupabase = true;
  static const bool enableContentUpload = true;
  static const bool enableSearch = true;
  static const bool enableRealTimeFeatures = true;

  // Validation
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && 
           supabaseAnonKey.isNotEmpty &&
           supabaseUrl.startsWith('https://') &&
           supabaseAnonKey.length > 10;
  }

  static String get configurationError {
    if (supabaseUrl.isEmpty) {
      return 'Supabase URL not configured in environment variables';
    }
    if (supabaseAnonKey.isEmpty) {
      return 'Supabase anonymous key not configured in environment variables';
    }
    if (!supabaseUrl.startsWith('https://')) {
      return 'Supabase URL must be a valid HTTPS URL';
    }
    return '';
  }
}
