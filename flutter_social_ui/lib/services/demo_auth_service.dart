import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Demo authentication service that works without Supabase
/// This is used when AppConfig.demoMode is true
class DemoAuthService {
  static final DemoAuthService _instance = DemoAuthService._internal();
  factory DemoAuthService() => _instance;
  DemoAuthService._internal();

  UserModel? _currentUser;
  bool _isInitialized = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  String? get currentUserId => _currentUser?.id;

  // Initialize demo auth service
  Future<void> initialize() async {
    try {
      debugPrint('🎭 Initializing Demo Auth Service');

      // Try to load user from local storage
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('demo_user_email');

      if (userEmail != null) {
        _currentUser = UserModel.create(
          email: userEmail,
          username: prefs.getString('demo_user_username') ?? 'demouser',
          displayName: prefs.getString('demo_user_display_name') ?? 'Demo User',
        );
        debugPrint('🎭 Loaded demo user: ${_currentUser?.email}');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Demo auth initialization failed: $e');
      rethrow;
    }
  }

  // Demo sign up
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    try {
      debugPrint('🎭 Demo sign up: $email');

      // Create demo user
      _currentUser = UserModel.create(
        email: email,
        username: username,
        displayName: displayName ?? username,
      );

      // Save to local storage
      await _saveToLocalStorage();

      return _currentUser!;
    } catch (e) {
      throw Exception('Demo sign up failed: $e');
    }
  }

  // Demo sign in
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🎭 Demo sign in: $email');

      // For demo, accept any credentials
      _currentUser = UserModel.create(
        email: email,
        username: email.split('@').first,
        displayName: 'Demo User',
      );

      // Save to local storage
      await _saveToLocalStorage();

      return _currentUser!;
    } catch (e) {
      throw Exception('Demo sign in failed: $e');
    }
  }

  // Demo sign out
  Future<void> signOut() async {
    try {
      debugPrint('🎭 Demo sign out');
      _currentUser = null;
      await _clearLocalStorage();
    } catch (e) {
      throw Exception('Demo sign out failed: $e');
    }
  }

  // Demo password reset
  Future<void> resetPassword(String email) async {
    try {
      debugPrint('🎭 Demo password reset: $email');
      // In demo mode, just pretend it worked
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      throw Exception('Demo password reset failed: $e');
    }
  }

  // Demo profile update
  Future<UserModel> updateProfile({
    String? username,
    String? displayName,
    String? profileImageUrl,
  }) async {
    try {
      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🎭 Demo profile update');

      _currentUser = _currentUser!.copyWith(
        username: username,
        displayName: displayName,
        // Note: UserModel copyWith doesn't support all fields in demo mode
      );

      await _saveToLocalStorage();

      return _currentUser!;
    } catch (e) {
      throw Exception('Demo profile update failed: $e');
    }
  }

  // Demo get user profile
  Future<UserModel?> getUserProfile() async {
    try {
      debugPrint('🎭 Demo get user profile');
      return _currentUser;
    } catch (e) {
      debugPrint('❌ Demo get profile failed: $e');
      return null;
    }
  }

  // Demo check onboarding completion
  Future<bool> hasCompletedOnboarding() async {
    try {
      debugPrint('🎭 Demo check onboarding completion');

      // For demo, let's say onboarding is completed if user exists
      // In a real app, this would check if user has created at least one avatar
      if (_currentUser == null) return false;

      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('demo_onboarding_completed') ?? false;
    } catch (e) {
      debugPrint('❌ Demo onboarding check failed: $e');
      return false;
    }
  }

  // Demo mark onboarding as completed
  Future<void> markOnboardingCompleted() async {
    try {
      debugPrint('🎭 Demo mark onboarding completed');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('demo_onboarding_completed', true);
    } catch (e) {
      debugPrint('❌ Demo mark onboarding failed: $e');
    }
  }

  // Save user to local storage
  Future<void> _saveToLocalStorage() async {
    if (_currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('demo_user_email', _currentUser!.email);
    await prefs.setString('demo_user_username', _currentUser!.username);
    await prefs.setString(
      'demo_user_display_name',
      _currentUser!.displayName ?? '',
    );

    debugPrint('🎭 Demo user saved to local storage');
  }

  // Clear local storage
  Future<void> _clearLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('demo_user_email');
    await prefs.remove('demo_user_username');
    await prefs.remove('demo_user_display_name');
    await prefs.remove('demo_onboarding_completed');

    debugPrint('🎭 Demo local storage cleared');
  }
}
