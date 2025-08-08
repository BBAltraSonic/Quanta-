import '../models/user_model.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'demo_auth_service.dart';

/// Wrapper that chooses between real AuthService and DemoAuthService
/// based on AppConfig.demoMode setting
class AuthServiceWrapper {
  static final AuthServiceWrapper _instance = AuthServiceWrapper._internal();
  factory AuthServiceWrapper() => _instance;
  AuthServiceWrapper._internal();

  late final dynamic _service;
  
  AuthServiceWrapper get instance => this;
  
  // Initialize the appropriate service
  Future<void> initialize() async {
    if (AppConfig.demoMode) {
      _service = DemoAuthService();
    } else {
      _service = AuthService();
    }
    
    await _service.initialize();
  }
  
  // Getters
  UserModel? get currentUser => _service.currentUser;
  bool get isAuthenticated => _service.isAuthenticated;
  String? get currentUserId => _service.currentUserId;
  
  // Auth methods
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    return await _service.signUp(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
    );
  }
  
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    return await _service.signIn(email: email, password: password);
  }
  
  Future<void> signOut() async {
    await _service.signOut();
  }
  
  Future<void> resetPassword(String email) async {
    await _service.resetPassword(email);
  }
  
  Future<UserModel> updateProfile({
    String? username,
    String? displayName,
    String? profileImageUrl,
  }) async {
    return await _service.updateProfile(
      username: username,
      displayName: displayName,
      profileImageUrl: profileImageUrl,
    );
  }
  
  Future<UserModel?> getUserProfile() async {
    return await _service.getUserProfile();
  }
  
  Future<bool> hasCompletedOnboarding() async {
    return await _service.hasCompletedOnboarding();
  }
  
  // Demo-specific method
  Future<void> markOnboardingCompleted() async {
    if (AppConfig.demoMode && _service is DemoAuthService) {
      await (_service as DemoAuthService).markOnboardingCompleted();
    }
    // For real AuthService, this would be handled differently
  }
}
