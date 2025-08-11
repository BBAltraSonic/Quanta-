import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/comment.dart';
import '../services/feeds_service.dart';
import '../constants.dart';

class EnhancedCommentsScreen extends StatefulWidget {
  final String postId;
  
  const EnhancedCommentsScreen({
    super.key,
    required this.postId,
  });

  @override
  State<EnhancedCommentsScreen> createState() => _EnhancedCommentsScreenState();
}

class _EnhancedCommentsScreenState extends State<EnhancedCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final FeedsService _feedsService = FeedsService();
  final ScrollController _scrollController = ScrollController();
  
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  RealtimeChannel? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _subscribeToRealTimeUpdates();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _realtimeSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final comments = await _feedsService.getComments(widget.postId);
      
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load comments'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      debugPrint('Error loading comments: $e');
    }
  }

  void _subscribeToRealTimeUpdates() {
    _realtimeSubscription = _feedsService.subscribeToComments(
      widget.postId,
      (newComment) {
        if (mounted) {
          setState(() {
            _comments.insert(0, newComment);
          });
          // Scroll to top to show new comment
          _scrollToTop();
        }
      },
    );
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    try {
      setState(() {
        _isSubmitting = true;
      });

      // Haptic feedback
      HapticFeedback.lightImpact();

      final comment = await _feedsService.addComment(widget.postId, text);
      
      if (comment != null && mounted) {
        // Clear the input
        _commentController.clear();
        _commentFocusNode.unfocus();
        
        // The real-time subscription will handle adding the comment to the list
        // But if it's our own comment, we might want to add it immediately
        if (!_comments.any((c) => c.id == comment.id)) {
          setState(() {
            _comments.insert(0, comment);
          });
          _scrollToTop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to post comment'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      debugPrint('Error submitting comment: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[800]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_comments.length} Comments',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: _buildCommentsList(),
          ),

          // Comment Input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: Colors.white54,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No comments yet',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to comment!',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return _buildCommentTile(comment);
      },
    );
  }

  Widget _buildCommentTile(Comment comment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[700],
            child: Text(
              comment.userName?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and time
                Row(
                  children: [
                    Text(
                      comment.userName ?? 'Anonymous',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Comment text
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Actions
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // TODO: Implement comment like functionality
                        HapticFeedback.lightImpact();
                      },
                      child: Row(
                        children: [
                          Icon(
                            comment.hasLiked ? Icons.favorite : Icons.favorite_border,
                            color: comment.hasLiked ? Colors.red : Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            comment.likesCount.toString(),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    GestureDetector(
                      onTap: () {
                        // TODO: Implement reply functionality
                        HapticFeedback.lightImpact();
                      },
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(
            color: Colors.grey[800]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[700],
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 18,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Text input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  isDense: true,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Send button
          GestureDetector(
            onTap: _isSubmitting ? null : _submitComment,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _commentController.text.trim().isNotEmpty && !_isSubmitting
                    ? kPrimaryColor
                    : Colors.grey[600],
                shape: BoxShape.circle,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 16,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
