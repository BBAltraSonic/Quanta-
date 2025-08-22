import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';
import '../store/app_state.dart';
import 'auth_service.dart';
import 'avatar_service.dart';
import 'follow_service.dart';
import 'profile_service.dart';
import 'avatar_profile_error_handler.dart';
import 'avatar_state_sync_service.dart';
import 'avatar_posts_pagination_service.dart';
import 'avatar_realtime_service_simple.dart';
import 'avatar_database_optimization_service.dart';
import 'avatar_performance_monitoring_service.dart';

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
  final AvatarProfileErrorHandler _errorHandler = AvatarProfileErrorHandler();
  final AvatarStateSyncService _syncService = AvatarStateSyncService();
  final AvatarPostsPaginationService _paginationService =
      AvatarPostsPaginationService();
  final AvatarRealtimeServiceSimple _realtimeService =
      AvatarRealtimeServiceSimple();
  final AvatarDatabaseOptimizationService _dbOptimizationService =
      AvatarDatabaseOptimizationService();
  final AvatarPerformanceMonitoringService _performanceService =
      AvatarPerformanceMonitoringService();

  SupabaseClient get _supabase => _authService.supabase;

  /// Get avatar profile data with view mode support (optimized)
  Future<AvatarProfileData> getAvatarProfile(
    String avatarId, {
    bool isOwnerView = false,
  }) async {
    return _performanceService.trackOperation('getAvatarProfile', () async {
      try {
        // Use optimized database query for better performance
        final profileData = await _dbOptimizationService
            .getAvatarProfileOptimized(avatarId);

        if (profileData.isEmpty) {
          throw AvatarProfileErrorHandler.avatarNotFound(avatarId);
        }

        final avatarData = profileData['avatar'] as Map<String, dynamic>;
        final statsData = profileData['stats'] as Map<String, dynamic>;

        final avatar = AvatarModel.fromJson(avatarData);

        // Determine view mode
        final viewMode = determineViewMode(
          avatarId,
          _authService.currentUserId,
        );

        // Check permissions for owner view
        if (isOwnerView && viewMode != ProfileViewMode.owner) {
          throw AvatarProfileErrorHandler.permissionDenied(
            'view owner profile',
          );
        }

        // Create stats from optimized query
        final stats = AvatarStats(
          followersCount: statsData['followers_count'] ?? 0,
          followingCount: 0, // Avatars don't follow others
          postsCount: statsData['posts_count'] ?? 0,
          totalLikes: statsData['total_likes'] ?? 0,
          engagementRate: statsData['engagement_rate'] ?? 0.0,
          lastActiveAt: avatar.updatedAt,
        );

        // Get recent posts using pagination service
        final recentPosts = await _paginationService.loadAvatarPosts(
          avatarId,
          page: 0,
          pageSize: 10,
        );

        // Get available actions based on view mode
        final availableActions = _getAvailableActions(viewMode, avatarId);

        // Get engagement metrics for owner view
        AvatarEngagementMetrics? engagementMetrics;
        if (viewMode == ProfileViewMode.owner) {
          engagementMetrics = await _getAvatarEngagementMetrics(avatarId);
        }

        // Get other avatars for owner view using optimized query
        List<AvatarModel>? otherAvatars;
        if (viewMode == ProfileViewMode.owner) {
          final userAvatarsData = await _dbOptimizationService
              .getUserAvatarsOptimized(avatar.ownerUserId);
          otherAvatars = userAvatarsData
              .map((data) => AvatarModel.fromJson(data['avatar']))
              .where((a) => a.id != avatarId)
              .toList();
        }

        // Subscribe to real-time updates for this avatar
        _realtimeService.subscribeToAllAvatarUpdates(avatarId);

        return AvatarProfileData(
          avatar: avatar,
          stats: stats,
          recentPosts: recentPosts,
          viewMode: viewMode,
          availableActions: availableActions,
          engagementMetrics: engagementMetrics,
          otherAvatars: otherAvatars,
        );
      } on AvatarProfileException {
        rethrow;
      } catch (e) {
        _errorHandler.logError(e, context: 'getAvatarProfile');
        if (e.toString().contains('network') ||
            e.toString().contains('timeout')) {
          throw AvatarProfileErrorHandler.networkError(
            'loading avatar profile',
            e,
          );
        }
        throw AvatarProfileErrorHandler.databaseError(
          'loading avatar profile',
          e,
        );
      }
    });
  }

  /// Get avatar posts with optimized pagination
  Future<List<PostModel>> getAvatarPosts(
    String avatarId, {
    int page = 1,
    int limit = 20,
  }) async {
    return _performanceService.trackOperation('getAvatarPosts', () async {
      try {
        // Use pagination service for efficient loading
        return await _paginationService.loadAvatarPosts(
          avatarId,
          page: page - 1, // Pagination service uses 0-based indexing
          pageSize: limit,
        );
      } catch (e) {
        debugPrint('Error getting avatar posts: $e');
        return [];
      }
    });
  }

  /// Get avatar statistics with optimized queries and caching
  Future<AvatarStats> getAvatarStats(String avatarId) async {
    return _performanceService.trackOperation('getAvatarStats', () async {
      try {
        // Try to get from cache first
        final cachedStats = _appState.getAvatarStats(avatarId);
        if (cachedStats.isNotEmpty) {
          _performanceService.recordCacheHit('avatar_stats');
          return AvatarStats(
            followersCount: cachedStats['followersCount'] ?? 0,
            followingCount: cachedStats['followingCount'] ?? 0,
            postsCount: cachedStats['postsCount'] ?? 0,
            totalLikes: cachedStats['likesCount'] ?? 0,
            engagementRate: cachedStats['engagementRate'] ?? 0.0,
            lastActiveAt: cachedStats['lastViewedAt'] ?? DateTime.now(),
          );
        }

        _performanceService.recordCacheMiss('avatar_stats');

        // Use optimized database query
        final profileData = await _dbOptimizationService
            .getAvatarProfileOptimized(avatarId);

        if (profileData.isEmpty) {
          throw AvatarProfileErrorHandler.avatarNotFound(avatarId);
        }

        final statsData = profileData['stats'] as Map<String, dynamic>;
        final avatarData = profileData['avatar'] as Map<String, dynamic>;

        final avatar = AvatarModel.fromJson(avatarData);

        return AvatarStats(
          followersCount: statsData['followers_count'] ?? 0,
          followingCount: 0, // Avatars don't follow others
          postsCount: statsData['posts_count'] ?? 0,
          totalLikes: statsData['total_likes'] ?? 0,
          engagementRate: statsData['engagement_rate'] ?? 0.0,
          lastActiveAt: avatar.updatedAt,
        );
      } on AvatarProfileException {
        rethrow;
      } catch (e) {
        _errorHandler.logError(e, context: 'getAvatarStats');

        // For stats, we can return default values instead of throwing
        // This provides a better user experience
        return AvatarStats(
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
          totalLikes: 0,
          engagementRate: 0.0,
          lastActiveAt: DateTime.now(),
        );
      }
    });
  }

  /// Set active avatar for a user with optimistic updates and rollback
  Future<void> setActiveAvatar(String userId, String avatarId) async {
    try {
      // Verify avatar exists and belongs to user
      final avatar = await _avatarService.getAvatarById(avatarId);
      if (avatar == null) {
        throw AvatarProfileErrorHandler.avatarNotFound(avatarId);
      }

      if (avatar.ownerUserId != userId) {
        throw AvatarProfileErrorHandler.avatarOwnershipError(avatarId);
      }

      // Use optimistic update with rollback capability
      await _syncService.optimisticSetActiveAvatar(userId, avatar, () async {
        await _supabase
            .from('users')
            .update({'active_avatar_id': avatarId})
            .eq('id', userId);
      });
    } on AvatarProfileException {
      rethrow;
    } catch (e) {
      _errorHandler.logError(e, context: 'setActiveAvatar');
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        throw AvatarProfileErrorHandler.networkError(
          'setting active avatar',
          e,
        );
      }
      throw AvatarProfileErrorHandler.databaseError('setting active avatar', e);
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

  /// Get all avatars for a user with optimized queries
  Future<List<AvatarModel>> getUserAvatars(String userId) async {
    return _performanceService.trackOperation('getUserAvatars', () async {
      try {
        // First check app state
        final cachedAvatars = _appState.getUserAvatars(userId);
        if (cachedAvatars.isNotEmpty) {
          _performanceService.recordCacheHit('user_avatars');
          return cachedAvatars;
        }

        _performanceService.recordCacheMiss('user_avatars');

        // Use optimized database query
        final userAvatarsData = await _dbOptimizationService
            .getUserAvatarsOptimized(userId);

        final avatars = userAvatarsData
            .map((data) => AvatarModel.fromJson(data['avatar']))
            .toList();

        // Cache in app state and preload into LRU cache
        _appState.preloadAvatars(avatars);
        for (final avatar in avatars) {
          _appState.setAvatar(avatar);
        }

        return avatars;
      } catch (e) {
        debugPrint('Error getting user avatars: $e');
        return [];
      }
    });
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

  // ========== PERFORMANCE OPTIMIZATION METHODS ==========

  /// Preload avatar data for better performance
  Future<void> preloadAvatarData(List<String> avatarIds) async {
    if (avatarIds.isEmpty) return;

    return _performanceService.trackOperation('preloadAvatarData', () async {
      try {
        // Use batch query for multiple avatars
        final avatarsData = await _dbOptimizationService
            .getMultipleAvatarsOptimized(avatarIds);

        final avatars = avatarsData
            .map((data) => AvatarModel.fromJson(data['avatar']))
            .toList();

        // Preload into cache
        _appState.preloadAvatars(avatars);

        // Cache in app state
        for (final avatar in avatars) {
          _appState.setAvatar(avatar);
        }

        // Subscribe to real-time updates for all avatars
        for (final avatarId in avatarIds) {
          _realtimeService.subscribeToAllAvatarUpdates(avatarId);
        }
      } catch (e) {
        debugPrint('Error preloading avatar data: $e');
      }
    });
  }

  /// Get trending avatars with optimized queries
  Future<List<AvatarModel>> getTrendingAvatars({
    int limit = 10,
    String timeframe = '7d',
  }) async {
    return _performanceService.trackOperation('getTrendingAvatars', () async {
      try {
        final trendingData = await _dbOptimizationService
            .getTrendingAvatarsOptimized(limit: limit, timeframe: timeframe);

        final avatars = trendingData
            .map((data) => AvatarModel.fromJson(data['avatar']))
            .toList();

        // Cache trending avatars
        _appState.preloadAvatars(avatars);
        for (final avatar in avatars) {
          _appState.setAvatar(avatar);
        }

        return avatars;
      } catch (e) {
        debugPrint('Error getting trending avatars: $e');
        return [];
      }
    });
  }

  /// Search avatars with optimized full-text search
  Future<List<AvatarModel>> searchAvatars(
    String query, {
    int page = 0,
    int limit = 20,
  }) async {
    return _performanceService.trackOperation('searchAvatars', () async {
      try {
        final searchResults = await _dbOptimizationService
            .searchAvatarsOptimized(query, offset: page * limit, limit: limit);

        final avatars = searchResults
            .map((data) => AvatarModel.fromJson(data['avatar']))
            .toList();

        // Cache search results
        for (final avatar in avatars) {
          _appState.setAvatar(avatar);
        }

        return avatars;
      } catch (e) {
        debugPrint('Error searching avatars: $e');
        return [];
      }
    });
  }

  /// Get performance metrics for monitoring
  Map<String, dynamic> getPerformanceMetrics() {
    return _performanceService.getPerformanceReport();
  }

  /// Cleanup resources and subscriptions
  void dispose() {
    // Unsubscribe from all real-time updates
    _realtimeService.dispose();

    // Stop performance monitoring
    _performanceService.dispose();
  }

  /// Refresh avatar data (force reload from database)
  Future<void> refreshAvatarData(String avatarId) async {
    return _performanceService.trackOperation('refreshAvatarData', () async {
      try {
        // Clear cache for this avatar
        _appState.removeAvatar(avatarId);

        // Refresh posts pagination
        await _paginationService.refreshAvatarPosts(avatarId);

        // Reload avatar profile
        await getAvatarProfile(avatarId);
      } catch (e) {
        debugPrint('Error refreshing avatar data: $e');
      }
    });
  }

  /// Preload next page of posts for better UX
  Future<void> preloadNextPostsPage(String avatarId) async {
    try {
      await _paginationService.preloadNextPage(avatarId);
    } catch (e) {
      // Silently fail for preloading
      debugPrint('Error preloading next posts page: $e');
    }
  }

  /// Check if more posts are available for pagination
  bool hasMorePosts(String avatarId) {
    return _paginationService.hasMorePosts(avatarId);
  }

  /// Get current page for avatar posts
  int getCurrentPostsPage(String avatarId) {
    return _paginationService.getCurrentPage(avatarId);
  }
}
