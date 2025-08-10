import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';

/// Service for user safety features
class UserSafetyService {
  static final UserSafetyService _instance = UserSafetyService._internal();
  factory UserSafetyService() => _instance;
  UserSafetyService._internal();

  SharedPreferences? _prefs;

  // Storage keys
  static const String _blockedUsersKey = 'blocked_users';
  static const String _mutedUsersKey = 'muted_users';
  static const String _reportedContentKey = 'reported_content';
  static const String _safetySettingsKey = 'safety_settings';

  /// Initialize user safety service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('UserSafetyService initialized');
  }

  /// Block a user
  Future<void> blockUser(String userId) async {
    if (_prefs == null) return;

    try {
      final blockedUsers = getBlockedUsers();
      if (!blockedUsers.contains(userId)) {
        blockedUsers.add(userId);
        await _prefs!.setStringList(_blockedUsersKey, blockedUsers);
        debugPrint('User blocked: $userId');
      }
    } catch (e) {
      debugPrint('Error blocking user: $e');
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String userId) async {
    if (_prefs == null) return;

    try {
      final blockedUsers = getBlockedUsers();
      if (blockedUsers.remove(userId)) {
        await _prefs!.setStringList(_blockedUsersKey, blockedUsers);
        debugPrint('User unblocked: $userId');
      }
    } catch (e) {
      debugPrint('Error unblocking user: $e');
    }
  }

  /// Get list of blocked users
  List<String> getBlockedUsers() {
    if (_prefs == null) return [];
    return _prefs!.getStringList(_blockedUsersKey) ?? [];
  }

  /// Check if user is blocked
  bool isUserBlocked(String userId) {
    return getBlockedUsers().contains(userId);
  }

  /// Mute a user
  Future<void> muteUser(String userId, {Duration? duration}) async {
    if (_prefs == null) return;

    try {
      final mutedUsers = getMutedUsers();
      final muteData = {
        'userId': userId,
        'mutedAt': DateTime.now().toIso8601String(),
        'duration': duration?.inMilliseconds,
      };

      // Remove existing mute for this user
      mutedUsers.removeWhere((mute) => mute['userId'] == userId);

      // Add new mute
      mutedUsers.add(muteData);

      await _prefs!.setString(_mutedUsersKey, jsonEncode(mutedUsers));
      debugPrint(
        'User muted: $userId for ${duration?.toString() ?? 'indefinitely'}',
      );
    } catch (e) {
      debugPrint('Error muting user: $e');
    }
  }

  /// Unmute a user
  Future<void> unmuteUser(String userId) async {
    if (_prefs == null) return;

    try {
      final mutedUsers = getMutedUsers();
      final originalLength = mutedUsers.length;

      mutedUsers.removeWhere((mute) => mute['userId'] == userId);

      if (mutedUsers.length < originalLength) {
        await _prefs!.setString(_mutedUsersKey, jsonEncode(mutedUsers));
        debugPrint('User unmuted: $userId');
      }
    } catch (e) {
      debugPrint('Error unmuting user: $e');
    }
  }

  /// Get list of muted users
  List<Map<String, dynamic>> getMutedUsers() {
    if (_prefs == null) return [];

    try {
      final mutedData = _prefs!.getString(_mutedUsersKey);
      if (mutedData != null) {
        final List<dynamic> mutedList = jsonDecode(mutedData);
        return mutedList.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error getting muted users: $e');
    }

    return [];
  }

  /// Check if user is muted
  bool isUserMuted(String userId) {
    final mutedUsers = getMutedUsers();

    for (final mute in mutedUsers) {
      if (mute['userId'] == userId) {
        // Check if mute has expired
        if (mute['duration'] != null) {
          final mutedAt = DateTime.parse(mute['mutedAt']);
          final duration = Duration(milliseconds: mute['duration']);

          if (DateTime.now().isAfter(mutedAt.add(duration))) {
            // Mute has expired, remove it
            unmuteUser(userId);
            return false;
          }
        }
        return true;
      }
    }

    return false;
  }

  /// Report content
  Future<void> reportContent({
    required String contentId,
    required ContentType contentType,
    required ReportReason reason,
    String? additionalInfo,
    String? reportedUserId,
  }) async {
    if (_prefs == null) return;

    try {
      final reports = getReportedContent();

      final report = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'contentId': contentId,
        'contentType': contentType.name,
        'reason': reason.name,
        'additionalInfo': additionalInfo,
        'reportedUserId': reportedUserId,
        'reportedAt': DateTime.now().toIso8601String(),
        'status': ReportStatus.pending.name,
      };

      reports.add(report);

      await _prefs!.setString(_reportedContentKey, jsonEncode(reports));
      debugPrint('Content reported: $contentId for ${reason.name}');

      // In production, this would send to backend moderation system
    } catch (e) {
      debugPrint('Error reporting content: $e');
    }
  }

  /// Get reported content
  List<Map<String, dynamic>> getReportedContent() {
    if (_prefs == null) return [];

    try {
      final reportsData = _prefs!.getString(_reportedContentKey);
      if (reportsData != null) {
        final List<dynamic> reportsList = jsonDecode(reportsData);
        return reportsList.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error getting reported content: $e');
    }

    return [];
  }

  /// Update safety settings
  Future<void> updateSafetySettings(SafetySettings settings) async {
    if (_prefs == null) return;

    try {
      await _prefs!.setString(
        _safetySettingsKey,
        jsonEncode(settings.toJson()),
      );
      debugPrint('Safety settings updated');
    } catch (e) {
      debugPrint('Error updating safety settings: $e');
    }
  }

  /// Get safety settings
  SafetySettings getSafetySettings() {
    if (_prefs == null) return SafetySettings.defaultSettings();

    try {
      final settingsData = _prefs!.getString(_safetySettingsKey);
      if (settingsData != null) {
        return SafetySettings.fromJson(jsonDecode(settingsData));
      }
    } catch (e) {
      debugPrint('Error getting safety settings: $e');
    }

    return SafetySettings.defaultSettings();
  }

  /// Filter content based on safety settings
  List<PostModel> filterContent(List<PostModel> posts) {
    final settings = getSafetySettings();
    final blockedUsers = getBlockedUsers();
    final mutedUsers = getMutedUsers()
        .map((m) => m['userId'] as String)
        .toList();

    return posts.where((post) {
      // Filter blocked users
      if (blockedUsers.contains(post.avatarId)) {
        return false;
      }

      // Filter muted users
      if (mutedUsers.contains(post.avatarId)) {
        return false;
      }

      // Filter based on content settings
      if (!settings.showExplicitContent && _containsExplicitContent(post)) {
        return false;
      }

      if (!settings.showViolentContent && _containsViolentContent(post)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Check if post contains explicit content
  bool _containsExplicitContent(PostModel post) {
    final text = '${post.caption} ${post.hashtags.join(' ')}'.toLowerCase();
    final explicitKeywords = ['explicit', 'nsfw', 'adult', 'sexual'];

    return explicitKeywords.any((keyword) => text.contains(keyword));
  }

  /// Check if post contains violent content
  bool _containsViolentContent(PostModel post) {
    final text = '${post.caption} ${post.hashtags.join(' ')}'.toLowerCase();
    final violentKeywords = ['violence', 'violent', 'kill', 'harm', 'attack'];

    return violentKeywords.any((keyword) => text.contains(keyword));
  }

  /// Get safety statistics
  Map<String, dynamic> getSafetyStats() {
    return {
      'blockedUsers': getBlockedUsers().length,
      'mutedUsers': getMutedUsers().length,
      'reportedContent': getReportedContent().length,
      'safetySettings': getSafetySettings().toJson(),
    };
  }

  /// Clear all safety data
  Future<void> clearAllSafetyData() async {
    if (_prefs == null) return;

    try {
      await Future.wait([
        _prefs!.remove(_blockedUsersKey),
        _prefs!.remove(_mutedUsersKey),
        _prefs!.remove(_reportedContentKey),
        _prefs!.remove(_safetySettingsKey),
      ]);

      debugPrint('All safety data cleared');
    } catch (e) {
      debugPrint('Error clearing safety data: $e');
    }
  }
}

/// Content types for reporting
enum ContentType { post, comment, message, profile }

/// Report reasons
enum ReportReason {
  spam,
  harassment,
  hateContent,
  violence,
  explicitContent,
  misinformation,
  copyright,
  other,
}

/// Report status
enum ReportStatus { pending, reviewed, resolved, dismissed }

/// Safety settings model
class SafetySettings {
  final bool showExplicitContent;
  final bool showViolentContent;
  final bool allowDirectMessages;
  final bool allowMentions;
  final bool showOnlineStatus;
  final bool allowLocationSharing;
  final int minimumAge;
  final bool requireFollowToMessage;

  SafetySettings({
    required this.showExplicitContent,
    required this.showViolentContent,
    required this.allowDirectMessages,
    required this.allowMentions,
    required this.showOnlineStatus,
    required this.allowLocationSharing,
    required this.minimumAge,
    required this.requireFollowToMessage,
  });

  factory SafetySettings.defaultSettings() {
    return SafetySettings(
      showExplicitContent: false,
      showViolentContent: false,
      allowDirectMessages: true,
      allowMentions: true,
      showOnlineStatus: true,
      allowLocationSharing: false,
      minimumAge: 13,
      requireFollowToMessage: false,
    );
  }

  factory SafetySettings.fromJson(Map<String, dynamic> json) {
    return SafetySettings(
      showExplicitContent: json['showExplicitContent'] ?? false,
      showViolentContent: json['showViolentContent'] ?? false,
      allowDirectMessages: json['allowDirectMessages'] ?? true,
      allowMentions: json['allowMentions'] ?? true,
      showOnlineStatus: json['showOnlineStatus'] ?? true,
      allowLocationSharing: json['allowLocationSharing'] ?? false,
      minimumAge: json['minimumAge'] ?? 13,
      requireFollowToMessage: json['requireFollowToMessage'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showExplicitContent': showExplicitContent,
      'showViolentContent': showViolentContent,
      'allowDirectMessages': allowDirectMessages,
      'allowMentions': allowMentions,
      'showOnlineStatus': showOnlineStatus,
      'allowLocationSharing': allowLocationSharing,
      'minimumAge': minimumAge,
      'requireFollowToMessage': requireFollowToMessage,
    };
  }

  SafetySettings copyWith({
    bool? showExplicitContent,
    bool? showViolentContent,
    bool? allowDirectMessages,
    bool? allowMentions,
    bool? showOnlineStatus,
    bool? allowLocationSharing,
    int? minimumAge,
    bool? requireFollowToMessage,
  }) {
    return SafetySettings(
      showExplicitContent: showExplicitContent ?? this.showExplicitContent,
      showViolentContent: showViolentContent ?? this.showViolentContent,
      allowDirectMessages: allowDirectMessages ?? this.allowDirectMessages,
      allowMentions: allowMentions ?? this.allowMentions,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowLocationSharing: allowLocationSharing ?? this.allowLocationSharing,
      minimumAge: minimumAge ?? this.minimumAge,
      requireFollowToMessage:
          requireFollowToMessage ?? this.requireFollowToMessage,
    );
  }
}

/// Widget for reporting content
class ReportContentDialog extends StatefulWidget {
  final String contentId;
  final ContentType contentType;
  final String? reportedUserId;

  const ReportContentDialog({
    super.key,
    required this.contentId,
    required this.contentType,
    this.reportedUserId,
  });

  @override
  State<ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<ReportContentDialog> {
  ReportReason? _selectedReason;
  final _additionalInfoController = TextEditingController();
  final _safetyService = UserSafetyService();

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Content'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this content?'),
            const SizedBox(height: 16),
            ...ReportReason.values.map(
              (reason) => RadioListTile<ReportReason>(
                title: Text(_getReasonDisplayName(reason)),
                value: reason,
                groupValue: _selectedReason,
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _additionalInfoController,
              decoration: const InputDecoration(
                labelText: 'Additional Information (Optional)',
                hintText: 'Provide more details...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedReason != null ? _submitReport : null,
          child: const Text('Submit Report'),
        ),
      ],
    );
  }

  String _getReasonDisplayName(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.harassment:
        return 'Harassment';
      case ReportReason.hateContent:
        return 'Hate Content';
      case ReportReason.violence:
        return 'Violence';
      case ReportReason.explicitContent:
        return 'Explicit Content';
      case ReportReason.misinformation:
        return 'Misinformation';
      case ReportReason.copyright:
        return 'Copyright Violation';
      case ReportReason.other:
        return 'Other';
    }
  }

  void _submitReport() async {
    if (_selectedReason == null) return;

    await _safetyService.reportContent(
      contentId: widget.contentId,
      contentType: widget.contentType,
      reason: _selectedReason!,
      additionalInfo: _additionalInfoController.text.trim().isEmpty
          ? null
          : _additionalInfoController.text.trim(),
      reportedUserId: widget.reportedUserId,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
