import 'package:flutter/material.dart';
import 'package:flutter_social_ui/widgets/post_item.dart';
import 'package:flutter_social_ui/widgets/overlay_icon.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PageController _pageController = PageController();

  final List<Map<String, String>> dummyPosts = [
    {
      'imageUrl': 'assets/images/p.jpg',
      'author': 'Chris Glasser',
      'description':
          'Drone hyperlapse of the Dubai skyline during golden hour. #dubai #hyperlapse',
      'likes': '12.2k',
      'comments': '137',
    },
    {
      'imageUrl': 'assets/images/p.jpg',
      'author': 'Another User',
      'description': 'Beautiful sunset over the ocean. #travel #beach',
      'likes': '5.1k',
      'comments': '50',
    },
    {
      'imageUrl': 'assets/images/p.jpg',
      'author': 'Travel Bug',
      'description': 'Exploring ancient ruins. #history #adventure',
      'likes': '8.9k',
      'comments': '90',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Edge-to-edge immersive look: no AppBar, overlays instead
    return Scaffold(
      backgroundColor: Colors
          .transparent, // Make Scaffold background transparent so nav area shows through
      extendBody: true, // Allow bottom nav to draw over body with transparency
      body: Stack(
        children: [
          // Vertical page feed
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: dummyPosts.length,
            itemBuilder: (context, index) {
              final post = dummyPosts[index];
              return PostItem(
                imageUrl: post['imageUrl']!,
                author: post['author']!,
                description: post['description']!,
                likes: post['likes']!,
                comments: post['comments']!,
              );
            },
          ),

          // Top overlay circular buttons (volume, menu) - search removed (bottom nav has Search)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: const [
                  // Move volume to the left
                  OverlayIcon(
                    assetPath:
                        'assets/icons/volume-loud-svgrepo-com.svg', // volume
                    size: 40,
                  ),
                  Spacer(),
                  OverlayIcon(
                    assetPath: 'assets/icons/menu-dots-svgrepo-com.svg', // menu
                    size: 40,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
