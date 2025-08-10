import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/follow_service.dart';

class FollowButton extends StatefulWidget {
  final String avatarId;
  final bool initialFollowState;
  final VoidCallback? onFollowChanged;
  final FollowButtonStyle style;

  const FollowButton({
    super.key,
    required this.avatarId,
    this.initialFollowState = false,
    this.onFollowChanged,
    this.style = FollowButtonStyle.primary,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton>
    with SingleTickerProviderStateMixin {
  final FollowService _followService = FollowService();
  
  bool _isFollowing = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialFollowState;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _checkFollowStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkFollowStatus() async {
    try {
      final isFollowing = await _followService.isFollowing(widget.avatarId);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Animation feedback
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    try {
      // Optimistic update
      final wasFollowing = _isFollowing;
      setState(() {
        _isFollowing = !wasFollowing;
      });

      // Backend update
      final nowFollowing = await _followService.toggleFollow(widget.avatarId);
      
      // Sync with actual result
      setState(() {
        _isFollowing = nowFollowing;
      });

      // Notify parent
      widget.onFollowChanged?.call();

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nowFollowing ? 'Following!' : 'Unfollowed',
            ),
            backgroundColor: nowFollowing ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        _isFollowing = !_isFollowing;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isFollowing ? 'follow' : 'unfollow'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildButton(),
        );
      },
    );
  }

  Widget _buildButton() {
    switch (widget.style) {
      case FollowButtonStyle.primary:
        return _buildPrimaryButton();
      case FollowButtonStyle.secondary:
        return _buildSecondaryButton();
      case FollowButtonStyle.compact:
        return _buildCompactButton();
      case FollowButtonStyle.icon:
        return _buildIconButton();
    }
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? kCardColor : kPrimaryColor,
          foregroundColor: _isFollowing ? kTextColor : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: _isFollowing 
                ? const BorderSide(color: kLightTextColor, width: 1)
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isFollowing ? Icons.check : Icons.add,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _toggleFollow,
        style: OutlinedButton.styleFrom(
          foregroundColor: _isFollowing ? kLightTextColor : kPrimaryColor,
          side: BorderSide(
            color: _isFollowing ? kLightTextColor : kPrimaryColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                ),
              )
            : Text(
                _isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }

  Widget _buildCompactButton() {
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? kCardColor : kPrimaryColor,
          foregroundColor: _isFollowing ? kTextColor : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: _isFollowing 
                ? const BorderSide(color: kLightTextColor, width: 1)
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
      ),
    );
  }

  Widget _buildIconButton() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _isFollowing ? kCardColor : kPrimaryColor,
        shape: BoxShape.circle,
        border: _isFollowing 
            ? Border.all(color: kLightTextColor, width: 1)
            : null,
      ),
      child: IconButton(
        onPressed: _isLoading ? null : _toggleFollow,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                _isFollowing ? Icons.check : Icons.add,
                color: _isFollowing ? kTextColor : Colors.white,
                size: 18,
              ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

enum FollowButtonStyle {
  primary,   // Large button with text and icon
  secondary, // Outlined button
  compact,   // Small button
  icon,      // Icon-only circular button
}
