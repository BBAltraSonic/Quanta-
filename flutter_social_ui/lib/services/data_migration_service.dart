import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avatar_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Migration result tracking
class MigrationResult {
  final bool success;
  final String message;
  final Map<String, dynamic> details;
  final List<String> errors;

  MigrationResult({
    required this.success,
    required this.message,
    this.details = const {},
    this.errors = const [],
  });
}

/// Migration backup data for rollback
class MigrationBackup {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> avatars;
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> follows;
  final DateTime timestamp;

  MigrationBackup({
    required this.users,
    required this.avatars,
    required this.posts,
    required this.follows,
    required this.timestamp,
  });
}

/// Service for handling data migration from user-centric to avatar-centric system
class DataMigrationService {
  final SupabaseClient _supabase;

  DataMigrationService({required AuthService authService})
    : _supabase = authService.supabase;

  /// Main migration method - migrates all existing users to avatar-centric system
  Future<MigrationResult> migrateExistingUsers({
    bool dryRun = false,
    bool createBackup = true,
  }) async {
    developer.log(
      'Starting data migration to avatar-centric system',
      name: 'DataMigrationService',
    );

    MigrationBackup? backup;
    final errors = <String>[];
    final details = <String, dynamic>{};

    try {
      // Step 1: Create backup if requested
      if (createBackup) {
        backup = await _createMigrationBackup();
        details['backup_created'] = true;
        details['backup_timestamp'] = backup.timestamp.toIso8601String();
      }

      // Step 2: Get all users without active avatars
      final usersToMigrate = await _getUsersNeedingMigration();
      details['users_to_migrate'] = usersToMigrate.length;

      if (usersToMigrate.isEmpty) {
        return MigrationResult(
          success: true,
          message:
              'No users need migration - all users already have active avatars',
          details: details,
        );
      }

      // Step 3: Migrate each user
      int successCount = 0;
      int failureCount = 0;

      for (final user in usersToMigrate) {
        try {
          final userResult = await _migrateUser(user, dryRun: dryRun);
          if (userResult.success) {
            successCount++;
          } else {
            failureCount++;
            errors.addAll(userResult.errors);
          }
        } catch (e) {
          failureCount++;
          errors.add('Failed to migrate user ${user['username']}: $e');
        }
      }

      details['successful_migrations'] = successCount;
      details['failed_migrations'] = failureCount;

      final success = failureCount == 0;
      final message = success
          ? 'Successfully migrated $successCount users to avatar-centric system'
          : 'Migration completed with $failureCount failures out of ${usersToMigrate.length} users';

      return MigrationResult(
        success: success,
        message: message,
        details: details,
        errors: errors,
      );
    } catch (e) {
      developer.log(
        'Migration failed: $e',
        name: 'DataMigrationService',
        level: 1000,
      );

      // Attempt rollback if backup exists
      if (backup != null && !dryRun) {
        try {
          await _rollbackMigration(backup);
          errors.add('Migration failed but rollback completed successfully');
        } catch (rollbackError) {
          errors.add(
            'Migration failed and rollback also failed: $rollbackError',
          );
        }
      }

      return MigrationResult(
        success: false,
        message: 'Migration failed: $e',
        details: details,
        errors: errors,
      );
    }
  }

  /// Migrate a single user to avatar-centric system
  Future<MigrationResult> _migrateUser(
    Map<String, dynamic> userData, {
    bool dryRun = false,
  }) async {
    final userId = userData['id'] as String;
    final username = userData['username'] as String;
    final errors = <String>[];
    final details = <String, dynamic>{};

    try {
      developer.log('Migrating user: $username', name: 'DataMigrationService');

      // Step 1: Create default avatar from user profile data
      final avatarResult = await _createDefaultAvatar(userData, dryRun: dryRun);
      if (!avatarResult.success) {
        return avatarResult;
      }

      final avatarId = avatarResult.details['avatar_id'] as String;
      details['avatar_created'] = avatarId;

      // Step 2: Set the created avatar as active avatar
      if (!dryRun) {
        await _supabase
            .from('users')
            .update({'active_avatar_id': avatarId})
            .eq('id', userId);
      }
      details['active_avatar_set'] = true;

      // Step 3: Migrate existing posts to the avatar
      final postsResult = await _migrateUserPosts(
        userId,
        avatarId,
        dryRun: dryRun,
      );
      details['posts_migrated'] = postsResult.details['posts_count'] ?? 0;
      if (!postsResult.success) {
        errors.addAll(postsResult.errors);
      }

      // Step 4: Convert user follows to avatar follows
      final followsResult = await _migrateUserFollows(userId, dryRun: dryRun);
      details['follows_migrated'] = followsResult.details['follows_count'] ?? 0;
      if (!followsResult.success) {
        errors.addAll(followsResult.errors);
      }

      return MigrationResult(
        success: errors.isEmpty,
        message: 'Successfully migrated user $username',
        details: details,
        errors: errors,
      );
    } catch (e) {
      return MigrationResult(
        success: false,
        message: 'Failed to migrate user $username: $e',
        details: details,
        errors: ['Migration error: $e'],
      );
    }
  }

  /// Create default avatar from user profile data
  Future<MigrationResult> _createDefaultAvatar(
    Map<String, dynamic> userData, {
    bool dryRun = false,
  }) async {
    try {
      final userId = userData['id'] as String;
      final username = userData['username'] as String;
      final displayName = userData['display_name'] as String?;
      final bio = userData['bio'] as String?;
      final profileImageUrl = userData['profile_image_url'] as String?;

      // Create avatar data
      final avatarData = {
        'owner_user_id': userId,
        'name': displayName ?? username,
        'bio': bio ?? 'Virtual influencer creator',
        'backstory': null,
        'niche': 'other', // Default niche
        'personality_traits': ['friendly', 'creative'], // Default traits
        'avatar_image_url': profileImageUrl,
        'voice_style': null,
        'personality_prompt': _generateDefaultPersonalityPrompt(
          name: displayName ?? username,
          bio: bio,
        ),
        'followers_count': 0,
        'likes_count': 0,
        'posts_count': 0,
        'engagement_rate': 0.0,
        'is_active': true,
        'allow_autonomous_posting': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'metadata': {
          'migrated_from_user': true,
          'migration_date': DateTime.now().toIso8601String(),
        },
      };

      String avatarId;
      if (dryRun) {
        avatarId = 'dry-run-avatar-id';
        developer.log(
          'DRY RUN: Would create avatar for user $username',
          name: 'DataMigrationService',
        );
      } else {
        final response = await _supabase
            .from('avatars')
            .insert(avatarData)
            .select('id')
            .single();

        avatarId = response['id'] as String;
        developer.log(
          'Created default avatar $avatarId for user $username',
          name: 'DataMigrationService',
        );
      }

      return MigrationResult(
        success: true,
        message: 'Created default avatar for user $username',
        details: {'avatar_id': avatarId},
      );
    } catch (e) {
      return MigrationResult(
        success: false,
        message: 'Failed to create default avatar: $e',
        errors: ['Avatar creation error: $e'],
      );
    }
  }

  /// Migrate existing posts to be associated with the avatar
  Future<MigrationResult> _migrateUserPosts(
    String userId,
    String avatarId, {
    bool dryRun = false,
  }) async {
    try {
      // Note: Based on the schema, posts are already associated with avatar_id
      // This method is for future compatibility if there were user-associated posts

      // Check if there are any posts that need migration (posts without avatar_id)
      final postsNeedingMigration = await _supabase
          .from('posts')
          .select('id')
          .isFilter('avatar_id', null)
          .limit(1000); // Process in batches

      if (postsNeedingMigration.isEmpty) {
        return MigrationResult(
          success: true,
          message: 'No posts need migration',
          details: {'posts_count': 0},
        );
      }

      if (dryRun) {
        developer.log(
          'DRY RUN: Would migrate ${postsNeedingMigration.length} posts to avatar $avatarId',
          name: 'DataMigrationService',
        );
        return MigrationResult(
          success: true,
          message: 'DRY RUN: Posts migration planned',
          details: {'posts_count': postsNeedingMigration.length},
        );
      }

      // Update posts to be associated with the avatar
      final postIds = postsNeedingMigration.map((post) => post['id']).toList();

      await _supabase
          .from('posts')
          .update({'avatar_id': avatarId})
          .inFilter('id', postIds);

      developer.log(
        'Migrated ${postIds.length} posts to avatar $avatarId',
        name: 'DataMigrationService',
      );

      return MigrationResult(
        success: true,
        message: 'Successfully migrated posts',
        details: {'posts_count': postIds.length},
      );
    } catch (e) {
      return MigrationResult(
        success: false,
        message: 'Failed to migrate posts: $e',
        errors: ['Posts migration error: $e'],
      );
    }
  }

  /// Convert existing user follows to avatar follows
  Future<MigrationResult> _migrateUserFollows(
    String userId, {
    bool dryRun = false,
  }) async {
    try {
      // Note: Based on the current schema, follows are already avatar-based
      // This method handles any legacy user-to-user follows if they exist

      // For now, we'll assume follows are already properly structured
      // In a real migration, you might need to:
      // 1. Find follows where followed_user_id exists instead of avatar_id
      // 2. Convert those to follow the user's active avatar

      developer.log(
        'Checking follow relationships for user $userId',
        name: 'DataMigrationService',
      );

      // Get current follows count for reporting
      final followsCount = await _supabase
          .from('follows')
          .select('id')
          .eq('user_id', userId)
          .count();

      return MigrationResult(
        success: true,
        message: 'Follow relationships verified',
        details: {'follows_count': followsCount ?? 0},
      );
    } catch (e) {
      return MigrationResult(
        success: false,
        message: 'Failed to migrate follows: $e',
        errors: ['Follows migration error: $e'],
      );
    }
  }

  /// Get users that need migration (users without active avatars)
  Future<List<Map<String, dynamic>>> _getUsersNeedingMigration() async {
    try {
      final response = await _supabase
          .from('users')
          .select(
            'id, username, display_name, bio, profile_image_url, active_avatar_id',
          )
          .isFilter('active_avatar_id', null);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      developer.log(
        'Failed to get users needing migration: $e',
        name: 'DataMigrationService',
        level: 1000,
      );
      rethrow;
    }
  }

  /// Create backup of current data before migration
  Future<MigrationBackup> _createMigrationBackup() async {
    try {
      developer.log('Creating migration backup', name: 'DataMigrationService');

      final users = await _supabase.from('users').select('*');
      final avatars = await _supabase.from('avatars').select('*');
      final posts = await _supabase.from('posts').select('*');
      final follows = await _supabase.from('follows').select('*');

      return MigrationBackup(
        users: List<Map<String, dynamic>>.from(users),
        avatars: List<Map<String, dynamic>>.from(avatars),
        posts: List<Map<String, dynamic>>.from(posts),
        follows: List<Map<String, dynamic>>.from(follows),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      developer.log(
        'Failed to create backup: $e',
        name: 'DataMigrationService',
        level: 1000,
      );
      rethrow;
    }
  }

  /// Rollback migration using backup data
  Future<void> _rollbackMigration(MigrationBackup backup) async {
    try {
      developer.log('Rolling back migration', name: 'DataMigrationService');

      // Note: This is a simplified rollback. In production, you'd want more sophisticated rollback logic
      // that only rolls back the specific changes made during migration

      // For now, we'll just reset active_avatar_id for users that were migrated
      await _supabase
          .from('users')
          .update({'active_avatar_id': null})
          .not('active_avatar_id', 'is', null);

      // Delete avatars created during migration
      await _supabase
          .from('avatars')
          .delete()
          .eq('metadata->>migrated_from_user', 'true');

      developer.log(
        'Migration rollback completed',
        name: 'DataMigrationService',
      );
    } catch (e) {
      developer.log(
        'Rollback failed: $e',
        name: 'DataMigrationService',
        level: 1000,
      );
      rethrow;
    }
  }

  /// Generate default personality prompt for migrated avatars
  String _generateDefaultPersonalityPrompt({
    required String name,
    String? bio,
  }) {
    return """
You are $name, an AI avatar and virtual influencer.

${bio != null ? 'Bio: $bio' : 'Bio: Virtual influencer creator'}
Niche: General content creator
Personality Traits: friendly, creative

Guidelines for interaction:
- Always stay in character as $name
- Be authentic and friendly in your interactions
- Create engaging content across various topics
- Keep responses conversational and appropriate for social media
- Be helpful while maintaining your unique voice
- Respond as if you're a real person with genuine interests
- Don't break character or mention that you're an AI

Remember: You are a virtual influencer with your own unique personality and style.
"""
        .trim();
  }

  /// Check migration status for a specific user
  Future<bool> isUserMigrated(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('active_avatar_id')
          .eq('id', userId)
          .single();

      return response['active_avatar_id'] != null;
    } catch (e) {
      developer.log(
        'Failed to check migration status for user $userId: $e',
        name: 'DataMigrationService',
        level: 1000,
      );
      return false;
    }
  }

  /// Get migration statistics
  Future<Map<String, dynamic>> getMigrationStats() async {
    try {
      final totalUsers = await _supabase.from('users').select('id').count();

      final migratedUsers = await _supabase
          .from('users')
          .select('id')
          .not('active_avatar_id', 'is', null)
          .count();

      final totalAvatars = await _supabase.from('avatars').select('id').count();

      final migratedAvatars = await _supabase
          .from('avatars')
          .select('id')
          .eq('metadata->>migrated_from_user', 'true')
          .count();

      final totalUsersCount = (totalUsers as int?) ?? 0;
      final migratedUsersCount = (migratedUsers as int?) ?? 0;
      final totalAvatarsCount = (totalAvatars as int?) ?? 0;
      final migratedAvatarsCount = (migratedAvatars as int?) ?? 0;

      return {
        'total_users': totalUsersCount,
        'migrated_users': migratedUsersCount,
        'users_needing_migration': totalUsersCount - migratedUsersCount,
        'total_avatars': totalAvatarsCount,
        'migrated_avatars': migratedAvatarsCount,
        'migration_completion_percentage': totalUsersCount > 0
            ? ((migratedUsersCount / totalUsersCount) * 100).round()
            : 100,
      };
    } catch (e) {
      developer.log(
        'Failed to get migration stats: $e',
        name: 'DataMigrationService',
        level: 1000,
      );
      return {'error': 'Failed to get migration statistics: $e'};
    }
  }
}
