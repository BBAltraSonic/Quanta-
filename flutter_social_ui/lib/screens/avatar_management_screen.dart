import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/avatar_model.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/skeleton_widgets.dart';
import '../screens/avatar_creation_wizard.dart';

class AvatarManagementScreen extends StatefulWidget {
  const AvatarManagementScreen({super.key});

  @override
  State<AvatarManagementScreen> createState() => _AvatarManagementScreenState();
}

class _AvatarManagementScreenState extends State<AvatarManagementScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  List<AvatarModel> _avatars = [];
  String? _activeAvatarId;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final avatars = await _profileService.getUserAvatars(userId);
        setState(() {
          _avatars = avatars;
          _activeAvatarId = avatars.isNotEmpty ? avatars.first.id : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load avatars: $e');
    }
  }

  Future<void> _setActiveAvatar(String avatarId) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        await _profileService.setActiveAvatar(userId, avatarId);
        setState(() {
          _activeAvatarId = avatarId;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Active avatar updated'),
            backgroundColor: kPrimaryColor,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update active avatar: $e');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _createNewAvatar() async {
    final result = await Navigator.push<AvatarModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const AvatarCreationWizard(
          returnResultOnCreate: true,
        ),
      ),
    );

    if (result != null) {
      // Refresh avatars list
      await _loadAvatars();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Avatar "${result.name}" created successfully! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showAvatarDetails(AvatarModel avatar) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: avatar.avatarImageUrl != null
                      ? avatar.avatarImageUrl!.startsWith('assets/')
                          ? AssetImage(avatar.avatarImageUrl!) as ImageProvider
                          : NetworkImage(avatar.avatarImageUrl!)
                      : null,
                  child: avatar.avatarImageUrl == null
                      ? const Icon(Icons.person, size: 30, color: kLightTextColor)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        avatar.name,
                        style: const TextStyle(
                          color: kTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        avatar.nicheDisplayName,
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              avatar.bio,
              style: const TextStyle(
                color: kLightTextColor,
                fontSize: 16,
              ),
            ),
            if (avatar.backstory != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Backstory:',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                avatar.backstory!,
                style: const TextStyle(
                  color: kLightTextColor,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Personality:',
                  style: TextStyle(
                    color: kTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    avatar.personalityTraitsDisplayText,
                    style: const TextStyle(
                      color: kLightTextColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  label: 'Followers',
                  value: _formatNumber(avatar.followersCount),
                ),
                _StatChip(
                  label: 'Posts',
                  value: avatar.postsCount.toString(),
                ),
                _StatChip(
                  label: 'Engagement',
                  value: '${avatar.engagementRate.toStringAsFixed(1)}%',
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kCardColor,
        elevation: 0,
        title: const Text(
          'My Avatars',
          style: TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: kTextColor),
        ),
        actions: [
          IconButton(
            onPressed: _createNewAvatar,
            icon: const Icon(Icons.add, color: kPrimaryColor),
            tooltip: 'Create New Avatar',
          ),
        ],
      ),
      body: _isLoading
          ? SkeletonLoader.avatarManagementGrid(itemCount: 4)
          : _avatars.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _avatars.length,
                  itemBuilder: (context, index) {
                    final avatar = _avatars[index];
                    final isActive = avatar.id == _activeAvatarId;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: kCardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: isActive
                            ? Border.all(color: kPrimaryColor, width: 2)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: avatar.avatarImageUrl != null
                                  ? avatar.avatarImageUrl!.startsWith('assets/')
                                      ? AssetImage(avatar.avatarImageUrl!) as ImageProvider
                                      : NetworkImage(avatar.avatarImageUrl!)
                                  : null,
                              child: avatar.avatarImageUrl == null
                                  ? const Icon(Icons.person, size: 30, color: kLightTextColor)
                                  : null,
                            ),
                            if (isActive)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                avatar.name,
                                style: TextStyle(
                                  color: isActive ? kPrimaryColor : kTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    avatar.nicheDisplayName,
                                    style: const TextStyle(
                                      color: kPrimaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_formatNumber(avatar.followersCount)} followers',
                                  style: const TextStyle(
                                    color: kLightTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          color: kCardColor,
                          icon: const Icon(Icons.more_vert, color: kLightTextColor),
                          itemBuilder: (context) => [
                            if (!isActive)
                              PopupMenuItem(
                                onTap: () => _setActiveAvatar(avatar.id),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: kPrimaryColor, size: 20),
                                    SizedBox(width: 8),
                                    Text('Set as Active', style: TextStyle(color: kTextColor)),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              onTap: () => _showAvatarDetails(avatar),
                              child: const Row(
                                children: [
                                  Icon(Icons.info, color: kTextColor, size: 20),
                                  SizedBox(width: 8),
                                  Text('View Details', style: TextStyle(color: kTextColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _showAvatarDetails(avatar),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewAvatar,
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 50,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Avatars Yet',
              style: TextStyle(
                color: kTextColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create your first AI avatar to start building your virtual influencer presence!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kLightTextColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Create Avatar',
              onPressed: _createNewAvatar,
              icon: Icons.add,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: kPrimaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: kLightTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
