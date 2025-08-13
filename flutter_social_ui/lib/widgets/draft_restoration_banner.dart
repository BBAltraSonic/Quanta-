import 'package:flutter/material.dart';

/// Widget to display a banner when a saved draft is available
class DraftRestorationBanner extends StatefulWidget {
  final String draftAge;
  final VoidCallback onRestore;
  final VoidCallback onDismiss;
  final String? customMessage;
  final bool showDismiss;

  const DraftRestorationBanner({
    Key? key,
    required this.draftAge,
    required this.onRestore,
    required this.onDismiss,
    this.customMessage,
    this.showDismiss = true,
  }) : super(key: key);

  @override
  State<DraftRestorationBanner> createState() => _DraftRestorationBannerState();
}

class _DraftRestorationBannerState extends State<DraftRestorationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!_isVisible) return;

    setState(() {
      _isVisible = false;
    });

    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  void _restore() {
    widget.onRestore();
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restore,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Draft Available',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.customMessage ?? 
                        'You have unsaved changes from ${widget.draftAge}.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showDismiss)
                  IconButton(
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.showDismiss)
                  TextButton(
                    onPressed: _dismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Dismiss'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _restore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Restore Draft'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to show unsaved changes indicator
class UnsavedChangesIndicator extends StatelessWidget {
  final List<String> changedFields;
  final bool isVisible;

  const UnsavedChangesIndicator({
    Key? key,
    required this.changedFields,
    this.isVisible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible || changedFields.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            _getChangesText(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  String _getChangesText() {
    if (changedFields.length == 1) {
      return '1 unsaved change';
    }
    return '${changedFields.length} unsaved changes';
  }
}

/// Auto-save status indicator widget
class AutoSaveStatusIndicator extends StatefulWidget {
  final bool isSaving;
  final bool isEnabled;
  final DateTime? lastSaved;

  const AutoSaveStatusIndicator({
    Key? key,
    this.isSaving = false,
    this.isEnabled = true,
    this.lastSaved,
  }) : super(key: key);

  @override
  State<AutoSaveStatusIndicator> createState() => _AutoSaveStatusIndicatorState();
}

class _AutoSaveStatusIndicatorState extends State<AutoSaveStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.isSaving) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AutoSaveStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isSaving != oldWidget.isSaving) {
      if (widget.isSaving) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isSaving) ...[
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation.value,
                  child: Icon(
                    Icons.sync,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            Text(
              'Saving...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              _getLastSavedText(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getLastSavedText() {
    if (widget.lastSaved == null) {
      return 'Auto-save enabled';
    }

    final now = DateTime.now();
    final difference = now.difference(widget.lastSaved!);
    
    if (difference.inSeconds < 30) {
      return 'Saved just now';
    } else if (difference.inMinutes < 1) {
      return 'Saved ${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return 'Saved ${difference.inMinutes}m ago';
    } else {
      return 'Saved ${difference.inHours}h ago';
    }
  }
}
