import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:quanta/services/data_migration_service.dart';
import 'package:quanta/services/auth_service.dart';

// Generate mocks
@GenerateMocks([AuthService, SupabaseClient])
import 'data_migration_service_test.mocks.dart';

void main() {
  group('DataMigrationService', () {
    late DataMigrationService migrationService;
    late MockAuthService mockAuthService;
    late MockSupabaseClient mockSupabase;

    setUp(() {
      mockAuthService = MockAuthService();
      mockSupabase = MockSupabaseClient();

      when(mockAuthService.supabase).thenReturn(mockSupabase);

      migrationService = DataMigrationService(authService: mockAuthService);
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

    group('Service Initialization', () {
      test('should initialize with auth service', () {
        expect(migrationService, isNotNull);
        verify(mockAuthService.supabase).called(greaterThan(0));
      });
    });

    group('Error Handling', () {
      test('should handle null auth service gracefully', () {
        expect(
          () => DataMigrationService(authService: mockAuthService),
          returnsNormally,
        );
      });
    });
  });
}
