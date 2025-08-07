import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';

class CommentsScreen extends StatelessWidget {
  const CommentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('44 Comments'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.filter_list,
            ), // Placeholder for filter/sort icon
            onPressed: () {
              // Handle filter/sort
            },
          ),
          IconButton(
            icon: const Icon(Icons.close), // Close icon
            onPressed: () {
              Navigator.pop(context); // Close the comments screen
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Comment Input Field
          Padding(
            padding: const EdgeInsets.all(kDefaultPadding),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundImage: AssetImage(
                    'assets/images/p.jpg',
                  ), // User avatar
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: kLightTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: kCardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: kDefaultPadding,
                        vertical: 10,
                      ),
                    ),
                    style: TextStyle(color: kTextColor),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: kPrimaryColor,
                  onPressed: () {
                    // Handle send comment
                  },
                ),
              ],
            ),
          ),
          // Comment List
          Expanded(
            child: ListView.builder(
              itemCount: 4, // Example: 4 comments
              itemBuilder: (context, index) {
                return const CommentItem();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CommentItem extends StatelessWidget {
  const CommentItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kDefaultPadding,
        vertical: kDefaultPadding / 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundImage: AssetImage(
              'assets/images/p.jpg',
            ), // Commenter avatar
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Kurt Bates', // Example commenter name
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '14m', // Example time elapsed
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'That\'s the dopest hyperlapse video I\'ve ever seen mate', // Example comment text
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 16,
                      color: kLightTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text('4', style: TextStyle(color: kLightTextColor)),
                    const SizedBox(width: 16),
                    Text('REPLY', style: TextStyle(color: kLightTextColor)),
                    const SizedBox(width: 16),
                    Text(
                      'View All 8 Replies',
                      style: TextStyle(color: kPrimaryColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
