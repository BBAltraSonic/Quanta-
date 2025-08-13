import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_social_ui/widgets/post_item.dart';
import 'package:flutter_social_ui/widgets/overlay_icon.dart';
import 'package:flutter_social_ui/screens/chat_screen.dart';
import 'package:flutter_social_ui/widgets/comments_modal.dart';
import 'package:flutter_social_ui/services/enhanced_feeds_service.dart';
import 'package:flutter_social_ui/services/enhanced_video_service.dart';
import 'package:flutter_social_ui/services/share_service.dart';
import 'package:flutter_social_ui/models/post_model.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/services/user_safety_service.dart';
import 'package:flutter_social_ui/services/chat_validation_service.dart';
import 'package:flutter_social_ui/widgets/report_content_dialog.dart';
import 'package:flutter_social_ui/services/analytics_service.dart';
import 'package:flutter_social_ui/widgets/skeleton_widgets.dart';



class PostDetailScreen extends StatefulWidget {
  final String? postId;
  final PostModel? initialPost;
  
  const PostDetailScreen({
    super.key,
    this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PageController _pageController = PageController();
  final EnhancedFeedsService _feedsService = EnhancedFeedsService();
  final EnhancedVideoService _videoService = EnhancedVideoService();
  final ShareService _shareService = ShareService();
  final ChatValidationService _chatValidationService = ChatValidationService();
  final AnalyticsService _analyticsService = AnalyticsService();
  
  // State for interactions
  Map<String, bool> _likedStatus = {};
  Map<String, bool> _followingStatus = {};
  Map<String, bool> _bookmarkedStatus = {};
  // Settings
  bool _isMuted = false;

  List<PostModel> _posts = [];
  Map<String, AvatarModel> _avatarCache = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupVideoAnalytics();
  }

  Future<void> _initializeServices() async {
    try {
      await _videoService.initialize();
      
      if (widget.initialPost != null) {
        _loadSinglePost(widget.initialPost!);
      } else if (widget.postId != null) {
        _loadPostById(widget.postId!);
      } else {
        _loadInitialPosts();
      }
    } catch (e) {
      debugPrint('Error initializing services: $e');
      _setError('Failed to initialize feed. Please check your connection and try again.');
    }
  }
  
  void _setupVideoAnalytics() {
    _videoService.onAnalyticsEvent = (url, event, data) {
      // Find post ID from URL and track analytics
      final post = _posts.firstWhere(
        (p) => p.videoUrl == url,
        orElse: () => _posts.first,
      );
      
      _trackAnalyticsEvent(post.id, event, data);
    };
  }
  
  void _trackAnalyticsEvent(String postId, String event, Map<String, dynamic> data) {
    // Track analytics events using the analytics service
    try {
      _analyticsService.trackEvent(event, {
        'post_id': postId,
        ...data,
      });
    } catch (e) {
      debugPrint('Failed to track analytics event: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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

      // Cache avatar for the post
      await _cacheAvatarsForPosts([post]);
      await _loadLikedAndFollowingStatus([post]);

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
        // Cache avatars for loaded posts
        await _cacheAvatarsForPosts(posts);
        await _loadLikedAndFollowingStatus(posts);
        
        // Preload video controllers for better playback
        await _preloadVideosForPosts(posts);

        setState(() {
          _posts = posts;
          _isLoading = false;
        });
        
        // Start playing the first video if it's a video post
        if (posts.isNotEmpty && posts[0].type == PostType.video && posts[0].videoUrl != null) {
          _playVideoForPost(posts[0]);
        }
      } else {
        // No posts available from backend
        _setError('No posts available. Create some content to get started!');
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      _setError('Failed to load posts. Please check your connection and try again.');
    }
  }

  void _setError(String message) {
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = message;
    });
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
        await _loadLikedAndFollowingStatus(newPosts);
        
        // Preload video controllers for new posts
        await _preloadVideosForPosts(newPosts);

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
    final avatarIds = posts.map((p) => p.avatarId).toSet();

    for (String avatarId in avatarIds) {
      if (!_avatarCache.containsKey(avatarId)) {
        try {
          final avatar = await _feedsService.getAvatarForPost(avatarId);
          if (avatar != null) {
            _avatarCache[avatarId] = avatar;
          }
        } catch (e) {
          debugPrint('Error caching avatar $avatarId: $e');
        }
      }
    }
  }

  /// Preload video controllers for posts to ensure smooth playback
  Future<void> _preloadVideosForPosts(List<PostModel> posts) async {
    final videoTasks = <Future<void>>[];
    
    for (final post in posts) {
      if (post.type == PostType.video && post.videoUrl != null && post.videoUrl!.isNotEmpty) {
        // Create video controller and initialize it
        final task = () async {
          try {
            await _videoService.preloadVideo(post.videoUrl!);
            debugPrint('✅ Preloaded video: ${post.videoUrl}');
          } catch (e) {
            debugPrint('❌ Failed to preload video ${post.videoUrl}: $e');
          }
        }();
        videoTasks.add(task);
      }
    }
    
    // Wait for all video preloading tasks to complete (with timeout)
    if (videoTasks.isNotEmpty) {
      await Future.wait(videoTasks).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Video preloading timeout - some videos may not be ready');
          return <void>[];
        },
      );
    }
  }
  
  /// Play video for a specific post
  Future<void> _playVideoForPost(PostModel post) async {
    if (post.type == PostType.video && post.videoUrl != null && post.videoUrl!.isNotEmpty) {
      try {
        await _videoService.playVideo(post.videoUrl!);
        debugPrint('▶️ Playing video: ${post.videoUrl}');
      } catch (e) {
        debugPrint('❌ Failed to play video ${post.videoUrl}: $e');
      }
    }
  }
  
  /// Pause video for a specific post
  Future<void> _pauseVideoForPost(PostModel post) async {
    if (post.type == PostType.video && post.videoUrl != null && post.videoUrl!.isNotEmpty) {
      try {
        await _videoService.pauseVideo(post.videoUrl!);
        debugPrint('⏸️ Paused video: ${post.videoUrl}');
      } catch (e) {
        debugPrint('❌ Failed to pause video ${post.videoUrl}: $e');
      }
    }
  }

  /// Load liked, following, and bookmarked status for posts
  Future<void> _loadLikedAndFollowingStatus(List<PostModel> posts) async {
    final postIds = posts.map((p) => p.id).toList();
    final avatarIds = posts.map((p) => p.avatarId).toList();

    try {
      // Batch load liked status
      final likedStatus = await _feedsService.getLikedStatusBatch(postIds);
      _likedStatus.addAll(likedStatus);

      // Batch load following status
      final followingStatus = await _feedsService.getFollowingStatusBatch(avatarIds);
      _followingStatus.addAll(followingStatus);

      // Batch load bookmarked status
      final bookmarkedStatus = await _feedsService.getBookmarkedStatusBatch(postIds);
      _bookmarkedStatus.addAll(bookmarkedStatus);
    } catch (e) {
      debugPrint('Error loading engagement status: $e');
    }
  }



  void _onPostLike(PostModel post) async {
    try {
      final newLikedStatus = await _feedsService.toggleLike(post.id);

      setState(() {
        _likedStatus[post.id] = newLikedStatus;
        
        // Update post likes count optimistically
        final postIndex = _posts.indexWhere((p) => p.id == post.id);
        if (postIndex != -1) {
          final increment = newLikedStatus ? 1 : -1;
          _posts[postIndex] = _posts[postIndex].copyWith(
            likesCount: (_posts[postIndex].likesCount + increment).clamp(0, double.infinity).toInt(),
          );
        }
      });

      // Track analytics
      _analyticsService.trackLikeToggle(
        post.id, 
        newLikedStatus,
        postType: post.type.toString(),
        authorId: post.avatarId,
        likesCount: post.likesCount + (newLikedStatus ? 1 : -1),
      );
    } catch (e) {
      debugPrint('Error liking post: $e');
      // Show error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to like post. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onPostComment(PostModel post) {
    // Track analytics for comment modal open
    _analyticsService.trackCommentModalOpen(
      post.id,
      postType: post.type.toString(),
      authorId: post.avatarId,
      commentsCount: post.commentsCount,
    );

    openCommentsModal(
      context, 
      postId: post.id,
      onCommentCountChanged: (int newCount) {
        // Update the post's comment count in real time
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          setState(() {
            _posts[index] = _posts[index].copyWith(
              commentsCount: newCount,
            );
          });
        }

        // Track analytics for comment count change
        _trackAnalyticsEvent(post.id, 'comment_count_updated', {
          'new_count': newCount,
          'post_type': post.type.toString(),
        });
      },
    );
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Share', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _onPostShare(_posts[_currentPage]);
              },
            ),
            ListTile(
              leading: Icon(
                _bookmarkedStatus[_posts[_currentPage].id] == true 
                    ? Icons.bookmark 
                    : Icons.bookmark_border, 
                color: Colors.white
              ),
              title: Text(
                _bookmarkedStatus[_posts[_currentPage].id] == true ? 'Unsave' : 'Save', 
                style: TextStyle(color: Colors.white)
              ),
              onTap: () {
                Navigator.pop(context);
                _onPostSave(_posts[_currentPage]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.white),
              title: const Text('Report', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(_posts[_currentPage]);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }



  void _onAvatarTap(PostModel post) {
    final avatar = _avatarCache[post.avatarId];
    if (avatar == null) return;

    // Show avatar action sheet with follow/unfollow and chat options
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Avatar info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: avatar.avatarImageUrl != null && avatar.avatarImageUrl!.isNotEmpty && avatar.avatarImageUrl!.startsWith('http')
                        ? NetworkImage(avatar.avatarImageUrl!) as ImageProvider
                        : null,
                    backgroundColor: Colors.grey[800],
                    child: avatar.avatarImageUrl == null || avatar.avatarImageUrl!.isEmpty || !avatar.avatarImageUrl!.startsWith('http')
                        ? Icon(Icons.person, color: Colors.white54, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          avatar.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (avatar.bio.isNotEmpty)
                          Text(
                            avatar.bio,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            ListTile(
              leading: Icon(
                _followingStatus[post.avatarId] == true 
                    ? Icons.person_remove 
                    : Icons.person_add,
                color: Colors.white,
              ),
              title: Text(
                _followingStatus[post.avatarId] == true ? 'Unfollow' : 'Follow',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _onAvatarFollow(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.white),
              title: const Text('Chat', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _onAvatarChat(post, avatar);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  void _onAvatarFollow(PostModel post) async {
    try {
      final newFollowingStatus = await _feedsService.toggleFollow(post.avatarId);
      
      setState(() {
        _followingStatus[post.avatarId] = newFollowingStatus;
      });

      final avatar = _avatarCache[post.avatarId];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newFollowingStatus 
                ? 'Now following ${avatar?.name ?? "avatar"}' 
                : 'Unfollowed ${avatar?.name ?? "avatar"}'
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Track analytics
      _trackAnalyticsEvent(post.id, 'follow_toggle', {
        'following': newFollowingStatus,
        'avatar_id': post.avatarId,
        'avatar_name': avatar?.name,
      });
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update follow status. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onAvatarChat(PostModel post, AvatarModel avatar) async {
    try {
      // First, perform basic validation without network calls
      final basicValidation = _chatValidationService.validateBasicRequirements(post.avatarId);
      
      if (!basicValidation.isValid) {
        _showChatValidationTooltip(basicValidation.errorType!, basicValidation.errorMessage!);
        return;
      }

      // Show loading indicator while performing full validation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: kCardColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: kPrimaryColor),
              SizedBox(height: 16),
              Text(
                'Connecting to ${avatar.name}...',
                style: kBodyTextStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Perform full validation
      final validation = await _chatValidationService.validateChatAvailability(post.avatarId);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (validation.isValid) {
        // Navigation is valid, proceed to chat
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              name: avatar.name,
              avatar: avatar.avatarImageUrl ?? '',
              avatarId: post.avatarId, // Pass the avatar ID for proper functionality
            ),
          ),
        );

        // Track analytics
        _trackAnalyticsEvent(post.id, 'chat_started', {
          'avatar_id': post.avatarId,
          'avatar_name': avatar.name,
        });
      } else {
        // Validation failed, show error
        _showChatValidationTooltip(validation.errorType!, validation.errorMessage!);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      debugPrint('Error validating chat: $e');
      _showChatValidationTooltip(
        ChatValidationErrorType.unknown,
        'Unable to start chat. Please try again.',
      );
    }
  }

  void _showChatValidationTooltip(ChatValidationErrorType errorType, String errorMessage) {
    final tooltip = _chatValidationService.getErrorTooltip(errorType);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tooltip,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (errorMessage != tooltip)
                    Text(
                      errorMessage,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey[800],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _toggleVolume() {
    setState(() {
      _isMuted = !_isMuted;
    });

    // Apply mute/unmute to video service
    if (_isMuted) {
      _videoService.muteAllVideos();
    } else {
      _videoService.unmuteAllVideos();
    }

    // Track analytics
    _trackAnalyticsEvent(_posts[_currentPage].id, 'volume_toggle', {
      'muted': _isMuted,
    });

    // Show brief feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMuted ? 'Videos muted' : 'Videos unmuted'),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _onPostShare(PostModel post) async {
    try {
      // Track analytics first
      _analyticsService.trackShareAttempt(
        post.id,
        'system_share',
        postType: post.type.toString(),
        successful: null, // Will be updated after share attempt
      );

      // Get avatar info for sharing
      final avatar = _avatarCache[post.avatarId];
      final shareText = '${avatar?.name ?? 'Avatar'}: ${post.caption}';
      final shareUrl = _shareService.generatePostLink(post.id);
      
      // Share using ShareService.shareToExternal
      await _shareService.shareToExternal(shareText, shareUrl);
      
      // Record the share in database
      await _feedsService.sharePost(post.id, platform: 'native_share');
      
      // Track successful share
      _analyticsService.trackShareAttempt(
        post.id,
        'system_share',
        postType: post.type.toString(),
        successful: true,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post shared successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error sharing post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share post. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onPostSave(PostModel post) async {
    try {
      final newBookmarkedStatus = await _feedsService.toggleBookmark(post.id);
      
      setState(() {
        _bookmarkedStatus[post.id] = newBookmarkedStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newBookmarkedStatus ? 'Post saved!' : 'Post removed from saved'),
          duration: Duration(seconds: 2),
        ),
      );

      // Track analytics
      _analyticsService.trackBookmarkToggle(
        post.id,
        newBookmarkedStatus,
        postType: post.type.toString(),
      );
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save post. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }



  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SkeletonLoader.videoFeed(),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadInitialPosts,
                child: Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty && !_isLoading && !_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore, color: Colors.white54, size: 64),
              SizedBox(height: 16),
              Text(
                'No posts available',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Check back later for new content!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadInitialPosts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    // Edge-to-edge immersive look: no AppBar, overlays instead
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          // Vertical page feed with real data
          NotificationListener<ScrollEndNotification>(
            onNotification: (scrollEnd) {
              final metrics = scrollEnd.metrics;
              if (metrics.atEdge && metrics.pixels != 0) {
                // Near the end, load more posts
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

                // Load more posts when near end
                if (index >= _posts.length - 2) {
                  _loadMorePosts();
                }

                if (index < _posts.length) {
                  final currentPost = _posts[index];
                  
                  // Handle video playback - pause previous, play current
                  if (index > 0 && index - 1 < _posts.length) {
                    _pauseVideoForPost(_posts[index - 1]);
                  }
                  if (index + 1 < _posts.length) {
                    _pauseVideoForPost(_posts[index + 1]);
                  }
                  
                  // Play current video if it's a video post
                  if (currentPost.type == PostType.video) {
                    _playVideoForPost(currentPost);
                  }
                  
                  // Update view count and track analytics
                  _feedsService.incrementViewCount(currentPost.id);
                  
                  _trackAnalyticsEvent(currentPost.id, 'post_view', {
                    'post_type': currentPost.type.toString(),
                    'author_id': currentPost.avatarId,
                    'page_index': index,
                    'view_method': 'swipe',
                  });
                }
              },
              itemBuilder: (context, index) {
                if (index >= _posts.length) {
                  // Loading indicator at end
                  return Center(child: CircularProgressIndicator());
                }

                final post = _posts[index];
                final avatar = _avatarCache[post.avatarId];

                return PostItem(
                  imageUrl: post.type == PostType.image
                      ? (post.imageUrl ?? '')
                      : (post.thumbnailUrl ?? ''),
                  videoUrl: post.type == PostType.video ? post.videoUrl : null,
                  isVideo: post.type == PostType.video,
                  author: avatar?.name ?? 'Unknown Avatar',
                  avatarUrl: avatar?.avatarImageUrl,
                  description: post.caption,
                  likes: _formatCount(post.likesCount),
                  comments: _formatCount(post.commentsCount),
                  isLiked: _likedStatus[post.id] ?? false,
                  isBookmarked: _bookmarkedStatus[post.id] ?? false,
                  isFollowing: _followingStatus[post.avatarId] ?? false,
                  onLike: () => _onPostLike(post),
                  onComment: () => _onPostComment(post),
                  onShare: () => _onPostShare(post),
                  onSave: () => _onPostSave(post),
                  onAvatarTap: () => _onAvatarTap(post),
                );
              },
            ),
          ),

          // Top overlay buttons with navigation
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Left: back button if single post, brand text if feed
                  if (widget.postId != null || widget.initialPost != null)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const OverlayIcon(
                        assetPath: 'assets/icons/round-alt-arrow-left-svgrepo-com.svg',
                        size: 40,
                      ),
                    )
                  else
                    const Text(
                      'Quanta',
                      style: TextStyle(
                        color: Color.fromRGBO(0, 0, 0, 0.2),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const Spacer(),
                  // Right: volume and menu dots
                  GestureDetector(
                    onTap: _toggleVolume,
                    child: OverlayIcon(
                      assetPath: _isMuted 
                          ? 'assets/icons/volume.svg'
                          : 'assets/icons/volume-loud-svgrepo-com.svg',
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showPostOptions(),
                    child: const OverlayIcon(
                      assetPath: 'assets/icons/menu-dots-svgrepo-com.svg',
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator for more posts
          if (_isLoadingMore)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading more posts...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
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

  void _showReportDialog(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => ReportContentDialog(
        contentId: post.id,
        contentType: ContentType.post,
        reportedUserId: post.avatarId, // Use avatar ID as the reported user ID
      ),
    );
  }
}

