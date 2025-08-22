import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../screens/avatar_creation_wizard.dart';
import '../services/auth_service.dart';
import '../services/avatar_profile_service.dart';
import '../store/app_state.dart';

/// Service for handling avatar-centric navigation throughout the app
class AvatarNavigationService {
  static final AvatarNavigationService _instance =
      AvatarNavigationService._internal();
  factory AvatarNavigationService() => _instance;
  AvatarNavigationService._internal();

  final AuthService _authService = AuthService();
  final AvatarProfileService _avatarProfileService = AvatarProfileService();
  final AppState _appState = AppState();

  /// Navigate to the profile tab with avatar-centric routing
  /// This is the main method called by the profile tab navigation
  Future<void> navigateToProfile(BuildContext context) async {
    try {
      final currentUserId = _authService.currentUserId;

      if (currentUserId == null) {
        // User not authenticated, navigate to guest profile or login
        _navigateToGuestProfile(context);
        return;
      }

      // Get the user's active avatar
      final activeAvatar = await _avatarProfileService.getActiveAvatar(
        currentUserId,
      );

      if (activeAvatar != null) {
        // Navigate to active avatar profile
        _navigateToAvatarProfile(context, activeAvatar.id);
      } else {
        // User has no active avatar, show fallback
        _navigateToAvatarCreationFallback(context);
      }
    } catch (e) {
      debugPrint('Error in profile navigation: $e');
      // Fallback to basic profile screen
      _navigateToBasicProfile(context);
    }
  }

  /// Navigate to a specific avatar's profile
  void navigateToAvatarProfile(BuildContext context, String avatarId) {
    _navigateToAvatarProfile(context, avatarId);
  }

  /// Navigate to a user's active avatar profile (for deep linking)
  Future<void> navigateToUserProfile(
    BuildContext context,
    String userId,
  ) async {
    try {
      final activeAvatar = await _avatarProfileService.getActiveAvatar(userId);

      if (activeAvatar != null) {
        _navigateToAvatarProfile(context, activeAvatar.id);
      } else {
        // User has no avatars, show empty profile or creation prompt
        _navigateToEmptyProfile(context, userId);
      }
    } catch (e) {
      debugPrint('Error navigating to user profile: $e');
      _navigateToBasicProfile(context);
    }
  }

  /// Handle deep link navigation to avatar profiles
  Future<Widget> resolveProfileRoute(String? avatarId, String? userId) async {
    try {
      // If avatar ID is provided, use it directly
      if (avatarId != null) {
        return ProfileScreen(avatarId: avatarId);
      }

      // If user ID is provided, get their active avatar
      if (userId != null) {
        final activeAvatar = await _avatarProfileService.getActiveAvatar(
          userId,
        );
        if (activeAvatar != null) {
          return ProfileScreen(avatarId: activeAvatar.id);
        }
      }

      // Fallback to current user's profile
      final currentUserId = _authService.currentUserId;
      if (currentUserId != null) {
        final activeAvatar = await _avatarProfileService.getActiveAvatar(
          currentUserId,
        );
        if (activeAvatar != null) {
          return ProfileScreen(avatarId: activeAvatar.id);
        }
      }

      // Final fallback to basic profile screen
      return const ProfileScreen();
    } catch (e) {
      debugPrint('Error resolving profile route: $e');
      return const ProfileScreen();
    }
  }

  /// Get the appropriate back navigation context for avatar profiles
  String getBackNavigationContext(String avatarId) {
    final currentUserId = _authService.currentUserId;
    final viewMode = _appState.determineAvatarViewMode(avatarId, currentUserId);

    switch (viewMode) {
      case ProfileViewMode.owner:
        return 'owner_profile';
      case ProfileViewMode.public:
        return 'public_profile';
      case ProfileViewMode.guest:
        return 'guest_profile';
    }
  }

  /// Check if the current navigation should show avatar switcher
  bool shouldShowAvatarSwitcher(String avatarId) {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return false;

    final viewMode = _appState.determineAvatarViewMode(avatarId, currentUserId);
    return viewMode == ProfileViewMode.owner;
  }

  /// Get navigation title for avatar profile
  String getNavigationTitle(String avatarId) {
    final avatar = _appState.getAvatar(avatarId);
    if (avatar != null) {
      return avatar.name;
    }

    final currentUserId = _authService.currentUserId;
    final viewMode = _appState.determineAvatarViewMode(avatarId, currentUserId);

    switch (viewMode) {
      case ProfileViewMode.owner:
        return 'My Profile';
      case ProfileViewMode.public:
        return 'Profile';
      case ProfileViewMode.guest:
        return 'Profile';
    }
  }

  // Private helper methods

  void _navigateToAvatarProfile(BuildContext context, String avatarId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ProfileScreen(avatarId: avatarId),
        settings: RouteSettings(
          name: '/profile/avatar/$avatarId',
          arguments: {
            'avatarId': avatarId,
            'navigationContext': getBackNavigationContext(avatarId),
          },
        ),
      ),
    );
  }

  void _navigateToGuestProfile(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
        settings: const RouteSettings(
          name: '/profile/guest',
          arguments: {'navigationContext': 'guest_profile'},
        ),
      ),
    );
  }

  void _navigateToAvatarCreationFallback(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            const AvatarCreationWizard(returnResultOnCreate: true),
        settings: const RouteSettings(
          name: '/profile/create_avatar',
          arguments: {
            'navigationContext': 'avatar_creation',
            'showAvatarCreation': true,
          },
        ),
      ),
    );
  }

  void _navigateToEmptyProfile(BuildContext context, String userId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => FutureBuilder<Widget>(
          future: resolveProfileRoute(null, userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return snapshot.data ?? const ProfileScreen();
          },
        ),
        settings: RouteSettings(
          name: '/profile/user/$userId',
          arguments: {'userId': userId, 'navigationContext': 'empty_profile'},
        ),
      ),
    );
  }

  void _navigateToBasicProfile(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
        settings: const RouteSettings(
          name: '/profile',
          arguments: {'navigationContext': 'basic_profile'},
        ),
      ),
    );
  }
}
