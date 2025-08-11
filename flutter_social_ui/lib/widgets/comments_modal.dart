import 'package:flutter/material.dart';
import '../models/comment.dart';
import 'comment_tile.dart';

Future<void> openCommentsModal(
  BuildContext context, {
  List<Comment>? initial,
}) async {
  final comments = List<Comment>.from(initial ?? <Comment>[]);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.65), // slightly darker backdrop
    builder: (ctx) {
      return _CommentsSheet(initialComments: comments);
    },
  );
}

class _CommentsSheet extends StatefulWidget {
  final List<Comment> initialComments;
  const _CommentsSheet({required this.initialComments});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late List<Comment> comments;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    comments = List<Comment>.from(widget.initialComments);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      comments.insert(
        0,
        Comment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          postId: 'demo-post',
          userId: 'me',
          authorId: 'me',
          authorType: CommentAuthorType.user,
          text: text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          userName: 'You',
          userAvatar: 'assets/images/p.jpg',
          hasLiked: false,
        ),
      );
      _controller.clear();
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
              color: theme.colorScheme.surface.withOpacity(0.98),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 32,
                  offset: const Offset(0, -10),
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
                    color: color.onSurface.withOpacity(0.3),
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
                          '${comments.length} Comments',
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
                            color: color.surfaceContainerHighest.withOpacity(
                              0.6,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: color.onSurface.withOpacity(0.06),
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
                                  onSubmitted: (_) => _send(),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Add a comment...',
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
                                    onTap: _send,
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: Icon(
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
                  child: ScrollConfiguration(
                    behavior: const _NoGlowBehavior(),
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => Divider(
                        color: color.onSurface.withOpacity(0.06),
                        height: 1,
                        thickness: 0.6,
                      ),
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        return CommentTile(
                          comment: c,
                          onLike: () {
                            setState(() {
                              c.hasLiked = !c.hasLiked;
                              c.likes += c.hasLiked ? 1 : -1;
                            });
                          },
                          onReply: () {
                            _focusNode.requestFocus();
                          },
                          onViewReplies: () {},
                        );
                      },
                    ),
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
