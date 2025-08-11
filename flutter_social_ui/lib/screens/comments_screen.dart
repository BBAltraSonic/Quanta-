import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import '../models/comment.dart';
import '../services/comment_service.dart';
import '../widgets/comment_tile.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final List<Comment>? initialComments;
  
  const CommentsScreen({
    super.key,
    required this.postId,
    this.initialComments,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _commentController = TextEditingController();
  final _commentService = CommentService();
  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _comments = widget.initialComments ?? [];
    if (_comments.isEmpty) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _commentService.getPostComments(postId: widget.postId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comments: $e')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final comment = await _commentService.addComment(
        postId: widget.postId,
        text: text,
      );
      
      setState(() {
        _comments.insert(0, comment);
        _commentController.clear();
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }

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
                  child:                   TextField(
                    controller: _commentController,
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
                    enabled: !_isSubmitting,
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: kPrimaryColor,
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
          // Comment List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
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
                              'No comments yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(kDefaultPadding),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: CommentTile(comment: comment),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


