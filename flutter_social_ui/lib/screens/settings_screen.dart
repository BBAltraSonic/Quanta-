import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';
import '../services/profile_service.dart';
import '../services/auth_service_wrapper.dart';
import '../widgets/custom_button.dart';
import '../screens/auth_wrapper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthServiceWrapper _authService = AuthServiceWrapper();

  Map<String, dynamic> _preferences = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final profileData = await _profileService.getUserProfileData(userId);
        setState(() {
          _preferences = Map.from(profileData['preferences'] ?? {});
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _preferences = {
          'notifications_enabled': true,
          'push_notifications': true,
          'email_notifications': false,
          'dark_mode': true,
          'auto_play_videos': true,
          'data_saver': false,
          'privacy_level': 'public',
        };
      });
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        await _profileService.updateUserPreferences(
          userId: userId,
          preferences: _preferences,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved successfully'),
              backgroundColor: kPrimaryColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updatePreference(String key, dynamic value) {
    setState(() {
      _preferences[key] = value;
    });
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: kTextColor),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: kLightTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kLightTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        await _profileService.deleteAccount(userId);
        await _authService.signOut();
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kCardColor,
        elevation: 0,
        title: const Text(
          'Settings',
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
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kPrimaryColor,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _savePreferences,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('Notifications', [
                  _buildSwitchTile(
                    'Enable Notifications',
                    'Receive notifications from your avatars and fans',
                    'notifications_enabled',
                    Icons.notifications,
                  ),
                  _buildSwitchTile(
                    'Push Notifications',
                    'Get instant notifications on your device',
                    'push_notifications',
                    Icons.push_pin,
                  ),
                  _buildSwitchTile(
                    'Email Notifications',
                    'Receive updates via email',
                    'email_notifications',
                    Icons.email,
                  ),
                ]),
                
                const SizedBox(height: 24),
                
                _buildSection('Appearance', [
                  _buildSwitchTile(
                    'Dark Mode',
                    'Use dark theme throughout the app',
                    'dark_mode',
                    Icons.dark_mode,
                  ),
                ]),
                
                const SizedBox(height: 24),
                
                _buildSection('Content', [
                  _buildSwitchTile(
                    'Auto-play Videos',
                    'Automatically play videos in feed',
                    'auto_play_videos',
                    Icons.play_circle,
                  ),
                  _buildSwitchTile(
                    'Data Saver',
                    'Reduce data usage while browsing',
                    'data_saver',
                    Icons.data_saver_on,
                  ),
                ]),
                
                const SizedBox(height: 24),
                
                _buildSection('Privacy', [
                  _buildDropdownTile(
                    'Account Privacy',
                    'Control who can see your profile',
                    'privacy_level',
                    Icons.privacy_tip,
                    {
                      'public': 'Public',
                      'friends': 'Friends Only',
                      'private': 'Private',
                    },
                  ),
                ]),
                
                const SizedBox(height: 32),
                
                _buildSection('Account', [
                  _buildActionTile(
                    'Change Password',
                    'Update your account password',
                    Icons.lock,
                    () => _showComingSoon('Change Password'),
                  ),
                  _buildActionTile(
                    'Export Data',
                    'Download your account data',
                    Icons.download,
                    () => _showComingSoon('Export Data'),
                  ),
                  _buildActionTile(
                    'Sign Out',
                    'Sign out of your account',
                    Icons.logout,
                    _signOut,
                  ),
                  _buildActionTile(
                    'Delete Account',
                    'Permanently delete your account',
                    Icons.delete_forever,
                    _confirmDeleteAccount,
                    textColor: Colors.red,
                  ),
                ]),
                
                const SizedBox(height: 24),
                
                _buildSection('About', [
                  _buildInfoTile('Version', '1.0.0', Icons.info),
                  _buildActionTile(
                    'Terms of Service',
                    'Read our terms and conditions',
                    Icons.article,
                    () => _showComingSoon('Terms of Service'),
                  ),
                  _buildActionTile(
                    'Privacy Policy',
                    'Learn about our privacy practices',
                    Icons.privacy_tip,
                    () => _showComingSoon('Privacy Policy'),
                  ),
                ]),
                
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    String key,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: kPrimaryColor),
      title: Text(
        title,
        style: const TextStyle(color: kTextColor, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: kLightTextColor, fontSize: 13),
      ),
      trailing: Switch(
        value: _preferences[key] ?? false,
        onChanged: (value) => _updatePreference(key, value),
        activeColor: kPrimaryColor,
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String key,
    IconData icon,
    Map<String, String> options,
  ) {
    return ListTile(
      leading: Icon(icon, color: kPrimaryColor),
      title: Text(
        title,
        style: const TextStyle(color: kTextColor, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: kLightTextColor, fontSize: 13),
      ),
      trailing: DropdownButton<String>(
        value: _preferences[key] ?? options.keys.first,
        onChanged: (value) => _updatePreference(key, value),
        items: options.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(
                  e.value,
                  style: const TextStyle(color: kTextColor),
                ),
              ),
            )
            .toList(),
        dropdownColor: kCardColor,
        underline: Container(),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? kPrimaryColor),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? kTextColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: kLightTextColor, fontSize: 13),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: textColor ?? kLightTextColor,
      ),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: kPrimaryColor),
      title: Text(
        title,
        style: const TextStyle(color: kTextColor, fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        value,
        style: const TextStyle(color: kLightTextColor),
      ),
    );
  }

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(
          feature,
          style: const TextStyle(color: kTextColor),
        ),
        content: Text(
          '$feature is coming soon! Stay tuned for updates.',
          style: const TextStyle(color: kLightTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
