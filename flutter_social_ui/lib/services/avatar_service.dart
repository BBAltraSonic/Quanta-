import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/avatar_model.dart';
import '../utils/environment.dart';
import 'auth_service.dart';

class AvatarService {
  static final AvatarService _instance = AvatarService._internal();
  factory AvatarService() => _instance;
  AvatarService._internal();

  final AuthService _authService = AuthService();
  SupabaseClient get _supabase => _authService.supabase;

  // Get user's avatar
  Future<AvatarModel?> getUserAvatar([String? userId]) async {
    try {
      final uid = userId ?? _authService.currentUserId;
      if (uid == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('avatars')
          .select()
          .eq('owner_user_id', uid)
          .maybeSingle();

      if (response == null) return null;
      return AvatarModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load avatar: $e');
    }
  }

  // Create new avatar
  Future<AvatarModel> createAvatar({
    required String name,
    required String bio,
    String? backstory,
    required AvatarNiche niche,
    required List<PersonalityTrait> personalityTraits,
    File? avatarImage,
    String? voiceStyle,
    bool allowAutonomousPosting = false,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Check if user already has an avatar (MVP: one avatar per user)
      final existingAvatar = await getUserAvatar();
      if (existingAvatar != null) {
        throw Exception(
          'You already have an avatar. Please delete it first to create a new one.',
        );
      }

      // Validate input
      _validateAvatarData(name, bio, backstory, personalityTraits);

      // Upload avatar image if provided
      String? avatarImageUrl;
      if (avatarImage != null) {
        avatarImageUrl = await _uploadAvatarImage(userId, avatarImage);
      }

      // Create avatar model
      final avatar = AvatarModel.create(
        ownerUserId: userId,
        name: name.trim(),
        bio: bio.trim(),
        backstory: backstory?.trim(),
        niche: niche,
        personalityTraits: personalityTraits,
        avatarImageUrl: avatarImageUrl,
        voiceStyle: voiceStyle,
        allowAutonomousPosting: allowAutonomousPosting,
      );

      // Save to database
      final response = await _supabase
          .from('avatars')
          .insert(avatar.toJson())
          .select()
          .single();

      return AvatarModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create avatar: $e');
    }
  }

  // Update existing avatar
  Future<AvatarModel> updateAvatar({
    required String avatarId,
    String? name,
    String? bio,
    String? backstory,
    AvatarNiche? niche,
    List<PersonalityTrait>? personalityTraits,
    File? newAvatarImage,
    String? voiceStyle,
    bool? allowAutonomousPosting,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get existing avatar
      final existingAvatar = await getAvatarById(avatarId);
      if (existingAvatar == null) {
        throw Exception('Avatar not found');
      }

      // Check ownership
      if (existingAvatar.ownerUserId != userId) {
        throw Exception('You can only update your own avatar');
      }

      // Validate input if provided
      if (name != null || bio != null || personalityTraits != null) {
        _validateAvatarData(
          name ?? existingAvatar.name,
          bio ?? existingAvatar.bio,
          backstory,
          personalityTraits ?? existingAvatar.personalityTraits,
        );
      }

      // Upload new image if provided
      String? avatarImageUrl = existingAvatar.avatarImageUrl;
      if (newAvatarImage != null) {
        // Delete old image if it exists
        if (avatarImageUrl != null) {
          await _deleteAvatarImage(userId, avatarImageUrl);
        }
        avatarImageUrl = await _uploadAvatarImage(userId, newAvatarImage);
      }

      // Create updated avatar
      final updatedAvatar = existingAvatar.copyWith(
        name: name?.trim(),
        bio: bio?.trim(),
        backstory: backstory?.trim(),
        niche: niche,
        personalityTraits: personalityTraits,
        avatarImageUrl: avatarImageUrl,
        voiceStyle: voiceStyle,
        allowAutonomousPosting: allowAutonomousPosting,
      );

      // Update in database
      final response = await _supabase
          .from('avatars')
          .update(updatedAvatar.toJson())
          .eq('id', avatarId)
          .eq('owner_user_id', userId)
          .select()
          .single();

      return AvatarModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update avatar: $e');
    }
  }

  // Get avatar by ID
  Future<AvatarModel?> getAvatarById(String avatarId) async {
    try {
      final response = await _supabase
          .from('avatars')
          .select()
          .eq('id', avatarId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return AvatarModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load avatar: $e');
    }
  }

  // Delete avatar
  Future<void> deleteAvatar(String avatarId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get existing avatar
      final existingAvatar = await getAvatarById(avatarId);
      if (existingAvatar == null) {
        throw Exception('Avatar not found');
      }

      // Check ownership
      if (existingAvatar.ownerUserId != userId) {
        throw Exception('You can only delete your own avatar');
      }

      // Delete avatar image if it exists
      if (existingAvatar.avatarImageUrl != null) {
        await _deleteAvatarImage(userId, existingAvatar.avatarImageUrl!);
      }

      // Soft delete avatar (set is_active to false)
      await _supabase
          .from('avatars')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', avatarId)
          .eq('owner_user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete avatar: $e');
    }
  }

  // Get trending avatars
  Future<List<AvatarModel>> getTrendingAvatars({int limit = 20}) async {
    try {
      final response = await _supabase
          .from('avatars')
          .select()
          .eq('is_active', true)
          .order('engagement_rate', ascending: false)
          .order('followers_count', ascending: false)
          .limit(limit);

      return response
          .map<AvatarModel>((json) => AvatarModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load trending avatars: $e');
    }
  }

  // Search avatars
  Future<List<AvatarModel>> searchAvatars({
    String? query,
    AvatarNiche? niche,
    List<PersonalityTrait>? traits,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('avatars')
          .select()
          .eq('is_active', true);

      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'name.ilike.%$query%,bio.ilike.%$query%',
        );
      }

      if (niche != null) {
        queryBuilder = queryBuilder.eq(
          'niche',
          niche.toString().split('.').last,
        );
      }

      if (traits != null && traits.isNotEmpty) {
        final traitStrings = traits
            .map((t) => t.toString().split('.').last)
            .toList();
        queryBuilder = queryBuilder.overlaps(
          'personality_traits',
          traitStrings,
        );
      }

      final response = await queryBuilder
          .order('followers_count', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<AvatarModel>((json) => AvatarModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search avatars: $e');
    }
  }

  // Upload avatar image
  Future<String> _uploadAvatarImage(String userId, File imageFile) async {
    try {
      // Validate file
      final fileSize = await imageFile.length();
      if (fileSize > Environment.maxImageSizeMB * 1024 * 1024) {
        throw Exception(
          'Image size must be less than ${Environment.maxImageSizeMB}MB',
        );
      }

      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$userId/$fileName';

      // Upload to Supabase storage
      await _supabase.storage.from('avatars').upload(filePath, imageFile);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload avatar image: $e');
    }
  }

  // Delete avatar image
  Future<void> _deleteAvatarImage(String userId, String imageUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2) {
        final filePath = pathSegments
            .sublist(pathSegments.length - 2)
            .join('/');
        await _supabase.storage.from('avatars').remove([filePath]);
      }
    } catch (e) {
      // Log error but don't throw - image deletion is not critical
      print('Failed to delete avatar image: $e');
    }
  }

  // Validate avatar data
  void _validateAvatarData(
    String name,
    String bio,
    String? backstory,
    List<PersonalityTrait> personalityTraits,
  ) {
    if (name.trim().length < 3 || name.trim().length > 50) {
      throw Exception('Avatar name must be between 3 and 50 characters');
    }

    if (bio.trim().length < 10 || bio.trim().length > 500) {
      throw Exception('Avatar bio must be between 10 and 500 characters');
    }

    if (backstory != null && backstory.trim().length > 1000) {
      throw Exception('Avatar backstory must be less than 1000 characters');
    }

    if (personalityTraits.length < 3 || personalityTraits.length > 5) {
      throw Exception('Please select between 3 and 5 personality traits');
    }

    // Validate name contains only allowed characters
    if (!RegExp(r'^[a-zA-Z0-9\s\-_.]+$').hasMatch(name.trim())) {
      throw Exception(
        'Avatar name can only contain letters, numbers, spaces, hyphens, underscores, and periods',
      );
    }
  }

  // Pick image from gallery or camera
  Future<File?> pickAvatarImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  // Additional method aliases for backward compatibility
  Future<AvatarModel?> getAvatar(String avatarId) async {
    return await getAvatarById(avatarId);
  }

  Future<List<AvatarModel>> getUserAvatars([String? userId]) async {
    try {
      final uid = userId ?? _authService.currentUserId;
      if (uid == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('avatars')
          .select()
          .eq('owner_user_id', uid)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return response
          .map<AvatarModel>((json) => AvatarModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load user avatars: $e');
    }
  }
}
