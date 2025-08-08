import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../utils/environment.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final String baseUrl = Environment.apiBaseUrl;

  // Get user profile with avatars
  Future<Map<String, dynamic>> getUserProfileData(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'user': UserModel.fromJson(data['user']),
          'avatars': (data['avatars'] as List)
              .map((avatar) => AvatarModel.fromJson(avatar))
              .toList(),
          'stats': data['stats'] ?? {},
          'preferences': data['preferences'] ?? {},
        };
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      // Return demo data for development
      return _getDemoProfileData(userId);
    }
  }

  // Update user profile
  Future<UserModel> updateUserProfile({
    required String userId,
    String? displayName,
    String? username,
    String? email,
    String? profileImageUrl,
  }) async {
    try {
      final body = {
        'display_name': displayName,
        'username': username,
        'email': email,
        'profile_image_url': profileImageUrl,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/user/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  // Upload profile image
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/profile-image'),
      );

      request.fields['user_id'] = userId;
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ));

      final response = await request.send();
      final responseData = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final data = json.decode(responseData.body);
        return data['image_url'];
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  // Get user's avatars
  Future<List<AvatarModel>> getUserAvatars(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/$userId/avatars'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['avatars'] as List)
            .map((avatar) => AvatarModel.fromJson(avatar))
            .toList();
      } else {
        throw Exception('Failed to load avatars: ${response.statusCode}');
      }
    } catch (e) {
      // Return demo avatars for development
      return _getDemoAvatars(userId);
    }
  }

  // Set active avatar
  Future<void> setActiveAvatar(String userId, String avatarId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/$userId/active-avatar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'avatar_id': avatarId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to set active avatar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error setting active avatar: $e');
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/user/$userId/preferences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'preferences': preferences}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update preferences: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating preferences: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete account: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting account: $e');
    }
  }

  // Demo data for development
  Map<String, dynamic> _getDemoProfileData(String userId) {
    return {
      'user': UserModel.create(
        email: 'demo@example.com',
        username: 'demo_user',
        displayName: 'Demo User',
        profileImageUrl: 'assets/images/p.jpg',
      ),
      'avatars': _getDemoAvatars(userId),
      'stats': {
        'total_posts': 24,
        'total_likes': 1245,
        'total_followers': 856,
        'total_views': 12489,
      },
      'preferences': {
        'notifications_enabled': true,
        'push_notifications': true,
        'email_notifications': false,
        'dark_mode': true,
        'auto_play_videos': true,
        'data_saver': false,
        'privacy_level': 'public',
      },
    };
  }

  List<AvatarModel> _getDemoAvatars(String userId) {
    return [
      AvatarModel.create(
        ownerUserId: userId,
        name: 'Lana Smith',
        bio: 'Photographer | Traveler | Coffee lover',
        niche: AvatarNiche.lifestyle,
        personalityTraits: [
          PersonalityTrait.friendly,
          PersonalityTrait.creative,
          PersonalityTrait.inspiring
        ],
        avatarImageUrl: 'assets/images/p.jpg',
      ).copyWith(
        followersCount: 8000,
        likesCount: 12450,
        postsCount: 50,
        engagementRate: 4.2,
      ),
      AvatarModel.create(
        ownerUserId: userId,
        name: 'Alex Chen',
        bio: 'Tech enthusiast | Gadget reviewer | Future lover',
        niche: AvatarNiche.tech,
        personalityTraits: [
          PersonalityTrait.analytical,
          PersonalityTrait.professional,
          PersonalityTrait.energetic
        ],
        avatarImageUrl: 'assets/images/We.jpg',
      ).copyWith(
        followersCount: 5200,
        likesCount: 8900,
        postsCount: 32,
        engagementRate: 3.8,
      ),
    ];
  }
}
