import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../widgets/overlay_icon.dart';
import '../screens/chat_screen.dart';
import '../screens/enhanced_comments_screen.dart';
import '../services/enhanced_feeds_service.dart';
import '../services/enhanced_video_service.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../config/db_config.dart';
import '../constants.dart';

/// Enhanced Post Detail Screen with full functionality
class EnhancedPostDetailScreen extends StatefulWidget {
  final String? postId;
  final PostModel? initialPost;
  
  const EnhancedPostDetailScreen({
    super.key,
    this.postId,
    this.initialPost,
  });

  @override
  State<EnhancedPostDetailScreen> createState() => _EnhancedPostDetailScreenState();
}

class _EnhancedPostDetailScreenState extends State<EnhancedPostDetailScreen> 
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final EnhancedFeedsService _feedsService = EnhancedFeedsService();
  final EnhancedVideoService _videoService = EnhancedVideoService();
  
  // State management
  List<PostModel> _posts = [];
  Map<String, AvatarModel> _avatarCache = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 0;
  bool _isLoadingMore = false;
  
  // Interaction states
  Map<String, bool> _likedStatus = {};
  Map<String, bool> _followingStatus = {};
  Map<String, bool> _bookmarkedStatus = {};
  
  // Optimistic update states
  Map<String, bool> _optimisticLikes = {};
  Map<String, bool> _optimisticFollows = {};
  Map<String, bool> _optimisticBookmarks = {};
  
  // Error handling
  Map<String, String> _errors = {};
  
  // Video analytics
  Map<String, DateTime> _viewStartTimes = {};
  Map<String, int> _totalWatchTimes = {};
  
  // UI state
  bool _showControls = true;
  bool _isMuted = false;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeServices();
    _setupVideoAnalytics();
  }

  void _setupAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeServices() async {
    try {
      await _videoService.initialize();
      
      if (widget.initialPost != null) {
        await _loadSinglePost(widget.initialPost!);
      } else if (widget.postId != null) {
        await _loadPostById(widget.postId!);
      } else {
        await _loadInitialPosts();
      }
    } catch (e) {
      debugPrint('Error initializing services: $e');
      _setError('Failed to load content');
    }
  }
  
  void _setupVideoAnalytics() {
    _videoService.onAnalyticsEvent = (url, event, data) {
      PostModel? post;
      try {
        post = _posts.firstWhere((p) => p.videoUrl == url);
      } catch (e) {
        post = _posts.isNotEmpty ? _posts.first : null;
      }
      
      if (post != null) {
        _trackAnalyticsEvent(post.id, event, data);
      }
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controlsAnimationController.dispose();
    _videoService.pauseAllVideos();
    _feedsService.dispose();
    super.dispose();
  }

  Future<void> _loadSinglePost(PostModel post) async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      await _cacheAvatarsForPosts([post]);
      await _loadInteractionStatus([post]);

      setState(() {
        _posts = [post];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading single post: $e');
      _setError('Failed to load post details');
    }
  }

  Future<void> _loadPostById(String postId) async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      final post = await _feedsService.getPostById(postId);
      if (post != null) {
        await _loadSinglePost(post);
      } else {
        _setError('Post not found');
      }
    } catch (e) {
      debugPrint('Error loading post by ID: $e');
      _setError('Failed to load post');
    }
  }

  Future<void> _loadInitialPosts() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      final posts = await _feedsService.getVideoFeed(
        page: 0,
        limit: 10,
        orderByTrending: true,
      );

      if (posts.isNotEmpty) {
        await _cacheAvatarsForPosts(posts);
        await _loadInteractionStatus(posts);

        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      } else {
        _setError('No posts available');
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      _setError('Failed to load posts');
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newPosts = await _feedsService.getVideoFeed(
        page: _currentPage + 1,
        limit: 10,
        orderByTrending: true,
      );

      if (newPosts.isNotEmpty) {
        await _cacheAvatarsForPosts(newPosts);
        await _loadInteractionStatus(newPosts);

        setState(() {
          _posts.addAll(newPosts);
          _currentPage++;
        });
      }
    } catch (e) {
      debugPrint('Error loading more posts: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _cacheAvatarsForPosts(List<PostModel> posts) async {
    for (final post in posts) {
      if (!_avatarCache.containsKey(post.avatarId)) {
        try {
          final avatar = await _feedsService.getAvatarForPost(post.avatarId);
          if (avatar != null) {
            _avatarCache[post.avatarId] = avatar;
          }
        } catch (e) {
          debugPrint('Error caching avatar ${post.avatarId}: $e');
        }
      }
    }
  }

  Future<void> _loadInteractionStatus(List<PostModel> posts) async {
    try {
      final postIds = posts.map((p) => p.id).toList();
      final avatarIds = posts.map((p) => p.avatarId).toList();

      final results = await Future.wait([
        _feedsService.getLikedStatusBatch(postIds),
        _feedsService.getFollowingStatusBatch(avatarIds),
        _feedsService.getBookmarkedStatusBatch(postIds),
      ]);

      setState(() {
        _likedStatus.addAll(results[0]);
        _followingStatus.addAll(results[1]);
        _bookmarkedStatus.addAll(results[2]);
      });
    } catch (e) {
      debugPrint('Error loading interaction status: $e');
    }
  }

  void _setError(String message) {
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Future<void> _refreshCurrentPost() async {
    if (_posts.isNotEmpty) {
      final currentPost = _posts[_currentPage];
      try {
        final refreshedPost = await _feedsService.getPostById(currentPost.id);
        if (refreshedPost != null) {
          setState(() {
            _posts[_currentPage] = refreshedPost;
          });
        }
      } catch (e) {
        debugPrint('Error refreshing current post: $e');
      }
    }
  }

  // ===== INTERACTION HANDLERS =====

  Future<void> _onPostLike(PostModel post) async {
    final wasLiked = (_optimisticLikes[post.id] ?? _likedStatus[post.id]) ?? false;
    final newLikedStatus = !wasLiked;
    
    // Optimistic update
    setState(() {
      _optimisticLikes[post.id] = newLikedStatus;
      _errors.remove('like_${post.id}');
      
      final postIndex = _posts.indexWhere((p) => p.id == post.id);
      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(
          likesCount: newLikedStatus 
              ? _posts[postIndex].likesCount + 1 
              : _posts[postIndex].likesCount - 1,
        );
      }
    });
    
    try {
      final actualStatus = await _feedsService.toggleLike(post.id);
      
      setState(() {
        _likedStatus[post.id] = actualStatus;
        _optimisticLikes.remove(post.id);
      });
      
      _trackAnalyticsEvent(post.id, DbConfig.likeEvent, {
        'liked': actualStatus,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      if (actualStatus) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      
      // Revert optimistic update
      setState(() {
        _optimisticLikes.remove(post.id);
        _errors['like_${post.id}'] = 'Failed to ${newLikedStatus ? 'like' : 'unlike'} post';
        
        final postIndex = _posts.indexWhere((p) => p.id == post.id);
        if (postIndex != -1) {
          _posts[postIndex] = _posts[postIndex].copyWith(
            likesCount: wasLiked 
                ? _posts[postIndex].likesCount + 1 
                : _posts[postIndex].likesCount - 1,
          );
        }
      });
      
      _showErrorSnackBar('Failed to ${newLikedStatus ? 'like' : 'unlike'} post', () => _onPostLike(post));
    }
  }

  Future<void> _onPostComment(PostModel post) async {
    _trackAnalyticsEvent(post.id, DbConfig.commentEvent, {
      'action': 'open_modal',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedCommentsScreen(postId: post.id),
      ),
    );
    
    // Refresh post data when returning from comments
    await _refreshCurrentPost();
  }

  Future<void> _onPostShare(PostModel post) async {
    try {
      final avatar = _avatarCache[post.avatarId];
      final shareText = '${avatar?.name ?? 'Avatar'}: ${post.caption}\n\nWatch on Quanta: https://quanta.app/post/${post.id}';
      
      await Share.share(
        shareText,
        subject: 'Check out this post on Quanta',
      );
      
      // Record the share
      await _feedsService.sharePost(post.id, platform: 'native_share');
      
      _trackAnalyticsEvent(post.id, DbConfig.shareEvent, {
        'platform': 'native_share',
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Error sharing post: $e');
      _showErrorSnackBar('Failed to share post', () => _onPostShare(post));
    }
  }

  Future<void> _onPostSave(PostModel post) async {
    final wasBookmarked = (_optimisticBookmarks[post.id] ?? _bookmarkedStatus[post.id]) ?? false;
    final newBookmarkedStatus = !wasBookmarked;
    
    // Optimistic update
    setState(() {
      _optimisticBookmarks[post.id] = newBookmarkedStatus;
      _errors.remove('bookmark_${post.id}');
    });
    
    try {
      final actualStatus = await _feedsService.toggleBookmark(post.id);
      
      setState(() {
        _bookmarkedStatus[post.id] = actualStatus;
        _optimisticBookmarks.remove(post.id);
      });
      
      HapticFeedback.selectionClick();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actualStatus ? 'Post saved' : 'Post removed from saved'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      
      // Revert optimistic update
      setState(() {
        _optimisticBookmarks.remove(post.id);
        _errors['bookmark_${post.id}'] = 'Failed to ${newBookmarkedStatus ? 'save' : 'unsave'} post';
      });
      
      _showErrorSnackBar('Failed to ${newBookmarkedStatus ? 'save' : 'unsave'} post', () => _onPostSave(post));
    }
  }

  Future<void> _onAvatarTap(PostModel post) async {
    final avatar = _avatarCache[post.avatarId];
    if (avatar != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            name: avatar.name,
            avatar: avatar.avatarImageUrl ?? 'assets/images/p.jpg',
          ),
        ),
      );
    }
  }

  Future<void> _onFollowToggle(PostModel post) async {
    final avatar = _avatarCache[post.avatarId];
    if (avatar == null) return;
    
    final wasFollowing = (_optimisticFollows[post.avatarId] ?? _followingStatus[post.avatarId]) ?? false;
    final newFollowingStatus = !wasFollowing;
    
    // Optimistic update
    setState(() {
      _optimisticFollows[post.avatarId] = newFollowingStatus;
      _errors.remove('follow_${post.avatarId}');
    });
    
    try {
      final actualStatus = await _feedsService.toggleFollow(post.avatarId);
      
      setState(() {
        _followingStatus[post.avatarId] = actualStatus;
        _optimisticFollows.remove(post.avatarId);
      });
      
      HapticFeedback.selectionClick();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actualStatus ? 'Following ${avatar.name}' : 'Unfollowed ${avatar.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      
      // Revert optimistic update
      setState(() {
        _optimisticFollows.remove(post.avatarId);
        _errors['follow_${post.avatarId}'] = 'Failed to ${newFollowingStatus ? 'follow' : 'unfollow'} ${avatar.name}';
      });
      
      _showErrorSnackBar('Failed to ${newFollowingStatus ? 'follow' : 'unfollow'} ${avatar.name}', () => _onFollowToggle(post));
    }
  }

  // ===== MORE MENU ACTIONS =====

  void _showMoreMenu(PostModel post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMoreMenu(post),
    );
  }

  Widget _buildMoreMenu(PostModel post) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildMenuOption(
            icon: Icons.link,
            title: 'Copy Link',
            onTap: () => _copyPostLink(post),
          ),
          _buildMenuOption(
            icon: Icons.flag_outlined,
            title: 'Report',
            onTap: () => _reportPost(post),
          ),
          _buildMenuOption(
            icon: Icons.block,
            title: 'Block User',
            onTap: () => _blockUser(post),
          ),
          if (post.type == PostType.video) ...[
            _buildMenuOption(
              icon: Icons.download,
              title: 'Download',
              onTap: () => _downloadPost(post),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _copyPostLink(PostModel post) async {
    try {
      final link = 'https://quanta.app/post/${post.id}';
      await Clipboard.setData(ClipboardData(text: link));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error copying link: $e');
      _showErrorSnackBar('Failed to copy link', () => _copyPostLink(post));
    }
  }

  Future<void> _reportPost(PostModel post) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _buildReportDialog(),
    );
    
    if (result != null) {
      try {
        await _feedsService.reportPost(post.id, result);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you for helping keep our community safe.'),
            duration: Duration(seconds: 3),
          ),
        );
        
        _trackAnalyticsEvent(post.id, DbConfig.reportEvent, {
          'report_type': result,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error reporting post: $e');
        _showErrorSnackBar('Failed to submit report', () => _reportPost(post));
      }
    }
  }

  Widget _buildReportDialog() {
    return AlertDialog(
      title: const Text('Report Post'),
      content: const Text('Why are you reporting this post?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DbConfig.spamReport),
          child: const Text('Spam'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DbConfig.inappropriateReport),
          child: const Text('Inappropriate'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DbConfig.harassmentReport),
          child: const Text('Harassment'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DbConfig.otherReport),
          child: const Text('Other'),
        ),
      ],
    );
  }

  Future<void> _blockUser(PostModel post) async {
    final avatar = _avatarCache[post.avatarId];
    if (avatar == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${avatar.name}? You won\'t see their posts anymore.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _feedsService.blockUser(avatar.ownerUserId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Blocked ${avatar.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Remove blocked user's posts from current feed
        setState(() {
          _posts.removeWhere((p) => p.avatarId == post.avatarId);
        });
      } catch (e) {
        debugPrint('Error blocking user: $e');
        _showErrorSnackBar('Failed to block user', () => _blockUser(post));
      }
    }
  }

  Future<void> _downloadPost(PostModel post) async {
    if (post.videoUrl == null) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download started...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Track download event
      _trackAnalyticsEvent(post.id, DbConfig.downloadEvent, {
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Note: Actual download implementation would require additional packages
      // and platform-specific code for saving to device storage
    } catch (e) {
      debugPrint('Error downloading post: $e');
      _showErrorSnackBar('Failed to download post', () => _downloadPost(post));
    }
  }

  // ===== VIDEO ANALYTICS =====

  void _trackAnalyticsEvent(String postId, String event, Map<String, dynamic> data) {
    // Record analytics event
    debugPrint('Analytics: $event for post $postId with data: $data');
    
    // In a real app, you would send this to your analytics service
    // Example: Analytics.track(event, {'post_id': postId, ...data});
  }

  void _onVideoViewStarted(String postId) {
    _viewStartTimes[postId] = DateTime.now();
  }

  void _onVideoViewEnded(String postId) {
    final startTime = _viewStartTimes[postId];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime).inSeconds;
      _totalWatchTimes[postId] = (_totalWatchTimes[postId] ?? 0) + duration;
      
      // Record view if significant watch time
      if (duration >= DbConfig.viewThresholdSeconds) {
        _feedsService.recordViewEvent(
          postId,
          durationSeconds: duration,
          watchPercentage: _videoService.getWatchPercentage(postId),
        );
      }
    }
  }

  // ===== UI HELPERS =====

  void _showErrorSnackBar(String message, VoidCallback? onRetry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  // ===== BUILD UI =====

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeServices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.post_add, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                'No posts yet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Follow some avatars to see their content here!',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Main content
          NotificationListener<ScrollEndNotification>(
            onNotification: (scrollEnd) {
              final metrics = scrollEnd.metrics;
              if (metrics.atEdge && metrics.pixels != 0) {
                _loadMorePosts();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });

                if (index >= _posts.length - 2) {
                  _loadMorePosts();
                }

                if (index < _posts.length) {
                  final post = _posts[index];
                  _onVideoViewStarted(post.id);
                  
                  // Stop previous video and start current one
                  if (index > 0) {
                    _onVideoViewEnded(_posts[index - 1].id);
                  }
                }
              },
              itemBuilder: (context, index) {
                if (index >= _posts.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final post = _posts[index];
                final avatar = _avatarCache[post.avatarId];
                
                return _buildPostItem(post, avatar, index == _currentPage);
              },
            ),
          ),

          // Top overlay controls
          _buildTopOverlay(),
        ],
      ),
    );
  }

  Widget _buildPostItem(PostModel post, AvatarModel? avatar, bool isActive) {
    final isLiked = (_optimisticLikes[post.id] ?? _likedStatus[post.id]) ?? false;
    final isFollowing = (_optimisticFollows[post.avatarId] ?? _followingStatus[post.avatarId]) ?? false;
    final isBookmarked = (_optimisticBookmarks[post.id] ?? _bookmarkedStatus[post.id]) ?? false;

    return Stack(
      children: [
        // Background media
        Positioned.fill(
          child: _buildMediaBackground(post, isActive),
        ),

        // Content overlay
        Positioned(
          left: 16,
          right: 16,
          bottom: 90,
          child: _buildContentOverlay(post, avatar, isLiked, isFollowing, isBookmarked),
        ),

        // Side actions
        Positioned(
          right: 16,
          bottom: 120,
          child: _buildSideActions(post, avatar, isLiked, isFollowing, isBookmarked),
        ),
      ],
    );
  }

  Widget _buildMediaBackground(PostModel post, bool isActive) {
    if (post.type == PostType.video && post.videoUrl != null) {
      return _videoService.getVideoController(post.videoUrl!) != null
          ? VideoPlayer(_videoService.getVideoController(post.videoUrl!)!)
          : Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
    } else {
      // Handle image posts or video error state
      return Container(
        color: Colors.black,
        child: post.imageUrl != null
            ? Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Content not available',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.white54,
                      size: 48,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Content not available',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
      );
    }
  }

  Widget _buildContentOverlay(PostModel post, AvatarModel? avatar, bool isLiked, bool isFollowing, bool isBookmarked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar and info
        Row(
          children: [
            GestureDetector(
              onTap: () => _onAvatarTap(post),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: avatar?.avatarImageUrl != null
                        ? NetworkImage(avatar!.avatarImageUrl!)
                        : const AssetImage('assets/images/p.jpg') as ImageProvider,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avatar?.name ?? 'Unknown Avatar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (avatar?.bio != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      avatar!.bio,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (!isFollowing) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _onFollowToggle(post),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Follow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Caption
        Text(
          post.caption,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.3,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSideActions(PostModel post, AvatarModel? avatar, bool isLiked, bool isFollowing, bool isBookmarked) {
    return Column(
      children: [
        _buildActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          count: _formatCount(post.likesCount),
          color: isLiked ? Colors.red : Colors.white,
          onTap: () => _onPostLike(post),
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.comment,
          count: _formatCount(post.commentsCount),
          onTap: () => _onPostComment(post),
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.share,
          count: _formatCount(post.sharesCount),
          onTap: () => _onPostShare(post),
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: isBookmarked ? kPrimaryColor : Colors.white,
          onTap: () => _onPostSave(post),
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.more_vert,
          onTap: () => _showMoreMenu(post),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    String? count,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          if (count != null) ...[
            const SizedBox(height: 4),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.postId != null || widget.initialPost != null) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              GestureDetector(
                onTap: () {
                  // Open search or navigate to search screen
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final isMuted = await _videoService.toggleMute(null);
                    setState(() {
                      _isMuted = isMuted;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
