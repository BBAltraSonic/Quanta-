import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/services/data_migration_service.dart';

void main() {
  group('DataMigrationService Integration Tests', () {
    test('MigrationResult should be created correctly', () {
      final result = MigrationResult(
        success: true,
        message: 'Test migration completed',
        details: {'users_migrated': 5},
        errors: [],
      );

      expect(result.success, isTrue);
      expect(result.message, equals('Test migration completed'));
      expect(result.details['users_migrated'], equals(5));
      expect(result.errors, isEmpty);
    });

    test('MigrationBackup should be created correctly', () {
      final backup = MigrationBackup(
        users: [
          {'id': 'user1', 'username': 'test'},
        ],
        avatars: [
          {'id': 'avatar1', 'name': 'Test Avatar'},
        ],
        posts: [
          {'id': 'post1', 'content': 'Test post'},
        ],
        follows: [
          {'id': 'follow1', 'user_id': 'user1'},
        ],
        timestamp: DateTime.now(),
      );

      expect(backup.users.length, equals(1));
      expect(backup.avatars.length, equals(1));
      expect(backup.posts.length, equals(1));
      expect(backup.follows.length, equals(1));
      expect(backup.timestamp, isA<DateTime>());
    });

    test('MigrationResult should handle errors correctly', () {
      final result = MigrationResult(
        success: false,
        message: 'Migration failed',
        details: {'attempted_users': 10},
        errors: ['Database connection failed', 'Invalid user data'],
      );

      expect(result.success, isFalse);
      expect(result.message, equals('Migration failed'));
      expect(result.errors.length, equals(2));
      expect(result.errors, contains('Database connection failed'));
      expect(result.errors, contains('Invalid user data'));
    });
  });
}
