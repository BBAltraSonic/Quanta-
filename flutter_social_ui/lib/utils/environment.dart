class Environment {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  
  // AI Service Configuration
  static const String openRouterApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
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
    // AI services are completely optional - no validation required
  }
  
  // Check if AI services are available
  static bool get hasAIServices {
    return openRouterApiKey.isNotEmpty || huggingFaceApiKey.isNotEmpty;
  }
}
