class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key-here';
  
  // AI Service Configuration
  static const String openRouterApiKey = 'your-openrouter-key';
  static const String huggingFaceApiKey = 'your-huggingface-key';
  
  // App Configuration
  static const String appName = 'Quanta';
  static const String appVersion = '1.0.0';
  static const bool isDevelopment = true;
  
  // Feature Flags
  static const bool enableAI = true; // Enable AI for production
  static const bool enableSupabase = true; // Enable Supabase for production
  static const bool enableContentUpload = true;
  static const bool enableSearch = true;
  
  // Demo Mode Configuration
  static const bool demoMode = false; // Disable demo mode for production
  
  // Validation
  static bool get isConfigured {
    if (demoMode) return true; // Always return true in demo mode
    
    return supabaseUrl != 'https://your-project.supabase.co' &&
           supabaseAnonKey != 'your-anon-key-here';
  }
  
  static String get configurationError {
    if (demoMode) return '';
    
    if (supabaseUrl == 'https://your-project.supabase.co') {
      return 'Supabase URL not configured';
    }
    if (supabaseAnonKey == 'your-anon-key-here') {
      return 'Supabase anonymous key not configured';
    }
    return '';
  }
}
