import 'package:flutter/material.dart';
import 'package:flutter_social_ui/widgets/post_item.dart';
import 'package:flutter_social_ui/widgets/overlay_icon.dart';
import 'package:flutter_social_ui/screens/chat_screen.dart';
import 'package:flutter_social_ui/services/content_service_wrapper.dart';
import 'package:flutter_social_ui/services/avatar_service.dart';
import 'package:flutter_social_ui/models/post_model.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PageController _pageController = PageController();
  final ContentService _contentService = ContentService();
  final AvatarService _avatarService = AvatarService();

  List<PostModel> _posts = [];
  Map<String, AvatarModel> _avatarCache = {};
  bool _isLoading = true;
  bool _hasError = false;
  final String _errorMessage = '';
  int _currentPage = 0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _contentService.initialize();
      _loadInitialPosts();
    } catch (e) {
      debugPrint('Error initializing services: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadInitialPosts() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final posts = await _contentService.getFeedPosts(
        limit: 10,
        orderByTrending: true,
      );

      if (posts.isNotEmpty) {
        // Cache avatars for loaded posts
        await _cacheAvatarsForPosts(posts);

        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      } else {
        // No posts available
        setState(() {
          _posts = [];
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      setState(() {
        _posts = [];
        _isLoading = false;
        _hasError = true;
      });
    }
  }



  Future<void> _cacheAvatarsForPosts(List<PostModel> posts) async {
    final avatarIds = posts.map((p) => p.avatarId).toSet();

    for (String avatarId in avatarIds) {
      if (!_avatarCache.containsKey(avatarId)) {
        try {
          final avatar = await _avatarService.getAvatar(avatarId);
          if (avatar != null) {
            _avatarCache[avatarId] = avatar;
          }
        } catch (e) {
          debugPrint('Error caching avatar $avatarId: $e');
        }
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newPosts = await _contentService.getFeedPosts(
        limit: 10,
        offset: _posts.length,
        orderByTrending: true,
      );

      if (newPosts.isNotEmpty) {
        await _cacheAvatarsForPosts(newPosts);

        setState(() {
          _posts.addAll(newPosts);
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

  void _onPostLike(PostModel post) async {
    try {
      await _contentService.updatePostEngagement(
        post.id,
        likesIncrement: 1,
        viewsIncrement: 1,
      );

      // Update local state
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        setState(() {
          _posts[index] = _posts[index].copyWith(
            likesCount: _posts[index].likesCount + 1,
            viewsCount: _posts[index].viewsCount + 1,
          );
        });
      }
    } catch (e) {
      debugPrint('Error liking post: $e');
    }
  }

  void _onPostComment(PostModel post) {
    // Navigate to comments or show comment sheet
    // For now, just increment comment count
    _onCommentAdded(post);
  }

  void _onCommentAdded(PostModel post) async {
    try {
      await _contentService.updatePostEngagement(post.id, commentsIncrement: 1);

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
            avatar: avatar.imageUrl ?? 'assets/images/p.jpg',
          ),
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
                  _contentService.updatePostEngagement(
                    _posts[index].id,
                    viewsIncrement: 1,
                  );
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
                  imageUrl: post.hasMedia
                      ? post.mediaUrl
                      : 'assets/images/p.jpg',
                  author: avatar?.name ?? 'Unknown Avatar',
                  description: post.caption,
                  likes: _formatCount(post.likesCount),
                  comments: _formatCount(post.commentsCount),
                  onLike: () => _onPostLike(post),
                  onComment: () => _onPostComment(post),
                  onAvatarTap: () => _onAvatarTap(post),
                );
              },
            ),
          ),

          // Top overlay buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: const [
                  OverlayIcon(
                    assetPath: 'assets/icons/volume-loud-svgrepo-com.svg',
                    size: 40,
                  ),
                  Spacer(),
                  OverlayIcon(
                    assetPath: 'assets/icons/menu-dots-svgrepo-com.svg',
                    size: 40,
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
