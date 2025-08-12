import 'package:flutter/material.dart';
import '../models/comment.dart';

class CommentTile extends StatelessWidget {
  final Comment comment;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final VoidCallback? onViewReplies;
  final VoidCallback? onDelete;
  final bool showDeleteOption;

  const CommentTile({
    super.key,
    required this.comment,
    this.onLike,
    this.onReply,
    this.onViewReplies,
    this.onDelete,
    this.showDeleteOption = false,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final color = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: AssetImage(comment.userAvatar ?? 'assets/images/p.jpg'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time + delete option
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName ?? 'User',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showDeleteOption && onDelete != null)
                      InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red.withOpacity(0.7),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: text.bodySmall?.copyWith(
                        color: color.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Comment text
                Text(comment.text, style: text.bodyMedium),
                const SizedBox(height: 8),
                // Actions row (icons left + time right like reference)
                Row(
                  children: [
                    // Like (heart) + count
                    InkWell(
                      onTap: onLike,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              comment.hasLiked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: comment.hasLiked ? Colors.red : Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${comment.likes}',
                              style: text.bodySmall?.copyWith(
                                color: comment.hasLiked ? Colors.red : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // REPLY text only (icon removed)
                    InkWell(
                      onTap: onReply,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          'REPLY',
                          style: text.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Right side: either "View All N Replies" or time
                    if (comment.repliesCount > 0)
                      InkWell(
                        onTap: onViewReplies,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            'View All ${comment.repliesCount} Replies',
                            style: text.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        _timeAgo(comment.createdAt),
                        style: text.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
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
}
