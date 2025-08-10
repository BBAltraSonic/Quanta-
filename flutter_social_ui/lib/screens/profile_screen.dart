import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_social_ui/constants.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../services/profile_service.dart';
import '../services/auth_service_wrapper.dart';
import '../screens/settings_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/avatar_management_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthServiceWrapper _authService = AuthServiceWrapper();
  
  UserModel? _user;
  List<AvatarModel> _avatars = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }
  
  Future<void> _loadProfileData() async {
    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final profileData = await _profileService.getUserProfileData(userId);
        setState(() {
          _user = profileData['user'] as UserModel;
          _avatars = profileData['avatars'] as List<AvatarModel>;
          _stats = profileData['stats'] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _navigateToEditProfile() async {
    if (_user == null) return;
    
    final updatedUser = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(user: _user!),
      ),
    );
    
    if (updatedUser != null) {
      setState(() {
        _user = updatedUser;
      });
    }
  }
  
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }
  
  void _navigateToAvatarManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AvatarManagementScreen(),
      ),
    );
  }
  
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppShell provides global bottom nav
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: null,
        centerTitle: false,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            onPressed: _navigateToSettings,
            icon: SvgPicture.asset(
              'assets/icons/settings-minimalistic-svgrepo-com.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            tooltip: 'Settings',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: _navigateToEditProfile,
              icon: SvgPicture.asset(
                'assets/icons/pen-new-square-svgrepo-com.svg',
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              tooltip: 'Edit profile',
            ),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : Stack(
        children: [
          // Fullscreen profile photo background with dark + red overlays
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _user?.profileImageUrl != null
                    ? _user!.profileImageUrl!.startsWith('assets/')
                        ? Image.asset(
                            _user!.profileImageUrl!,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            _user!.profileImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Image(
                                image: AssetImage('assets/images/We.jpg'),
                                fit: BoxFit.cover,
                              );
                            },
                          )
                    : const Image(
                        image: AssetImage('assets/images/We.jpg'),
                        fit: BoxFit.cover,
                      ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.78),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kPrimaryColor.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 240, 20, 14),
                  sliver: SliverToBoxAdapter(
                    child: _HeaderCard(child: _headerBlock()),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  sliver: SliverToBoxAdapter(
                    child: _buildAnalyticsSection(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  sliver: SliverToBoxAdapter(
                    child: _buildAvatarsSection(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverToBoxAdapter(child: _userPostsMasonry()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Header (name + bio + metrics)
  Widget _headerBlock() {
    final displayName = _user?.displayName ?? _user?.username ?? 'User';
    final activeAvatar = _avatars.isNotEmpty ? _avatars.first : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: _user?.profileImageUrl != null
                  ? _user!.profileImageUrl!.startsWith('assets/')
                      ? AssetImage(_user!.profileImageUrl!) as ImageProvider
                      : NetworkImage(_user!.profileImageUrl!)
                  : const AssetImage('assets/images/p.jpg'),
            ),
            const SizedBox(width: 12),
            // Name with inline verification badge (to the right of the name)
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: kPrimaryColor, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          activeAvatar?.bio ?? 'Virtual influencer creator',
          style: const TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.35),
        ),
        const SizedBox(height: 14),
        // Metrics chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricChip(value: _formatNumber(_stats['total_followers'] ?? 0), label: 'Followers'),
            _MetricChip(value: _formatNumber(_stats['total_posts'] ?? 0), label: 'Posts'),
            _MetricChip(value: '${_avatars.length}', label: 'Avatars'),
          ],
        ),
      ],
    );
  }
  
  // Analytics section
  Widget _buildAnalyticsSection() {
    return _HeaderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics Overview',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          // Performance metrics row
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Views',
                  value: _formatNumber(_stats['total_views'] ?? 0),
                  subtitle: '+12% this week',
                  icon: Icons.visibility,
                  color: Colors.blue,
                  isPositive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Engagement',
                  value: '${((_stats['engagement_rate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                  subtitle: '+3.2% this week',
                  icon: Icons.favorite,
                  color: Colors.red,
                  isPositive: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Revenue and growth metrics row
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Revenue',
                  value: '\$${_formatNumber(_stats['total_revenue'] ?? 0)}',
                  subtitle: '+8.5% this month',
                  icon: Icons.attach_money,
                  color: Colors.green,
                  isPositive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Growth Rate',
                  value: '+${(_stats['growth_rate'] ?? 0.0).toStringAsFixed(1)}%',
                  subtitle: 'Follower growth',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                  isPositive: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Top performing avatar
          if (_avatars.isNotEmpty) ...[
            const Text(
              'Top Performing Avatar',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            _buildTopAvatarCard(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? Colors.green : Colors.red,
                size: 12,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopAvatarCard() {
    final topAvatar = _avatars.first; // In real app, this would be sorted by performance
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: topAvatar.avatarImageUrl != null
                ? topAvatar.avatarImageUrl!.startsWith('assets/')
                    ? AssetImage(topAvatar.avatarImageUrl!) as ImageProvider
                    : NetworkImage(topAvatar.avatarImageUrl!)
                : null,
            child: topAvatar.avatarImageUrl == null
                ? const Icon(Icons.person, color: kLightTextColor, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topAvatar.name,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_formatNumber(topAvatar.followersCount)} followers • ${(topAvatar.engagementRate * 100).toStringAsFixed(1)}% engagement',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'TOP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Avatars section
  Widget _buildAvatarsSection() {
    if (_avatars.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _HeaderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Avatars',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              TextButton(
                onPressed: _navigateToAvatarManagement,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _avatars.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final avatar = _avatars[index];
                return Container(
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: avatar.avatarImageUrl != null
                            ? avatar.avatarImageUrl!.startsWith('assets/')
                                ? AssetImage(avatar.avatarImageUrl!) as ImageProvider
                                : NetworkImage(avatar.avatarImageUrl!)
                            : null,
                        child: avatar.avatarImageUrl == null
                            ? const Icon(Icons.person, color: kLightTextColor)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        avatar.name,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatNumber(avatar.followersCount)} followers',
                        style: const TextStyle(
                          color: kLightTextColor,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Masonry-like grid of user's posts (uses variable images)
  Widget _userPostsMasonry() {
    // Rotate through a few different images for visual variety.
    // Ensure these exist in assets/images and are declared in pubspec.yaml.
    const images = <String>['assets/images/We.jpg', 'assets/images/p.jpg'];
    int idx = 0;

    String nextImg() {
      final path = images[idx % images.length];
      idx++;
      return path;
    }

    Widget tile({
      required double h,
      bool play = false,
      String? badge,
      double radius = 18,
      String? image,
    }) {
      final imgPath = image ?? nextImg();
      return Container(
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          image: DecorationImage(image: AssetImage(imgPath), fit: BoxFit.cover),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // subtle gradient for text legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (play)
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: kPrimaryColor,
                    size: 34,
                  ),
                ),
              ),
            if (badge != null)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        const gap = 12.0;

        // Two bespoke columns: left thin, right wide
        final leftColW = (totalW - gap) * 0.35;
        final rightColW = totalW - leftColW - gap;

        const leftTopH = 120.0;
        const leftBottomH = 120.0;

        const rightTopH = 180.0;
        const rightBottomH = 120.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            SizedBox(
              width: leftColW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: tile(h: leftTopH, badge: '5/7', radius: 18),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: tile(h: leftBottomH, radius: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right column
            SizedBox(
              width: rightColW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: tile(
                      h: rightTopH,
                      play: true,
                      badge: '1/3',
                      radius: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: tile(h: rightBottomH, radius: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: tile(
                            h: rightBottomH,
                            badge: '1/3',
                            radius: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Card wrapper for the header that appears over the photo
class _HeaderCard extends StatelessWidget {
  final Widget child;
  const _HeaderCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.95)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: child,
    );
  }
}

// Const-friendly metric chip used in header Wrap
class _MetricChip extends StatelessWidget {
  final String value;
  final String label;
  const _MetricChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.95)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: kPrimaryColor),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
