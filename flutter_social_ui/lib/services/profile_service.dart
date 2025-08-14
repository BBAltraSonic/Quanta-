import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import 'auth_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final AuthService _authService = AuthService();

  // Get user profile with avatars
  Future<Map<String, dynamic>> getUserProfileData(String userId) async {
    try {
      // Get user data from Supabase (including active_avatar_id)
      final userResponse = await _authService.supabase
          .from('users')
          .select('*, active_avatar_id')
          .eq('id', userId)
          .single();

      // Get user's avatars
      final avatarsResponse = await _authService.supabase
          .from('avatars')
          .select()
          .eq('owner_user_id', userId)
          .order('created_at', ascending: true);

      // Get user stats (following count)
      final followsResponse = await _authService.supabase
          .from('follows')
          .select('avatar_id')
          .eq('user_id', userId);
      
      final followingCount = (followsResponse as List).length;

      List<AvatarModel> avatars = (avatarsResponse as List)
          .map((avatar) => AvatarModel.fromJson(avatar))
          .toList();

      // Find the active avatar or use the first one
      AvatarModel? activeAvatar;
      if (userResponse['active_avatar_id'] != null) {
        activeAvatar = avatars.firstWhere(
          (avatar) => avatar.id == userResponse['active_avatar_id'],
          orElse: () => avatars.isNotEmpty ? avatars.first : AvatarModel(
            id: '',
            name: 'No Avatar',
            bio: 'Create your first avatar to get started!',
            niche: AvatarNiche.other,
            personalityTraits: [],
            personalityPrompt: '',
            ownerUserId: userId,
            followersCount: 0,
            likesCount: 0,
            postsCount: 0,
            engagementRate: 0.0,
            isActive: true,
            allowAutonomousPosting: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      } else if (avatars.isNotEmpty) {
        activeAvatar = avatars.first;
      }

      return {
        'user': UserModel.fromJson(userResponse),
        'avatars': avatars,
        'active_avatar': activeAvatar,
        'stats': {
          'following_count': followingCount,
          'followers_count': userResponse['followers_count'] ?? 0,
          'posts_count': userResponse['posts_count'] ?? 0,
        },
        'preferences': userResponse['preferences'] ?? {
          'notifications_enabled': true,
          'push_notifications': true,
          'email_notifications': false,
          'auto_play_videos': true,
          'data_saver': false,
          'privacy_level': 'public',
        },
      };
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<UserModel> updateUserProfile({
    required String userId,
    String? displayName,
    String? username,
    String? email,
    String? profileImageUrl,
    String? bio,
    String? firstName,
    String? lastName,
  }) async {
    try {
      // Validate inputs
      if (username != null && username.trim().isEmpty) {
        throw Exception('Username cannot be empty');
      }
      
      if (email != null && !_isValidEmail(email)) {
        throw Exception('Please enter a valid email address');
      }
      
      if (bio != null && bio.length > 160) {
        throw Exception('Bio cannot exceed 160 characters');
      }
      
      // Check username uniqueness if username is being updated
      if (username != null) {
        final existingUser = await _checkUsernameExists(username, userId);
        if (existingUser) {
          throw Exception('Username is already taken');
        }
      }
      
      // Check email uniqueness if email is being updated
      if (email != null) {
        final existingUser = await _checkEmailExists(email, userId);
        if (existingUser) {
          throw Exception('Email is already registered');
        }
      }

      final updateData = <String, dynamic>{};
      if (displayName != null) updateData['display_name'] = displayName.trim().isEmpty ? null : displayName.trim();
      if (username != null) updateData['username'] = username.trim();
      if (email != null) updateData['email'] = email.trim().toLowerCase();
      if (profileImageUrl != null) updateData['profile_image_url'] = profileImageUrl;
      if (bio != null) updateData['bio'] = bio.trim().isEmpty ? null : bio.trim();
      if (firstName != null) updateData['first_name'] = firstName.trim().isEmpty ? null : firstName.trim();
      if (lastName != null) updateData['last_name'] = lastName.trim().isEmpty ? null : lastName.trim();
      
      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _authService.supabase
          .from('users')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      // More specific error messages
      String errorMessage = e.toString();
      if (errorMessage.contains('duplicate key value violates unique constraint "users_username_key"')) {
        throw Exception('Username is already taken');
      } else if (errorMessage.contains('duplicate key value violates unique constraint "users_email_key"')) {
        throw Exception('Email is already registered');
      } else if (errorMessage.contains('Error updating profile:')) {
        rethrow;
      }
      throw Exception('Error updating profile: $e');
    }
  }

  // Upload profile image
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      final fileName = '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Supabase storage
      await _authService.supabase.storage
          .from('avatars')
          .upload(fileName, imageFile);

      // Get public URL
      final publicUrl = _authService.supabase.storage
          .from('avatars')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  // Get user's avatars
  Future<List<AvatarModel>> getUserAvatars(String userId) async {
    try {
      final response = await _authService.supabase
          .from('avatars')
          .select()
          .eq('owner_user_id', userId);

      return (response as List)
          .map((avatar) => AvatarModel.fromJson(avatar))
          .toList();
    } catch (e) {
      debugPrint('Error loading user avatars: $e');
      return [];
    }
  }

  // Set active avatar
  Future<void> setActiveAvatar(String userId, String avatarId) async {
    try {
      await _authService.supabase
          .from('users')
          .update({'active_avatar_id': avatarId})
          .eq('id', userId);
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
      final validatedPrefs = _validatePreferences(preferences);
      await _authService.supabase
          .from('users')
          .update({'preferences': validatedPrefs, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Error updating preferences: $e');
    }
  }

  // Get user stats
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userResponse = await _authService.supabase
          .from('users')
          .select('followers_count, posts_count')
          .eq('id', userId)
          .single();

      // Get following count
      final followsResponse = await _authService.supabase
          .from('follows')
          .select('avatar_id')
          .eq('user_id', userId);
      
      final followingCount = (followsResponse as List).length;

      return {
        'following_count': followingCount,
        'followers_count': userResponse['followers_count'] ?? 0,
        'posts_count': userResponse['posts_count'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error loading user stats: $e');
      return {
        'following_count': 0,
        'followers_count': 0,
        'posts_count': 0,
      };
    }
  }

  // Delete account
  Future<void> deleteAccount(String userId) async {
    try {
      // Delete user's avatars first
      await _authService.supabase
          .from('avatars')
          .delete()
          .eq('owner_user_id', userId);
      
      // Delete user
      await _authService.supabase
          .from('users')
          .delete()
          .eq('id', userId);
    } catch (e) {
      throw Exception('Error deleting account: $e');
    }
  }

  /// Get pinned post for an avatar
  Future<Map<String, dynamic>?> getPinnedPost(String avatarId) async {
    try {
      final avatarResponse = await _authService.supabase
          .from('avatars')
          .select('pinned_post_id')
          .eq('id', avatarId)
          .single();
      
      final pinnedPostId = avatarResponse['pinned_post_id'] as String?;
      if (pinnedPostId == null) return null;
      
      final postResponse = await _authService.supabase
          .from('posts')
          .select('*')
          .eq('id', pinnedPostId)
          .eq('is_active', true)
          .single();
      
      return postResponse;
    } catch (e) {
      debugPrint('Error loading pinned post: $e');
      return null;
    }
  }

  /// Set pinned post for an avatar
  Future<void> setPinnedPost(String avatarId, String? postId) async {
    try {
      await _authService.supabase
          .from('avatars')
          .update({'pinned_post_id': postId})
          .eq('id', avatarId);
    } catch (e) {
      throw Exception('Error setting pinned post: $e');
    }
  }

  /// Remove pinned post for an avatar
  Future<void> unpinPost(String avatarId) async {
    try {
      await _authService.supabase
          .from('avatars')
          .update({'pinned_post_id': null})
          .eq('id', avatarId);
    } catch (e) {
      throw Exception('Error unpinning post: $e');
    }
  }

  /// Get collaborations for an avatar
  Future<List<Map<String, dynamic>>> getCollaborationPosts(String avatarId, {int limit = 10}) async {
    try {
      final response = await _authService.supabase
          .from('post_collaborations')
          .select('''
            posts:post_id(
              *,
              avatars:avatar_id(id, name, avatar_image_url)
            )
          ''')
          .eq('collaborator_avatar_id', avatarId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return response
          .map<Map<String, dynamic>>((item) => item['posts'] as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('Error loading collaboration posts: $e');
      return [];
    }
  }

  /// Add collaboration to a post
  Future<void> addCollaboration(String postId, String collaboratorAvatarId, String collaborationType) async {
    try {
      await _authService.supabase.from('post_collaborations').insert({
        'post_id': postId,
        'collaborator_avatar_id': collaboratorAvatarId,
        'collaboration_type': collaborationType,
      });
    } catch (e) {
      throw Exception('Error adding collaboration: $e');
    }
  }

  /// Remove collaboration from a post
  Future<void> removeCollaboration(String postId, String collaboratorAvatarId) async {
    try {
      await _authService.supabase
          .from('post_collaborations')
          .delete()
          .eq('post_id', postId)
          .eq('collaborator_avatar_id', collaboratorAvatarId);
    } catch (e) {
      throw Exception('Error removing collaboration: $e');
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// Check if username already exists (excluding current user)
  Future<bool> _checkUsernameExists(String username, String currentUserId) async {
    try {
      final response = await _authService.supabase
          .from('users')
          .select('id')
          .eq('username', username.trim())
          .neq('id', currentUserId)
          .limit(1);
      
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking username existence: $e');
      return false;
    }
  }

  /// Check if email already exists (excluding current user)
  Future<bool> _checkEmailExists(String email, String currentUserId) async {
    try {
      final response = await _authService.supabase
          .from('users')
          .select('id')
          .eq('email', email.trim().toLowerCase())
          .neq('id', currentUserId)
          .limit(1);
      
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking email existence: $e');
      return false;
    }
  }

  /// Validate name (only letters, spaces, hyphens, apostrophes)
  bool _isValidName(String name) {
    return RegExp(r"^[a-zA-Z\s\-\']+$").hasMatch(name);
  }

  /// Validate username (alphanumeric, underscore, dot, hyphen)
  bool _isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_.\-]+$').hasMatch(username) && 
           username.length >= 3 && 
           username.length <= 30;
  }

  /// Change user password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Validate password strength
      if (newPassword.length < 8) {
        throw Exception('Password must be at least 8 characters long');
      }
      
      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(newPassword)) {
        throw Exception('Password must contain at least one uppercase letter, one lowercase letter, and one number');
      }

      await _authService.supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('Error changing password: $e');
    }
  }

  /// Export user data
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    try {
      // Get user data
      final userResponse = await _authService.supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .single();

      // Get user's avatars
      final avatarsResponse = await _authService.supabase
          .from('avatars')
          .select('*')
          .eq('owner_user_id', userId);

      // Get user's posts
      final postsResponse = await _authService.supabase
          .from('posts')
          .select('*')
          .eq('avatar_id', 'IN.(${(avatarsResponse as List).map((a) => a['id']).join(',')})');

      // Get user's follows
      final followsResponse = await _authService.supabase
          .from('follows')
          .select('*')
          .eq('user_id', userId);

      // Get user's comments
      final commentsResponse = await _authService.supabase
          .from('comments')
          .select('*')
          .eq('user_id', userId);

      return {
        'user': userResponse,
        'avatars': avatarsResponse,
        'posts': postsResponse,
        'follows': followsResponse,
        'comments': commentsResponse,
        'exported_at': DateTime.now().toIso8601String(),
        'export_version': '1.0',
      };
    } catch (e) {
      throw Exception('Error exporting data: $e');
    }
  }

  /// Get user preferences safely
  Future<Map<String, dynamic>> getUserPreferences(String userId) async {
    try {
      final response = await _authService.supabase
          .from('users')
          .select('preferences')
          .eq('id', userId)
          .single();
      
      return response['preferences'] ?? {
        'notifications_enabled': true,
        'push_notifications': true,
        'email_notifications': false,
        'auto_play_videos': true,
        'data_saver': false,
        'privacy_level': 'public',
      };
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      return {
        'notifications_enabled': true,
        'push_notifications': true,
        'email_notifications': false,
        'auto_play_videos': true,
        'data_saver': false,
        'privacy_level': 'public',
      };
    }
  }

  /// Validate preference values
  Map<String, dynamic> _validatePreferences(Map<String, dynamic> preferences) {
    final validatedPrefs = <String, dynamic>{};
    
    // Boolean preferences
    final boolKeys = [
      'notifications_enabled',
      'push_notifications', 
      'email_notifications',
      'auto_play_videos',
      'data_saver',
    ];
    
    for (final key in boolKeys) {
      if (preferences.containsKey(key)) {
        validatedPrefs[key] = preferences[key] is bool ? preferences[key] : false;
      }
    }
    
    // Privacy level validation
    if (preferences.containsKey('privacy_level')) {
      final privacyLevel = preferences['privacy_level'] as String?;
      if (['public', 'friends', 'private'].contains(privacyLevel)) {
        validatedPrefs['privacy_level'] = privacyLevel;
      } else {
        validatedPrefs['privacy_level'] = 'public';
      }
    }
    
    return validatedPrefs;
  }

  /// Get real-time profile metrics from database
  Future<Map<String, dynamic>> getRealProfileMetrics(String userId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      endDate ??= DateTime.now();
      startDate ??= endDate.subtract(const Duration(days: 30));
      
      // Get profile views from analytics events
      final profileViews = await _authService.supabase
          .from('analytics_events')
          .select('id')
          .eq('user_id', userId)
          .eq('event_type', 'profile_view')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());
      
      // Get user's avatar IDs for post metrics
      final userAvatars = await _authService.supabase
          .from('avatars')
          .select('id')
          .eq('owner_user_id', userId);
      
      final avatarIds = (userAvatars as List).map((a) => a['id']).toList();
      
      // Get post engagement metrics
      Map<String, int> postMetrics = {'total_likes': 0, 'total_comments': 0, 'total_shares': 0, 'total_views': 0};
      
      if (avatarIds.isNotEmpty) {
        // Get posts for user's avatars
        final posts = await _authService.supabase
            .from('posts')
            .select('likes_count, comments_count, shares_count, views_count')
            .filter('avatar_id', 'in', '(${avatarIds.join(',')})')
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String());
        
        for (final post in posts as List) {
          postMetrics['total_likes'] = postMetrics['total_likes']! + ((post['likes_count'] ?? 0) as int);
          postMetrics['total_comments'] = postMetrics['total_comments']! + ((post['comments_count'] ?? 0) as int);
          postMetrics['total_shares'] = postMetrics['total_shares']! + ((post['shares_count'] ?? 0) as int);
          postMetrics['total_views'] = postMetrics['total_views']! + ((post['views_count'] ?? 0) as int);
        }
      }
      
      // Calculate engagement rate
      final totalEngagement = postMetrics['total_likes']! + postMetrics['total_comments']! + postMetrics['total_shares']!;
      final totalViews = postMetrics['total_views']!;
      final engagementRate = totalViews > 0 ? (totalEngagement / totalViews * 100) : 0.0;
      
      return {
        'profile_views': (profileViews as List).length,
        'engagement_rate': double.parse(engagementRate.toStringAsFixed(2)),
        'total_likes': postMetrics['total_likes'],
        'total_comments': postMetrics['total_comments'],
        'total_shares': postMetrics['total_shares'],
        'total_views': postMetrics['total_views'],
        'total_engagement': totalEngagement,
        'period_start': startDate.toIso8601String(),
        'period_end': endDate.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting real profile metrics: $e');
      // Return fallback metrics
      return {
        'profile_views': 0,
        'engagement_rate': 0.0,
        'total_likes': 0,
        'total_comments': 0,
        'total_shares': 0,
        'total_views': 0,
        'total_engagement': 0,
      };
    }
  }
  
  /// Export analytics data
  Future<Map<String, dynamic>> exportAnalyticsData(String userId, {
    int daysBack = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: daysBack));
      
      // Get analytics events
      final eventsResponse = await _authService.supabase
          .from('analytics_events')
          .select('*')
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .order('created_at', ascending: false);
      
      // Get user's avatars for context
      final avatarsResponse = await _authService.supabase
          .from('avatars')
          .select('id, name, followers_count, likes_count, posts_count, engagement_rate')
          .eq('owner_user_id', userId);
      
      // Get user's posts with engagement data
      final avatarIds = (avatarsResponse as List).map((a) => a['id']).join(',');
      final postsResponse = avatarIds.isNotEmpty ? await _authService.supabase
          .from('posts')
          .select('id, created_at, likes_count, comments_count, views_count, avatar_id')
          .filter('avatar_id', 'in', '($avatarIds)')
          .gte('created_at', startDate.toIso8601String())
          .order('created_at', ascending: false)
          : [];
      
      // Get engagement metrics
      final engagementMetrics = await _calculateEngagementMetrics(
        userId, 
        eventsResponse as List, 
        postsResponse as List,
      );
      
      return {
        'user_id': userId,
        'export_period': {
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'days': daysBack,
        },
        'summary': {
          'total_events': (eventsResponse as List).length,
          'total_posts': (postsResponse as List).length,
          'active_avatars': (avatarsResponse as List).length,
        },
        'avatars': avatarsResponse,
        'events': eventsResponse,
        'posts': postsResponse,
        'engagement_metrics': engagementMetrics,
        'exported_at': DateTime.now().toIso8601String(),
        'export_version': '1.0',
      };
    } catch (e) {
      throw Exception('Error exporting analytics data: $e');
    }
  }

  /// Calculate engagement metrics from raw data
  Future<Map<String, dynamic>> _calculateEngagementMetrics(
    String userId,
    List<dynamic> events,
    List<dynamic> posts,
  ) async {
    if (events.isEmpty && posts.isEmpty) {
      return {
        'total_views': 0,
        'total_likes': 0,
        'total_comments': 0,
        'total_shares': 0,
        'engagement_rate': 0.0,
        'avg_engagement_per_post': 0.0,
        'most_active_day': null,
        'top_performing_post': null,
      };
    }

    // Calculate totals from posts
    int totalLikes = 0;
    int totalComments = 0;
    int totalViews = 0;
    dynamic topPost;
    int maxEngagement = 0;
    
    final Map<String, int> dailyActivity = {};
    
    for (final post in posts) {
      final likes = post['likes_count'] ?? 0;
      final comments = post['comments_count'] ?? 0;
      final views = post['views_count'] ?? 0;
      final engagement = likes + comments;
      
      totalLikes += likes as int;
      totalComments += comments as int;
      totalViews += views as int;
      
      if (engagement > maxEngagement) {
        maxEngagement = engagement;
        topPost = post;
      }
      
      // Track daily activity
      final createdDate = DateTime.parse(post['created_at']).toLocal();
      final dateKey = '${createdDate.year}-${createdDate.month.toString().padLeft(2, '0')}-${createdDate.day.toString().padLeft(2, '0')}';
      dailyActivity[dateKey] = (dailyActivity[dateKey] ?? 0) + 1;
    }
    
    // Count shares and other events from analytics events
    int totalShares = 0;
    for (final event in events) {
      if (event['event_type'] == 'post_share') {
        totalShares++;
      }
      
      // Track daily activity from events too
      final eventDate = DateTime.parse(event['created_at']).toLocal();
      final dateKey = '${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}';
      dailyActivity[dateKey] = (dailyActivity[dateKey] ?? 0) + 1;
    }
    
    // Find most active day
    String? mostActiveDay;
    int maxActivity = 0;
    for (final entry in dailyActivity.entries) {
      if (entry.value > maxActivity) {
        maxActivity = entry.value;
        mostActiveDay = entry.key;
      }
    }
    
    // Calculate engagement rate
    final totalEngagement = totalLikes + totalComments + totalShares;
    final engagementRate = totalViews > 0 ? (totalEngagement / totalViews * 100) : 0.0;
    final avgEngagementPerPost = posts.isNotEmpty ? (totalEngagement / posts.length) : 0.0;
    
    return {
      'total_views': totalViews,
      'total_likes': totalLikes,
      'total_comments': totalComments,
      'total_shares': totalShares,
      'total_engagement': totalEngagement,
      'engagement_rate': double.parse(engagementRate.toStringAsFixed(2)),
      'avg_engagement_per_post': double.parse(avgEngagementPerPost.toStringAsFixed(2)),
      'most_active_day': mostActiveDay,
      'most_active_day_count': maxActivity,
      'top_performing_post': topPost,
      'daily_activity': dailyActivity,
      'posts_count': posts.length,
      'events_count': events.length,
    };
  }

  /// Convert analytics data to CSV format
  String convertAnalyticsToCSV(Map<String, dynamic> analyticsData) {
    final buffer = StringBuffer();
    
    // Add summary information
    buffer.writeln('QUANTA ANALYTICS EXPORT');
    buffer.writeln('User ID,${analyticsData['user_id']}');
    buffer.writeln('Export Date,${DateTime.parse(analyticsData['exported_at']).toLocal()}');
    buffer.writeln('Period,${analyticsData['export_period']['start_date']} to ${analyticsData['export_period']['end_date']}');
    buffer.writeln('Days,${analyticsData['export_period']['days']}');
    buffer.writeln('');
    
    // Engagement metrics summary
    buffer.writeln('ENGAGEMENT METRICS SUMMARY');
    final metrics = analyticsData['engagement_metrics'] as Map<String, dynamic>;
    buffer.writeln('Metric,Value');
    metrics.forEach((key, value) {
      if (value is! Map && value is! List) {
        buffer.writeln('$key,$value');
      }
    });
    buffer.writeln('');
    
    // Avatars data
    buffer.writeln('AVATARS');
    final avatars = analyticsData['avatars'] as List;
    if (avatars.isNotEmpty) {
      final firstAvatar = avatars.first as Map<String, dynamic>;
      buffer.writeln(firstAvatar.keys.join(','));
      
      for (final avatar in avatars) {
        final avatarMap = avatar as Map<String, dynamic>;
        buffer.writeln(avatarMap.values.join(','));
      }
    }
    buffer.writeln('');
    
    // Posts data
    buffer.writeln('POSTS');
    final posts = analyticsData['posts'] as List;
    if (posts.isNotEmpty) {
      final firstPost = posts.first as Map<String, dynamic>;
      buffer.writeln(firstPost.keys.join(','));
      
      for (final post in posts) {
        final postMap = post as Map<String, dynamic>;
        buffer.writeln(postMap.values.join(','));
      }
    }
    buffer.writeln('');
    
    // Events data (last 100 for CSV readability)
    buffer.writeln('RECENT EVENTS (Last 100)');
    final events = analyticsData['events'] as List;
    if (events.isNotEmpty) {
      buffer.writeln('Event Type,Timestamp,Properties');
      
      final recentEvents = events.take(100);
      for (final event in recentEvents) {
        final eventMap = event as Map<String, dynamic>;
        final eventType = eventMap['event_type'] ?? 'unknown';
        final timestamp = eventMap['created_at'] ?? '';
        final properties = eventMap['properties']?.toString()?.replaceAll(',', ';') ?? '';
        buffer.writeln('$eventType,$timestamp,"$properties"');
      }
    }
    
    return buffer.toString();
  }
}
