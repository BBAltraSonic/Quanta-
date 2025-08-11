import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/comment.dart';
import '../services/enhanced_feeds_service.dart';
import '../services/auth_service.dart';
import '../config/db_config.dart';
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildCommentsList()),
            _buildCommentInput(),
            if (keyboardHeight > 0) SizedBox(height: keyboardHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Comments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${_comments.length + _optimisticComments.length}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 20,
              ),
            ),
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No comments yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to comment!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
        
        return _buildCommentItem(comment, isOptimistic);
      },
    );
  }

  Widget _buildCommentItem(Comment comment, bool isOptimistic) {
    final isOwnComment = comment.userId == _authService.currentUserId;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            backgroundImage: comment.userAvatar != null && comment.userAvatar!.isNotEmpty
                ? (comment.userAvatar!.startsWith('http')
                    ? NetworkImage(comment.userAvatar!)
                    : AssetImage(comment.userAvatar!) as ImageProvider)
                : null,
            child: comment.userAvatar == null || comment.userAvatar!.isEmpty
                ? Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey[600],
                  )
                : null,
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
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOptimistic ? 'Sending...' : timeago.format(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (comment.isAiGenerated) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                
                // Comment text
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Actions
                Row(
                  children: [
                    GestureDetector(
                      onTap: isOptimistic ? null : () => _likeComment(comment),
                      child: Row(
                        children: [
                          Icon(
                            comment.hasLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: comment.hasLiked ? Colors.red : Colors.grey[600],
                          ),
                          if (comment.likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              comment.likesCount.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: isOptimistic ? null : () => _replyToComment(comment),
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isOwnComment && !isOptimistic) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _deleteComment(comment),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.grey[600],
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

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // User avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage: _authService.currentUser?.profileImageUrl != null
                  ? NetworkImage(_authService.currentUser!.profileImageUrl!)
                  : null,
              child: _authService.currentUser?.profileImageUrl == null
                  ? Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.grey[600],
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _addComment(),
                  enabled: !_isSubmitting,
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Send button
            GestureDetector(
              onTap: _isSubmitting ? null : _addComment,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isSubmitting ? Colors.grey[300] : kPrimaryColor,
                  shape: BoxShape.circle,
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
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
      ),
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
