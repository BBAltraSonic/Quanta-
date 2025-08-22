import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:quanta/services/data_migration_service.dart';
import 'package:quanta/services/auth_service.dart';

// Mock classes for testing
class MockAuthService extends Mock implements AuthService {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

void main() {
  group('DataMigrationService', () {
    late DataMigrationService migrationService;
    late MockAuthService mockAuthService;
    late MockSupabaseClient mockSupabase;
    late MockSupabaseQueryBuilder mockQueryBuilder;

    setUp(() {
      mockAuthService = MockAuthService();
      mockSupabase = MockSupabaseClient();
      mockQueryBuilder = MockSupabaseQueryBuilder();

      when(mockAuthService.supabase).thenReturn(mockSupabase);
      when(mockSupabase.from(any)).thenReturn(mockQueryBuilder);

      migrationService = DataMigrationService(authService: mockAuthService);
    });

    group('Migration Statistics', () {
      test('should return correct migration statistics', () async {
        // Mock count queries
        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.count()).thenAnswer((_) async => 10);
        when(mockQueryBuilder.not(any, any, any)).thenReturn(mockQueryBuilder);

        final stats = await migrationService.getMigrationStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('total_users'), isTrue);
        expect(stats.containsKey('migrated_users'), isTrue);
        expect(stats.containsKey('migration_completion_percentage'), isTrue);
      });

      test('should handle errors when getting statistics', () async {
        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.count()).thenThrow(Exception('Database error'));

        final stats = await migrationService.getMigrationStats();

        expect(stats.containsKey('error'), isTrue);
        expect(stats['error'], contains('Failed to get migration statistics'));
      });
    });

    group('User Migration Status', () {
      test('should correctly identify migrated user', () async {
        const userId = 'test-user-id';

        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.eq(any, any)).thenReturn(mockQueryBuilder);
        when(
          mockQueryBuilder.single(),
        ).thenAnswer((_) async => {'active_avatar_id': 'test-avatar-id'});

        final isMigrated = await migrationService.isUserMigrated(userId);

        expect(isMigrated, isTrue);
        verify(mockSupabase.from('users')).called(1);
        verify(mockQueryBuilder.select('active_avatar_id')).called(1);
        verify(mockQueryBuilder.eq('id', userId)).called(1);
      });

      test('should correctly identify non-migrated user', () async {
        const userId = 'test-user-id';

        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.eq(any, any)).thenReturn(mockQueryBuilder);
        when(
          mockQueryBuilder.single(),
        ).thenAnswer((_) async => {'active_avatar_id': null});

        final isMigrated = await migrationService.isUserMigrated(userId);

        expect(isMigrated, isFalse);
      });

      test('should handle errors when checking migration status', () async {
        const userId = 'test-user-id';

        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.eq(any, any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.single()).thenThrow(Exception('User not found'));

        final isMigrated = await migrationService.isUserMigrated(userId);

        expect(isMigrated, isFalse);
      });
    });

    group('Full Migration Process', () {
      test(
        'should complete migration successfully when users need migration',
        () async {
          // Mock users needing migration
          when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
          when(
            mockQueryBuilder.isFilter(any, any),
          ).thenReturn(mockQueryBuilder);
          when(mockQueryBuilder.then()).thenAnswer(
            (_) async => [
              {
                'id': 'user-1',
                'username': 'testuser1',
                'display_name': 'Test User 1',
                'bio': 'Test bio',
                'profile_image_url': null,
                'active_avatar_id': null,
              },
            ],
          );

          // Mock avatar creation
          when(mockQueryBuilder.insert(any)).thenReturn(mockQueryBuilder);
          when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
          when(
            mockQueryBuilder.single(),
          ).thenAnswer((_) async => {'id': 'new-avatar-id'});

          // Mock user update
          when(mockQueryBuilder.update(any)).thenReturn(mockQueryBuilder);
          when(mockQueryBuilder.eq(any, any)).thenReturn(mockQueryBuilder);

          // Mock posts migration (no posts to migrate)
          when(
            mockQueryBuilder.isFilter(any, any),
          ).thenReturn(mockQueryBuilder);
          when(mockQueryBuilder.limit(any)).thenReturn(mockQueryBuilder);
          when(mockQueryBuilder.then()).thenAnswer((_) async => []);

          // Mock follows count
          when(mockQueryBuilder.count()).thenAnswer((_) async => 0);

          final result = await migrationService.migrateExistingUsers(
            dryRun: true,
            createBackup: false,
          );

          expect(result.success, isTrue);
          expect(result.details['users_to_migrate'], equals(1));
          expect(result.details['successful_migrations'], equals(1));
          expect(result.details['failed_migrations'], equals(0));
        },
      );

      test('should handle case when no users need migration', () async {
        // Mock no users needing migration
        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.isFilter(any, any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.then()).thenAnswer((_) async => []);

        final result = await migrationService.migrateExistingUsers(
          dryRun: true,
          createBackup: false,
        );

        expect(result.success, isTrue);
        expect(result.message, contains('No users need migration'));
        expect(result.details['users_to_migrate'], equals(0));
      });

      test('should handle migration errors gracefully', () async {
        // Mock users needing migration
        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.isFilter(any, any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.then()).thenAnswer(
          (_) async => [
            {
              'id': 'user-1',
              'username': 'testuser1',
              'display_name': 'Test User 1',
              'bio': 'Test bio',
              'profile_image_url': null,
              'active_avatar_id': null,
            },
          ],
        );

        // Mock avatar creation failure
        when(mockQueryBuilder.insert(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(
          mockQueryBuilder.single(),
        ).thenThrow(Exception('Avatar creation failed'));

        final result = await migrationService.migrateExistingUsers(
          dryRun: false,
          createBackup: false,
        );

        expect(result.success, isFalse);
        expect(result.details['failed_migrations'], equals(1));
        expect(result.errors.isNotEmpty, isTrue);
      });
    });

    group('Dry Run Mode', () {
      test('should not make database changes in dry run mode', () async {
        // Mock users needing migration
        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.isFilter(any, any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.then()).thenAnswer(
          (_) async => [
            {
              'id': 'user-1',
              'username': 'testuser1',
              'display_name': 'Test User 1',
              'bio': 'Test bio',
              'profile_image_url': null,
              'active_avatar_id': null,
            },
          ],
        );

        // Mock posts migration (no posts to migrate)
        when(mockQueryBuilder.isFilter(any, any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.limit(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.then()).thenAnswer((_) async => []);

        // Mock follows count
        when(mockQueryBuilder.count()).thenAnswer((_) async => 0);

        final result = await migrationService.migrateExistingUsers(
          dryRun: true,
          createBackup: false,
        );

        expect(result.success, isTrue);

        // Verify no insert or update operations were called
        verifyNever(mockQueryBuilder.insert(any));
        verifyNever(mockQueryBuilder.update(any));
      });
    });

    group('Backup Creation', () {
      test('should create backup when requested', () async {
        // Mock backup data
        when(mockQueryBuilder.select('*')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.then()).thenAnswer((_) async => []);

        // Mock no users needing migration
        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.isFilter(any, any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.then()).thenAnswer((_) async => []);

        final result = await migrationService.migrateExistingUsers(
          dryRun: true,
          createBackup: true,
        );

        expect(result.success, isTrue);
        expect(result.details['backup_created'], isTrue);
        expect(result.details.containsKey('backup_timestamp'), isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle database connection errors', () async {
        when(mockQueryBuilder.select(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.isFilter(any, any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.then()).thenThrow(Exception('Connection failed'));

        final result = await migrationService.migrateExistingUsers(
          dryRun: true,
          createBackup: false,
        );

        expect(result.success, isFalse);
        expect(result.message, contains('Migration failed'));
        expect(result.errors.isNotEmpty, isTrue);
      });

      test('should handle backup creation errors', () async {
        when(mockQueryBuilder.select('*')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.then()).thenThrow(Exception('Backup failed'));

        final result = await migrationService.migrateExistingUsers(
          dryRun: true,
          createBackup: true,
        );

        expect(result.success, isFalse);
        expect(result.message, contains('Migration failed'));
      });
    });

    group('Migration Result', () {
      test('should create proper migration result for success', () {
        final result = MigrationResult(
          success: true,
          message: 'Test success',
          details: {'test': 'value'},
          errors: [],
        );

        expect(result.success, isTrue);
        expect(result.message, equals('Test success'));
        expect(result.details['test'], equals('value'));
        expect(result.errors.isEmpty, isTrue);
      });

      test('should create proper migration result for failure', () {
        final result = MigrationResult(
          success: false,
          message: 'Test failure',
          details: {},
          errors: ['Error 1', 'Error 2'],
        );

        expect(result.success, isFalse);
        expect(result.message, equals('Test failure'));
        expect(result.errors.length, equals(2));
        expect(result.errors, contains('Error 1'));
        expect(result.errors, contains('Error 2'));
      });
    });

    group('Migration Backup', () {
      test('should create migration backup with proper structure', () {
        final backup = MigrationBackup(
          users: [
            {'id': 'user1'},
          ],
          avatars: [
            {'id': 'avatar1'},
          ],
          posts: [
            {'id': 'post1'},
          ],
          follows: [
            {'id': 'follow1'},
          ],
          timestamp: DateTime.now(),
        );

        expect(backup.users.length, equals(1));
        expect(backup.avatars.length, equals(1));
        expect(backup.posts.length, equals(1));
        expect(backup.follows.length, equals(1));
        expect(backup.timestamp, isA<DateTime>());
      });
    });
  });
}
