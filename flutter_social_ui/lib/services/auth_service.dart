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
  bool _isInitialized = false;
  
  // Getters
  SupabaseClient get supabase => _supabase;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  String? get currentUserId => _currentUser?.id;
  
  // Initialize Supabase
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_isInitialized) {
      return;
    }
    
    try {
      // Validate core configuration only (AI services are completely optional)
      Environment.validateConfiguration();
      
      // Initialize Supabase (handle if already initialized)
      try {
        await Supabase.initialize(
          url: Environment.supabaseUrl,
          anonKey: Environment.supabaseAnonKey,
          debug: false,
        );
      } catch (e) {
        // If already initialized, that's fine, just continue
        if (!e.toString().contains('already initialized')) {
          rethrow;
        }
      }
      
      _supabase = Supabase.instance.client;
      _isInitialized = true;
      
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
      
      // Create user profile with the same ID as Supabase Auth user
      final user = UserModel(
        id: response.user!.id, // Use Supabase Auth user ID
        email: email,
        username: username,
        displayName: displayName,
        role: UserRole.creator, // Everyone is a creator by default
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Save user profile to database
      // NOTE: Temporarily removing display_name from initial insert due to Supabase schema cache issue
      await _supabase.from('users').insert({
        'id': response.user!.id,  // Ensure consistent ID
        'email': user.email,
        'username': user.username,
        'role': user.role.toString().split('.').last,
        'created_at': user.createdAt.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
      });
      
      // If display name was provided, update it separately
      if (displayName != null && displayName.isNotEmpty) {
        try {
          await _supabase
              .from('users')
              .update({'display_name': displayName})
              .eq('id', response.user!.id);
        } catch (e) {
          // Log but don't fail registration if display_name update fails
          print('Warning: Could not update display_name: $e');
        }
      }
      
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
  
  // Mark onboarding as completed
  Future<void> markOnboardingCompleted() async {
    if (_currentUser == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      await _supabase
          .from('users')
          .update({
            'onboarding_completed': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentUser!.id);
          
      // Update local user model if needed
      await _loadUserProfile(_currentUser!.id);
    } catch (e) {
      print('Failed to mark onboarding as completed: $e');
    }
  }
  
  // Get current user asynchronously (refreshes from database)
  Future<UserModel?> getCurrentUser() async {
    if (_currentUser == null) return null;
    
    try {
      // Refresh user data from database
      await _loadUserProfile(_currentUser!.id);
      return _currentUser;
    } catch (e) {
      print('Failed to refresh current user: $e');
      return _currentUser; // Return cached user if refresh fails
    }
  }
}
