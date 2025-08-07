import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'comments_modal.dart';

class PostItem extends StatelessWidget {
  final String imageUrl;
  final String author;
  final String description;
  final String likes;
  final String comments;

  const PostItem({
    super.key,
    required this.imageUrl,
    required this.author,
    required this.description,
    required this.likes,
    required this.comments,
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
        // Edge-to-edge media
        Positioned.fill(child: Image.asset(imageUrl, fit: BoxFit.cover)),

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
                  const CircleAvatar(
                    radius: 16,
                    backgroundImage: AssetImage('assets/images/p.jpg'),
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
                    _iconWithCounter(
                      asset: 'assets/icons/heart-svgrepo-com.svg', // like
                      count: likes,
                    ),
                    GestureDetector(
                      onTap: () {
                        openCommentsModal(context);
                      },
                      child: _iconWithCounter(
                        asset:
                            'assets/icons/chat-round-svgrepo-com.svg', // comment
                        count: comments,
                      ),
                    ),
                    _iconWithCounter(
                      asset: 'assets/icons/reply-svgrepo-com.svg', // share
                    ),
                    _iconWithCounter(
                      asset: 'assets/icons/bookmark-svgrepo-com.svg', // save
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom progress line (mocked)
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
