import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';

class CommentsScreen extends StatelessWidget {
  const CommentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  child: Icon(
                    Icons.person,
                    color: Colors.grey[600],
                  ),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Comment functionality is not yet implemented'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Comment List
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Comments not available',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Comment system is not yet implemented.\nPlease ensure the backend service is configured.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
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


