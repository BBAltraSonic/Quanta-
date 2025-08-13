import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../screens/auth_wrapper.dart';
import '../screens/analytics_settings_screen.dart';
import '../widgets/skeleton_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  Map<String, dynamic> _preferences = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;
  bool _isExportingAnalytics = false;
  bool _hasChanges = false;

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
          setState(() {
            _hasChanges = false;
          });
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
      // Enforce logical dependencies
      if (key == 'notifications_enabled' && value == false) {
        _preferences['push_notifications'] = false;
        _preferences['email_notifications'] = false;
      }
      if (key == 'data_saver' && value == true) {
        _preferences['auto_play_videos'] = false;
      }
      _hasChanges = true;
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: kLightTextColor),
            ),
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
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
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
              onPressed: (!_hasChanges || _isSaving) ? null : () {
                HapticFeedback.lightImpact();
                _savePreferences();
              },
              child: Text(
                'Save',
                style: TextStyle(
                  color: (!_hasChanges || _isSaving) ? kLightTextColor : kPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? SkeletonLoader.settingsScreen()
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
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
                    enabled: _preferences['notifications_enabled'] == true,
                  ),
                  _buildSwitchTile(
                    'Email Notifications',
                    'Receive updates via email',
                    'email_notifications',
                    Icons.email,
                    enabled: _preferences['notifications_enabled'] == true,
                  ),
                ]),

                const SizedBox(height: 24),

                _buildSection('Content', [
                  _buildSwitchTile(
                    'Auto-play Videos',
                    'Automatically play videos in feed',
                    'auto_play_videos',
                    Icons.play_circle,
                    enabled: _preferences['data_saver'] != true,
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
                    "Current: ${_privacyLabel(_preferences['privacy_level'])}",
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

                _buildSection('Analytics', [
                  _buildActionTile(
                    'My Analytics',
                    'View detailed analytics and insights',
                    Icons.analytics,
                    _navigateToAnalytics,
                  ),
                  _buildActionTile(
                    'Analytics Export',
                    'Export your analytics data in JSON or CSV',
                    Icons.file_download,
                    _exportAnalyticsData,
                    isLoading: _isExportingAnalytics,
                  ),
                ]),

                const SizedBox(height: 24),

                _buildSection('Account', [
                  _buildActionTile(
                    'Change Password',
                    'Update your account password',
                    Icons.lock,
                    _changePassword,
                  ),
                  _buildActionTile(
                    'Export Data',
                    'Download your account data',
                    Icons.download,
                    _exportUserData,
                    isLoading: _isExporting,
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

                const SizedBox(height: 24),

                _buildResetDefaults(),

                const SizedBox(height: 100),
              ],
            ),
          )
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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: _withDividers(children),
          ),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final List<Widget> result = [];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i != items.length - 1) {
        result.add(const Divider(height: 1, color: Color(0x22FFFFFF)));
      }
    }
    return result;
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    String key,
    IconData icon, {
    bool enabled = true,
  }) {
    final bool value = _preferences[key] ?? false;
    return ListTile(
      leading: Icon(icon, color: enabled ? kPrimaryColor : kLightTextColor),
      title: Text(
        title,
        style: TextStyle(color: enabled ? kTextColor : kLightTextColor, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: kLightTextColor, fontSize: 13),
      ),
      trailing: Switch(
        value: enabled ? value : false,
        onChanged: enabled ? (val) { HapticFeedback.selectionClick(); _updatePreference(key, val); } : null,
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
        onChanged: (value) { HapticFeedback.selectionClick(); _updatePreference(key, value); },
        items: options.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: const TextStyle(color: kTextColor)),
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
    bool isLoading = false,
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
      trailing: isLoading 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kPrimaryColor,
              ),
            )
          : Icon(Icons.chevron_right, color: textColor ?? kLightTextColor),
      onTap: isLoading ? null : () { HapticFeedback.lightImpact(); onTap(); },
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: kPrimaryColor),
      title: Text(
        title,
        style: const TextStyle(color: kTextColor, fontWeight: FontWeight.w500),
      ),
      trailing: Text(value, style: const TextStyle(color: kLightTextColor)),
    );
  }

  void _navigateToAnalytics() {
    final userId = _authService.currentUserId;
    if (userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnalyticsSettingsScreen(userId: userId),
        ),
      );
    }
  }

  void _changePassword() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kCardColor,
          title: const Text(
            'Change Password',
            style: TextStyle(color: kTextColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                style: const TextStyle(color: kTextColor),
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: kLightTextColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kLightTextColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kPrimaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: const TextStyle(color: kTextColor),
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: kLightTextColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kLightTextColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kPrimaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: kTextColor),
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(color: kLightTextColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kLightTextColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kPrimaryColor),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: kLightTextColor),
              ),
            ),
            TextButton(
              onPressed: isUpdating ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  isUpdating = true;
                });

                try {
                  await _profileService.changePassword(
                    currentPassword: currentPasswordController.text,
                    newPassword: newPasswordController.text,
                  );
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully'),
                      backgroundColor: kPrimaryColor,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to change password: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setDialogState(() {
                    isUpdating = false;
                  });
                }
              },
              child: isUpdating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kPrimaryColor,
                      ),
                    )
                  : const Text(
                      'Update',
                      style: TextStyle(color: kPrimaryColor),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportUserData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      final userData = await _profileService.exportUserData(userId);
      final jsonString = const JsonEncoder.withIndent('  ').convert(userData);
      
      // Get the downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'quanta_data_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(jsonString);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Your Quanta account data export',
        subject: 'Quanta Data Export',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully'),
            backgroundColor: kPrimaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _exportAnalyticsData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text(
          'Export Analytics Data',
          style: TextStyle(color: kTextColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose the format and time period for your analytics export:',
              style: TextStyle(color: kLightTextColor),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _performAnalyticsExport('json', 30);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('JSON\n(30 days)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _performAnalyticsExport('csv', 30);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCardColor,
                      foregroundColor: kTextColor,
                      side: const BorderSide(color: kPrimaryColor),
                    ),
                    child: const Text('CSV\n(30 days)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _performAnalyticsExport('json', 90);
                    },
                    child: const Text(
                      '90 Days JSON',
                      style: TextStyle(color: kPrimaryColor),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _performAnalyticsExport('csv', 90);
                    },
                    child: const Text(
                      '90 Days CSV',
                      style: TextStyle(color: kPrimaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: kLightTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performAnalyticsExport(String format, int daysBack) async {
    setState(() {
      _isExportingAnalytics = true;
    });

    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      final analyticsData = await _profileService.exportAnalyticsData(userId, daysBack: daysBack);
      
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'quanta_analytics_${daysBack}days_$timestamp.$format';
      final file = File('${directory.path}/$fileName');
      
      String fileContent;
      if (format == 'json') {
        fileContent = const JsonEncoder.withIndent('  ').convert(analyticsData);
      } else {
        fileContent = _profileService.convertAnalyticsToCSV(analyticsData);
      }
      
      await file.writeAsString(fileContent);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Your Quanta analytics export ($daysBack days, $format format)',
        subject: 'Quanta Analytics Export',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analytics exported successfully as $format'),
            backgroundColor: kPrimaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingAnalytics = false;
        });
      }
    }
  }

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(feature, style: const TextStyle(color: kTextColor)),
        content: Text(
          '$feature is coming soon! Stay tuned for updates.',
          style: const TextStyle(color: kLightTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune, color: kPrimaryColor, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalize your experience',
                  style: TextStyle(color: kTextColor, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage notifications, privacy, and content preferences. Changes are saved to your account.',
                  style: TextStyle(color: kLightTextColor, fontSize: 13, height: 1.3),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildResetDefaults() {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          setState(() {
            _preferences = {
              'notifications_enabled': true,
              'push_notifications': true,
              'email_notifications': false,
              'auto_play_videos': true,
              'data_saver': false,
              'privacy_level': 'public',
            };
            _hasChanges = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Defaults restored. Don\'t forget to save.'),
              backgroundColor: kPrimaryColor,
            ),
          );
        },
        icon: const Icon(Icons.restore, color: kPrimaryColor),
        label: const Text('Reset to defaults', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _privacyLabel(dynamic key) {
    switch (key) {
      case 'friends':
        return 'Friends Only';
      case 'private':
        return 'Private';
      case 'public':
      default:
        return 'Public';
    }
  }
}
