import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// A widget that displays a user's avatar with proper fallback logic
class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final double radius;
  final String? fallbackAsset;

  const UserAvatar({
    super.key,
    this.user,
    this.radius = 16,
    this.fallbackAsset = 'assets/images/p.jpg',
  });

  @override
  Widget build(BuildContext context) {
    // If user has a profile image URL, use it
    if (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(user!.profileImageUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // If network image fails to load, fall back to asset
          debugPrint('Failed to load profile image: $exception');
        },
        child: user!.profileImageUrl!.isEmpty
            ? _buildFallbackAvatar()
            : null,
      );
    }

    // Fall back to asset image or default
    return CircleAvatar(
      radius: radius,
      backgroundImage: fallbackAsset != null
          ? AssetImage(fallbackAsset!)
          : null,
      child: fallbackAsset == null ? _buildFallbackAvatar() : null,
    );
  }

  Widget _buildFallbackAvatar() {
    return Icon(
      Icons.person,
      size: radius * 1.2,
      color: Colors.white54,
    );
  }
}
