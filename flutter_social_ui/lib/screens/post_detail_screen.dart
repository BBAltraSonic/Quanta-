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
    // Track analytics events
    debugPrint('Analytics: $event for post $postId with data: $data');
    
    // In a real app, you would send this to your analytics service
    // For now, we'll just log it
    try {
      // Example: Analytics.track(event, {
      //   'post_id': postId,
      //   'timestamp': DateTime.now().toIso8601String(),
      //   ...data,
      // });
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

        setState(() {
          _posts = posts;
          _isLoading = false;
        });
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
      _trackAnalyticsEvent(post.id, 'like_toggle', {
        'liked': newLikedStatus,
        'post_type': post.type.toString(),
        'author_id': post.avatarId,
        'likes_count': post.likesCount + (newLikedStatus ? 1 : -1),
      });
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
    _trackAnalyticsEvent(post.id, 'comment_modal_open', {
      'post_type': post.type.toString(),
      'author_id': post.avatarId,
      'current_comments_count': post.commentsCount,
    });

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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      name: avatar.name,
                      avatar: avatar.avatarImageUrl ?? '', // Let ChatScreen handle missing avatars
                    ),
                  ),
                );
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
      _trackAnalyticsEvent(post.id, 'share_attempt', {
        'post_type': post.type.toString(),
        'share_method': 'system_share',
      });

      // Get avatar info for sharing
      final avatar = _avatarCache[post.avatarId];
      final shareText = '${avatar?.name ?? 'Avatar'}: ${post.caption}';
      final shareUrl = _shareService.generatePostLink(post.id);
      
      // Share using ShareService.shareToExternal
      await _shareService.shareToExternal(shareText, shareUrl);
      
      // Record the share in database
      await _feedsService.sharePost(post.id, platform: 'native_share');
      
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
      _trackAnalyticsEvent(post.id, 'bookmark_toggle', {
        'bookmarked': newBookmarkedStatus,
        'post_type': post.type.toString(),
      });
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading your feed...',
                style: TextStyle(color: Colors.white),
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

                // Update view count for current post and track analytics
                if (index < _posts.length) {
                  _feedsService.incrementViewCount(_posts[index].id);
                  
                  // Track post view analytics
                  _trackAnalyticsEvent(_posts[index].id, 'post_view', {
                    'post_type': _posts[index].type.toString(),
                    'author_id': _posts[index].avatarId,
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
                  // Left: back button if single post, search if feed
                  GestureDetector(
                    onTap: () {
                      if (widget.postId != null || widget.initialPost != null) {
                        Navigator.of(context).pop();
                      } else {
                        // Handle search
                      }
                    },
                    child: OverlayIcon(
                      assetPath: widget.postId != null || widget.initialPost != null 
                          ? 'assets/icons/round-alt-arrow-left-svgrepo-com.svg'
                          : 'assets/icons/magnifer-svgrepo-com.svg',
                      size: 40,
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

