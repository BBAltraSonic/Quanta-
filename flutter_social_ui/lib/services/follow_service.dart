import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avatar_model.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'avatar_service.dart';

/// Service for handling following/follower relationships
class FollowService {
  static final FollowService _instance = FollowService._internal();
  factory FollowService() => _instance;
  FollowService._internal();

  final AuthService _authService = AuthService();
  final AvatarService _avatarService = AvatarService();
  
  // Supabase client
  SupabaseClient get _supabase => Supabase.instance.client;
  
  // In-memory cache for demo mode
  final Map<String, Set<String>> _userFollowingAvatars = {}; // userId -> Set<avatarId>
  final Map<String, Set<String>> _avatarFollowers = {}; // avatarId -> Set<userId>
  final Map<String, List<AvatarModel>> _recommendedAvatars = {};

  /// Follow or unfollow an avatar
  Future<bool> toggleFollow(String avatarId) async {
    final userId = _authService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      if (false) {
        return _toggleFollowDemo(avatarId, userId);
      } else {
        return _toggleFollowSupabase(avatarId, userId);
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      rethrow;
    }
  }

  /// Check if user is following an avatar
  Future<bool> isFollowing(String avatarId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      if (false) {
        return _userFollowingAvatars[userId]?.contains(avatarId) ?? false;
      } else {
        return _isFollowingSupabase(avatarId, userId);
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
      return false;
    }
  }

  /// Get list of avatars the user is following
  Future<List<AvatarModel>> getFollowingAvatars({int limit = 20, int offset = 0}) async {
    final userId = _authService.currentUserId;
    if (userId == null) return [];

    try {
      if (false) {
        return _getFollowingAvatarsDemo(userId, limit, offset);
      } else {
        return _getFollowingAvatarsSupabase(userId, limit, offset);
      }
    } catch (e) {
      debugPrint('Error getting following avatars: $e');
      return [];
    }
  }

  /// Get list of users following an avatar
  Future<List<UserModel>> getAvatarFollowers(String avatarId, {int limit = 20, int offset = 0}) async {
    try {
      if (false) {
        return _getAvatarFollowersDemo(avatarId, limit, offset);
      } else {
        return _getAvatarFollowersSupabase(avatarId, limit, offset);
      }
    } catch (e) {
      debugPrint('Error getting avatar followers: $e');
      return [];
    }
  }

  /// Get follower count for an avatar
  Future<int> getFollowerCount(String avatarId) async {
    try {
      if (false) {
        return _avatarFollowers[avatarId]?.length ?? 0;
      } else {
        return _getFollowerCountSupabase(avatarId);
      }
    } catch (e) {
      debugPrint('Error getting follower count: $e');
      return 0;
    }
  }

  /// Get following count for a user
  Future<int> getFollowingCount() async {
    final userId = _authService.currentUserId;
    if (userId == null) return 0;

    try {
      if (false) {
        return _userFollowingAvatars[userId]?.length ?? 0;
      } else {
        return _getFollowingCountSupabase(userId);
      }
    } catch (e) {
      debugPrint('Error getting following count: $e');
      return 0;
    }
  }

  /// Get recommended avatars to follow
  Future<List<AvatarModel>> getRecommendedAvatars({int limit = 10}) async {
    final userId = _authService.currentUserId;
    if (userId == null) return [];

    try {
      if (false) {
        return _getRecommendedAvatarsDemo(userId, limit);
      } else {
        return _getRecommendedAvatarsSupabase(userId, limit);
      }
    } catch (e) {
      debugPrint('Error getting recommended avatars: $e');
      return [];
    }
  }

  /// Get trending avatars
  Future<List<AvatarModel>> getTrendingAvatars({int limit = 10}) async {
    try {
      if (false) {
        return _getTrendingAvatarsDemo(limit);
      } else {
        return _getTrendingAvatarsSupabase(limit);
      }
    } catch (e) {
      debugPrint('Error getting trending avatars: $e');
      return [];
    }
  }

  /// Get mutual follows (avatars followed by both users)
  Future<List<AvatarModel>> getMutualFollows(String otherUserId, {int limit = 10}) async {
    final userId = _authService.currentUserId;
    if (userId == null) return [];

    try {
      if (false) {
        return _getMutualFollowsDemo(userId, otherUserId, limit);
      } else {
        return _getMutualFollowsSupabase(userId, otherUserId, limit);
      }
    } catch (e) {
      debugPrint('Error getting mutual follows: $e');
      return [];
    }
  }

  // Demo mode implementations
  bool _toggleFollowDemo(String avatarId, String userId) {
    _userFollowingAvatars[userId] ??= <String>{};
    _avatarFollowers[avatarId] ??= <String>{};
    
    final isFollowing = _userFollowingAvatars[userId]!.contains(avatarId);
    
    if (isFollowing) {
      _userFollowingAvatars[userId]!.remove(avatarId);
      _avatarFollowers[avatarId]!.remove(userId);
      return false;
    } else {
      _userFollowingAvatars[userId]!.add(avatarId);
      _avatarFollowers[avatarId]!.add(userId);
      return true;
    }
  }

  Future<List<AvatarModel>> _getFollowingAvatarsDemo(String userId, int limit, int offset) async {
    final followingIds = _userFollowingAvatars[userId] ?? <String>{};
    final avatarsList = followingIds.toList();
    
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, avatarsList.length);
    
    if (startIndex >= avatarsList.length) return [];
    
    final limitedIds = avatarsList.sublist(startIndex, endIndex);
    final avatars = <AvatarModel>[];
    
    for (final avatarId in limitedIds) {
      try {
        final avatar = await _avatarService.getAvatarById(avatarId);
        if (avatar != null) avatars.add(avatar);
      } catch (e) {
        debugPrint('Error loading avatar $avatarId: $e');
      }
    }
    
    return avatars;
  }

  Future<List<UserModel>> _getAvatarFollowersDemo(String avatarId, int limit, int offset) async {
    final followerIds = _avatarFollowers[avatarId] ?? <String>{};
    final followersList = followerIds.toList();
    
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, followersList.length);
    
    if (startIndex >= followersList.length) return [];
    
    // For demo, create mock users
    return followersList.sublist(startIndex, endIndex).map<UserModel>((userId) {
      return UserModel.create(
        email: 'user$userId@demo.com',
        username: 'user_${userId.substring(0, 8)}',
        displayName: 'Demo User ${userId.substring(0, 4)}',
      );
    }).toList();
  }

  Future<List<AvatarModel>> _getRecommendedAvatarsDemo(String userId, int limit) async {
    // For demo, return some sample avatars that user isn't following
    final allAvatars = await _avatarService.getAllAvatars();
    final following = _userFollowingAvatars[userId] ?? <String>{};
    
    final recommended = allAvatars.where((avatar) => !following.contains(avatar.id)).take(limit).toList();
    return recommended;
  }

  Future<List<AvatarModel>> _getTrendingAvatarsDemo(int limit) async {
    // For demo, return avatars sorted by follower count
    final allAvatars = await _avatarService.getAllAvatars();
    
    // Sort by follower count (demo)
    allAvatars.sort((a, b) {
      final aFollowers = _avatarFollowers[a.id]?.length ?? 0;
      final bFollowers = _avatarFollowers[b.id]?.length ?? 0;
      return bFollowers.compareTo(aFollowers);
    });
    
    return allAvatars.take(limit).toList();
  }

  Future<List<AvatarModel>> _getMutualFollowsDemo(String userId, String otherUserId, int limit) async {
    final userFollowing = _userFollowingAvatars[userId] ?? <String>{};
    final otherFollowing = _userFollowingAvatars[otherUserId] ?? <String>{};
    
    final mutual = userFollowing.intersection(otherFollowing).take(limit);
    final avatars = <AvatarModel>[];
    
    for (final avatarId in mutual) {
      try {
        final avatar = await _avatarService.getAvatarById(avatarId);
        if (avatar != null) avatars.add(avatar);
      } catch (e) {
        debugPrint('Error loading mutual follow avatar $avatarId: $e');
      }
    }
    
    return avatars;
  }

  // Supabase implementations (placeholders)
  Future<bool> _toggleFollowSupabase(String avatarId, String userId) async {
    try {
      // Check if already following
      final existingFollow = await _supabase
          .from('follows')
          .select()
          .eq('user_id', userId)
          .eq('avatar_id', avatarId)
          .maybeSingle();

      if (existingFollow != null) {
        // Unfollow
        await _supabase
            .from('follows')
            .delete()
            .eq('user_id', userId)
            .eq('avatar_id', avatarId);
        return false;
      } else {
        // Follow
        await _supabase.from('follows').insert({
          'user_id': userId,
          'avatar_id': avatarId,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle follow: $e');
      rethrow;
    }
  }

  Future<bool> _isFollowingSupabase(String avatarId, String userId) async {
    try {
      final follow = await _supabase
          .from('follows')
          .select()
          .eq('user_id', userId)
          .eq('avatar_id', avatarId)
          .maybeSingle();
      
      return follow != null;
    } catch (e) {
      debugPrint('❌ Failed to check follow status: $e');
      return false;
    }
  }

  Future<List<AvatarModel>> _getFollowingAvatarsSupabase(String userId, int limit, int offset) async {
    try {
      final response = await _supabase
          .from('follows')
          .select('''
            avatar_id,
            avatars:avatar_id (
              id, name, bio, backstory, niche, personality_traits, 
              avatar_image_url, voice_style, allow_autonomous_posting, 
              owner_user_id, created_at, updated_at, is_active
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<AvatarModel>((item) => AvatarModel.fromJson(item['avatars']))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get following avatars: $e');
      return [];
    }
  }

  Future<List<UserModel>> _getAvatarFollowersSupabase(String avatarId, int limit, int offset) async {
    try {
      final response = await _supabase
          .from('follows')
          .select('''
            user_id,
            users:user_id (
              id, email, username, display_name, avatar_url, bio, created_at, updated_at
            )
          ''')
          .eq('avatar_id', avatarId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<UserModel>((item) => UserModel.fromJson(item['users']))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get avatar followers: $e');
      return [];
    }
  }

  Future<int> _getFollowerCountSupabase(String avatarId) async {
    try {
      final response = await _supabase
          .from('follows')
          .select('id')
          .eq('avatar_id', avatarId);
      
      return response.length;
    } catch (e) {
      debugPrint('❌ Failed to get follower count: $e');
      return 0;
    }
  }

  Future<int> _getFollowingCountSupabase(String userId) async {
    try {
      final response = await _supabase
          .from('follows')
          .select('id')
          .eq('user_id', userId);
      
      return response.length;
    } catch (e) {
      debugPrint('❌ Failed to get following count: $e');
      return 0;
    }
  }

  Future<List<AvatarModel>> _getRecommendedAvatarsSupabase(String userId, int limit) async {
    try {
      // Simplified approach: Just get recent active avatars that aren't owned by the user
      final response = await _supabase
          .from('avatars')
          .select()
          .eq('is_active', true)
          .neq('owner_user_id', userId) // Don't recommend user's own avatar
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<AvatarModel>((json) => AvatarModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get recommended avatars: $e');
      return [];
    }
  }

  Future<List<AvatarModel>> _getTrendingAvatarsSupabase(int limit) async {
    try {
      // Get recent active avatars (simplified trending)
      final response = await _supabase
          .from('avatars')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<AvatarModel>((json) => AvatarModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get trending avatars: $e');
      return [];
    }
  }

  Future<List<AvatarModel>> _getMutualFollowsSupabase(String userId, String otherUserId, int limit) async {
    try {
      // Simplified approach: Get the first user's follows, then check if other user follows them
      final user1Follows = await _supabase
          .from('follows')
          .select('avatar_id')
          .eq('user_id', userId)
          .limit(limit);
      
      final mutualAvatars = <AvatarModel>[];
      
      for (final follow in user1Follows) {
        final avatarId = follow['avatar_id'];
        
        // Check if other user also follows this avatar
        final otherUserFollows = await _supabase
            .from('follows')
            .select('id')
            .eq('user_id', otherUserId)
            .eq('avatar_id', avatarId)
            .maybeSingle();
            
        if (otherUserFollows != null) {
          // Get avatar details
          final avatarData = await _supabase
              .from('avatars')
              .select()
              .eq('id', avatarId)
              .single();
              
          mutualAvatars.add(AvatarModel.fromJson(avatarData));
          
          if (mutualAvatars.length >= limit) break;
        }
      }

      return mutualAvatars;
    } catch (e) {
      debugPrint('❌ Failed to get mutual follows: $e');
      return [];
    }
  }

  /// Initialize with some demo data for testing
  void initializeDemoData() {
    // Pre-populate some follow relationships for demo
    const demoUserId = 'demo-user-1';
    _userFollowingAvatars[demoUserId] = {'avatar-1', 'avatar-2'};
    _avatarFollowers['avatar-1'] = {demoUserId, 'demo-user-2', 'demo-user-3'};
    _avatarFollowers['avatar-2'] = {demoUserId, 'demo-user-4'};
    _avatarFollowers['avatar-3'] = {'demo-user-2', 'demo-user-3', 'demo-user-4', 'demo-user-5'};
  }

  /// Clear all cache
  void clearCache() {
    _userFollowingAvatars.clear();
    _avatarFollowers.clear();
    _recommendedAvatars.clear();
  }
}
