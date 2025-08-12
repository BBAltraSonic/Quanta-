import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import '../constants.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../services/enhanced_video_service.dart';
import '../widgets/comments_modal.dart';


/// Enhanced post item widget with full functionality
class EnhancedPostItem extends StatefulWidget {
  final PostModel post;
  final AvatarModel? avatar;
  final bool isActive;
  final bool isLiked;
  final bool isFollowing;
  final bool isBookmarked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;
  final Function(bool isPlaying)? onPlayStateChanged;
  final Function(Duration position)? onPositionChanged;

  const EnhancedPostItem({
    super.key,
    required this.post,
    this.avatar,
    this.isActive = false,
    this.isLiked = false,
    this.isFollowing = false,
    this.isBookmarked = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onAvatarTap,
    this.onFollow,
    this.onMore,
    this.onPlayStateChanged,
    this.onPositionChanged,
  });

  @override
  State<EnhancedPostItem> createState() => _EnhancedPostItemState();
}

class _EnhancedPostItemState extends State<EnhancedPostItem>
    with TickerProviderStateMixin {
  final EnhancedVideoService _videoService = EnhancedVideoService();
  
  // Animation controllers
  late AnimationController _likeAnimationController;
  late AnimationController _playButtonAnimationController;
  late Animation<double> _likeScaleAnimation;
  late Animation<double> _playButtonOpacityAnimation;
  
  bool _showPlayButton = false;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupVideoPlayer();
  }

  void _setupAnimations() {
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _playButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _likeScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));

    _playButtonOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _playButtonAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupVideoPlayer() {
    if (widget.post.type == PostType.video && widget.post.videoUrl != null) {
      _videoService.preloadVideo(widget.post.videoUrl!);
    }
  }

  @override
  void didUpdateWidget(EnhancedPostItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.isActive != widget.isActive) {
      _handleActiveStateChange();
    }
    
    if (oldWidget.isLiked != widget.isLiked && widget.isLiked) {
      _animateLike();
    }
  }

  void _handleActiveStateChange() {
    if (widget.post.type == PostType.video && widget.post.videoUrl != null) {
      if (widget.isActive) {
        _playVideo();
      } else {
        _pauseVideo();
      }
    }
  }

  Future<void> _playVideo() async {
    if (widget.post.videoUrl == null) return;
    
    try {
      await _videoService.playVideo(widget.post.videoUrl!);
      setState(() {
        _isPlaying = true;
        _showPlayButton = false;
      });
      _playButtonAnimationController.reverse();
    } catch (e) {
      debugPrint('Error playing video: $e');
    }
  }

  Future<void> _pauseVideo() async {
    if (widget.post.videoUrl == null) return;
    
    try {
      await _videoService.pauseVideo(widget.post.videoUrl!);
      setState(() {
        _isPlaying = false;
        _showPlayButton = true;
      });
      _playButtonAnimationController.forward();
    } catch (e) {
      debugPrint('Error pausing video: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    if (widget.post.videoUrl == null) return;
    
    final isPlaying = await _videoService.togglePlayPause(widget.post.videoUrl!);
    setState(() {
      _isPlaying = isPlaying;
      _showPlayButton = !isPlaying;
    });
    
    if (isPlaying) {
      _playButtonAnimationController.reverse();
    } else {
      _playButtonAnimationController.forward();
    }
    
    widget.onPlayStateChanged?.call(isPlaying);
  }

  void _animateLike() {
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });
    HapticFeedback.lightImpact();
  }

  void _onDoubleTap() {
    widget.onLike?.call();
    _animateLike();
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _playButtonAnimationController.dispose();
    super.dispose();
  }

  Widget _iconWithCounter({required String asset, String? count}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          asset,
          width: 28,
          height: 28,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        if (count != null && count.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      onTap: widget.post.type == PostType.video ? _togglePlayPause : null,
      child: Stack(
        children: [
          // Background media
          Positioned.fill(
            child: _buildMediaBackground(),
          ),

          // Video controls overlay
          if (widget.post.type == PostType.video) ...[
            _buildVideoControls(),
          ],

          // Like animation overlay
          _buildLikeAnimationOverlay(),

          // Content overlay
          Positioned(
            left: 16,
            right: 80,
            bottom: 90,
            child: _buildContentOverlay(),
          ),

          // Side actions
          Positioned(
            right: 16,
            bottom: 120,
            child: _buildSideActions(),
          ),

          // Progress indicator
          if (widget.post.type == PostType.video) ...[
            _buildProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaBackground() {
    if (widget.post.type == PostType.video && widget.post.videoUrl != null) {
      final controller = _videoService.getVideoController(widget.post.videoUrl!);
      
      if (controller != null && controller.value.isInitialized) {
        return VideoPlayer(controller);
      } else {
        // Show thumbnail while loading
        return Container(
          color: Colors.black,
          child: widget.post.thumbnailUrl != null
              ? Image.network(
                  widget.post.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildErrorState(),
                )
              : _buildLoadingState(),
        );
      }
    } else if (widget.post.imageUrl != null) {
      // Image post
      return Image.network(
        widget.post.imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingState();
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorState(),
      );
    } else {
      return _buildErrorState();
    }
  }

  Widget _buildLoadingState() {
              return Container(
                color: Colors.grey[900],
      child: const Center(
                  child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
  }

  Widget _buildErrorState() {
              return Container(
                color: Colors.grey[900],
                child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'Content not available',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _playButtonOpacityAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _showPlayButton ? _playButtonOpacityAnimation.value : 0.0,
            child: Container(
              color: Colors.black26,
              child: const Center(
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 64,
                ),
                  ),
                ),
              );
            },
      ),
    );
  }

  Widget _buildLikeAnimationOverlay() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _likeScaleAnimation,
        builder: (context, child) {
          return Center(
            child: Transform.scale(
              scale: widget.isLiked ? _likeScaleAnimation.value : 0.0,
                  child: Icon(
                Icons.favorite,
                color: Colors.red.withOpacity(0.8),
                size: 100,
                  ),
                ),
              );
            },
      ),
    );
  }

  Widget _buildContentOverlay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar and info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
              onTap: widget.onAvatarTap,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 16,
                    backgroundImage: widget.avatar?.avatarImageUrl != null
                        ? NetworkImage(widget.avatar!.avatarImageUrl!)
                        : const AssetImage('assets/images/p.jpg') as ImageProvider,
                    onBackgroundImageError: (exception, stackTrace) {
                      debugPrint('Error loading avatar image: $exception');
                    },
                        ),
                        // AI indicator
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.avatar?.name ?? 'Unknown Avatar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!widget.isFollowing) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: widget.onFollow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(height: 4),
                        Text(
                    widget.post.caption,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.25,
                          ),
                        ),
                  
                  // Hashtags
                  if (widget.post.hashtags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.post.hashtags.take(3).map((hashtag) {
                        return Text(
                          '#$hashtag',
                          style: TextStyle(
                            color: kPrimaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        
              const SizedBox(height: 12),

              // Interaction row
        Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
              onTap: widget.onLike,
              child: AnimatedBuilder(
                animation: _likeScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.isLiked ? _likeScaleAnimation.value : 1.0,
                      child: _iconWithCounter(
                      asset: widget.isLiked 
                          ? 'assets/icons/heart-svgrepo-com.svg'
                          : 'assets/icons/heart-svgrepo-com.svg',
                      count: _formatCount(widget.post.likesCount),
                    ),
                  );
                },
              ),
                    ),
                    GestureDetector(
              onTap: widget.onComment ?? () {
                openCommentsModal(
                  context,
                  postId: widget.post.id,
                );
                          },
                      child: _iconWithCounter(
                asset: 'assets/icons/chat-round-svgrepo-com.svg',
                count: _formatCount(widget.post.commentsCount),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onShare,
                      child: _iconWithCounter(
                asset: 'assets/icons/reply-svgrepo-com.svg',
                count: widget.post.sharesCount > 0 
                    ? _formatCount(widget.post.sharesCount) 
                    : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onSave,
              child: SvgPicture.asset(
                widget.isBookmarked
                    ? 'assets/icons/bookmark-svgrepo-com.svg'
                    : 'assets/icons/bookmark-svgrepo-com.svg',
                width: 28,
                height: 28,
                colorFilter: ColorFilter.mode(
                  widget.isBookmarked ? kPrimaryColor : Colors.white,
                  BlendMode.srcIn,
                ),
                      ),
                    ),
                  ],
        ),
      ],
    );
  }

  Widget _buildSideActions() {
    return Column(
      children: [
        // More options
        GestureDetector(
          onTap: widget.onMore,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // View count
        if (widget.post.viewsCount > 0) ...[
          Column(
            children: [
              const Icon(
                Icons.visibility,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                _formatCount(widget.post.viewsCount),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProgressIndicator() {
    if (widget.post.videoUrl == null) return const SizedBox.shrink();
    
    final controller = _videoService.getVideoController(widget.post.videoUrl!);
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Positioned(
            left: 4,
            right: 4,
            bottom: 74,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          final progress = value.duration.inMilliseconds > 0
              ? value.position.inMilliseconds / value.duration.inMilliseconds
              : 0.0;
              
          return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
              ),
          );
        },
          ),
    );
  }
}