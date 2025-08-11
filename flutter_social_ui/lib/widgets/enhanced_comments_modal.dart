import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/comment.dart';
import '../services/enhanced_feeds_service.dart';
import '../services/auth_service.dart';
import '../constants.dart';

/// Enhanced comments modal with realtime updates and infinite scroll
Future<void> openEnhancedCommentsModal(
  BuildContext context, {
  required String postId,
  List<Comment>? initialComments,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (ctx) {
      return EnhancedCommentsModal(
        postId: postId,
        initialComments: initialComments ?? [],
      );
    },
  );
}

class EnhancedCommentsModal extends StatefulWidget {
  final String postId;
  final List<Comment> initialComments;
  
  const EnhancedCommentsModal({
    super.key,
    required this.postId,
    required this.initialComments,
  });

  @override
  State<EnhancedCommentsModal> createState() => _EnhancedCommentsModalState();
}

class _EnhancedCommentsModalState extends State<EnhancedCommentsModal> 
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final EnhancedFeedsService _feedsService = EnhancedFeedsService();
  final AuthService _authService = AuthService();
  
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLoadingMore = false;
  bool _hasMoreComments = true;
  int _currentPage = 0;
  
  // Realtime subscription
  RealtimeChannel? _realtimeSubscription;
  
  // Optimistic updates
  final List<Comment> _optimisticComments = [];
  final Map<String, String> _errors = {};
  
  // Animation controllers
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupScrollListener();
    _loadComments();
    _subscribeToRealTimeUpdates();
  }

  void _setupAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _slideAnimationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreComments();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _slideAnimationController.dispose();
    _realtimeSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (!_hasMoreComments || _isLoadingMore) return;
    
    setState(() {
      if (_currentPage == 0) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final comments = await _feedsService.getComments(
        widget.postId,
        limit: 20,
        offset: _currentPage * 20,
      );

      setState(() {
        if (_currentPage == 0) {
          _comments = widget.initialComments.isNotEmpty 
              ? widget.initialComments 
              : comments;
        } else {
          _comments.addAll(comments);
        }
        
        _hasMoreComments = comments.length >= 20;
        _currentPage++;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading comments: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comments: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadComments,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMoreComments) return;
    await _loadComments();
  }

  void _subscribeToRealTimeUpdates() {
    _realtimeSubscription = _feedsService.subscribeToComments(
      widget.postId,
      (newComment) {
        // Only add if not already in list (avoid duplicates)
        if (!_comments.any((c) => c.id == newComment.id) &&
            !_optimisticComments.any((c) => c.id == newComment.id)) {
          setState(() {
            _comments.insert(0, newComment);
          });
          
          // Show notification for new comment
          if (newComment.userId != _authService.currentUserId) {
            _showNewCommentNotification(newComment);
          }
        }
      },
    );
  }

  void _showNewCommentNotification(Comment comment) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${comment.userName ?? 'Someone'} commented'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80),
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    // Create optimistic comment
    final optimisticComment = Comment.create(
      postId: widget.postId,
      text: text,
      authorId: _authService.currentUserId ?? 'temp',
      authorType: CommentAuthorType.user,
      userId: _authService.currentUserId,
    );

    setState(() {
      _isSubmitting = true;
      _optimisticComments.insert(0, optimisticComment);
      _commentController.clear();
      _errors.remove('add_comment');
    });

    try {
      final actualComment = await _feedsService.addComment(widget.postId, text);
      
      setState(() {
        _isSubmitting = false;
        _optimisticComments.removeWhere((c) => c.id == optimisticComment.id);
        
        if (actualComment != null) {
          // Insert at beginning if not already present
          if (!_comments.any((c) => c.id == actualComment.id)) {
            _comments.insert(0, actualComment);
          }
        }
      });

      // Haptic feedback
      HapticFeedback.lightImpact();
      
      // Scroll to top to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
      
      setState(() {
        _isSubmitting = false;
        _optimisticComments.removeWhere((c) => c.id == optimisticComment.id);
        _errors['add_comment'] = 'Failed to post comment';
        _commentController.text = text; // Restore text
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to post comment'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _commentController.text = text;
                _addComment();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Optimistically remove comment
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
      });

      try {
        final success = await _feedsService.deleteComment(comment.id);
        
        if (!success) {
          // Restore comment if deletion failed
          setState(() {
            _comments.insert(0, comment);
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete comment'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          HapticFeedback.lightImpact();
        }
      } catch (e) {
        debugPrint('Error deleting comment: $e');
        
        // Restore comment on error
        setState(() {
          _comments.insert(0, comment);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete comment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = screenHeight * 0.75;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: modalHeight + keyboardHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(
              '${_comments.length + _optimisticComments.length} Comments',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  // Handle filter/sort - placeholder for now
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Filter/sort coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Column(
            children: [
              // Comment Input Field
              _buildCommentInput(),
              
              // Comment List
              Expanded(
                child: _buildCommentsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.all(kDefaultPadding),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: kCardColor,
            backgroundImage: _authService.currentUser?.profileImageUrl != null
                ? NetworkImage(_authService.currentUser!.profileImageUrl!)
                : const AssetImage('assets/images/p.jpg') as ImageProvider,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
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
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
              enabled: !_isSubmitting,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                    ),
                  )
                : const Icon(Icons.send),
            color: kPrimaryColor,
            onPressed: _isSubmitting ? null : _addComment,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    final allComments = [..._optimisticComments, ..._comments];

    if (_isLoading && allComments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (allComments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.comment_outlined,
              size: 64,
              color: kLightTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No comments yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to comment!',
              style: TextStyle(
                fontSize: 14,
                color: kLightTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: allComments.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= allComments.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final comment = allComments[index];
        final isOptimistic = _optimisticComments.contains(comment);
        
        return CommentItem(
          comment: comment,
          isOptimistic: isOptimistic,
          onDelete: () => _deleteComment(comment),
          onLike: () => _likeComment(comment),
          onReply: () => _replyToComment(comment),
          isOwnComment: comment.userId == _authService.currentUserId,
        );
      },
    );
  }

  Future<void> _likeComment(Comment comment) async {
    // Note: This would require implementing comment likes in the backend
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment likes coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _replyToComment(Comment comment) {
    _commentController.text = '@${comment.userName ?? 'user'} ';
    _commentFocusNode.requestFocus();
  }
}

class CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isOptimistic;
  final VoidCallback onDelete;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final bool isOwnComment;

  const CommentItem({
    super.key,
    required this.comment,
    required this.isOptimistic,
    required this.onDelete,
    required this.onLike,
    required this.onReply,
    required this.isOwnComment,
  });

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
          CircleAvatar(
            radius: 18,
            backgroundColor: kCardColor,
            backgroundImage: comment.userAvatar != null && comment.userAvatar!.isNotEmpty
                ? (comment.userAvatar!.startsWith('http')
                    ? NetworkImage(comment.userAvatar!)
                    : AssetImage(comment.userAvatar!) as ImageProvider)
                : const AssetImage('assets/images/p.jpg') as ImageProvider,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName ?? 'Anonymous',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOptimistic ? 'now' : timeago.format(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: isOptimistic ? null : onLike,
                      child: Row(
                        children: [
                          Icon(
                            comment.hasLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                            size: 16,
                            color: comment.hasLiked ? kPrimaryColor : kLightTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            comment.likesCount.toString(),
                            style: TextStyle(color: kLightTextColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: isOptimistic ? null : onReply,
                      child: Text(
                        'REPLY',
                        style: TextStyle(
                          color: kLightTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (comment.repliesCount > 0)
                      GestureDetector(
                        onTap: () {
                          // Handle view replies
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('View replies coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text(
                          'View All ${comment.repliesCount} Replies',
                          style: TextStyle(color: kPrimaryColor),
                        ),
                      ),
                    if (isOwnComment && !isOptimistic) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: kLightTextColor,
                        ),
                      ),
                    ],
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