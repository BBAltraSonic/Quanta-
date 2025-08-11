import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comment.dart';
import '../services/comment_service.dart';
import '../services/auth_service.dart';
import 'comment_tile.dart';

Future<void> openCommentsModal(
  BuildContext context, {
  required String postId,
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
        initialComments: initial ?? [],
        onCommentCountChanged: onCommentCountChanged,
      );
    },
  );
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final List<Comment> initialComments;
  final Function(int)? onCommentCountChanged;
  
  const _CommentsSheet({
    super.key,
    required this.postId,
    required this.initialComments,
    this.onCommentCountChanged,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final CommentService _commentService = CommentService();
  final AuthService _authService = AuthService();
  
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _comments = List<Comment>.from(widget.initialComments);
    if (_comments.isEmpty) {
      _loadComments();
    } else {
      _isLoading = false;
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
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load comments: ${e.toString()}';
      });
    }
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
      final success = await _commentService.toggleCommentLike(comment.id);
      if (success) {
        setState(() {
          final index = _comments.indexWhere((c) => c.id == comment.id);
          if (index != -1) {
            _comments[index] = _comments[index].copyWith(
              hasLiked: !_comments[index].hasLiked,
              likesCount: _comments[index].hasLiked 
                  ? _comments[index].likesCount - 1
                  : _comments[index].likesCount + 1,
            );
          }
        });
        HapticFeedback.selectionClick();
      }
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
                      // Filter button
                      _RoundIconChip(
                        icon: Icons.tune,
                        onTap: () {
                          // Placeholder for sort/filter options
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Filter options coming soon'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        tooltip: 'Filter',
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
                      const CircleAvatar(
                        radius: 16,
                        backgroundImage: AssetImage('assets/images/p.jpg'),
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
          return CommentTile(
            comment: comment,
            onLike: () => _toggleCommentLike(comment),
            onReply: () {
              _focusNode.requestFocus();
            },
            onViewReplies: () {
              // TODO: Implement replies functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Replies feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
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
