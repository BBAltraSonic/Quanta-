class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'https://neyfqiauyxfurfhdtrug.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzQzNzgsImV4cCI6MjA2OTk1MDM3OH0.gKc0NEJvKwipztJyDLcGB2ScJwkh3de8-5BRKk9V6qY';

  // AI Service Configuration
  static const String openRouterApiKey = 'your-openrouter-key';
  static const String huggingFaceApiKey = 'your-huggingface-key';

  // App Configuration
  static const String appName = 'Quanta';
  static const String appVersion = '1.0.0';
  static const bool isDevelopment = true;

  // Feature Flags
  static const bool enableAI = true;
  static const bool enableSupabase = true;
  static const bool enableContentUpload = true;
  static const bool enableSearch = true;

  // Validation
  static bool get isConfigured {
    return supabaseUrl != 'https://your-project.supabase.co' &&
        supabaseAnonKey != 'your-anon-key-here';
  }

  static String get configurationError {
    if (supabaseUrl == 'https://your-project.supabase.co') {
      return 'Supabase URL not configured';
    }
    if (supabaseAnonKey == 'your-anon-key-here') {
      return 'Supabase anonymous key not configured';
    }
    return '';
  }
}
