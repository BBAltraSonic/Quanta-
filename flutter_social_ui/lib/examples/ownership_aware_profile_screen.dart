import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';
import '../services/profile_service.dart';
import '../store/state_service_adapter.dart';
import '../widgets/ownership_aware_widgets.dart';
import '../services/ownership_guard_service.dart';
import '../services/enhanced_feeds_service.dart';
import '../screens/settings_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/create_post_screen.dart';

/// Example of an ownership-aware profile screen that adapts UI based on ownership
/// Shows edit/settings for own profile vs follow/block for others
class OwnershipAwareProfileScreen extends StatefulWidget {
  final String? userId; // null means current user's profile
  const OwnershipAwareProfileScreen({super.key, this.userId});

  @override
  State<OwnershipAwareProfileScreen> createState() =>
      _OwnershipAwareProfileScreenState();
}

class _OwnershipAwareProfileScreenState
    extends State<OwnershipAwareProfileScreen>
    with OwnershipAwareMixin {
  final ProfileService _profileService = ProfileService();
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();
  final OwnershipGuardService _guardService = OwnershipGuardService();
  final EnhancedFeedsService _feedsService = EnhancedFeedsService();

  UserModel? _user;
  List<AvatarModel> _avatars = [];
  AvatarModel? _activeAvatar;
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  List<PostModel> _userPosts = [];
  bool _isPostsLoading = false;

  String? get _targetUserId => widget.userId ?? _stateAdapter.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadProfileData();

    // Listen to state changes for reactive UI updates
    _stateAdapter.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _stateAdapter.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    // Update UI when ownership state changes (e.g., user logs in/out)
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProfileData() async {
    if (_targetUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load the profile data
      final profileData = await _profileService.getUserProfileData(
        _targetUserId!,
      );

      if (mounted) {
        setState(() {
          _user = profileData['user'] as UserModel;
          _avatars = profileData['avatars'] as List<AvatarModel>;
          _activeAvatar = profileData['active_avatar'] as AvatarModel?;
          _stats = profileData['stats'] as Map<String, dynamic>;
          _isLoading = false;
        });
      }

      // Load user posts after profile data is loaded
      await _loadUserPosts();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading profile data: $e');
    }
  }

  Future<void> _loadUserPosts() async {
    if (_user == null) return;

    setState(() => _isPostsLoading = true);

    try {
      final posts = await _feedsService.getUserPosts(
        userId: _user!.id,
        page: 1,
        limit: 20,
      );

      setState(() {
        _userPosts = posts;
        _isPostsLoading = false;
      });
    } catch (e) {
      setState(() => _isPostsLoading = false);
      debugPrint('Error loading user posts: $e');
    }
  }

  // ==================== OWNERSHIP-AWARE ACTIONS ====================

  Future<void> _onEditProfile() async {
    try {
      // Guard the action - only owner can edit
      await _guardService.guardProfileEdit(_targetUserId!);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfileScreen(user: _user!),
        ),
      );
    } catch (e) {
      _showErrorSnackbar(e.toString());
    }
  }

  Future<void> _onSettings() async {
    try {
      // Guard the action - only owner can access settings
      await _guardService.guardProfilePrivateView(_targetUserId!);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );
    } catch (e) {
      _showErrorSnackbar(e.toString());
    }
  }

  Future<void> _onFollow() async {
    if (_activeAvatar == null) return;

    try {
      await _guardService.guardFollowAction(_activeAvatar!.id);

      final success = await _feedsService.toggleFollow(_activeAvatar!.id);
      if (success) {
        _showSuccessSnackbar('Successfully followed ${_activeAvatar!.name}');
      } else {
        _showSuccessSnackbar('Successfully unfollowed ${_activeAvatar!.name}');
      }
    } catch (e) {
      _showErrorSnackbar(e.toString());
    }
  }

  Future<void> _onReport() async {
    try {
      await _guardService.guardReportAction(_user, 'profile');

      showOwnershipAwareDialog(
        element: _user,
        ownedDialog: (context, element) =>
            _buildOwnedDialog('report your own profile'),
        otherDialog: (context, element) => _buildReportDialog(),
      );
    } catch (e) {
      _showErrorSnackbar(e.toString());
    }
  }

  Future<void> _onBlock() async {
    if (_user == null) return;

    try {
      await _guardService.guardBlockAction(_user!.id);

      showOwnershipAwareDialog(
        element: _user,
        ownedDialog: (context, element) => _buildOwnedDialog('block yourself'),
        otherDialog: (context, element) => _buildBlockDialog(),
      );
    } catch (e) {
      _showErrorSnackbar(e.toString());
    }
  }

  Future<void> _onEditPost(PostModel post) async {
    try {
      await _guardService.guardPostEdit(post.id);

      // Navigate to edit post screen (note: current CreatePostScreen doesn't support editing)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreatePostScreen()),
      );

      // TODO: Implement post editing functionality
    } catch (e) {
      _showErrorSnackbar(e.toString());
    }
  }

  Future<void> _onDeletePost(PostModel post) async {
    try {
      await _guardService.guardPostDelete(post.id);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Post'),
          content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Implement actual post deletion
        setState(() {
          _userPosts.removeWhere((p) => p.id == post.id);
        });
        _showSuccessSnackbar('Post deleted successfully');
      }
    } catch (e) {
      _showErrorSnackbar(e.toString());
    }
  }

  // ==================== UI BUILDERS ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Profile not found')),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        child: CustomScrollView(
          slivers: [
            _buildProfileHeader(),
            _buildActionButtons(),
            _buildStatsSection(),
            _buildPostsSection(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_user?.displayName ?? 'Profile'),
      actions: [
        // Ownership-aware settings/menu button
        OwnershipVisibility(
          element: _user,
          permission: OwnershipPermission.isOwned,
          child: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _onSettings,
            tooltip: 'Settings',
          ),
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => _buildMenuItems(),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _activeAvatar?.avatarImageUrl != null
                  ? NetworkImage(_activeAvatar!.avatarImageUrl!)
                  : null,
              child: _activeAvatar?.avatarImageUrl == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              _user?.displayName ?? 'Unknown User',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_user?.bio?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                _user!.bio!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: OwnershipActionButtons(
          element: _user,
          onEdit: _onEditProfile,
          onSettings: _onSettings,
          onFollow: _onFollow,
          onUnfollow: _onFollow, // Same function handles toggle
          onReport: _onReport,
          onBlock: _onBlock,
          style: OwnershipActionStyle.defaultStyle().copyWith(
            buttonStyle: ActionButtonStyle.button,
            spacing: 12.0,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Posts', _stats['posts_count']?.toString() ?? '0'),
            _buildStatItem(
              'Followers',
              _stats['followers_count']?.toString() ?? '0',
            ),
            _buildStatItem(
              'Following',
              _stats['following_count']?.toString() ?? '0',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildPostsSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Posts', style: Theme.of(context).textTheme.titleLarge),
          ),
          if (_isPostsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_userPosts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No posts yet'),
            )
          else
            ..._userPosts.map((post) => _buildPostItem(post)),
        ],
      ),
    );
  }

  Widget _buildPostItem(PostModel post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.caption ?? 'No caption',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              // Ownership-aware post actions
              OwnershipActionButtons(
                element: post,
                onEdit: () => _onEditPost(post),
                onDelete: () => _onDeletePost(post),
                onShare: () => _sharePost(post),
                style: OwnershipActionStyle.defaultStyle().copyWith(
                  iconSize: 20.0,
                  spacing: 4.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${post.likesCount} likes'),
              const SizedBox(width: 16),
              Text('${post.commentsCount} comments'),
              const SizedBox(width: 16),
              Text('${post.viewsCount} views'),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== HELPER METHODS ====================

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final menuItems = <PopupMenuEntry<String>>[];

    // Ownership-aware menu items
    if (isOwnElement(_user)) {
      menuItems.addAll([
        const PopupMenuItem(
          value: 'edit_profile',
          child: Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('Edit Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('Settings'),
            ],
          ),
        ),
      ]);
    } else {
      menuItems.addAll([
        const PopupMenuItem(
          value: 'report',
          child: Row(
            children: [Icon(Icons.report), SizedBox(width: 8), Text('Report')],
          ),
        ),
        const PopupMenuItem(
          value: 'block',
          child: Row(
            children: [Icon(Icons.block), SizedBox(width: 8), Text('Block')],
          ),
        ),
      ]);
    }

    return menuItems;
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit_profile':
        _onEditProfile();
        break;
      case 'settings':
        _onSettings();
        break;
      case 'report':
        _onReport();
        break;
      case 'block':
        _onBlock();
        break;
    }
  }

  Widget _buildOwnedDialog(String action) {
    return AlertDialog(
      title: const Text('Not Allowed'),
      content: Text('You cannot $action.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildReportDialog() {
    return AlertDialog(
      title: const Text('Report User'),
      content: const Text('Are you sure you want to report this user?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _showSuccessSnackbar('User reported successfully');
          },
          child: const Text('Report'),
        ),
      ],
    );
  }

  Widget _buildBlockDialog() {
    return AlertDialog(
      title: const Text('Block User'),
      content: const Text('Are you sure you want to block this user?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _showSuccessSnackbar('User blocked successfully');
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Block'),
        ),
      ],
    );
  }

  void _sharePost(PostModel post) {
    // Implement post sharing logic
    _showSuccessSnackbar('Post shared successfully');
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }
}

/// Extension to add copyWith functionality to OwnershipActionStyle
extension OwnershipActionStyleCopyWith on OwnershipActionStyle {
  OwnershipActionStyle copyWith({
    ActionButtonStyle? buttonStyle,
    double? iconSize,
    double? spacing,
    TextStyle? textStyle,
    IconData? editIcon,
    IconData? deleteIcon,
    IconData? settingsIcon,
    IconData? followIcon,
    IconData? unfollowIcon,
    IconData? reportIcon,
    IconData? blockIcon,
    IconData? shareIcon,
    Color? editColor,
    Color? deleteColor,
    Color? settingsColor,
    Color? followColor,
    Color? unfollowColor,
    Color? reportColor,
    Color? blockColor,
    Color? shareColor,
  }) {
    return OwnershipActionStyle(
      buttonStyle: buttonStyle ?? this.buttonStyle,
      iconSize: iconSize ?? this.iconSize,
      spacing: spacing ?? this.spacing,
      textStyle: textStyle ?? this.textStyle,
      editIcon: editIcon ?? this.editIcon,
      deleteIcon: deleteIcon ?? this.deleteIcon,
      settingsIcon: settingsIcon ?? this.settingsIcon,
      followIcon: followIcon ?? this.followIcon,
      unfollowIcon: unfollowIcon ?? this.unfollowIcon,
      reportIcon: reportIcon ?? this.reportIcon,
      blockIcon: blockIcon ?? this.blockIcon,
      shareIcon: shareIcon ?? this.shareIcon,
      editColor: editColor ?? this.editColor,
      deleteColor: deleteColor ?? this.deleteColor,
      settingsColor: settingsColor ?? this.settingsColor,
      followColor: followColor ?? this.followColor,
      unfollowColor: unfollowColor ?? this.unfollowColor,
      reportColor: reportColor ?? this.reportColor,
      blockColor: blockColor ?? this.blockColor,
      shareColor: shareColor ?? this.shareColor,
    );
  }
}
