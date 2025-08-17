import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../store/app_state.dart';
import 'auth_service.dart';
import 'avatar_service.dart';
import 'follow_service.dart';
import 'profile_service.dart';

// Import ProfileViewMode from app_state.dart to avoid duplication

/// Avatar profile data model for centralized profile operations
class AvatarProfileData {
  final AvatarModel avatar;
  final AvatarStats stats;
  final List<PostModel> recentPosts;
  final ProfileViewMode viewMode;
  final List<ProfileAction> availableActions;
  final AvatarEngagementMetrics? engagementMetrics; // Owner view only
  final List<AvatarModel>? otherAvatars; // Owner view only

  AvatarProfileData({
    required this.avatar,
    required this.stats,
    required this.recentPosts,
    required this.viewMode,
    required this.availableActions,
    this.engagementMetrics,
    this.otherAvatars,
  });
}

/// Avatar statistics model
class AvatarStats {
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int totalLikes;
  final double engagementRate;
  final DateTime lastActiveAt;

  AvatarStats({
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.totalLikes,
    required this.engagementRate,
    required this.lastActiveAt,
  });
}

/// Avatar engagement metrics for owner view
class AvatarEngagementMetrics {
  final int totalViews;
  final int totalShares;
  final double avgEngagementPerPost;
  final Map<String, int> dailyActivity;

  AvatarEngagementMetrics({
    required this.totalViews,
    required this.totalShares,
    required this.avgEngagementPerPost,
    required this.dailyActivity,
  });
}

/// Profile action types
enum ProfileActionType {
  follow,
  unfollow,
  message,
  report,
  share,
  block,
  editAvatar,
  manageAvatars,
  viewAnalytics,
  switchAvatar,
}

/// Profile action model
class ProfileAction {
  final ProfileActionType type;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  ProfileAction({
    required this.type,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });
}

/// Centralized service for avatar-centric profile operations
class AvatarProfileService {
  static final AvatarProfileService _instance =
      AvatarProfileService._internal();
  factory AvatarProfileService() => _instance;
  AvatarProfileService._internal();

  final AuthService _authService = AuthService();
  final AvatarService _avatarService = AvatarService();
  final FollowService _followService = FollowService();
  final ProfileService _profileService = ProfileService();
  final AppState _appState = AppState();

  SupabaseClient get _supabase => _authService.supabase;

  /// Get avatar profile data with view mode support
  Future<AvatarProfileData> getAvatarProfile(
    String avatarId, {
    bool isOwnerView = false,
  }) async {
    try {
      // Get avatar data
      final avatar = await _avatarService.getAvatarById(avatarId);
      if (avatar == null) {
        throw Exception('Avatar not found');
      }

      // Determine view mode
      final viewMode = determineViewMode(avatarId, _authService.currentUserId);

      // Get avatar stats
      final stats = await getAvatarStats(avatarId);

      // Get recent posts
      final recentPosts = await getAvatarPosts(avatarId, page: 1, limit: 10);

      // Get available actions based on view mode
      final availableActions = _getAvailableActions(viewMode, avatarId);

      // Get engagement metrics for owner view
      AvatarEngagementMetrics? engagementMetrics;
      if (viewMode == ProfileViewMode.owner) {
        engagementMetrics = await _getAvatarEngagementMetrics(avatarId);
      }

      // Get other avatars for owner view
      List<AvatarModel>? otherAvatars;
      if (viewMode == ProfileViewMode.owner) {
        otherAvatars = await getUserAvatars(avatar.ownerUserId);
        // Remove current avatar from the list
        otherAvatars.removeWhere((a) => a.id == avatarId);
      }

      return AvatarProfileData(
        avatar: avatar,
        stats: stats,
        recentPosts: recentPosts,
        viewMode: viewMode,
        availableActions: availableActions,
        engagementMetrics: engagementMetrics,
        otherAvatars: otherAvatars,
      );
    } catch (e) {
      debugPrint('Error getting avatar profile: $e');
      rethrow;
    }
  }

  /// Get avatar posts with pagination
  Future<List<PostModel>> getAvatarPosts(
    String avatarId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final offset = (page - 1) * limit;

      final response = await _supabase
          .from('posts')
          .select('*')
          .eq('avatar_id', avatarId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<PostModel>((json) => PostModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting avatar posts: $e');
      return [];
    }
  }

  /// Get avatar statistics
  Future<AvatarStats> getAvatarStats(String avatarId) async {
    try {
      // Get avatar data for basic stats
      final avatar = await _avatarService.getAvatarById(avatarId);
      if (avatar == null) {
        throw Exception('Avatar not found');
      }

      // Get follower count
      final followersCount = await _followService.getFollowerCount(avatarId);

      // Get posts count and total likes from posts
      final postsResponse = await _supabase
          .from('posts')
          .select('likes_count')
          .eq('avatar_id', avatarId)
          .eq('is_active', true);

      final postsCount = postsResponse.length;
      final totalLikes = postsResponse.fold<int>(
        0,
        (sum, post) => sum + ((post['likes_count'] as int?) ?? 0),
      );

      // Following count is not applicable for avatars (avatars don't follow others)
      const followingCount = 0;

      return AvatarStats(
        followersCount: followersCount,
        followingCount: followingCount,
        postsCount: postsCount,
        totalLikes: totalLikes,
        engagementRate: avatar.engagementRate,
        lastActiveAt: avatar.updatedAt,
      );
    } catch (e) {
      debugPrint('Error getting avatar stats: $e');
      // Return default stats on error
      return AvatarStats(
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
        totalLikes: 0,
        engagementRate: 0.0,
        lastActiveAt: DateTime.now(),
      );
    }
  }

  /// Set active avatar for a user
  Future<void> setActiveAvatar(String userId, String avatarId) async {
    try {
      // Verify avatar exists and belongs to user
      final avatar = await _avatarService.getAvatarById(avatarId);
      if (avatar == null) {
        throw Exception('Avatar not found');
      }

      if (avatar.ownerUserId != userId) {
        throw Exception('Avatar does not belong to user');
      }

      // Update in database
      await _supabase
          .from('users')
          .update({'active_avatar_id': avatarId})
          .eq('id', userId);

      // Update app state
      _appState.setActiveAvatar(avatar);
      _appState.setActiveAvatarForUser(userId, avatar);
    } catch (e) {
      debugPrint('Error setting active avatar: $e');
      rethrow;
    }
  }

  /// Get active avatar for a user
  Future<AvatarModel?> getActiveAvatar(String userId) async {
    try {
      // First check app state
      final cachedAvatar = _appState.getActiveAvatarForUser(userId);
      if (cachedAvatar != null) {
        return cachedAvatar;
      }

      // Get from database
      final userResponse = await _supabase
          .from('users')
          .select('active_avatar_id')
          .eq('id', userId)
          .single();

      final activeAvatarId = userResponse['active_avatar_id'] as String?;
      if (activeAvatarId == null) {
        return null;
      }

      final avatar = await _avatarService.getAvatarById(activeAvatarId);
      if (avatar != null) {
        // Cache in app state
        _appState.setActiveAvatar(avatar);
      }

      return avatar;
    } catch (e) {
      debugPrint('Error getting active avatar: $e');
      return null;
    }
  }

  /// Get all avatars for a user
  Future<List<AvatarModel>> getUserAvatars(String userId) async {
    try {
      // First check app state
      final cachedAvatars = _appState.getUserAvatars(userId);
      if (cachedAvatars.isNotEmpty) {
        return cachedAvatars;
      }

      // Get from database via avatar service
      final avatars = await _avatarService.getUserAvatars(userId);

      // Cache in app state
      for (final avatar in avatars) {
        _appState.setAvatar(avatar);
      }

      return avatars;
    } catch (e) {
      debugPrint('Error getting user avatars: $e');
      return [];
    }
  }

  /// Determine view mode for an avatar profile
  ProfileViewMode determineViewMode(String avatarId, String? currentUserId) {
    // Check app state cache first
    final cachedViewMode = _appState.getAvatarViewMode(avatarId);
    if (cachedViewMode != ProfileViewMode.guest || currentUserId != null) {
      return cachedViewMode;
    }

    // Determine view mode based on ownership
    ProfileViewMode viewMode;
    if (currentUserId == null) {
      viewMode = ProfileViewMode.guest;
    } else {
      final avatar = _appState.getAvatar(avatarId);
      if (avatar != null && avatar.ownerUserId == currentUserId) {
        viewMode = ProfileViewMode.owner;
      } else {
        viewMode = ProfileViewMode.public;
      }
    }

    // Cache the view mode
    _appState.setAvatarViewMode(avatarId, viewMode);
    return viewMode;
  }

  /// Get available actions based on view mode
  List<ProfileAction> _getAvailableActions(
    ProfileViewMode viewMode,
    String avatarId,
  ) {
    final actions = <ProfileAction>[];

    switch (viewMode) {
      case ProfileViewMode.owner:
        actions.addAll([
          ProfileAction(
            type: ProfileActionType.editAvatar,
            label: 'Edit Avatar',
            isPrimary: true,
            onTap: () => _handleEditAvatar(avatarId),
          ),
          ProfileAction(
            type: ProfileActionType.manageAvatars,
            label: 'Manage Avatars',
            isPrimary: false,
            onTap: () => _handleManageAvatars(),
          ),
          ProfileAction(
            type: ProfileActionType.viewAnalytics,
            label: 'View Analytics',
            isPrimary: false,
            onTap: () => _handleViewAnalytics(avatarId),
          ),
          ProfileAction(
            type: ProfileActionType.switchAvatar,
            label: 'Switch Avatar',
            isPrimary: false,
            onTap: () => _handleSwitchAvatar(),
          ),
        ]);
        break;

      case ProfileViewMode.public:
        actions.addAll([
          ProfileAction(
            type: ProfileActionType.follow,
            label: 'Follow',
            isPrimary: true,
            onTap: () => _handleFollow(avatarId),
          ),
          ProfileAction(
            type: ProfileActionType.message,
            label: 'Message',
            isPrimary: false,
            onTap: () => _handleMessage(avatarId),
          ),
          ProfileAction(
            type: ProfileActionType.share,
            label: 'Share',
            isPrimary: false,
            onTap: () => _handleShare(avatarId),
          ),
          ProfileAction(
            type: ProfileActionType.report,
            label: 'Report',
            isPrimary: false,
            onTap: () => _handleReport(avatarId),
          ),
        ]);
        break;

      case ProfileViewMode.guest:
        actions.addAll([
          ProfileAction(
            type: ProfileActionType.share,
            label: 'Share',
            isPrimary: true,
            onTap: () => _handleShare(avatarId),
          ),
        ]);
        break;
    }

    return actions;
  }

  /// Get engagement metrics for owner view
  Future<AvatarEngagementMetrics> _getAvatarEngagementMetrics(
    String avatarId,
  ) async {
    try {
      // Get posts for the avatar
      final postsResponse = await _supabase
          .from('posts')
          .select(
            'views_count, shares_count, likes_count, comments_count, created_at',
          )
          .eq('avatar_id', avatarId)
          .eq('is_active', true);

      int totalViews = 0;
      int totalShares = 0;
      int totalEngagement = 0;
      final Map<String, int> dailyActivity = {};

      for (final post in postsResponse) {
        totalViews += (post['views_count'] as int?) ?? 0;
        totalShares += (post['shares_count'] as int?) ?? 0;

        final likes = (post['likes_count'] as int?) ?? 0;
        final comments = (post['comments_count'] as int?) ?? 0;
        totalEngagement += likes + comments;

        // Track daily activity
        final createdAt = DateTime.parse(post['created_at']);
        final dateKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        dailyActivity[dateKey] = (dailyActivity[dateKey] ?? 0) + 1;
      }

      final avgEngagementPerPost = postsResponse.isNotEmpty
          ? totalEngagement / postsResponse.length
          : 0.0;

      return AvatarEngagementMetrics(
        totalViews: totalViews,
        totalShares: totalShares,
        avgEngagementPerPost: avgEngagementPerPost,
        dailyActivity: dailyActivity,
      );
    } catch (e) {
      debugPrint('Error getting avatar engagement metrics: $e');
      return AvatarEngagementMetrics(
        totalViews: 0,
        totalShares: 0,
        avgEngagementPerPost: 0.0,
        dailyActivity: {},
      );
    }
  }

  // Action handlers (placeholder implementations)
  void _handleEditAvatar(String avatarId) {
    // TODO: Navigate to avatar edit screen
    debugPrint('Edit avatar: $avatarId');
  }

  void _handleManageAvatars() {
    // TODO: Navigate to avatar management screen
    debugPrint('Manage avatars');
  }

  void _handleViewAnalytics(String avatarId) {
    // TODO: Navigate to analytics screen
    debugPrint('View analytics for avatar: $avatarId');
  }

  void _handleSwitchAvatar() {
    // TODO: Show avatar switcher
    debugPrint('Switch avatar');
  }

  void _handleFollow(String avatarId) {
    // TODO: Toggle follow status
    _followService.toggleFollow(avatarId);
  }

  void _handleMessage(String avatarId) {
    // TODO: Navigate to message screen
    debugPrint('Message avatar: $avatarId');
  }

  void _handleShare(String avatarId) {
    // TODO: Share avatar profile
    debugPrint('Share avatar: $avatarId');
  }

  void _handleReport(String avatarId) {
    // TODO: Report avatar
    debugPrint('Report avatar: $avatarId');
  }
}
