import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_social_ui/screens/chat_screen.dart';
import 'package:flutter_social_ui/widgets/video_player_widget.dart';


class PostItem extends StatelessWidget {
  final String imageUrl;
  final String author;
  final String description;
  final String likes;
  final String comments;
  final String? avatarUrl;
  final String? videoUrl;
  final bool isVideo;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onAvatarTap;

  const PostItem({
    super.key,
    required this.imageUrl,
    required this.author,
    required this.description,
    required this.likes,
    required this.comments,
    this.avatarUrl,
    this.videoUrl,
    this.isVideo = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onAvatarTap,
  });

  Widget _iconWithCounter({required String asset, String? count}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          asset,
          width: 28, // bigger reaction icons
          height: 28,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        if (count != null && count.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            count,
            // bigger, higher contrast, aligned with caption baseline feel
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Edge-to-edge media with video/image support
        Positioned.fill(
          child: isVideo && videoUrl != null
              ? VideoPlayerWidget(
                  videoUrl: videoUrl,
                  fallbackImageUrl: imageUrl,
                  isPlaying: true, // Auto-play for feeds
                  onTap: () {
                    // Handle video tap
                  },
                )
              : imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
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
                      imageUrl,
                      fit: BoxFit.cover,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
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
                    ),
        ),

        // Top overlay: search, Spacer, volume, 12, menu

        // Bottom overlays: caption cluster + interaction row
        Positioned(
          left: 16,
          right: 16,
          bottom: 90, // lowered section a bit toward the bottom
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Caption cluster
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap:
                        onAvatarTap ??
                        () {
                          // Fallback navigation to avatar chat
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                name: author,
                                avatar: 'assets/images/p.jpg',
                              ),
                            ),
                          );
                        },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                              ? (avatarUrl!.startsWith('http')
                                  ? NetworkImage(avatarUrl!) as ImageProvider
                                  : AssetImage(avatarUrl!))
                              : const AssetImage('assets/images/p.jpg'),
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
                        Text(
                          author,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
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

              // Interaction row (larger icons and text, aligned with caption)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: _iconWithCounter(
                        asset: 'assets/icons/heart-svgrepo-com.svg', // like
                        count: likes,
                      ),
                    ),
                    GestureDetector(
                      onTap: onComment,
                      child: _iconWithCounter(
                        asset:
                            'assets/icons/chat-round-svgrepo-com.svg', // comment
                        count: comments,
                      ),
                    ),
                    GestureDetector(
                      onTap: onShare,
                      child: _iconWithCounter(
                        asset: 'assets/icons/reply-svgrepo-com.svg', // share
                      ),
                    ),
                    GestureDetector(
                      onTap: onSave,
                      child: _iconWithCounter(
                        asset: 'assets/icons/bookmark-svgrepo-com.svg', // save
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Progress indicator
        Positioned(
          left: 4,
          right: 4,
          bottom: 74, // keep progress bar aligned beneath the lowered section
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.7,
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
