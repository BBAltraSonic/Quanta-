import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../models/user_model.dart';
import '../widgets/feeds_video_player.dart';
import '../screens/enhanced_comments_screen.dart';
import '../constants.dart';

class VideoFeedItem extends StatefulWidget {
  final PostModel post;
  final AvatarModel? avatar;
  final UserModel? user;
  final bool isActive;
  final bool isLiked;
  final bool isFollowing;
  final VoidCallback? onLike;
  final VoidCallback? onFollow;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onProfileTap;
  final ValueChanged<bool>? onPlayStateChanged;

  const VideoFeedItem({
    super.key,
    required this.post,
    this.avatar,
    this.user,
    this.isActive = false,
    this.isLiked = false,
    this.isFollowing = false,
    this.onLike,
    this.onFollow,
    this.onComment,
    this.onShare,
    this.onProfileTap,
    this.onPlayStateChanged,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  bool _showLikeAnimation = false;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _likeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (!widget.isLiked) {
      widget.onLike?.call();
      _triggerLikeAnimation();
    }
  }

  void _triggerLikeAnimation() {
    setState(() {
      _showLikeAnimation = true;
    });
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reset();
      setState(() {
        _showLikeAnimation = false;
      });
    });
  }

  void _handleShare() {
    widget.onShare?.call();
    // Generate a shareable link for the video
    final videoUrl = widget.post.videoUrl ?? '';
    final caption = widget.post.caption;
    final avatarName = widget.avatar?.name ?? 'Unknown';
    
    Share.share(
      '$caption\n\nShared from @$avatarName on Quanta\n$videoUrl',
      subject: 'Check out this video on Quanta',
    );
  }

  void _openComments() {
    widget.onComment?.call();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedCommentsScreen(
          postId: widget.post.id,
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildAvatar() {
    final imageUrl = widget.avatar?.avatarImageUrl;
    
    return GestureDetector(
      onTap: widget.onProfileTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          backgroundColor: Colors.grey[800],
          backgroundImage: imageUrl != null && imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : null,
          child: imageUrl == null || imageUrl.isEmpty
              ? Text(
                  widget.avatar?.name.substring(0, 1).toUpperCase() ?? 'A',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFollowButton() {
    if (widget.isFollowing) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: widget.onFollow,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: kPrimaryColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: 32,
            ),
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
        ),
      ),
    );
  }

  Widget _buildCaptionOverlay() {
    final avatarName = widget.avatar?.name ?? 'Unknown';
    final timeAgo = timeago.format(widget.post.createdAt);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.4),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username and time
          Row(
            children: [
              Text(
                '@$avatarName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeAgo,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Caption
          if (widget.post.caption.isNotEmpty)
            Text(
              widget.post.caption,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          
          const SizedBox(height: 8),
          
          // Hashtags
          if (widget.post.hashtags.isNotEmpty)
            Wrap(
              spacing: 8,
              children: widget.post.hashtags.take(3).map((hashtag) {
                return Text(
                  hashtag,
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = widget.post.videoUrl;
    
    if (videoUrl == null || videoUrl.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Video not available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Player
        FeedsVideoPlayer(
          videoUrl: videoUrl,
          isActive: widget.isActive,
          onDoubleTap: _handleDoubleTap,
          onPlayStateChanged: widget.onPlayStateChanged,
        ),

        // Right side actions
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              // Avatar with follow button
              Column(
                children: [
                  _buildAvatar(),
                  _buildFollowButton(),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Like button
              _buildActionButton(
                icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                count: _formatCount(widget.post.likesCount),
                onTap: () {
                  widget.onLike?.call();
                  if (!widget.isLiked) {
                    _triggerLikeAnimation();
                  }
                },
                iconColor: widget.isLiked ? Colors.red : Colors.white,
              ),
              
              const SizedBox(height: 16),
              
              // Comment button
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                count: _formatCount(widget.post.commentsCount),
                onTap: _openComments,
              ),
              
              const SizedBox(height: 16),
              
              // Share button
              _buildActionButton(
                icon: Icons.share,
                count: _formatCount(widget.post.sharesCount),
                onTap: _handleShare,
              ),
            ],
          ),
        ),

        // Bottom caption overlay
        Positioned(
          left: 0,
          right: 80,
          bottom: 0,
          child: _buildCaptionOverlay(),
        ),

        // Like animation
        if (_showLikeAnimation)
          Center(
            child: AnimatedBuilder(
              animation: _likeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (1.2 * _likeAnimation.value),
                  child: Opacity(
                    opacity: 1.0 - _likeAnimation.value,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 100,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
