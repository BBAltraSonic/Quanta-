class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'https://neyfqiauyxfurfhdtrug.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzQzNzgsImV4cCI6MjA2OTk1MDM3OH0.gKc0NEJvKwipztJyDLcGB2ScJwkh3de8-5BRKk9V6qY';

  // AI Service Configuration - Use Environment variables instead
  // These are kept for backward compatibility but should use Environment class

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
