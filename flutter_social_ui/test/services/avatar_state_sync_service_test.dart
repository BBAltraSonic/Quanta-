import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../lib/services/avatar_state_sync_service.dart';
import '../../lib/services/auth_service.dart';
import '../../lib/services/avatar_service.dart';
import '../../lib/store/app_state.dart';
import '../../lib/models/avatar_model.dart';
import '../../lib/services/avatar_profile_error_handler.dart';

@GenerateMocks([AuthService, AvatarService])
import 'avatar_state_sync_service_test.mocks.dart';

void main() {
  group('AvatarStateSyncService', () {
    late AvatarStateSyncService syncService;
    late MockAuthService mockAuthService;
    late MockAvatarService mockAvatarService;
    late AppState appState;

    setUp(() {
      syncService = AvatarStateSyncService();
      mockAuthService = MockAuthService();
      mockAvatarService = MockAvatarService();
      appState = AppState();

      // Reset app state
      appState.setCurrentUser(null, null);
    });

    tearDown(() {
      syncService.clearStateHistory();
    });

    group('Snapshot Management', () {
      test('should create and restore snapshots', () async {
        // Create test avatar
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set up initial state
        appState.setAvatar(avatar);
        appState.setActiveAvatar(avatar);

        // Create snapshot
        final initialSnapshots = syncService.getAvailableSnapshots();
        expect(initialSnapshots, isEmpty);

        // Perform operation that creates snapshot
        await syncService.syncAvatarState('test-user-1');

        // Should have created a snapshot
        final snapshots = syncService.getAvailableSnapshots();
        expect(snapshots, isNotEmpty);
      });

      test('should limit snapshot history size', () async {
        // Create multiple snapshots
        for (int i = 0; i < 15; i++) {
          final avatar = AvatarModel(
            id: 'test-avatar-$i',
            ownerUserId: 'test-user-1',
            name: 'Test Avatar $i',
            bio: 'Test bio $i',
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.friendly],
            personalityPrompt: 'Test prompt',
            avatarImageUrl: 'test-url',
            followersCount: 100,
            engagementRate: 0.5,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          appState.setAvatar(avatar);

          // This should create a snapshot
          try {
            await syncService.syncAvatarState('test-user-1');
          } catch (e) {
            // Ignore errors for this test
          }
        }

        final snapshots = syncService.getAvailableSnapshots();
        expect(snapshots.length, lessThanOrEqualTo(10)); // Max history size
      });

      test('should rollback to last snapshot', () async {
        final avatar1 = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Original Avatar',
          bio: 'Original bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final avatar2 = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Modified Avatar',
          bio: 'Modified bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 200,
          engagementRate: 0.7,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set initial state and create snapshot
        appState.setAvatar(avatar1);
        try {
          await syncService.syncAvatarState('test-user-1');
        } catch (e) {
          // Ignore sync errors for this test
        }

        // Modify state
        appState.setAvatar(avatar2);
        expect(appState.getAvatar('test-avatar-1')?.name, 'Modified Avatar');

        // Rollback
        final rollbackSuccess = await syncService.rollbackToLastSnapshot();
        expect(rollbackSuccess, isTrue);
        expect(appState.getAvatar('test-avatar-1')?.name, 'Original Avatar');
      });

      test('should handle rollback when no snapshots exist', () async {
        final rollbackSuccess = await syncService.rollbackToLastSnapshot();
        expect(rollbackSuccess, isFalse);
      });
    });

    group('Optimistic Updates', () {
      test(
        'should perform optimistic avatar update with rollback on failure',
        () async {
          final originalAvatar = AvatarModel(
            id: 'test-avatar-1',
            ownerUserId: 'test-user-1',
            name: 'Original Avatar',
            bio: 'Original bio',
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.friendly],
            personalityPrompt: 'Test prompt',
            avatarImageUrl: 'test-url',
            followersCount: 100,
            engagementRate: 0.5,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final updatedAvatar = originalAvatar.copyWith(name: 'Updated Avatar');

          // Set initial state
          appState.setAvatar(originalAvatar);

          // Perform optimistic update that fails
          expect(() async {
            await syncService.optimisticAvatarUpdate(
              'test-avatar-1',
              updatedAvatar,
              () async {
                throw Exception('Remote update failed');
              },
            );
          }, throwsA(isA<AvatarProfileException>()));

          // State should be rolled back
          expect(appState.getAvatar('test-avatar-1')?.name, 'Original Avatar');
        },
      );

      test(
        'should perform optimistic set active avatar with rollback on failure',
        () async {
          final avatar = AvatarModel(
            id: 'test-avatar-1',
            ownerUserId: 'test-user-1',
            name: 'Test Avatar',
            bio: 'Test bio',
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.friendly],
            personalityPrompt: 'Test prompt',
            avatarImageUrl: 'test-url',
            followersCount: 100,
            engagementRate: 0.5,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Set initial state with no active avatar
          appState.setAvatar(avatar);
          expect(appState.activeAvatar, isNull);

          // Perform optimistic update that fails
          expect(() async {
            await syncService.optimisticSetActiveAvatar(
              'test-user-1',
              avatar,
              () async {
                throw Exception('Remote update failed');
              },
            );
          }, throwsA(isA<AvatarProfileException>()));

          // Active avatar should still be null (rolled back)
          expect(appState.activeAvatar, isNull);
        },
      );
    });

    group('Operation Tracking', () {
      test('should track pending operations', () {
        expect(syncService.hasPendingOperations, isFalse);
        expect(syncService.pendingOperationsCount, 0);
        expect(syncService.pendingOperationIds, isEmpty);
      });

      test('should handle operation timeouts', () {
        // Check for timeouts (this method is public)
        expect(() => syncService.checkForTimeouts(), returnsNormally);
      });
    });

    group('State Validation', () {
      test('should validate consistent state', () {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set up consistent state
        appState.setCurrentUser(null, 'test-user-1');
        appState.setAvatar(avatar);
        appState.setActiveAvatar(avatar);

        expect(syncService.validateStateConsistency(), isTrue);
      });

      test('should detect inconsistent active avatar', () {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set active avatar without adding it to avatars map
        appState.setActiveAvatar(avatar);
        // Don't call setAvatar to create inconsistency

        expect(syncService.validateStateConsistency(), isFalse);
      });
    });

    group('Cache Management', () {
      test('should clear state history', () {
        // Create some snapshots
        try {
          syncService.syncAvatarState('test-user-1');
        } catch (e) {
          // Ignore errors
        }

        syncService.clearStateHistory();
        expect(syncService.getAvailableSnapshots(), isEmpty);
      });

      test('should get available snapshots', () {
        final snapshots = syncService.getAvailableSnapshots();
        expect(snapshots, isA<List<DateTime>>());
      });
    });

    group('Error Handling', () {
      test('should handle sync errors gracefully', () async {
        // Mock avatar service to throw error
        when(
          mockAvatarService.getUserAvatars(any),
        ).thenThrow(Exception('Database error'));

        expect(() async {
          await syncService.syncAvatarState('test-user-1');
        }, throwsA(isA<AvatarProfileException>()));
      });

      test('should handle rollback failures', () async {
        // Create invalid snapshot state that would cause rollback to fail
        // This is a edge case test
        final rollbackSuccess = await syncService.rollbackToLastSnapshot();
        expect(rollbackSuccess, isFalse); // No snapshots to rollback to
      });
    });
  });
}
