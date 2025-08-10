import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/avatar_model.dart';
import '../models/user_model.dart';
import '../services/follow_service.dart';
import '../widgets/follow_button.dart';
import '../screens/chat_screen.dart';

enum FollowersScreenType { followers, following, recommended, trending }

class FollowersScreen extends StatefulWidget {
  final FollowersScreenType type;
  final String? avatarId; // For showing followers of a specific avatar
  final String? userId; // For showing following of a specific user

  const FollowersScreen({
    super.key,
    required this.type,
    this.avatarId,
    this.userId,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen>
    with SingleTickerProviderStateMixin {
  final FollowService _followService = FollowService();
  final ScrollController _scrollController = ScrollController();
  
  List<AvatarModel> _avatars = [];
  List<UserModel> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  
  late TabController _tabController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      switch (widget.type) {
        case FollowersScreenType.followers:
          if (widget.avatarId != null) {
            _users = await _followService.getAvatarFollowers(
              widget.avatarId!,
              limit: 20,
              offset: 0,
            );
          }
          break;
        case FollowersScreenType.following:
          _avatars = await _followService.getFollowingAvatars(
            limit: 20,
            offset: 0,
          );
          break;
        case FollowersScreenType.recommended:
          _avatars = await _followService.getRecommendedAvatars(limit: 20);
          break;
        case FollowersScreenType.trending:
          _avatars = await _followService.getTrendingAvatars(limit: 20);
          break;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      switch (widget.type) {
        case FollowersScreenType.followers:
          if (widget.avatarId != null) {
            final newUsers = await _followService.getAvatarFollowers(
              widget.avatarId!,
              limit: 20,
              offset: _users.length,
            );
            setState(() {
              _users.addAll(newUsers);
            });
          }
          break;
        case FollowersScreenType.following:
          final newAvatars = await _followService.getFollowingAvatars(
            limit: 20,
            offset: _avatars.length,
          );
          setState(() {
            _avatars.addAll(newAvatars);
          });
          break;
        case FollowersScreenType.recommended:
          final newAvatars = await _followService.getRecommendedAvatars(
            limit: 20,
          );
          setState(() {
            _avatars.addAll(newAvatars);
          });
          break;
        case FollowersScreenType.trending:
          final newAvatars = await _followService.getTrendingAvatars(
            limit: 20,
          );
          setState(() {
            _avatars.addAll(newAvatars);
          });
          break;
      }
    } catch (e) {
      debugPrint('Error loading more data: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  String get _title {
    switch (widget.type) {
      case FollowersScreenType.followers:
        return 'Followers';
      case FollowersScreenType.following:
        return 'Following';
      case FollowersScreenType.recommended:
        return 'Recommended';
      case FollowersScreenType.trending:
        return 'Trending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kCardColor,
        elevation: 0,
        title: Text(
          _title,
          style: const TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: kTextColor),
        ),
        bottom: widget.type == FollowersScreenType.recommended
            ? TabBar(
                controller: _tabController,
                indicatorColor: kPrimaryColor,
                labelColor: kPrimaryColor,
                unselectedLabelColor: kLightTextColor,
                tabs: const [
                  Tab(text: 'For You'),
                  Tab(text: 'Trending'),
                ],
              )
            : null,
      ),
      body: widget.type == FollowersScreenType.recommended
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildRecommendedTab(),
                _buildTrendingTab(),
              ],
            )
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: const TextStyle(
                color: kTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: kLightTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (widget.type == FollowersScreenType.followers) {
      return _buildUsersList(_users);
    } else {
      return _buildAvatarsList(_avatars);
    }
  }

  Widget _buildRecommendedTab() {
    return _buildAvatarsList(_avatars);
  }

  Widget _buildTrendingTab() {
    return FutureBuilder<List<AvatarModel>>(
      future: _followService.getTrendingAvatars(limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading trending avatars',
              style: const TextStyle(color: kLightTextColor),
            ),
          );
        }

        return _buildAvatarsList(snapshot.data ?? []);
      },
    );
  }

  Widget _buildAvatarsList(List<AvatarModel> avatars) {
    if (avatars.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: kLightTextColor,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No avatars found',
              style: TextStyle(
                color: kTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for new avatars to follow!',
              style: TextStyle(color: kLightTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: avatars.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= avatars.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }

        final avatar = avatars[index];
        return _AvatarCard(
          avatar: avatar,
          onFollowChanged: () {
            // Refresh data when follow status changes
            _loadData();
          },
        );
      },
    );
  }

  Widget _buildUsersList(List<UserModel> users) {
    if (users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: kLightTextColor,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No followers yet',
              style: TextStyle(
                color: kTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Share your avatar to get more followers!',
              style: TextStyle(color: kLightTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: users.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= users.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }

        final user = users[index];
        return _UserCard(user: user);
      },
    );
  }
}

class _AvatarCard extends StatelessWidget {
  final AvatarModel avatar;
  final VoidCallback? onFollowChanged;

  const _AvatarCard({
    required this.avatar,
    this.onFollowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar image
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    name: avatar.name,
                    avatar: avatar.avatarImageUrl ?? 'assets/images/p.jpg',
                    avatarId: avatar.id,
                  ),
                ),
              );
            },
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: avatar.avatarImageUrl != null
                      ? (avatar.avatarImageUrl!.startsWith('assets/')
                          ? AssetImage(avatar.avatarImageUrl!) as ImageProvider
                          : NetworkImage(avatar.avatarImageUrl!))
                      : const AssetImage('assets/images/p.jpg'),
                ),
                // AI indicator
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: kCardColor, width: 2),
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Avatar info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avatar.name,
                  style: const TextStyle(
                    color: kTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  avatar.bio,
                  style: const TextStyle(
                    color: kLightTextColor,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        avatar.niche.displayName,
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatCount(avatar.followersCount)} followers',
                      style: const TextStyle(
                        color: kLightTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Follow button
          FollowButton(
            avatarId: avatar.id,
            style: FollowButtonStyle.secondary,
            onFollowChanged: onFollowChanged,
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            radius: 28,
            backgroundImage: user.profileImageUrl != null
                ? (user.profileImageUrl!.startsWith('assets/')
                    ? AssetImage(user.profileImageUrl!) as ImageProvider
                    : NetworkImage(user.profileImageUrl!))
                : const AssetImage('assets/images/p.jpg'),
          ),
          const SizedBox(width: 12),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? user.username,
                  style: const TextStyle(
                    color: kTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    color: kLightTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Message button
          IconButton(
            onPressed: () {
              // TODO: Implement user messaging
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User messaging coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(
              Icons.message_outlined,
              color: kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
