import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_social_ui/screens/chat_screen.dart';
import 'package:flutter_social_ui/widgets/video_player_widget.dart';
import 'comments_modal.dart';

enum PostMediaType { image, video }

class EnhancedPostItem extends StatefulWidget {
  final String? postId;
  final String? imageUrl;
  final String? videoUrl;
  final PostMediaType mediaType;
  final String author;
  final String description;
  final String likes;
  final String comments;
  final String? avatarUrl;
  final bool isPlaying;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onPlayPause;
  final bool isLiked;
  final bool isSaved;

  const EnhancedPostItem({
    super.key,
    this.postId,
    this.imageUrl,
    this.videoUrl,
    this.mediaType = PostMediaType.image,
    required this.author,
    required this.description,
    required this.likes,
    required this.comments,
    this.avatarUrl,
    this.isPlaying = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onAvatarTap,
    this.onPlayPause,
    this.isLiked = false,
    this.isSaved = false,
  });

  @override
  State<EnhancedPostItem> createState() => _EnhancedPostItemState();
}

class _EnhancedPostItemState extends State<EnhancedPostItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _handleLike() {
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });
    widget.onLike?.call();
  }

  Widget _iconWithCounter({
    required String asset,
    String? count,
    bool isActive = false,
    Animation<double>? animation,
  }) {
    Widget iconWidget = SvgPicture.asset(
      asset,
      width: 28,
      height: 28,
      colorFilter: ColorFilter.mode(
        isActive ? Colors.red : Colors.white,
        BlendMode.srcIn,
      ),
    );

    if (animation != null) {
      iconWidget = AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: animation.value,
            child: child,
          );
        },
        child: iconWidget,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
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

  Widget _buildMediaContent() {
    switch (widget.mediaType) {
      case PostMediaType.video:
        return VideoPlayerWidget(
          videoUrl: widget.videoUrl,
          fallbackImageUrl: widget.imageUrl,
          isPlaying: widget.isPlaying,
          onPlayPause: widget.onPlayPause,
        );
      case PostMediaType.image:
        return _buildImageContent();
    }
  }

  Widget _buildImageContent() {
    final url = widget.imageUrl ?? 'assets/images/p.jpg';
    
    return url.startsWith('http')
        ? Image.network(
            url,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: child,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[900],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              );
            },
          )
        : Image.asset(
            url,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Edge-to-edge media content
        Positioned.fill(
          child: _buildMediaContent(),
        ),

        // Bottom overlays: caption cluster + interaction row
        Positioned(
          left: 16,
          right: 16,
          bottom: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Caption cluster
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: widget.onAvatarTap ??
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                name: widget.author,
                                avatar: widget.avatarUrl ?? 'assets/images/p.jpg',
                              ),
                            ),
                          );
                        },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: widget.avatarUrl != null
                              ? (widget.avatarUrl!.startsWith('http')
                                  ? NetworkImage(widget.avatarUrl!)
                                  : AssetImage(widget.avatarUrl!)) as ImageProvider
                              : const AssetImage('assets/images/p.jpg'),
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
                        Text(
                          widget.author,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interaction row
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _handleLike,
                      child: _iconWithCounter(
                        asset: 'assets/icons/like.svg',
                        count: widget.likes,
                        isActive: widget.isLiked,
                        animation: widget.isLiked ? _likeAnimation : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onComment ??
                          () {
                            openCommentsModal(context, postId: widget.postId ?? 'unknown');
                          },
                      child: _iconWithCounter(
                        asset: 'assets/icons/comment.svg',
                        count: widget.comments,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onShare,
                      child: _iconWithCounter(
                        asset: 'assets/icons/share.svg',
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onSave,
                      child: _iconWithCounter(
                        asset: 'assets/icons/save.svg',
                        isActive: widget.isSaved,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Video progress indicator (only for videos)
        if (widget.mediaType == PostMediaType.video)
          Positioned(
            left: 4,
            right: 4,
            bottom: 74,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: 0.7, // TODO: Connect to actual video progress
                minHeight: 3,
                backgroundColor: Colors.white.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
              ),
            ),
          ),
      ],
    );
  }
}
