import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comment.dart';
import '../models/post_model.dart';
import '../services/comment_service.dart';
import '../services/auth_service.dart';
import '../services/ai_comment_suggestion_service.dart';

import 'comment_tile.dart';
import 'user_avatar.dart';
import 'ai_comment_suggestion_widget.dart';

Future<void> openCommentsModal(
  BuildContext context, {
  required String postId,
  PostModel? post,
  List<Comment>? initial,
  Function(int)? onCommentCountChanged,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (ctx) {
      return _CommentsSheet(
        postId: postId,
        post: post,
        initialComments: initial ?? [],
        onCommentCountChanged: onCommentCountChanged,
      );
    },
  );
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final PostModel? post;
  final List<Comment> initialComments;
  final Function(int)? onCommentCountChanged;
  
  const _CommentsSheet({
    super.key,
    required this.postId,
    this.post,
    required this.initialComments,
    this.onCommentCountChanged,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

enum CommentSortOrder {
  newest,
  oldest,
  mostLiked,
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final CommentService _commentService = CommentService();
  final AuthService _authService = AuthService();
  final AICommentSuggestionService _aiSuggestionService = AICommentSuggestionService();
  
  List<Comment> _comments = [];
  List<AICommentSuggestion> _aiSuggestions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLoadingAISuggestions = false;
  String? _errorMessage;
  CommentSortOrder _sortOrder = CommentSortOrder.newest;

  @override
  void initState() {
    super.initState();
    _comments = List<Comment>.from(widget.initialComments);
    if (_comments.isEmpty) {
      _loadComments();
    } else {
      _isLoading = false;
    }
    
    // Load AI suggestions if we have a post
    if (widget.post != null) {
      _loadAISuggestions();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final comments = await _commentService.getPostComments(
        postId: widget.postId,
      );
      
      setState(() {
        _comments = comments;
        _isLoading = false;
      });

      // Notify parent about the real comment count
      widget.onCommentCountChanged?.call(_comments.length);
      
      // Apply current sorting
      _sortComments();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load comments: ${e.toString()}';
      });
      
      // Enhanced error debugging
      debugPrint('❌ Comments loading error details:');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: ${e.toString()}');
      debugPrint('Post ID: ${widget.postId}');
      
      if (e.toString().contains('type cast') || e.toString().contains('Null')) {
        debugPrint('🔍 This appears to be a type casting/null value issue');
        debugPrint('Check database for NULL values in required fields');
      }
    }
  }

  Future<void> _loadAISuggestions() async {
    if (widget.post == null) return;

    setState(() {
      _isLoadingAISuggestions = true;
    });

    try {
      final suggestions = await _aiSuggestionService.generateSuggestions(
        postId: widget.postId,
        post: widget.post!,
        existingComments: _comments,
        maxSuggestions: 2,
      );

      setState(() {
        _aiSuggestions = suggestions;
        _isLoadingAISuggestions = false;
      });

      debugPrint('💡 Loaded ${suggestions.length} AI suggestions');
    } catch (e) {
      setState(() {
        _isLoadingAISuggestions = false;
      });
      debugPrint('❌ Error loading AI suggestions: $e');
    }
  }

  void _sortComments() {
    setState(() {
      switch (_sortOrder) {
        case CommentSortOrder.newest:
          _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case CommentSortOrder.oldest:
          _comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case CommentSortOrder.mostLiked:
          _comments.sort((a, b) => b.likesCount.compareTo(a.likesCount));
          break;
      }
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sort Comments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _SortOption(
              title: 'Newest First',
              isSelected: _sortOrder == CommentSortOrder.newest,
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _sortOrder = CommentSortOrder.newest;
                });
                _sortComments();
              },
            ),
            _SortOption(
              title: 'Oldest First',
              isSelected: _sortOrder == CommentSortOrder.oldest,
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _sortOrder = CommentSortOrder.oldest;
                });
                _sortComments();
              },
            ),
            _SortOption(
              title: 'Most Liked',
              isSelected: _sortOrder == CommentSortOrder.mostLiked,
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _sortOrder = CommentSortOrder.mostLiked;
                });
                _sortComments();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final newComment = await _commentService.addComment(
        postId: widget.postId,
        text: text,
      );

      setState(() {
        _comments.insert(0, newComment);
        _controller.clear();
        _isSubmitting = false;
      });

      // Notify parent about comment count change
      widget.onCommentCountChanged?.call(_comments.length);

      // Haptic feedback
      HapticFeedback.lightImpact();
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to add comment: ${e.toString()}';
      });

      // Provide user-friendly error messages with debugging info
      String errorMessage = 'Failed to add comment';
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('row-level security') || errorString.contains('policy')) {
        errorMessage = 'Authentication required. Please log in to comment.';
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        errorMessage = 'Network error. Please check your connection';
      } else if (errorString.contains('user not authenticated') || errorString.contains('authentication')) {
        errorMessage = 'Please log in to add comments';
      } else if (errorString.contains('mismatch')) {
        errorMessage = 'Session error. Please try logging out and back in.';
      }
      
      // Debug info for development
      debugPrint('Comment error: ${e.toString()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _addComment,
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleCommentLike(Comment comment) async {
    try {
      final wasLiked = await _commentService.toggleCommentLike(comment.id);
      setState(() {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          _comments[index] = _comments[index].copyWith(
            hasLiked: wasLiked,
            likesCount: wasLiked 
                ? _comments[index].likesCount + 1
                : _comments[index].likesCount - 1,
          );
        }
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle like: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Comment', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this comment?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final success = await _commentService.deleteComment(comment.id);
        if (success) {
          setState(() {
            _comments.removeWhere((c) => c.id == comment.id);
          });
          widget.onCommentCountChanged?.call(_comments.length);
          HapticFeedback.lightImpact();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Comment deleted successfully'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete comment: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _viewReplies(Comment comment) async {
    try {
      final replies = await _commentService.getCommentReplies(commentId: comment.id);
      
      if (mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withOpacity(0.7),
          builder: (ctx) => _RepliesSheet(
            parentComment: comment,
            replies: replies,
            onReplyAdded: () {
              // Refresh the parent comment to update replies count
              _loadComments();
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load replies: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAcceptAISuggestion(AICommentSuggestion suggestion) async {
    try {
      final comment = await _aiSuggestionService.acceptSuggestion(suggestion);
      if (comment != null) {
        setState(() {
          _comments.insert(0, comment);
          _aiSuggestions.removeWhere((s) => s.id == suggestion.id);
        });

        // Notify parent about comment count change
        widget.onCommentCountChanged?.call(_comments.length);
        
        // Apply current sorting
        _sortComments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept AI suggestion: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleDeclineAISuggestion(AICommentSuggestion suggestion) {
    _aiSuggestionService.declineSuggestion(suggestion);
    setState(() {
      _aiSuggestions.removeWhere((s) => s.id == suggestion.id);
    });
  }

  void _handleAllAISuggestionsDismissed() {
    setState(() {
      _aiSuggestions.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.46,
      maxChildSize: 0.98,
      snap: true,
      snapSizes: const [0.62, 0.85, 0.98],
      builder: (context, scrollController) {
        return AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  offset: const Offset(0, -16),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_comments.length} Comments',
                          // Ensure strong contrast and visibility
                          style:
                              (theme.textTheme.titleMedium ?? const TextStyle())
                                  .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                        ),
                      ),
                      // Sort button
                      _RoundIconChip(
                        icon: Icons.sort,
                        onTap: _showSortOptions,
                        tooltip: 'Sort',
                      ),
                      const SizedBox(width: 8),
                      // Close button
                      _RoundIconChip(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Composer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      UserAvatar(
                        user: _authService.currentUser,
                        radius: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          padding: const EdgeInsets.only(left: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  maxLines: 1,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _addComment(),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Add a comment...',
                                    hintStyle: TextStyle(color: Colors.white54),
                                  ),
                                ),
                              ),
                              // Send pill
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Material(
                                  color: color.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: _isSubmitting ? null : _addComment,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.arrow_upward_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // AI Suggestions
                if (_aiSuggestions.isNotEmpty) ...[
                  AICommentSuggestionsContainer(
                    suggestions: _aiSuggestions,
                    onAccept: _handleAcceptAISuggestion,
                    onDecline: _handleDeclineAISuggestion,
                    onAllDismissed: _handleAllAISuggestionsDismissed,
                  ),
                ],

                // List
                Expanded(
                  child: _buildCommentsList(scrollController),
                ),
                SafeArea(top: false, child: SizedBox(height: 0)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentsList(ScrollController scrollController) {
    if (_isLoading && _comments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null && _comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadComments,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.comment_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No comments yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to comment!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const _NoGlowBehavior(),
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _comments.length,
        separatorBuilder: (_, __) => Divider(
          color: Colors.white.withOpacity(0.08),
          height: 1,
          thickness: 0.6,
        ),
        itemBuilder: (context, index) {
          final comment = _comments[index];
          final currentUser = _authService.currentUser;
          final canDelete = currentUser != null && comment.userId == currentUser.id;
          
          return CommentTile(
            comment: comment,
            onLike: () => _toggleCommentLike(comment),
            onReply: () {
              _focusNode.requestFocus();
            },
            onViewReplies: comment.repliesCount > 0 ? () => _viewReplies(comment) : null,
            onDelete: canDelete ? () => _deleteComment(comment) : null,
            showDeleteOption: canDelete,
          );
        },
      ),
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

// Small rounded circular chip used in the header for filter/close
class _RoundIconChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _RoundIconChip({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Stronger contrast so actions are clearly visible on dark sheet
    final bg = Colors.white.withOpacity(0.08);
    final fg = Colors.white.withOpacity(0.92);

    final content = Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );

    return tooltip != null
        ? Tooltip(message: tooltip!, child: content)
        : content;
  }
}

// Replies sheet for viewing and adding replies to a comment
class _RepliesSheet extends StatefulWidget {
  final Comment parentComment;
  final List<Comment> replies;
  final VoidCallback? onReplyAdded;

  const _RepliesSheet({
    required this.parentComment,
    required this.replies,
    this.onReplyAdded,
  });

  @override
  State<_RepliesSheet> createState() => _RepliesSheetState();
}

class _RepliesSheetState extends State<_RepliesSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final CommentService _commentService = CommentService();
  final AuthService _authService = AuthService();
  
  List<Comment> _replies = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _replies = List<Comment>.from(widget.replies);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final newReply = await _commentService.addComment(
        postId: widget.parentComment.postId,
        text: text,
        parentCommentId: widget.parentComment.id,
      );

      setState(() {
        _replies.add(newReply);
        _controller.clear();
        _isSubmitting = false;
      });

      widget.onReplyAdded?.call();
      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add reply: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_replies.length} Replies',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _RoundIconChip(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Parent comment
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: CommentTile(comment: widget.parentComment),
                ),
                
                const Divider(color: Colors.white24, height: 32),
                
                // Reply composer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      UserAvatar(
                        user: _authService.currentUser,
                        radius: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          padding: const EdgeInsets.only(left: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  maxLines: 1,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _addReply(),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Add a reply...',
                                    hintStyle: TextStyle(color: Colors.white54),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Material(
                                  color: color.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: _isSubmitting ? null : _addReply,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.arrow_upward_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Replies list
                Expanded(
                  child: _replies.isEmpty
                      ? const Center(
                          child: Text(
                            'No replies yet',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _replies.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final reply = _replies[index];
                            final currentUser = _authService.currentUser;
                            final canDelete = currentUser != null && reply.userId == currentUser.id;
                            
                            return CommentTile(
                              comment: reply,
                              onDelete: canDelete ? () => _deleteReply(reply) : null,
                              showDeleteOption: canDelete,
                            );
                          },
                        ),
                ),
                SafeArea(top: false, child: SizedBox(height: 0)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteReply(Comment reply) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Reply', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this reply?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final success = await _commentService.deleteComment(reply.id);
        if (success) {
          setState(() {
            _replies.removeWhere((r) => r.id == reply.id);
          });
          widget.onReplyAdded?.call(); // Refresh parent
          HapticFeedback.lightImpact();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete reply: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Sort option widget for the sort modal
class _SortOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: isSelected 
          ? const Icon(Icons.check, color: Colors.blue, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
