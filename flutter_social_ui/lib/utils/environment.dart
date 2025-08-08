class Environment {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );
  
  // AI Service Configuration
  static const String openRouterApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: 'your-openrouter-key-here',
  );
  
  static const String huggingFaceApiKey = String.fromEnvironment(
    'HUGGINGFACE_API_KEY',
    defaultValue: 'your-huggingface-key-here',
  );
  
  // App Configuration
  static const String appName = 'Quanta';
  static const String appVersion = '1.0.0';
  
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
    return supabaseUrl != 'https://your-project.supabase.co' &&
           supabaseAnonKey != 'your-anon-key-here';
  }
  
  static void validateConfiguration() {
    if (!isConfigured) {
      throw Exception(
        'Environment not configured properly. Please set SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
  }
}
