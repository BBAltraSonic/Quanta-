import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quanta/constants.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';
import '../models/analytics_insight_model.dart';
// Using ProfileViewMode from AppState instead of separate model
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../services/follow_service.dart';
import '../services/enhanced_feeds_service.dart';
import '../services/analytics_insights_service.dart';
import '../services/user_role_service.dart';
import '../services/avatar_profile_service.dart';
import '../screens/settings_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/avatar_management_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/create_post_screen.dart';
import '../widgets/skeleton_widgets.dart';
import '../widgets/avatar_switcher.dart';
import '../store/app_state.dart';

class ProfileScreen extends StatefulWidget {
  final String?
  avatarId; // Avatar ID to display, null means current user's active avatar
  const ProfileScreen({super.key, this.avatarId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  final FollowService _followService = FollowService();
  final AnalyticsInsightsService _analyticsService = AnalyticsInsightsService();
  final AvatarProfileService _avatarProfileService = AvatarProfileService();
  final AppState _appState = AppState();

  // Avatar-centric state
  AvatarModel? _currentAvatar;
  AvatarProfileData? _avatarProfileData;
  ProfileViewMode _viewMode = ProfileViewMode.guest;
  List<AvatarModel> _userAvatars = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  // Posts content state
  List<PostModel> _avatarPosts = [];
  bool _isPostsLoading = false;
  bool _hasMorePosts = true;
  int _postsPage = 1;
  final int _postsPerPage = 20;
  Map<String, dynamic>? _comparisons;

  // Pinned post and collaborations state
  PostModel? _pinnedPost;
  List<PostModel> _collaborationPosts = [];
  bool _isPinnedPostLoading = false;
  bool _isCollaborationsLoading = false;

  // Analytics state
  List<AnalyticsInsight> _insights = [];
  List<AnalyticsMetric> _detailedMetrics = [];
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.month;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  /// Load avatar posts from database
  Future<void> _loadAvatarPosts({bool loadMore = false}) async {
    if (_isPostsLoading ||
        (_avatarPosts.isNotEmpty && !loadMore && !_hasMorePosts)) {
      return;
    }

    if (_currentAvatar == null) return;

    setState(() {
      _isPostsLoading = true;
    });

    try {
      // Use EnhancedFeedsService to get avatar-specific posts
      final feedsService = EnhancedFeedsService();
      final posts = await feedsService.getAvatarPosts(
        avatarId: _currentAvatar!.id,
        page: loadMore ? _postsPage + 1 : 1,
        limit: _postsPerPage,
      );

      setState(() {
        if (loadMore) {
          _avatarPosts.addAll(posts);
          _postsPage++;
        } else {
          _avatarPosts = posts;
          _postsPage = 1;
        }
        _hasMorePosts = posts.length == _postsPerPage;
        _isPostsLoading = false;
      });
    } catch (e) {
      setState(() {
        _isPostsLoading = false;
      });
      debugPrint('Error loading avatar posts: $e');
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final currentUserId = _authService.currentUserId;

      // Determine which avatar to load
      String? targetAvatarId = widget.avatarId;

      // If no avatar ID provided, use current user's active avatar
      if (targetAvatarId == null) {
        if (currentUserId != null) {
          final activeAvatar = await _avatarProfileService.getActiveAvatar(
            currentUserId,
          );
          targetAvatarId = activeAvatar?.id;
        }

        // If still no avatar, show empty state
        if (targetAvatarId == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Load avatar profile data
      final avatarProfileData = await _avatarProfileService.getAvatarProfile(
        targetAvatarId,
        isOwnerView: currentUserId != null,
      );

      // Determine view mode
      final viewMode = _avatarProfileService.determineViewMode(
        targetAvatarId,
        currentUserId,
      );

      // Check follow status for public view
      if (viewMode == ProfileViewMode.public) {
        await _checkAvatarFollowStatus(targetAvatarId);
      }

      // Load user avatars for owner view
      List<AvatarModel> userAvatars = [];
      if (viewMode == ProfileViewMode.owner && currentUserId != null) {
        userAvatars = await _avatarProfileService.getUserAvatars(currentUserId);
      }

      if (mounted) {
        setState(() {
          _currentAvatar = avatarProfileData.avatar;
          _avatarProfileData = avatarProfileData;
          _viewMode = viewMode;
          _userAvatars = userAvatars;
          _isLoading = false;
        });
      }

      // Load avatar posts
      await _loadAvatarPosts();

      // Load pinned post and collaborations
      await _loadPinnedPost();
      await _loadCollaborations();

      // Load analytics data for owner view
      if (viewMode == ProfileViewMode.owner) {
        await _loadAnalyticsData();
      }
    } catch (e) {
      debugPrint('Error loading avatar profile data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Check follow status for avatar-centric profiles
  Future<void> _checkAvatarFollowStatus(String avatarId) async {
    try {
      setState(() {
        _isFollowLoading = true;
      });

      // Check if current user is following this avatar
      final isFollowing = await _followService.isFollowing(avatarId);

      setState(() {
        _isFollowing = isFollowing;
        _isFollowLoading = false;
      });
    } catch (e) {
      setState(() {
        _isFollowLoading = false;
      });
      debugPrint('Error checking avatar follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentAvatar == null) return;

    try {
      setState(() {
        _isFollowLoading = true;
      });

      // Toggle follow status for the current avatar
      final newFollowStatus = await _followService.toggleFollow(
        _currentAvatar!.id,
      );

      setState(() {
        _isFollowing = newFollowStatus;
      });

      // Refresh follower count
      await _refreshAvatarFollowerCount();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFollowing
                ? 'Now following ${_currentAvatar!.name}!'
                : 'Unfollowed ${_currentAvatar!.name}',
          ),
          backgroundColor: kPrimaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isFollowLoading = false;
      });
    }
  }

  /// Refresh avatar follower count
  Future<void> _refreshAvatarFollowerCount() async {
    if (_currentAvatar == null) return;

    try {
      final updatedStats = await _avatarProfileService.getAvatarStats(
        _currentAvatar!.id,
      );

      // Update app state
      _appState.updateAvatarFollowerCount(
        _currentAvatar!.id,
        updatedStats.followersCount,
      );

      // Update avatar profile data
      if (_avatarProfileData != null) {
        setState(() {
          _avatarProfileData = AvatarProfileData(
            avatar: _avatarProfileData!.avatar,
            stats: updatedStats,
            recentPosts: _avatarProfileData!.recentPosts,
            viewMode: _avatarProfileData!.viewMode,
            availableActions: _avatarProfileData!.availableActions,
            engagementMetrics: _avatarProfileData!.engagementMetrics,
            otherAvatars: _avatarProfileData!.otherAvatars,
          );
        });
      }
    } catch (e) {
      debugPrint('Error refreshing avatar follower count: $e');
    }
  }

  /// Handle avatar switching
  Future<void> _onAvatarSelected(AvatarModel selectedAvatar) async {
    if (_currentAvatar?.id == selectedAvatar.id) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Set as active avatar
      final currentUserId = _authService.currentUserId;
      if (currentUserId != null) {
        await _avatarProfileService.setActiveAvatar(
          currentUserId,
          selectedAvatar.id,
        );
      }

      // Reload profile data for the new avatar
      await _loadProfileData();
    } catch (e) {
      debugPrint('Error switching avatar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error switching avatar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToEditProfile() async {
    if (_currentAvatar == null) return;
    
    // Navigate to avatar edit screen
    // For now, we'll navigate to the avatar management screen since we don't have
    // a specific avatar edit screen yet. In a full implementation, this would
    // navigate to an avatar-specific edit screen.
    _navigateToAvatarManagement();
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _navigateToAvatarManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AvatarManagementScreen()),
    );
  }

  void _navigateToCreatePost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );
  }

  void _navigateToChat() {
    if (_currentAvatar == null && _userAvatars.isEmpty) {
      // Show tooltip or guide to create avatar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create an avatar first to start chatting!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final chatAvatar = _currentAvatar ?? _userAvatars.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          name: chatAvatar.name,
          avatar: chatAvatar.avatarImageUrl ?? 'assets/images/p.jpg',
          avatarId: chatAvatar.id,
        ),
      ),
    );
  }

  void _shareProfile() {
    // Simple share profile functionality - shows profile URL
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Profile shared! Link: quanta.app/profile/${_currentAvatar?.name ?? 'avatar'}',
        ),
        backgroundColor: kPrimaryColor,
        action: SnackBarAction(
          label: 'COPY',
          textColor: Colors.white,
          onPressed: () {
            // In a real app, this would copy to clipboard
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile link copied to clipboard!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// Load analytics data for the avatar's profile
  Future<void> _loadAnalyticsData() async {
    if (_currentAvatar == null) return;

    try {
      // Use avatar-specific analytics
      final analyticsData = await _analyticsService.getAvatarAnalytics(
        avatarId: _currentAvatar!.id,
        period: _selectedPeriod,
      );

      // Extract metrics from the avatar analytics data
      final metricsData = analyticsData['metrics'] as Map<String, dynamic>;
      
      // Convert metrics data to AnalyticsMetric objects
      final metrics = <AnalyticsMetric>[];
      metricsData.forEach((key, value) {
        metrics.add(AnalyticsMetric(
          key: key,
          label: _getMetricLabel(key),
          value: value is num ? value.toDouble() : 0.0,
          type: _getMetricType(key),
        ));
      });

      setState(() {
        _detailedMetrics = metrics;
        // For now, we'll keep insights and comparisons as empty since the avatar analytics
        // doesn't provide them in the same format as the user analytics
        _insights = [];
        _comparisons = null;
      });
    } catch (e) {
      debugPrint('Error loading avatar analytics data: $e');
      // Set empty analytics data on error
      setState(() {
        _detailedMetrics = [];
        _insights = [];
        _comparisons = null;
      });
    }
  }

  /// Get human-readable label for a metric key
  String _getMetricLabel(String key) {
    switch (key) {
      case 'total_posts':
        return 'Total Posts';
      case 'total_likes':
        return 'Total Likes';
      case 'total_comments':
        return 'Total Comments';
      case 'total_shares':
        return 'Total Shares';
      case 'engagement_rate':
        return 'Engagement Rate';
      case 'reach':
        return 'Reach';
      case 'impressions':
        return 'Impressions';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  /// Get metric type for a metric key
  MetricType _getMetricType(String key) {
    switch (key) {
      case 'engagement_rate':
        return MetricType.percentage;
      default:
        return MetricType.count;
    }
  }

  /// Handle period change in analytics
  void _onPeriodChanged(AnalyticsPeriod period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
      });

      // Reload analytics data for the new period
      if (_viewMode == ProfileViewMode.owner && _currentAvatar != null) {
        _loadAnalyticsData();
      }
    }
  }

  /// Format metric value based on its type
  String _formatMetricValue(AnalyticsMetric metric) {
    switch (metric.type) {
      case MetricType.percentage:
        return '${metric.value.toStringAsFixed(1)}${metric.unit}';
      case MetricType.count:
        return _formatNumber((metric.value as num).toInt());
      case MetricType.currency:
        return '\$${metric.value.toStringAsFixed(2)}';
      case MetricType.duration:
        final seconds = (metric.value as num).toInt();
        if (seconds >= 60) {
          final minutes = seconds ~/ 60;
          final remainingSeconds = seconds % 60;
          return '${minutes}m ${remainingSeconds}s';
        }
        return '${seconds}s';
      case MetricType.rate:
        return '${metric.value.toStringAsFixed(2)}/min';
      default:
        return metric.value.toString();
    }
  }

  /// Handle insight action button press
  void _handleInsightAction(AnalyticsInsight insight) {
    final actionType = insight.actionData?['type'] as String?;

    switch (actionType) {
      case 'engagement_tips':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Engagement tips: Post consistently, use trending hashtags, engage with your audience!',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
        break;
      case 'growth_strategy':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Growth tips: Collaborate with others, post at peak times, create shareable content!',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        break;
      case 'reach_optimization':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reach tips: Use relevant hashtags, post when your audience is active, create engaging content!',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        break;
      case 'post_scheduling':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Schedule your posts for 6-8 PM on weekdays for maximum engagement!',
            ),
            backgroundColor: Colors.purple,
            duration: Duration(seconds: 4),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Learn more about: ${insight.title}'),
            backgroundColor: kPrimaryColor,
          ),
        );
        break;
    }
  }

  /// Load pinned post for the current avatar
  Future<void> _loadPinnedPost() async {
    if (_currentAvatar == null) return;

    setState(() {
      _isPinnedPostLoading = true;
    });

    try {
      final pinnedPostData = await _profileService.getPinnedPost(
        _currentAvatar!.id,
      );

      if (pinnedPostData != null) {
        setState(() {
          _pinnedPost = PostModel.fromJson(pinnedPostData);
        });
      }
    } catch (e) {
      debugPrint('Error loading pinned post: $e');
    } finally {
      setState(() {
        _isPinnedPostLoading = false;
      });
    }
  }

  /// Load collaboration posts for the current avatar
  Future<void> _loadCollaborations() async {
    if (_currentAvatar == null) return;

    setState(() {
      _isCollaborationsLoading = true;
    });

    try {
      final collaborationData = await _profileService.getCollaborationPosts(
        _currentAvatar!.id,
      );

      setState(() {
        _collaborationPosts = collaborationData
            .map((data) => PostModel.fromJson(data))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading collaborations: $e');
    } finally {
      setState(() {
        _isCollaborationsLoading = false;
      });
    }
  }

  Widget _buildSkeletonLoading() {
    return Stack(
      children: [
        // Background with shimmer
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.grey[800]),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.black.withOpacity(0.88),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 240, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: _HeaderCard(child: SkeletonProfileHeader()),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: _HeaderCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonWidget(width: 100, height: 18),
                            SkeletonWidget(width: 60, height: 16),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 3,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) => Container(
                              width: 90,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SkeletonWidget(
                                    width: 48,
                                    height: 48,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  const SizedBox(height: 8),
                                  SkeletonWidget(width: 60, height: 12),
                                  const SizedBox(height: 4),
                                  SkeletonWidget(width: 40, height: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppShell provides global bottom nav
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: null,
        centerTitle: false,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            onPressed: _navigateToSettings,
            icon: SvgPicture.asset(
              'assets/icons/settings-minimalistic-svgrepo-com.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            tooltip: 'Settings',
          ),
        ),
        actions: [
          if (_viewMode == ProfileViewMode.owner) ...[
            // DEBUG: Test crash button (remove before production)
            if (const bool.fromEnvironment('DEBUG_MODE', defaultValue: false))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () {
                    // Test Sentry crash reporting
                    throw Exception('Test crash from profile screen');
                  },
                  icon: const Icon(Icons.bug_report, color: Colors.red),
                  tooltip: 'Test Crash (DEBUG)',
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _navigateToCreatePost,
                icon: SvgPicture.asset(
                  'assets/icons/add-square-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                tooltip: 'Create post',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: _navigateToEditProfile,
                icon: SvgPicture.asset(
                  'assets/icons/pen-new-square-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                tooltip: 'Edit profile',
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: _navigateToEditProfile,
                icon: SvgPicture.asset(
                  'assets/icons/pen-new-square-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                tooltip: 'Edit profile',
              ),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? _buildSkeletonLoading()
          : Stack(
              children: [
                // Fullscreen profile photo background with dark + red overlays
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _currentAvatar?.avatarImageUrl != null
                          ? _currentAvatar!.avatarImageUrl!.startsWith(
                                  'assets/',
                                )
                                ? Image.asset(
                                    _currentAvatar!.avatarImageUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    _currentAvatar!.avatarImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Image(
                                        image: AssetImage(
                                          'assets/images/We.jpg',
                                        ),
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  )
                          : const Image(
                              image: AssetImage('assets/images/We.jpg'),
                              fit: BoxFit.cover,
                            ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.65),
                              Colors.black.withOpacity(0.88),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              kPrimaryColor.withOpacity(0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 240, 20, 14),
                        sliver: SliverToBoxAdapter(
                          child: _HeaderCard(child: _headerBlock()),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        sliver: SliverToBoxAdapter(
                          child: _buildAvatarsSection(),
                        ),
                      ),
                      // Pinned Post Section
                      if (_pinnedPost != null || _isPinnedPostLoading)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                          sliver: SliverToBoxAdapter(
                            child: _buildPinnedPostSection(),
                          ),
                        ),
                      // Collaborations Section
                      if (_collaborationPosts.isNotEmpty ||
                          _isCollaborationsLoading)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                          sliver: SliverToBoxAdapter(
                            child: _buildCollaborationsSection(),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        sliver: SliverToBoxAdapter(child: _avatarPostsMasonry()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Header (avatar name + bio + metrics + avatar switcher)
  Widget _headerBlock() {
    // Use avatar data only (no more user fallback)
    final avatarName = _currentAvatar?.name ?? 'Avatar';
    final avatarBio = _currentAvatar?.bio ?? 'Virtual influencer creator';
    final avatarImageUrl = _currentAvatar?.avatarImageUrl;

    // Get stats from avatar profile data
    final stats = _avatarProfileData?.stats;
    final postsCount = stats?.postsCount ?? 0;
    final followersCount = stats?.followersCount ?? 0;
    final followingCount = stats?.followingCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: avatarImageUrl != null
                  ? avatarImageUrl.startsWith('assets/')
                        ? AssetImage(avatarImageUrl) as ImageProvider
                        : NetworkImage(avatarImageUrl)
                  : const AssetImage('assets/images/p.jpg'),
            ),
            const SizedBox(width: 12),
            // Avatar name with inline verification badge
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      avatarName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: kPrimaryColor, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          avatarBio,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13.5,
            height: 1.35,
          ),
        ),

        // Avatar switcher for owner view
        if (_viewMode == ProfileViewMode.owner && _userAvatars.length > 1) ...[
          const SizedBox(height: 12),
          AvatarSwitcher(
            avatars: _userAvatars,
            activeAvatar: _currentAvatar,
            onAvatarSelected: _onAvatarSelected,
            style: AvatarSwitcherStyle.dropdown,
            showAvatarNames: true,
            showAvatarStats: true,
          ),
        ],

        const SizedBox(height: 14),
        // Stats row (Posts • Followers • Following) - Avatar-specific
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatColumn(value: _formatNumber(postsCount), label: 'Posts'),
            _StatColumn(
              value: _formatNumber(followersCount),
              label: 'Followers',
            ),
            _StatColumn(
              value: _formatNumber(followingCount),
              label: 'Following',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Primary actions based on view mode
        Row(
          children: [
            if (_viewMode == ProfileViewMode.owner) ...[
              // Owner view: Show Share and Chat buttons
              Expanded(
                child: ElevatedButton(
                  onPressed: _shareProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Share Profile',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _navigateToChat,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24, width: 1.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Chat with me',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else if (_viewMode == ProfileViewMode.public) ...[
              // Public view: Show Follow and Message buttons (avatar-specific)
              Expanded(
                child: ElevatedButton(
                  onPressed: _isFollowLoading ? null : _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFollowing
                        ? Colors.grey[700]
                        : kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isFollowLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _navigateToChat,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24, width: 1.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Message',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else ...[
              // Guest view: Show only Share button
              Expanded(
                child: ElevatedButton(
                  onPressed: _shareProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Share Profile',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // Enhanced Analytics section - Phase 3
  Widget _buildAnalyticsSection() {
    // Only show enhanced analytics for own profile
    if (_viewMode != ProfileViewMode.owner) {
      return _buildBasicAnalyticsSection();
    }

    return Column(
      children: [
        // Analytics Header with Period Selector
        _HeaderCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      '📊 Analytics Insights',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: _buildPeriodSelector()),
                ],
              ),
              const SizedBox(height: 16),
              _buildEnhancedMetricsGrid(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Insights Section
        if (_insights.isNotEmpty)
          _HeaderCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Key Insights',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._insights
                    .take(3)
                    .map((insight) => _buildInsightCard(insight)),
              ],
            ),
          ),
        if (_insights.isNotEmpty) const SizedBox(height: 14),
        // Benchmarks and Comparisons
        if (_comparisons != null) _HeaderCard(child: _buildBenchmarksSection()),
      ],
    );
  }

  Widget _buildBasicAnalyticsSection() {
    // Get stats from avatar profile data
    final stats = _avatarProfileData?.stats;
    final postsCount = stats?.postsCount ?? 0;
    final followersCount = stats?.followersCount ?? 0;

    return _HeaderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics Overview',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Posts',
                  value: _formatNumber(postsCount),
                  subtitle: 'Total content',
                  icon: Icons.grid_view,
                  color: Colors.blue,
                  isPositive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Followers',
                  value: _formatNumber(followersCount),
                  subtitle: 'Total followers',
                  icon: Icons.people,
                  color: Colors.green,
                  isPositive: true,
                ),
              ),
            ],
          ),
          if (_userAvatars.length > 1) ...[
            const SizedBox(height: 16),
            const Text(
              'Top Performing Avatar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            _buildTopAvatarCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: AnalyticsPeriod.values.take(4).map((period) {
          final isSelected = period == _selectedPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(period),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  period.shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEnhancedMetricsGrid() {
    if (_detailedMetrics.isEmpty) {
      return _buildBasicMetricsGrid();
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDetailedMetricCard(
                _detailedMetrics.firstWhere(
                  (m) => m.key == 'engagement_rate',
                  orElse: () => AnalyticsMetric(
                    key: 'engagement_rate',
                    label: 'Engagement',
                    value: 0.0,
                    type: MetricType.percentage,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailedMetricCard(
                _detailedMetrics.firstWhere(
                  (m) => m.key == 'reach',
                  orElse: () => AnalyticsMetric(
                    key: 'reach',
                    label: 'Reach',
                    value: 0,
                    type: MetricType.count,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDetailedMetricCard(
                _detailedMetrics.firstWhere(
                  (m) => m.key == 'profile_views',
                  orElse: () => AnalyticsMetric(
                    key: 'profile_views',
                    label: 'Profile Views',
                    value: 0,
                    type: MetricType.count,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailedMetricCard(
                _detailedMetrics.firstWhere(
                  (m) => m.key == 'follower_growth',
                  orElse: () => AnalyticsMetric(
                    key: 'follower_growth',
                    label: 'New Followers',
                    value: 0,
                    type: MetricType.count,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBasicMetricsGrid() {
    // Get stats from avatar profile data
    final stats = _avatarProfileData?.stats;
    final postsCount = stats?.postsCount ?? 0;
    final followersCount = stats?.followersCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildAnalyticsCard(
            title: 'Posts',
            value: _formatNumber(postsCount),
            subtitle: 'Total content',
            icon: Icons.grid_view,
            color: Colors.blue,
            isPositive: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCard(
            title: 'Followers',
            value: _formatNumber(followersCount),
            subtitle: 'Total followers',
            icon: Icons.people,
            color: Colors.green,
            isPositive: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMetricCard(AnalyticsMetric metric) {
    final hasChange = metric.changePercentage != null;
    final isPositive = metric.isPositiveChange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _formatMetricValue(metric),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasChange)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isPositive ? Colors.green : Colors.red).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        color: isPositive ? Colors.green : Colors.red,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        metric.changeText!,
                        style: TextStyle(
                          color: isPositive ? Colors.green : Colors.red,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(AnalyticsInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: insight.type.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: insight.type.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insight.type.icon, color: insight.type.color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (insight.priority == InsightPriority.high ||
                  insight.priority == InsightPriority.critical)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: insight.priority.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    insight.priority == InsightPriority.high
                        ? 'HIGH'
                        : 'URGENT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (insight.isActionable) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _handleInsightAction(insight),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  backgroundColor: insight.type.color.withOpacity(0.1),
                ),
                child: Text(
                  insight.actionLabel ?? 'Learn More',
                  style: TextStyle(
                    color: insight.type.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenchmarksSection() {
    final category = _comparisons!['category'] as String;
    final percentile = _comparisons!['user_percentile'] as int;
    final message = _comparisons!['benchmark_message'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Performance Benchmark',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        'Creator Category',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${percentile}th percentile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? Colors.green : Colors.red,
                size: 12,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: isPositive ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopAvatarCard() {
    final topAvatar =
        _userAvatars.first; // In real app, this would be sorted by performance

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: topAvatar.avatarImageUrl != null
                ? topAvatar.avatarImageUrl!.startsWith('assets/')
                      ? AssetImage(topAvatar.avatarImageUrl!) as ImageProvider
                      : NetworkImage(topAvatar.avatarImageUrl!)
                : null,
            child: topAvatar.avatarImageUrl == null
                ? const Icon(Icons.person, color: kLightTextColor, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topAvatar.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_formatNumber(topAvatar.followersCount)} followers • ${(topAvatar.engagementRate * 100).toStringAsFixed(1)}% engagement',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'TOP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build pinned post section
  Widget _buildPinnedPostSection() {
    if (_isPinnedPostLoading) {
      return _buildPinnedPostSkeleton();
    }

    if (_pinnedPost == null) {
      return const SizedBox.shrink();
    }

    return _HeaderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin, color: kPrimaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Pinned Post',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (_viewMode == ProfileViewMode.owner)
                IconButton(
                  onPressed: _unpinPost,
                  icon: Icon(Icons.more_vert, color: Colors.white70, size: 20),
                  tooltip: 'Post options',
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPinnedPostCard(_pinnedPost!),
        ],
      ),
    );
  }

  /// Build pinned post skeleton loading
  Widget _buildPinnedPostSkeleton() {
    return _HeaderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonWidget(
                width: 20,
                height: 20,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 8),
              SkeletonWidget(width: 100, height: 16),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SkeletonWidget(
                  width: 80,
                  height: 120,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonWidget(width: double.infinity, height: 14),
                      const SizedBox(height: 8),
                      SkeletonWidget(width: 120, height: 12),
                      const SizedBox(height: 8),
                      SkeletonWidget(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build pinned post card
  Widget _buildPinnedPostCard(PostModel post) {
    final isVideo = post.type == PostType.video;
    final imageUrl = post.thumbnailUrl ?? post.imageUrl;

    return GestureDetector(
      onTap: () {
        // Navigate to post detail
        Navigator.pushNamed(context, '/post_detail', arguments: post);
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            // Post image/thumbnail
            Container(
              width: 80,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                color: Colors.grey[800],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    imageUrl.startsWith('assets/')
                        ? Image.asset(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackImage(),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackImage(),
                          )
                  else
                    _buildFallbackImage(),
                  if (isVideo)
                    Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: kPrimaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Post details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.caption ?? 'No caption',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.favorite, color: Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(post.likesCount ?? 0),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.comment, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(post.commentsCount ?? 0),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      _formatPostDate(post.createdAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build collaborations section
  Widget _buildCollaborationsSection() {
    if (_isCollaborationsLoading) {
      return _buildCollaborationsSkeleton();
    }

    if (_collaborationPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    return _HeaderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Collaborations',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '${_collaborationPosts.length} posts',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _collaborationPosts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final post = _collaborationPosts[index];
                return _buildCollaborationPostCard(post);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build collaborations skeleton loading
  Widget _buildCollaborationsSkeleton() {
    return _HeaderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonWidget(
                width: 20,
                height: 20,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 8),
              SkeletonWidget(width: 120, height: 16),
              const Spacer(),
              SkeletonWidget(width: 60, height: 12),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => Container(
                width: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SkeletonWidget(
                      width: 110,
                      height: 80,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          SkeletonWidget(width: double.infinity, height: 12),
                          const SizedBox(height: 4),
                          SkeletonWidget(width: 60, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build collaboration post card
  Widget _buildCollaborationPostCard(PostModel post) {
    final isVideo = post.type == PostType.video;
    final imageUrl = post.thumbnailUrl ?? post.imageUrl;

    return GestureDetector(
      onTap: () {
        // Navigate to post detail
        Navigator.pushNamed(context, '/post_detail', arguments: post);
      },
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post image/thumbnail
            Container(
              width: 110,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: Colors.grey[800],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    imageUrl.startsWith('assets/')
                        ? Image.asset(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackImage(),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackImage(),
                          )
                  else
                    _buildFallbackImage(),
                  // Collaboration badge
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'COLLAB',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (isVideo)
                    Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: kPrimaryColor,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Post details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.caption ?? 'Collaboration post',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.favorite, color: Colors.red, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          _formatNumber(post.likesCount ?? 0),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format post date for display
  String _formatPostDate(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Build fallback image for posts
  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey[800],
      child: Center(child: Icon(Icons.image, color: Colors.white54, size: 32)),
    );
  }

  /// Unpin post from current avatar
  Future<void> _unpinPost() async {
    if (_currentAvatar == null) return;

    try {
      await _profileService.unpinPost(_currentAvatar!.id);
      setState(() {
        _pinnedPost = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post unpinned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unpinning post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Avatars section
  Widget _buildAvatarsSection() {
    // Only show avatars section for owner view or if there are multiple avatars to display
    if (_viewMode != ProfileViewMode.owner && _userAvatars.length <= 1) {
      return const SizedBox.shrink();
    }

    if (_userAvatars.isEmpty) {
      // Show empty state only when viewing your own profile (owner view)
      if (_viewMode == ProfileViewMode.owner) {
        return _buildEmptyAvatarsState();
      }
      return const SizedBox.shrink();
    }

    return _HeaderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _viewMode == ProfileViewMode.owner
                    ? 'My Avatars'
                    : '${_currentAvatar?.name ?? 'User'}\'s Avatars',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              TextButton(
                onPressed: _navigateToAvatarManagement,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _userAvatars.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final avatar = _userAvatars[index];
                final isActive = _currentAvatar?.id == avatar.id;
                return GestureDetector(
                  onTap: _viewMode == ProfileViewMode.owner
                      ? () => _onAvatarSelected(avatar)
                      : null,
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: isActive
                          ? Border.all(color: kPrimaryColor, width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: avatar.avatarImageUrl != null
                              ? avatar.avatarImageUrl!.startsWith('assets/')
                                    ? AssetImage(avatar.avatarImageUrl!)
                                          as ImageProvider
                                    : NetworkImage(avatar.avatarImageUrl!)
                              : null,
                          child: avatar.avatarImageUrl == null
                              ? const Icon(Icons.person, color: kLightTextColor)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          avatar.name,
                          style: TextStyle(
                            color: isActive ? kPrimaryColor : Colors.white,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatNumber(avatar.followersCount)} followers',
                          style: const TextStyle(
                            color: kLightTextColor,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Avatar posts grid - displays posts for the current avatar
  Widget _avatarPostsMasonry() {
    // Show loading state while posts are loading
    if (_isPostsLoading && _avatarPosts.isEmpty) {
      return _buildPostsLoadingGrid();
    }

    // Show empty state if no posts
    if (_avatarPosts.isEmpty) {
      return _buildEmptyPostsState();
    }

    // Show posts in masonry layout
    return _buildDatabasePostsGrid();
  }

  /// Build loading skeleton for posts
  Widget _buildPostsLoadingGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        const gap = 12.0;
        final leftColW = (totalW - gap) * 0.35;
        final rightColW = totalW - leftColW - gap;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column skeleton
            SizedBox(
              width: leftColW,
              child: Column(
                children: [
                  SkeletonWidget(
                    width: leftColW,
                    height: 120,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  const SizedBox(height: 12),
                  SkeletonWidget(
                    width: leftColW,
                    height: 120,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right column skeleton
            SizedBox(
              width: rightColW,
              child: Column(
                children: [
                  SkeletonWidget(
                    width: rightColW,
                    height: 180,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build empty state for avatars section
  Widget _buildEmptyAvatarsState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Avatars Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first avatar to get started',
            style: TextStyle(
              color: kLightTextColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _navigateToAvatarManagement,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Create Avatar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state for posts section
  Widget _buildEmptyPostsState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.grid_view_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _viewMode == ProfileViewMode.owner
                ? 'No Posts Yet'
                : 'No Posts Available',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _viewMode == ProfileViewMode.owner
                ? 'Create your first post to get started'
                : 'This avatar hasn\'t posted anything yet',
            style: const TextStyle(
              color: kLightTextColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (_viewMode == ProfileViewMode.owner) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _navigateToCreatePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Post',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build posts grid from database
  Widget _buildDatabasePostsGrid() {
    if (_avatarPosts.isEmpty) {
      return _buildEmptyPostsState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        const gap = 12.0;
        final leftColW = (totalW - gap) * 0.35;
        final rightColW = totalW - leftColW - gap;

        // Split posts into left and right columns
        final leftPosts = <PostModel>[];
        final rightPosts = <PostModel>[];

        for (int i = 0; i < _avatarPosts.length; i++) {
          if (i % 2 == 0) {
            leftPosts.add(_avatarPosts[i]);
          } else {
            rightPosts.add(_avatarPosts[i]);
          }
        }

        return Column(
          children: [
            // Load more button at the top for owner view
            if (_viewMode == ProfileViewMode.owner &&
                _hasMorePosts &&
                _avatarPosts.length >= _postsPerPage) ...[
              Center(
                child: TextButton(
                  onPressed: () => _loadAvatarPosts(loadMore: true),
                  child: const Text(
                    'Load More',
                    style: TextStyle(color: kPrimaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column
                Expanded(
                  flex: 35,
                  child: Column(
                    children: leftPosts
                        .map((post) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildPostItem(post),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(width: gap),
                // Right column
                Expanded(
                  flex: 65,
                  child: Column(
                    children: rightPosts
                        .map((post) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildPostItem(post),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            // Load more button at the bottom
            if (_hasMorePosts &&
                _avatarPosts.length >= _postsPerPage) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => _loadAvatarPosts(loadMore: true),
                  child: const Text(
                    'Load More',
                    style: TextStyle(color: kPrimaryColor),
                  ),
                ),
              ),
            ],
            // Loading indicator for more posts
            if (_isPostsLoading && _avatarPosts.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Build individual post item
  Widget _buildPostItem(PostModel post) {
    final isVideo = post.type == PostType.video;
    final imageUrl = post.thumbnailUrl ?? post.imageUrl;

    return GestureDetector(
      onTap: () {
        // Navigate to post detail
        Navigator.pushNamed(context, '/post_detail', arguments: post);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post image/thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  if (imageUrl != null)
                    imageUrl.startsWith('assets/')
                        ? Image.asset(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackImage(),
                          )
                        : Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackImage(),
                          )
                  else
                    _buildFallbackImage(),
                  if (isVideo)
                    Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: kPrimaryColor,
                          size: 28,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Post details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.caption != null) ...[
                    Text(
                      post.caption!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatNumber(post.likesCount ?? 0),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.comment, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatNumber(post.commentsCount ?? 0),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatPostDate(post.createdAt),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header card widget with consistent styling
  Widget _HeaderCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  /// Stats column widget for header block
  Widget _StatColumn({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: kLightTextColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
