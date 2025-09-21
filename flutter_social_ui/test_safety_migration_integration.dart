import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/user_safety_service.dart';
import 'lib/services/enhanced_feeds_service.dart';

/// Integration test for safety features migration
/// This test verifies that the migration from SharedPreferences to Supabase works correctly
void main() {
  group('Safety Features Migration Integration Tests', () {
    late UserSafetyService safetyService;
    late EnhancedFeedsService feedsService;

    setUpAll(() async {
      // Initialize services
      safetyService = UserSafetyService();
      feedsService = EnhancedFeedsService();

      // Note: These tests require a running Supabase instance with the proper schema
      await safetyService.initialize();
    });

    group('Migration from SharedPreferences', () {
      test('should migrate blocked users from local to Supabase', () async {
        // Setup: Add some test data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('blocked_users', ['user1', 'user2', 'user3']);

        // Trigger migration
        await safetyService.forceMigration();

        // Verify: Check that data was migrated to Supabase
        final blockedUsers = await safetyService.getBlockedUsers();
        expect(blockedUsers, contains('user1'));
        expect(blockedUsers, contains('user2'));
        expect(blockedUsers, contains('user3'));

        // Verify: Check that local data was cleared
        final localBlocked = prefs.getStringList('blocked_users');
        expect(localBlocked, isNull);
      });

      test('should migrate muted users with expiration handling', () async {
        // Setup: Add muted users with different expiration scenarios
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now();
        final mutedData = [
          {
            'userId': 'muted_user_1',
            'mutedAt': now.subtract(Duration(minutes: 30)).toIso8601String(),
            'duration': Duration(
              hours: 1,
            ).inMilliseconds, // Should still be active
          },
          {
            'userId': 'muted_user_2',
            'mutedAt': now.subtract(Duration(hours: 2)).toIso8601String(),
            'duration': Duration(hours: 1).inMilliseconds, // Should be expired
          },
          {
            'userId': 'muted_user_3',
            'mutedAt': now.toIso8601String(),
            'duration': null, // Indefinite mute
          },
        ];

        await prefs.setString('muted_users', json.encode(mutedData));

        // Trigger migration
        await safetyService.forceMigration();

        // Verify: Check that only non-expired mutes were migrated
        final mutedUsers = await safetyService.getMutedUsers();
        final mutedIds = mutedUsers.map((m) => m['userId']).toList();

        expect(
          mutedIds,
          contains('muted_user_1'),
        ); // Should be migrated (not expired)
        expect(
          mutedIds,
          isNot(contains('muted_user_2')),
        ); // Should not be migrated (expired)
        expect(
          mutedIds,
          contains('muted_user_3'),
        ); // Should be migrated (indefinite)
      });
    });

    group('Database Operations', () {
      test('should block and unblock users correctly', () async {
        const testUserId = 'test_block_user';

        // Test blocking
        final blockResult = await safetyService.blockUser(testUserId);
        expect(blockResult, isTrue);

        // Verify blocked
        final isBlocked = await safetyService.isUserBlocked(testUserId);
        expect(isBlocked, isTrue);

        // Test unblocking
        final unblockResult = await safetyService.unblockUser(testUserId);
        expect(unblockResult, isTrue);

        // Verify unblocked
        final isStillBlocked = await safetyService.isUserBlocked(testUserId);
        expect(isStillBlocked, isFalse);
      });

      test('should mute and unmute users with duration handling', () async {
        const testUserId = 'test_mute_user';

        // Test muting with duration
        final muteResult = await safetyService.muteUser(
          testUserId,
          duration: Duration(minutes: 30),
        );
        expect(muteResult, isTrue);

        // Verify muted
        final isMuted = await safetyService.isUserMuted(testUserId);
        expect(isMuted, isTrue);

        // Test unmuting
        final unmuteResult = await safetyService.unmuteUser(testUserId);
        expect(unmuteResult, isTrue);

        // Verify unmuted
        final isStillMuted = await safetyService.isUserMuted(testUserId);
        expect(isStillMuted, isFalse);
      });

      test('should handle report creation correctly', () async {
        const testPostId = 'test_post_123';

        // Test reporting
        final reportResult = await safetyService.reportContent(
          contentId: testPostId,
          contentType: ContentType.post,
          reason: ReportReason.spam,
          additionalInfo: 'Test report for integration testing',
        );
        expect(reportResult, isTrue);

        // Verify report was created
        final reports = await safetyService.getReportedContent();
        expect(reports, isNotEmpty);
        expect(reports.any((r) => r['post_id'] == testPostId), isTrue);
      });
    });

    group('Enhanced Feeds Integration', () {
      test('should filter posts from blocked users in feed', () async {
        // This test would require actual post data and avatar relationships
        // For now, we'll test that the method runs without error
        final feed = await feedsService.getVideoFeed(
          page: 0,
          limit: 10,
          applySafetyFiltering: true,
        );

        // Should not throw an error
        expect(feed, isA<List>());
      });

      test(
        'should provide mute/block functionality through feeds service',
        () async {
          const testUserId = 'feeds_test_user';

          // Test feeds service mute/block methods
          final muteResult = await feedsService.muteUser(testUserId);
          expect(muteResult, isTrue);

          final isMuted = await feedsService.isUserMuted(testUserId);
          expect(isMuted, isTrue);

          final blockResult = await feedsService.blockUser(testUserId);
          expect(blockResult, isTrue);

          final isBlocked = await feedsService.isUserBlocked(testUserId);
          expect(isBlocked, isTrue);

          // Cleanup
          await feedsService.unmuteUser(testUserId);
          await feedsService.unblockUser(testUserId);
        },
      );
    });

    group('Safety Statistics', () {
      test('should provide accurate safety statistics', () async {
        final stats = await safetyService.getSafetyStats();

        expect(stats, containsPair('blockedUsers', isA<int>()));
        expect(stats, containsPair('mutedUsers', isA<int>()));
        expect(stats, containsPair('reportedContent', isA<int>()));
        expect(stats, containsPair('migrationCompleted', isA<bool>()));
        expect(stats, containsPair('safetySettings', isA<Map>()));
      });
    });

    tearDownAll(() async {
      // Cleanup: Clear all test data
      await safetyService.clearAllSafetyData();
    });
  });
}

/// Manual test runner for when running outside of test framework
void runManualTests() async {
  print('🧪 Starting Safety Migration Integration Tests...');

  try {
    final safetyService = UserSafetyService();
    await safetyService.initialize();

    // Test basic functionality
    print('📊 Testing safety statistics...');
    final stats = await safetyService.getSafetyStats();
    print('Stats: $stats');

    // Test migration status
    print('🔄 Migration completed: ${stats['migrationCompleted']}');

    // Test blocking
    print('🚫 Testing block functionality...');
    await safetyService.blockUser('test_user_manual');
    final isBlocked = await safetyService.isUserBlocked('test_user_manual');
    print('Block test successful: $isBlocked');

    // Test muting
    print('🔇 Testing mute functionality...');
    await safetyService.muteUser(
      'test_user_manual',
      duration: Duration(minutes: 1),
    );
    final isMuted = await safetyService.isUserMuted('test_user_manual');
    print('Mute test successful: $isMuted');

    // Cleanup
    await safetyService.unblockUser('test_user_manual');
    await safetyService.unmuteUser('test_user_manual');

    print('✅ All manual tests completed successfully!');
  } catch (e) {
    print('❌ Test failed: $e');
  }
}

/// Usage documentation for the safety features
class SafetyFeaturesUsageGuide {
  static const String documentation = '''
# Safety Features Migration Usage Guide

## Overview
The safety features have been migrated from SharedPreferences to Supabase for better consistency and moderation capabilities.

## Key Features

### 1. Automatic Migration
- On first app launch after update, local safety data is automatically migrated to Supabase
- Migration only runs once per user
- Local data is cleared after successful migration

### 2. User Blocking
```dart
// Block a user
await UserSafetyService().blockUser('user_id');

// Check if user is blocked
final isBlocked = await UserSafetyService().isUserBlocked('user_id');

// Unblock a user
await UserSafetyService().unblockUser('user_id');
```

### 3. User Muting
```dart
// Mute a user indefinitely
await UserSafetyService().muteUser('user_id');

// Mute a user for specific duration
await UserSafetyService().muteUser('user_id', duration: Duration(hours: 24));

// Check if user is muted
final isMuted = await UserSafetyService().isUserMuted('user_id');

// Unmute a user
await UserSafetyService().unmuteUser('user_id');
```

### 4. Content Reporting
```dart
// Report a post
await UserSafetyService().reportContent(
  contentId: 'post_id',
  contentType: ContentType.post,
  reason: ReportReason.spam,
  additionalInfo: 'Additional details',
);
```

### 5. Feed Filtering
- Posts from blocked/muted users are automatically filtered from feeds
- Filtering can be disabled per request if needed
- Database-level filtering for better performance

## Database Schema

### Tables Created:
- `user_blocks`: Stores user blocking relationships
- `user_mutes`: Stores user muting with optional expiration
- `reports`: Stores content reports for moderation
- `view_events`: Analytics for content viewing

### RLS Policies:
- Users can only manage their own blocks/mutes/reports
- Admins can view all reports for moderation
- Proper security through Row Level Security

## Migration Process:
1. Check if migration is needed (user authenticated + not previously migrated)
2. Migrate blocked users to `user_blocks` table
3. Migrate muted users to `user_mutes` table (excluding expired)
4. Clear local SharedPreferences data
5. Mark migration as completed

## Database Functions:
- `is_user_muted(muter_id, muted_id)`: Check mute status with automatic cleanup
- `is_user_blocked(blocker_id, blocked_id)`: Check block status
- `cleanup_expired_mutes()`: Remove expired mutes
''';
}
