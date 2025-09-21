import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../models/post_model.dart';
import '../services/enhanced_feeds_service.dart';
import '../services/enhanced_video_service.dart';
import '../store/state_service_adapter.dart';
import '../widgets/video_feed_item.dart';
import '../widgets/skeleton_widgets.dart';

/// @deprecated This feed screen is deprecated.
/// Use PostDetailScreen instead, which now has feature parity and is the default home screen.
/// This file will be removed in a future version.
class FeedsScreen extends StatefulWidget {
  const FeedsScreen({super.key});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );
  final EnhancedFeedsService _feedsService = EnhancedFeedsService();
  final EnhancedVideoService _videoService = EnhancedVideoService();
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();

  // UI state only - all data comes from central state
  int _currentIndex = 0;
  static const int _pageSize = 10;
  static const String _feedContext = 'video_feed';

  // Central state getters - single source of truth
  List<PostModel> get _posts => _stateAdapter.feedPosts;
  bool get _isLoading => _stateAdapter.getLoadingState(_feedContext);
  bool get _isLoadingMore =>
      _stateAdapter.getLoadingState('${_feedContext}_more');
  String? get _errorMessage => _stateAdapter.error;
  bool get _hasError => _errorMessage != null;
  int get _currentPage => _stateAdapter.getCurrentPage(_feedContext);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _preloadVideosAroundCurrent();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  /// Load initial posts
  Future<void> _loadInitialPosts() async {
    try {
      _stateAdapter.setLoadingState(_feedContext, true);
      _stateAdapter.clearError();

      final posts = await _feedsService.getVideoFeed(
        page: 0,
        limit: _pageSize,
        orderByTrending: true,
      );

      if (posts.isNotEmpty) {
        await _loadPostMetadata(posts);
        await _loadLikedAndFollowingStatus(posts);

        // Update central state
        _stateAdapter.setPosts(posts, context: _feedContext);
        _stateAdapter.setPaginationState(
          _feedContext,
          0,
          posts.length >= _pageSize,
        );

        // Preload videos for better performance
        _preloadVideosAroundCurrent();
      } else {
        _stateAdapter.setError('No videos available at the moment');
      }
    } catch (e) {
      _stateAdapter.setError('Failed to load videos. Please try again.');
      debugPrint('Error loading initial posts: $e');
    } finally {
      _stateAdapter.setLoadingState(_feedContext, false);
    }
  }

  /// Load more posts for pagination
  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;

    try {
      // Set loading state through state adapter
      _stateAdapter.setLoadingState('${_feedContext}_more', true);

      final newPosts = await _feedsService.getVideoFeed(
        page: _currentPage + 1,
        limit: _pageSize,
        orderByTrending: true,
      );

      if (newPosts.isNotEmpty) {
        await _loadPostMetadata(newPosts);
        await _loadLikedAndFollowingStatus(newPosts);

        // Add new posts to existing posts and update pagination
        final existingPosts = List<PostModel>.from(_posts);
        existingPosts.addAll(newPosts);
        _stateAdapter.setPosts(existingPosts, context: _feedContext);
        _stateAdapter.setPaginationState(
          _feedContext,
          _currentPage + 1,
          newPosts.length >= _pageSize,
        );

        _preloadVideosAroundCurrent();
      }
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load more videos'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      // Clear loading state through state adapter
      _stateAdapter.setLoadingState('${_feedContext}_more', false);
    }
  }

  /// Load metadata (avatars, users) for posts
  Future<void> _loadPostMetadata(List<PostModel> posts) async {
    final avatarIds = posts.map((post) => post.avatarId).toSet();

    for (final avatarId in avatarIds) {
      // Check central state first
      if (_stateAdapter.getAvatar(avatarId) == null) {
        final avatar = await _feedsService.getAvatarForPost(avatarId);
        if (avatar != null) {
          // Store in central state
          _stateAdapter.setAvatar(avatar);
        }
      }
    }
  }

  /// Load liked and following status for posts
  Future<void> _loadLikedAndFollowingStatus(List<PostModel> posts) async {
    final postIds = posts.map((post) => post.id).toList();
    final avatarIds = posts.map((post) => post.avatarId).toList();

    final [likedStatus, followingStatus] = await Future.wait([
      _feedsService.getLikedStatusBatch(postIds),
      _feedsService.getFollowingStatusBatch(avatarIds),
    ]);

    // Store in central state
    _stateAdapter.warmCacheFromService(
      likedPosts: likedStatus,
      followingAvatars: followingStatus,
    );
  }

  /// Preload videos around current index for smooth playback
  void _preloadVideosAroundCurrent() {
    if (_posts.isEmpty) return; // Early return if no posts

    final preloadRange = 2; // Preload 2 videos before and after current
    final maxIndex = _posts.length - 1;
    final startIndex = (_currentIndex - preloadRange).clamp(0, maxIndex);
    final endIndex = (_currentIndex + preloadRange).clamp(0, maxIndex);

    for (int i = startIndex; i <= endIndex; i++) {
      final videoUrl = _posts[i].videoUrl;
      if (videoUrl != null && videoUrl.isNotEmpty) {
        _videoService.preloadVideo(videoUrl);
      }
    }
  }

  /// Handle page change
  void _onPageChanged(int index) {
    if (_posts.isEmpty || index >= _posts.length) return;

    setState(() {
      _currentIndex = index;
    });

    // Increment view count for current video
    _feedsService.incrementViewCount(_posts[index].id);

    // Preload surrounding videos
    _preloadVideosAroundCurrent();

    // Load more posts when nearing the end
    if (index >= _posts.length - 3) {
      _loadMorePosts();
    }

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  /// Handle refresh
  Future<void> _onRefresh() async {
    try {
      final posts = await _feedsService.getVideoFeed(
        page: 0,
        limit: _pageSize,
        orderByTrending: true,
      );

      if (posts.isNotEmpty) {
        await _loadPostMetadata(posts);
        await _loadLikedAndFollowingStatus(posts);

        // Update state through state adapter
        _stateAdapter.setPosts(posts, context: _feedContext);
        _stateAdapter.setPaginationState(
          _feedContext,
          0,
          posts.length >= _pageSize,
        );
        _stateAdapter.clearError();

        setState(() {
          _currentIndex = 0;
        });

        // Jump to first post
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        _preloadVideosAroundCurrent();
      }

      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
      debugPrint('Error refreshing posts: $e');
    }
  }

  /// Handle like action
  Future<void> _handleLike(PostModel post) async {
    try {
      // Optimistic update
      _stateAdapter.optimisticTogglePostLike(post.id);

      // API call
      final isLiked = await _feedsService.toggleLike(post.id);

      // Sync with actual result
      final updatedPost = _stateAdapter.getPost(post.id);
      if (updatedPost != null) {
        final newLikesCount = isLiked
            ? post.likesCount + 1
            : post.likesCount - 1;
        _stateAdapter.setPostLikeStatus(
          post.id,
          isLiked,
          newLikesCount: newLikesCount,
        );
      }

      // Haptic feedback
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Revert optimistic update on error
      _stateAdapter.optimisticTogglePostLike(post.id);

      debugPrint('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to like post'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Handle follow action
  Future<void> _handleFollow(String avatarId) async {
    try {
      // Optimistic update
      _stateAdapter.optimisticToggleFollow(avatarId);

      // API call
      final isFollowing = await _feedsService.toggleFollow(avatarId);

      // Sync with actual result
      _stateAdapter.setFollowStatus(avatarId, isFollowing);

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFollowing ? 'Following!' : 'Unfollowed'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // Revert optimistic update on error
      _stateAdapter.optimisticToggleFollow(avatarId);

      debugPrint('Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to follow'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Handle comment action
  void _handleComment(PostModel post) {
    // Comments are handled by the VideoFeedItem itself
    HapticFeedback.lightImpact();
  }

  /// Handle share action
  void _handleShare(PostModel post) {
    // Share is handled by the VideoFeedItem itself
    HapticFeedback.lightImpact();
  }

  /// Handle profile tap
  void _handleProfileTap(PostModel post) {
    // TODO: Navigate to avatar profile screen
    HapticFeedback.lightImpact();
    debugPrint('Navigate to profile for avatar: ${post.avatarId}');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(backgroundColor: Color(0xFF002B36), body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return SkeletonLoader.videoFeed();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return SmartRefresher(
      controller: _refreshController,
      onRefresh: _onRefresh,
      header: WaterDropMaterialHeader(
        backgroundColor: Theme.of(context).primaryColor,
        color: Colors.white,
      ),
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          final avatar = _stateAdapter.getAvatar(post.avatarId);
          final isLiked = _stateAdapter.isPostLiked(post.id);
          final isFollowing = _stateAdapter.isFollowingAvatar(post.avatarId);

          return VideoFeedItem(
            post: post,
            avatar: avatar,
            user:
                null, // User data will be handled by VideoFeedItem itself or removed
            isActive: index == _currentIndex,
            isLiked: isLiked,
            isFollowing: isFollowing,
            onLike: () => _handleLike(post),
            onFollow: () => _handleFollow(post.avatarId),
            onComment: () => _handleComment(post),
            onShare: () => _handleShare(post),
            onProfileTap: () => _handleProfileTap(post),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadInitialPosts,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, color: Colors.white, size: 64),
          SizedBox(height: 16),
          Text(
            'No videos available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Check back later for new content!',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
