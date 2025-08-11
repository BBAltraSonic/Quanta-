import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_social_ui/widgets/post_item.dart';
import 'package:flutter_social_ui/widgets/overlay_icon.dart';
import 'package:flutter_social_ui/screens/chat_screen.dart';
import 'package:flutter_social_ui/screens/enhanced_comments_screen.dart';
import 'package:flutter_social_ui/services/enhanced_feeds_service.dart';
import 'package:flutter_social_ui/services/enhanced_video_service.dart';
import 'package:flutter_social_ui/models/post_model.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import 'package:flutter_social_ui/config/db_config.dart';
import '../widgets/enhanced_post_item.dart';


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
  
  // State for interactions
  Map<String, bool> _likedStatus = {};
  Map<String, bool> _followingStatus = {};
  Map<String, bool> _bookmarkedStatus = {};
  Map<String, int> _viewStartTimes = {};
  
  // Optimistic update state
  Map<String, bool> _optimisticLikes = {};
  Map<String, bool> _optimisticFollows = {};
  Map<String, bool> _optimisticBookmarks = {};
  
  // Error handling
  Map<String, String> _errors = {};
  
  // Settings
  bool _isMuted = false;
  bool _showControls = true;

  List<PostModel> _posts = [];
  Map<String, AvatarModel> _avatarCache = {};
  Map<String, bool> _likedStatus = {};
  Map<String, bool> _followingStatus = {};
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
      _loadDemoData();
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
        // If no real posts, use demo data
        _loadDemoData();
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      // Fallback to demo data on error
      _loadDemoData();
    }
  }

  void _setError(String message) {
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = message;
    });
  }

  void _loadDemoData() {
    // Create demo posts for when backend is not available
    final demoAvatars = _createDemoAvatars();
    final demoPosts = _createDemoPosts(demoAvatars);

    setState(() {
      _posts = demoPosts;
      _avatarCache = {for (var avatar in demoAvatars) avatar.id: avatar};
      _isLoading = false;
      _hasError = false;
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

  /// Load liked and following status for posts
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
    } catch (e) {
      debugPrint('Error loading engagement status: $e');
    }
  }

  List<AvatarModel> _createDemoAvatars() {
    return [
      AvatarModel.create(
        ownerUserId: 'demo-user-1',
        name: 'Chris Glasser',
        bio: 'Travel enthusiast and adventure seeker',
        niche: AvatarNiche.travel,
        personalityTraits: [
          PersonalityTrait.creative,
          PersonalityTrait.energetic,
        ],
        avatarImageUrl: 'assets/images/p.jpg',
      ),
      AvatarModel.create(
        ownerUserId: 'demo-user-2',
        name: 'TechGuru AI',
        bio: 'Exploring technology and creativity',
        niche: AvatarNiche.tech,
        personalityTraits: [PersonalityTrait.analytical, PersonalityTrait.inspiring],
        avatarImageUrl: 'assets/images/p.jpg',
      ),
      AvatarModel.create(
        ownerUserId: 'demo-user-3',
        name: 'Ocean Explorer',
        bio: 'Nature lover and ocean conservationist',
        niche: AvatarNiche.travel,
        personalityTraits: [PersonalityTrait.calm, PersonalityTrait.inspiring],
        avatarImageUrl: 'assets/images/p.jpg',
      ),
    ];
  }

  List<PostModel> _createDemoPosts(List<AvatarModel> avatars) {
    return [
      PostModel.create(
        avatarId: avatars[0].id,
        type: PostType.image,
        imageUrl: 'assets/images/p.jpg',
        caption:
            'Drone hyperlapse of the Dubai skyline during golden hour. #dubai #hyperlapse',
        hashtags: ['#dubai', '#hyperlapse'],
      ).copyWith(likesCount: 12200, commentsCount: 137, viewsCount: 45000),
      PostModel.create(
        avatarId: avatars[1].id,
        type: PostType.image,
        imageUrl: 'assets/images/p.jpg',
        caption: 'The intersection of technology and creativity is where magic happens. Today I\'m exploring how AI can enhance human creativity rather than replace it. Thoughts? 🤔',
        hashtags: ['#Creativity', '#Tech'],
      ).copyWith(likesCount: 234, commentsCount: 18, viewsCount: 1200),
      PostModel.create(
        avatarId: avatars[2].id,
        type: PostType.image,
        imageUrl: 'assets/images/p.jpg',
        caption: 'Beautiful sunset over the ocean. #travel #beach',
        hashtags: ['#travel', '#beach'],
      ).copyWith(likesCount: 5100, commentsCount: 50, viewsCount: 18000),
    ];
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
    } catch (e) {
      debugPrint('Error liking post: $e');
    }
  }

  void _onPostComment(PostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedCommentsScreen(postId: post.id),
      ),
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
              leading: const Icon(Icons.bookmark_border, color: Colors.white),
              title: const Text('Save', style: TextStyle(color: Colors.white)),
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
                // Handle report
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  void _onCommentAdded(PostModel post) async {
    try {
      await _feedsService.incrementViewCount(post.id);

      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        setState(() {
          _posts[index] = _posts[index].copyWith(
            commentsCount: _posts[index].commentsCount + 1,
          );
        });
      }
    } catch (e) {
      debugPrint('Error updating comment count: $e');
    }
  }

  void _onAvatarTap(PostModel post) {
    final avatar = _avatarCache[post.avatarId];
    if (avatar != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            name: avatar.name,
            avatar: avatar.avatarImageUrl ?? 'assets/images/p.jpg',
          ),
        ),
      );
    }
  }

  void _onPostShare(PostModel post) {
    // TODO: Implement proper share functionality with share_plus package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onPostSave(PostModel post) {
    // TODO: Implement save/bookmark functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post saved!'),
        duration: Duration(seconds: 2),
      ),
    );
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

    if (_posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.post_add, color: Colors.white54, size: 64),
              SizedBox(height: 16),
              Text(
                'No posts yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Follow some avatars to see their content here!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
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

                // Update view count for current post
                if (index < _posts.length) {
                  _feedsService.incrementViewCount(_posts[index].id);
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
                      ? (post.imageUrl ?? 'assets/images/p.jpg')
                      : (post.thumbnailUrl ?? 'assets/images/p.jpg'),
                  videoUrl: post.type == PostType.video ? post.videoUrl : null,
                  isVideo: post.type == PostType.video,
                  author: avatar?.name ?? 'Unknown Avatar',
                  avatarUrl: avatar?.avatarImageUrl,
                  description: post.caption,
                  likes: _formatCount(post.likesCount),
                  comments: _formatCount(post.commentsCount),
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
                  const OverlayIcon(
                    assetPath: 'assets/icons/volume-loud-svgrepo-com.svg',
                    size: 40,
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
}

