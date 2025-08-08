import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/environment.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  late final SupabaseClient _supabase;
  UserModel? _currentUser;
  
  // Getters
  SupabaseClient get supabase => _supabase;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  String? get currentUserId => _currentUser?.id;
  
  // Initialize Supabase
  Future<void> initialize() async {
    try {
      Environment.validateConfiguration();
      
      await Supabase.initialize(
        url: Environment.supabaseUrl,
        anonKey: Environment.supabaseAnonKey,
        debug: false,
      );
      
      _supabase = Supabase.instance.client;
      
      // Check for existing session
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _loadUserProfile(session.user.id);
      }
      
      // Listen to auth state changes
      _supabase.auth.onAuthStateChange.listen((data) async {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        
        switch (event) {
          case AuthChangeEvent.signedIn:
            if (session?.user != null) {
              await _loadUserProfile(session!.user.id);
            }
            break;
          case AuthChangeEvent.signedOut:
            _currentUser = null;
            await _clearLocalStorage();
            break;
          case AuthChangeEvent.userUpdated:
            if (session?.user != null) {
              await _loadUserProfile(session!.user.id);
            }
            break;
          default:
            break;
        }
      });
      
    } catch (e) {
      throw Exception('Failed to initialize authentication: $e');
    }
  }
  
  // Sign up with email and password
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    try {
      // Check if username is already taken
      final existingUser = await _supabase
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();
          
      if (existingUser != null) {
        throw Exception('Username already taken');
      }
      
      // Sign up with Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'display_name': displayName,
        },
      );
      
      if (response.user == null) {
        throw Exception('Failed to create user account');
      }
      
      // Create user profile
      final user = UserModel.create(
        email: email,
        username: username,
        displayName: displayName,
      );
      
      // Save user profile to database
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'email': user.email,
        'username': user.username,
        'display_name': user.displayName,
        'role': user.role.toString().split('.').last,
        'created_at': user.createdAt.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
      });
      
      _currentUser = user.copyWith();
      await _saveToLocalStorage();
      
      return _currentUser!;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }
  
  // Sign in with email and password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user == null) {
        throw Exception('Invalid credentials');
      }
      
      await _loadUserProfile(response.user!.id);
      
      if (_currentUser == null) {
        throw Exception('User profile not found');
      }
      
      return _currentUser!;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
      await _clearLocalStorage();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }
  
  // Update user profile
  Future<UserModel> updateProfile({
    String? username,
    String? displayName,
    String? profileImageUrl,
  }) async {
    try {
      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final updates = <String, dynamic>{};
      
      if (username != null && username != _currentUser!.username) {
        // Check if username is already taken
        final existingUser = await _supabase
            .from('users')
            .select()
            .eq('username', username)
            .neq('id', _currentUser!.id)
            .maybeSingle();
            
        if (existingUser != null) {
          throw Exception('Username already taken');
        }
        updates['username'] = username;
      }
      
      if (displayName != null) updates['display_name'] = displayName;
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;
      
      if (updates.isNotEmpty) {
        updates['updated_at'] = DateTime.now().toIso8601String();
        
        await _supabase
            .from('users')
            .update(updates)
            .eq('id', _currentUser!.id);
            
        _currentUser = _currentUser!.copyWith(
          username: username,
          displayName: displayName,
          profileImageUrl: profileImageUrl,
        );
        
        await _saveToLocalStorage();
      }
      
      return _currentUser!;
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }
  
  // Load user profile from database
  Future<void> _loadUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
          
      _currentUser = UserModel.fromJson(response);
      await _saveToLocalStorage();
    } catch (e) {
      print('Failed to load user profile: $e');
      _currentUser = null;
    }
  }
  
  // Save user data to local storage
  Future<void> _saveToLocalStorage() async {
    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', _currentUser!.toJson().toString());
    }
  }
  
  // Clear local storage
  Future<void> _clearLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }
  
  // Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    if (_currentUser == null) return false;
    
    try {
      // Check if user has created an avatar
      final response = await _supabase
          .from('avatars')
          .select('id')
          .eq('owner_user_id', _currentUser!.id)
          .limit(1);
          
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
