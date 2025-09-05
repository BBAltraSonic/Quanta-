import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_comment_suggestion_service.dart';
import '../models/avatar_model.dart';


/// Widget for displaying AI comment suggestions with accept/decline options
class AICommentSuggestionWidget extends StatefulWidget {
  final AICommentSuggestion suggestion;
  final AvatarModel? avatar;
  final Function(AICommentSuggestion)? onAccept;
  final Function(AICommentSuggestion)? onDecline;
  final VoidCallback? onDismiss;

  const AICommentSuggestionWidget({
    super.key,
    required this.suggestion,
    this.avatar,
    this.onAccept,
    this.onDecline,
    this.onDismiss,
  });

  @override
  State<AICommentSuggestionWidget> createState() => _AICommentSuggestionWidgetState();
}

class _AICommentSuggestionWidgetState extends State<AICommentSuggestionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await widget.onAccept?.call(widget.suggestion);
      HapticFeedback.lightImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('AI comment posted successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      // Animate out and dismiss
      await _animateOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: ${e.toString()}'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleDecline() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      widget.onDecline?.call(widget.suggestion);
      HapticFeedback.selectionClick();
      
      // Animate out and dismiss
      await _animateOut();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _animateOut() async {
    await _animationController.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[600]!.withOpacity(0.15),
                    Colors.purple[600]!.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with AI indicator and avatar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.smart_toy,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'AI Suggestion',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (widget.avatar != null) ...[
                        Text(
                          'for ${widget.avatar!.name}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: widget.avatar!.avatarImageUrl != null
                              ? NetworkImage(widget.avatar!.avatarImageUrl!)
                              : const AssetImage('assets/images/p.jpg') as ImageProvider,
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Suggested comment text
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      widget.suggestion.suggestedText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      // Accept button
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _handleAccept,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: Text(_isProcessing ? 'Posting...' : 'Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Decline button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _handleDecline,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Timestamp
                  const SizedBox(height: 8),
                  Text(
                    'Generated ${_formatTimeAgo(widget.suggestion.createdAt)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Expandable container for multiple AI suggestions
class AICommentSuggestionsContainer extends StatefulWidget {
  final List<AICommentSuggestion> suggestions;
  final Function(AICommentSuggestion)? onAccept;
  final Function(AICommentSuggestion)? onDecline;
  final VoidCallback? onAllDismissed;

  const AICommentSuggestionsContainer({
    super.key,
    required this.suggestions,
    this.onAccept,
    this.onDecline,
    this.onAllDismissed,
  });

  @override
  State<AICommentSuggestionsContainer> createState() => _AICommentSuggestionsContainerState();
}

class _AICommentSuggestionsContainerState extends State<AICommentSuggestionsContainer> {
  final List<AICommentSuggestion> _activeSuggestions = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _activeSuggestions.addAll(widget.suggestions);
  }

  void _removeSuggestion(AICommentSuggestion suggestion) {
    setState(() {
      _activeSuggestions.removeWhere((s) => s.id == suggestion.id);
    });

    if (_activeSuggestions.isEmpty) {
      widget.onAllDismissed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Header to expand/collapse suggestions
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[600]!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.smart_toy,
                  color: Colors.blue[300],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_activeSuggestions.length} AI comment ${_activeSuggestions.length == 1 ? 'suggestion' : 'suggestions'} available',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.blue[300],
                ),
              ],
            ),
          ),
        ),

        // Suggestions list
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isExpanded ? null : 0,
          child: _isExpanded
              ? Column(
                  children: _activeSuggestions.map((suggestion) {
                    return AICommentSuggestionWidget(
                      suggestion: suggestion,
                      onAccept: widget.onAccept,
                      onDecline: widget.onDecline,
                      onDismiss: () => _removeSuggestion(suggestion),
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
