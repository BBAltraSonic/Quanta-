import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../services/enhanced_feeds_service.dart';
import '../services/auth_service.dart';
import '../config/db_config.dart';

/// Service for user safety features with Supabase backend and migration support
class UserSafetyService {
  static final UserSafetyService _instance = UserSafetyService._internal();
  factory UserSafetyService() => _instance;
  UserSafetyService._internal();

  SharedPreferences? _prefs;
  late final SupabaseClient _supabase;
  late final AuthService _authService;
  
  // Cache for performance optimization
  Map<String, Set<String>>? _blockedAvatarIdsCache;
  Map<String, Set<String>>? _mutedAvatarIdsCache;
  DateTime? _cacheLastUpdated;

  // Legacy storage keys for migration
  static const String _blockedUsersKey = 'blocked_users';
  static const String _mutedUsersKey = 'muted_users';
  static const String _reportedContentKey = 'reported_content';
  static const String _safetySettingsKey = 'safety_settings';
  static const String _migrationCompletedKey = 'safety_migration_completed';

  /// Initialize user safety service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _supabase = Supabase.instance.client;
    _authService = AuthService();
    
    debugPrint('UserSafetyService initialized');
    
    // Check if migration is needed and user is authenticated
    if (_authService.currentUserId != null && !_isMigrationCompleted()) {
      await _migrateLocalDataToSupabase();
    }
  }

  /// Check if migration has been completed
  bool _isMigrationCompleted() {
    return _prefs?.getBool(_migrationCompletedKey) ?? false;
  }

  /// Mark migration as completed
  Future<void> _markMigrationCompleted() async {
    await _prefs?.setBool(_migrationCompletedKey, true);
  }

  /// Migrate local SharedPreferences data to Supabase
  Future<void> _migrateLocalDataToSupabase() async {
    if (_authService.currentUserId == null) return;

    try {
      debugPrint('🔄 Starting safety data migration to Supabase...');

      // Migrate blocked users
      await _migrateBlockedUsers();

      // Migrate muted users
      await _migrateMutedUsers();

      // Note: Reports are not migrated as they should be server-side anyway

      // Clear local data after successful migration
      await _clearLocalData();

      // Mark migration as completed
      await _markMigrationCompleted();

      debugPrint('✅ Safety data migration completed successfully');
    } catch (e) {
      debugPrint('❌ Error during safety data migration: $e');
      // Don't mark as completed if migration failed
    }
  }

  /// Migrate blocked users from SharedPreferences to Supabase
  Future<void> _migrateBlockedUsers() async {
    final localBlockedUsers = _prefs?.getStringList(_blockedUsersKey) ?? [];
    if (localBlockedUsers.isEmpty) return;

    final userId = _authService.currentUserId!;
    final blocksToInsert = <Map<String, dynamic>>[];

    for (final blockedUserId in localBlockedUsers) {
      blocksToInsert.add({
        'blocker_user_id': userId,
        'blocked_user_id': blockedUserId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (blocksToInsert.isNotEmpty) {
      await _supabase.from(DbConfig.userBlocksTable).upsert(blocksToInsert);
      debugPrint('📦 Migrated ${blocksToInsert.length} blocked users');
    }
  }

  /// Migrate muted users from SharedPreferences to Supabase
  Future<void> _migrateMutedUsers() async {
    final mutedData = _prefs?.getString(_mutedUsersKey);
    if (mutedData == null) return;

    try {
      final List<dynamic> localMutedUsers = jsonDecode(mutedData);
      if (localMutedUsers.isEmpty) return;

      final userId = _authService.currentUserId!;
      final mutesToInsert = <Map<String, dynamic>>[];

      for (final mute in localMutedUsers) {
        final muteMap = mute as Map<String, dynamic>;
        final mutedAt = DateTime.parse(muteMap['mutedAt']);
        final durationMs = muteMap['duration'] as int?;
        
        // Check if mute hasn't expired
        if (durationMs != null) {
          final expiresAt = mutedAt.add(Duration(milliseconds: durationMs));
          if (DateTime.now().isAfter(expiresAt)) {
            continue; // Skip expired mutes
          }
        }

        mutesToInsert.add({
          'muter_user_id': userId,
          'muted_user_id': muteMap['userId'],
          'muted_at': mutedAt.toIso8601String(),
          'duration_minutes': durationMs != null ? (durationMs / 60000).round() : null,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mutesToInsert.isNotEmpty) {
        await _supabase.from(DbConfig.userMutesTable).upsert(mutesToInsert);
        debugPrint('📦 Migrated ${mutesToInsert.length} muted users');
      }
    } catch (e) {
      debugPrint('Error migrating muted users: $e');
    }
  }

  /// Clear local SharedPreferences data after migration
  Future<void> _clearLocalData() async {
    await Future.wait([
      _prefs?.remove(_blockedUsersKey) ?? Future.value(),
      _prefs?.remove(_mutedUsersKey) ?? Future.value(),
      _prefs?.remove(_reportedContentKey) ?? Future.value(),
    ]);
  }

  /// Block a user (Supabase-backed)
  Future<bool> blockUser(String userId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    if (currentUserId == userId) {
      throw Exception('Cannot block yourself');
    }

    try {
      await _supabase.from(DbConfig.userBlocksTable).upsert({
        'blocker_user_id': currentUserId,
        'blocked_user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('User blocked: $userId');
      _clearSafetyCache(); // Clear cache after blocking
      return true;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user (Supabase-backed)
  Future<bool> unblockUser(String userId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from(DbConfig.userBlocksTable)
          .delete()
          .eq('blocker_user_id', currentUserId)
          .eq('blocked_user_id', userId);

      debugPrint('User unblocked: $userId');
      _clearSafetyCache(); // Clear cache after unblocking
      return true;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }

  /// Get list of blocked users (Supabase-backed)
  Future<List<String>> getBlockedUsers() async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return [];

    try {
      final response = await _supabase
          .from(DbConfig.userBlocksTable)
          .select('blocked_user_id')
          .eq('blocker_user_id', currentUserId);

      return response.map<String>((block) => block['blocked_user_id'] as String).toList();
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return [];
    }
  }

  /// Check if user is blocked (Supabase-backed)
  Future<bool> isUserBlocked(String userId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return false;

    try {
      final response = await _supabase
          .from(DbConfig.userBlocksTable)
          .select('id')
          .eq('blocker_user_id', currentUserId)
          .eq('blocked_user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Mute a user (Supabase-backed)
  Future<bool> muteUser(String userId, {Duration? duration}) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    if (currentUserId == userId) {
      throw Exception('Cannot mute yourself');
    }

    try {
      await _supabase.from(DbConfig.userMutesTable).upsert({
        'muter_user_id': currentUserId,
        'muted_user_id': userId,
        'muted_at': DateTime.now().toIso8601String(),
        'duration_minutes': duration?.inMinutes,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('User muted: $userId for ${duration?.toString() ?? 'indefinitely'}');
      _clearSafetyCache(); // Clear cache after muting
      return true;
    } catch (e) {
      debugPrint('Error muting user: $e');
      return false;
    }
  }

  /// Unmute a user (Supabase-backed)
  Future<bool> unmuteUser(String userId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from(DbConfig.userMutesTable)
          .delete()
          .eq('muter_user_id', currentUserId)
          .eq('muted_user_id', userId);

      debugPrint('User unmuted: $userId');
      _clearSafetyCache(); // Clear cache after unmuting
      return true;
    } catch (e) {
      debugPrint('Error unmuting user: $e');
      return false;
    }
  }

  /// Get list of muted users (Supabase-backed)
  Future<List<Map<String, dynamic>>> getMutedUsers() async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return [];

    try {
      final response = await _supabase
          .from(DbConfig.userMutesTable)
          .select('muted_user_id, muted_at, duration_minutes, expires_at')
          .eq('muter_user_id', currentUserId)
          .order('created_at', ascending: false);

      return response.map<Map<String, dynamic>>((mute) => {
        'userId': mute['muted_user_id'],
        'mutedAt': mute['muted_at'],
        'duration': mute['duration_minutes'] != null 
            ? mute['duration_minutes'] * 60000 // Convert minutes to milliseconds for compatibility
            : null,
        'expiresAt': mute['expires_at'],
      }).toList();
    } catch (e) {
      debugPrint('Error getting muted users: $e');
      return [];
    }
  }

  /// Check if user is muted (Supabase-backed with automatic cleanup)
  Future<bool> isUserMuted(String userId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return false;

    try {
      // Use the database function that includes automatic cleanup
      final response = await _supabase.rpc('is_user_muted', params: {
        'muter_id': currentUserId,
        'muted_id': userId,
      });

      return response == true;
    } catch (e) {
      debugPrint('Error checking if user is muted: $e');
      return false;
    }
  }

  /// Report content (Supabase-backed)
  Future<bool> reportContent({
    required String contentId,
    required ContentType contentType,
    required ReportReason reason,
    String? additionalInfo,
    String? reportedUserId,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final reportData = <String, dynamic>{
        'user_id': currentUserId,
        'content_type': contentType.name,
        'report_type': reason.toReportType(),
        'reason': reason.name,
        'details': additionalInfo,
        'status': DbConfig.pendingReport,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Add content-specific fields
      switch (contentType) {
        case ContentType.post:
          reportData['post_id'] = contentId;
          break;
        case ContentType.comment:
          reportData['comment_id'] = contentId;
          break;
        case ContentType.profile:
          reportData['reported_user_id'] = reportedUserId ?? contentId;
          break;
        case ContentType.message:
          // For messages, we might need a different approach
          reportData['reported_user_id'] = reportedUserId;
          reportData['details'] = '${reportData['details'] ?? ''}\nMessage ID: $contentId';
          break;
      }

      await _supabase.from(DbConfig.reportsTable).insert(reportData);

      debugPrint('Content reported: $contentId for ${reason.name}');
      return true;
    } catch (e) {
      debugPrint('Error reporting content: $e');
      return false;
    }
  }

  /// Get reported content (Supabase-backed)
  Future<List<Map<String, dynamic>>> getReportedContent() async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return [];

    try {
      final response = await _supabase
          .from(DbConfig.reportsTable)
          .select('*')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting reported content: $e');
      return [];
    }
  }

  /// Update safety settings (still using SharedPreferences for user preferences)
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

  /// Get safety settings (still using SharedPreferences for user preferences)
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

  /// Filter content based on safety settings and blocks/mutes
  Future<List<PostModel>> filterContent(List<PostModel> posts) async {
    final settings = getSafetySettings();

    // Check cache validity (refresh every 5 minutes)
    final now = DateTime.now();
    if (_cacheLastUpdated == null || 
        now.difference(_cacheLastUpdated!).inMinutes > 5) {
      await _refreshSafetyCache();
    }

    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return posts;

    final blockedAvatarIds = _blockedAvatarIdsCache?[currentUserId] ?? <String>{};
    final mutedAvatarIds = _mutedAvatarIdsCache?[currentUserId] ?? <String>{};

    // Filter posts
    return posts.where((post) {
      // Filter blocked avatars
      if (blockedAvatarIds.contains(post.avatarId)) {
        return false;
      }

      // Filter muted avatars
      if (mutedAvatarIds.contains(post.avatarId)) {
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
  Future<Map<String, dynamic>> getSafetyStats() async {
    final blockedUsers = await getBlockedUsers();
    final mutedUsers = await getMutedUsers();
    final reportedContent = await getReportedContent();

    return {
      'blockedUsers': blockedUsers.length,
      'mutedUsers': mutedUsers.length,
      'reportedContent': reportedContent.length,
      'safetySettings': getSafetySettings().toJson(),
      'migrationCompleted': _isMigrationCompleted(),
    };
  }

  /// Clear all safety data (for testing/debugging)
  Future<void> clearAllSafetyData() async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return;

    try {
      await Future.wait([
        // Clear Supabase data
        _supabase
            .from(DbConfig.userBlocksTable)
            .delete()
            .eq('blocker_user_id', currentUserId),
        _supabase
            .from(DbConfig.userMutesTable)
            .delete()
            .eq('muter_user_id', currentUserId),
        _supabase
            .from(DbConfig.reportsTable)
            .delete()
            .eq('user_id', currentUserId),
        
        // Clear local data
        _clearLocalData(),
        
        // Reset migration flag
        _prefs?.remove(_migrationCompletedKey) ?? Future.value(),
        _prefs?.remove(_safetySettingsKey) ?? Future.value(),
      ]);

      debugPrint('All safety data cleared');
    } catch (e) {
      debugPrint('Error clearing safety data: $e');
    }
  }

  /// Force migration for testing
  Future<void> forceMigration() async {
    await _prefs?.setBool(_migrationCompletedKey, false);
    if (_authService.currentUserId != null) {
      await _migrateLocalDataToSupabase();
    }
  }

  /// Refresh safety cache for performance optimization
  Future<void> _refreshSafetyCache() async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return;

    try {
      _blockedAvatarIdsCache ??= {};
      _mutedAvatarIdsCache ??= {};

      // Get blocked user IDs
      final blockedUserIds = await getBlockedUsers();

      // Map blocked user IDs to avatar IDs (owners' avatars)
      final Set<String> blockedAvatarIds = {};
      if (blockedUserIds.isNotEmpty) {
        final rows = await _supabase
            .from(DbConfig.avatarsTable)
            .select('id')
            .in_('owner_user_id', blockedUserIds);
        blockedAvatarIds.addAll(rows.map<String>((r) => r['id'] as String));
      }

      // Get active mutes and map to user IDs
      final muted = await getMutedUsers();
      final now = DateTime.now();
      final mutedUserIds = muted
          .where((m) {
            final expiresAt = m['expiresAt'] as String?;
            if (expiresAt == null) return true; // Indefinite mute
            return now.isBefore(DateTime.parse(expiresAt));
          })
          .map((m) => m['userId'] as String)
          .toList();

      // Map muted user IDs to avatar IDs
      final Set<String> mutedAvatarIds = {};
      if (mutedUserIds.isNotEmpty) {
        final rows = await _supabase
            .from(DbConfig.avatarsTable)
            .select('id')
            .in_('owner_user_id', mutedUserIds);
        mutedAvatarIds.addAll(rows.map<String>((r) => r['id'] as String));
      }

      _blockedAvatarIdsCache![currentUserId] = blockedAvatarIds;
      _mutedAvatarIdsCache![currentUserId] = mutedAvatarIds;
      _cacheLastUpdated = DateTime.now();

      debugPrint('🔄 Refreshed safety cache: ${blockedAvatarIds.length} blocked, ${mutedAvatarIds.length} muted avatars');
    } catch (e) {
      debugPrint('Error refreshing safety cache: $e');
    }
  }

  /// Clear safety cache when blocking/muting operations are performed
  void _clearSafetyCache() {
    _blockedAvatarIdsCache?.clear();
    _mutedAvatarIdsCache?.clear();
    _cacheLastUpdated = null;
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

/// Extension to convert ReportReason to database report type
extension ReportReasonExtension on ReportReason {
  String toReportType() {
    switch (this) {
      case ReportReason.spam:
        return DbConfig.spamReport;
      case ReportReason.harassment:
        return DbConfig.harassmentReport;
      case ReportReason.hateContent:
        return DbConfig.inappropriateReport;
      case ReportReason.violence:
        return DbConfig.inappropriateReport;
      case ReportReason.explicitContent:
        return DbConfig.inappropriateReport;
      case ReportReason.misinformation:
        return DbConfig.inappropriateReport;
      case ReportReason.copyright:
        return DbConfig.copyrightReport;
      case ReportReason.other:
        return DbConfig.otherReport;
    }
  }
}

/// Report status
enum ReportStatus { pending, reviewed, resolved, dismissed }

/// Safety settings model
class SafetySettings {
  final bool showExplicitContent;
  final bool showViolentContent;
  final bool autoMuteSpam;
  final bool allowDirectMessages;
  final bool showSensitiveContent;

  SafetySettings({
    required this.showExplicitContent,
    required this.showViolentContent,
    required this.autoMuteSpam,
    required this.allowDirectMessages,
    required this.showSensitiveContent,
  });

  factory SafetySettings.defaultSettings() {
    return SafetySettings(
      showExplicitContent: false,
      showViolentContent: false,
      autoMuteSpam: true,
      allowDirectMessages: true,
      showSensitiveContent: false,
    );
  }

  factory SafetySettings.fromJson(Map<String, dynamic> json) {
    return SafetySettings(
      showExplicitContent: json['showExplicitContent'] ?? false,
      showViolentContent: json['showViolentContent'] ?? false,
      autoMuteSpam: json['autoMuteSpam'] ?? true,
      allowDirectMessages: json['allowDirectMessages'] ?? true,
      showSensitiveContent: json['showSensitiveContent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showExplicitContent': showExplicitContent,
      'showViolentContent': showViolentContent,
      'autoMuteSpam': autoMuteSpam,
      'allowDirectMessages': allowDirectMessages,
      'showSensitiveContent': showSensitiveContent,
    };
  }

  SafetySettings copyWith({
    bool? showExplicitContent,
    bool? showViolentContent,
    bool? autoMuteSpam,
    bool? allowDirectMessages,
    bool? showSensitiveContent,
  }) {
    return SafetySettings(
      showExplicitContent: showExplicitContent ?? this.showExplicitContent,
      showViolentContent: showViolentContent ?? this.showViolentContent,
      autoMuteSpam: autoMuteSpam ?? this.autoMuteSpam,
      allowDirectMessages: allowDirectMessages ?? this.allowDirectMessages,
      showSensitiveContent: showSensitiveContent ?? this.showSensitiveContent,
    );
  }
}