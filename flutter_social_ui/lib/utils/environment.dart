class Environment {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://neyfqiauyxfurfhdtrug.supabase.co',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzQzNzgsImV4cCI6MjA2OTk1MDM3OH0.gKc0NEJvKwipztJyDLcGB2ScJwkh3de8-5BRKk9V6qY',
  );
  
  // AI Service Configuration
  static const String openRouterApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
  );
  
  static const String huggingFaceApiKey = String.fromEnvironment(
    'HUGGINGFACE_API_KEY',
  );
  
  // App Configuration
  static const String appName = 'Quanta';
  static const String appVersion = '1.0.0';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  
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
        'SUPABASE_URL environment variable is required but not set.',
      );
    }
    if (supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY environment variable is required but not set.',
      );
    }
    if (!supabaseUrl.startsWith('https://')) {
      throw Exception(
        'SUPABASE_URL must be a valid HTTPS URL.',
      );
    }
    if (openRouterApiKey.isEmpty && huggingFaceApiKey.isEmpty) {
      throw Exception(
        'At least one AI service API key (OPENROUTER_API_KEY or HUGGINGFACE_API_KEY) must be configured.',
      );
    }
  }
}
