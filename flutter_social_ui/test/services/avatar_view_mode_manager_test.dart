import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/avatar_view_mode_manager.dart';
import '../../lib/models/profile_view_mode.dart';
import '../../lib/models/profile_action.dart';

void main() {
  group('AvatarViewModeManager', () {
    late AvatarViewModeManager manager;

    setUp(() {
      manager = AvatarViewModeManager();
    });

    group('determineViewMode', () {
      test('should return owner view when current user owns the avatar', () {
        const avatarOwnerId = 'user123';
        const currentUserId = 'user123';

        final result = manager.determineViewMode(avatarOwnerId, currentUserId);

        expect(result, ProfileViewMode.owner);
      });

      test(
        'should return public view when current user is authenticated but does not own avatar',
        () {
          const avatarOwnerId = 'user123';
          const currentUserId = 'user456';

          final result = manager.determineViewMode(
            avatarOwnerId,
            currentUserId,
          );

          expect(result, ProfileViewMode.public);
        },
      );

      test(
        'should return guest view when current user is not authenticated',
        () {
          const avatarOwnerId = 'user123';
          const String? currentUserId = null;

          final result = manager.determineViewMode(
            avatarOwnerId,
            currentUserId,
          );

          expect(result, ProfileViewMode.guest);
        },
      );
    });

    group('getAvailableActions', () {
      test('should return owner actions for owner view mode', () {
        final actions = manager.getAvailableActions(ProfileViewMode.owner);

        expect(actions, contains(ProfileActionType.editAvatar));
        expect(actions, contains(ProfileActionType.manageAvatars));
        expect(actions, contains(ProfileActionType.viewAnalytics));
        expect(actions, contains(ProfileActionType.switchAvatar));
        expect(actions, contains(ProfileActionType.share));
        expect(actions, contains(ProfileActionType.deleteAvatar));
        expect(actions, isNot(contains(ProfileActionType.follow)));
        expect(actions, isNot(contains(ProfileActionType.message)));
      });

      test(
        'should return public actions for public view mode when not following',
        () {
          final actions = manager.getAvailableActions(
            ProfileViewMode.public,
            isFollowing: false,
            isBlocked: false,
          );

          expect(actions, contains(ProfileActionType.follow));
          expect(actions, contains(ProfileActionType.message));
          expect(actions, contains(ProfileActionType.share));
          expect(actions, contains(ProfileActionType.report));
          expect(actions, contains(ProfileActionType.block));
          expect(actions, isNot(contains(ProfileActionType.unfollow)));
          expect(actions, isNot(contains(ProfileActionType.editAvatar)));
        },
      );

      test(
        'should return public actions for public view mode when following',
        () {
          final actions = manager.getAvailableActions(
            ProfileViewMode.public,
            isFollowing: true,
            isBlocked: false,
          );

          expect(actions, contains(ProfileActionType.unfollow));
          expect(actions, contains(ProfileActionType.message));
          expect(actions, contains(ProfileActionType.share));
          expect(actions, contains(ProfileActionType.report));
          expect(actions, contains(ProfileActionType.block));
          expect(actions, isNot(contains(ProfileActionType.follow)));
          expect(actions, isNot(contains(ProfileActionType.editAvatar)));
        },
      );

      test(
        'should return limited actions for public view mode when blocked',
        () {
          final actions = manager.getAvailableActions(
            ProfileViewMode.public,
            isFollowing: false,
            isBlocked: true,
          );

          expect(
            actions,
            contains(ProfileActionType.unfollow),
          ); // Represents unblock
          expect(actions, contains(ProfileActionType.share));
          expect(actions, contains(ProfileActionType.report));
          expect(actions, isNot(contains(ProfileActionType.follow)));
          expect(actions, isNot(contains(ProfileActionType.message)));
        },
      );

      test('should return guest actions for guest view mode', () {
        final actions = manager.getAvailableActions(ProfileViewMode.guest);

        expect(actions, contains(ProfileActionType.viewProfile));
        expect(actions, contains(ProfileActionType.share));
        expect(actions, contains(ProfileActionType.login));
        expect(actions, isNot(contains(ProfileActionType.follow)));
        expect(actions, isNot(contains(ProfileActionType.editAvatar)));
        expect(actions, isNot(contains(ProfileActionType.message)));
      });
    });

    group('canPerformAction', () {
      test('should allow owner actions in owner view mode', () {
        expect(
          manager.canPerformAction(
            ProfileActionType.editAvatar,
            ProfileViewMode.owner,
          ),
          isTrue,
        );
        expect(
          manager.canPerformAction(
            ProfileActionType.viewAnalytics,
            ProfileViewMode.owner,
          ),
          isTrue,
        );
        expect(
          manager.canPerformAction(
            ProfileActionType.manageAvatars,
            ProfileViewMode.owner,
          ),
          isTrue,
        );
      });

      test('should not allow owner actions in public view mode', () {
        expect(
          manager.canPerformAction(
            ProfileActionType.editAvatar,
            ProfileViewMode.public,
          ),
          isFalse,
        );
        expect(
          manager.canPerformAction(
            ProfileActionType.viewAnalytics,
            ProfileViewMode.public,
          ),
          isFalse,
        );
        expect(
          manager.canPerformAction(
            ProfileActionType.manageAvatars,
            ProfileViewMode.public,
          ),
          isFalse,
        );
      });

      test(
        'should allow follow action in public view mode when not following',
        () {
          expect(
            manager.canPerformAction(
              ProfileActionType.follow,
              ProfileViewMode.public,
              isFollowing: false,
            ),
            isTrue,
          );
        },
      );

      test(
        'should allow unfollow action in public view mode when following',
        () {
          expect(
            manager.canPerformAction(
              ProfileActionType.unfollow,
              ProfileViewMode.public,
              isFollowing: true,
            ),
            isTrue,
          );
        },
      );

      test(
        'should not allow follow action in public view mode when already following',
        () {
          expect(
            manager.canPerformAction(
              ProfileActionType.follow,
              ProfileViewMode.public,
              isFollowing: true,
            ),
            isFalse,
          );
        },
      );

      test('should allow limited actions in guest view mode', () {
        expect(
          manager.canPerformAction(
            ProfileActionType.viewProfile,
            ProfileViewMode.guest,
          ),
          isTrue,
        );
        expect(
          manager.canPerformAction(
            ProfileActionType.share,
            ProfileViewMode.guest,
          ),
          isTrue,
        );
        expect(
          manager.canPerformAction(
            ProfileActionType.login,
            ProfileViewMode.guest,
          ),
          isTrue,
        );
      });

      test('should not allow authenticated actions in guest view mode', () {
        expect(
          manager.canPerformAction(
            ProfileActionType.follow,
            ProfileViewMode.guest,
          ),
          isFalse,
        );
        expect(
          manager.canPerformAction(
            ProfileActionType.message,
            ProfileViewMode.guest,
          ),
          isFalse,
        );
      });
    });

    group('getPrimaryAction', () {
      test(
        'should return editAvatar as primary action for owner view mode',
        () {
          final primaryAction = manager.getPrimaryAction(ProfileViewMode.owner);
          expect(primaryAction, ProfileActionType.editAvatar);
        },
      );

      test(
        'should return follow as primary action for public view mode when not following',
        () {
          final primaryAction = manager.getPrimaryAction(
            ProfileViewMode.public,
            isFollowing: false,
          );
          expect(primaryAction, ProfileActionType.follow);
        },
      );

      test(
        'should return unfollow as primary action for public view mode when following',
        () {
          final primaryAction = manager.getPrimaryAction(
            ProfileViewMode.public,
            isFollowing: true,
          );
          expect(primaryAction, ProfileActionType.unfollow);
        },
      );

      test('should return login as primary action for guest view mode', () {
        final primaryAction = manager.getPrimaryAction(ProfileViewMode.guest);
        expect(primaryAction, ProfileActionType.login);
      });
    });

    group('validateActionPermission', () {
      test('should not throw for valid owner actions', () {
        expect(
          () => manager.validateActionPermission(
            ProfileActionType.editAvatar,
            'user123',
            'user123',
          ),
          returnsNormally,
        );
      });

      test(
        'should throw UnauthorizedActionException for owner actions by non-owners',
        () {
          expect(
            () => manager.validateActionPermission(
              ProfileActionType.editAvatar,
              'user123',
              'user456',
            ),
            throwsA(isA<UnauthorizedActionException>()),
          );
        },
      );

      test(
        'should throw UnauthorizedActionException for authenticated actions by guests',
        () {
          expect(
            () => manager.validateActionPermission(
              ProfileActionType.follow,
              'user123',
              null,
            ),
            throwsA(isA<UnauthorizedActionException>()),
          );
        },
      );

      test('should not throw for valid public actions', () {
        expect(
          () => manager.validateActionPermission(
            ProfileActionType.follow,
            'user123',
            'user456',
          ),
          returnsNormally,
        );
      });

      test('should not throw for valid guest actions', () {
        expect(
          () => manager.validateActionPermission(
            ProfileActionType.viewProfile,
            'user123',
            null,
          ),
          returnsNormally,
        );
      });

      test('should throw with descriptive message for owner-only actions', () {
        expect(
          () => manager.validateActionPermission(
            ProfileActionType.viewAnalytics,
            'user123',
            'user456',
          ),
          throwsA(
            predicate(
              (e) =>
                  e is UnauthorizedActionException &&
                  e.message.contains('requires avatar ownership'),
            ),
          ),
        );
      });

      test(
        'should throw with descriptive message for authentication required actions',
        () {
          expect(
            () => manager.validateActionPermission(
              ProfileActionType.message,
              'user123',
              null,
            ),
            throwsA(
              predicate(
                (e) =>
                    e is UnauthorizedActionException &&
                    e.message.contains('requires authentication'),
              ),
            ),
          );
        },
      );
    });
  });

  group('ProfileViewMode extension', () {
    test('should correctly identify owner view mode', () {
      expect(ProfileViewMode.owner.isOwner, isTrue);
      expect(ProfileViewMode.public.isOwner, isFalse);
      expect(ProfileViewMode.guest.isOwner, isFalse);
    });

    test('should correctly identify public view mode', () {
      expect(ProfileViewMode.owner.isPublic, isFalse);
      expect(ProfileViewMode.public.isPublic, isTrue);
      expect(ProfileViewMode.guest.isPublic, isFalse);
    });

    test('should correctly identify guest view mode', () {
      expect(ProfileViewMode.owner.isGuest, isFalse);
      expect(ProfileViewMode.public.isGuest, isFalse);
      expect(ProfileViewMode.guest.isGuest, isTrue);
    });

    test('should correctly identify authenticated view modes', () {
      expect(ProfileViewMode.owner.isAuthenticated, isTrue);
      expect(ProfileViewMode.public.isAuthenticated, isTrue);
      expect(ProfileViewMode.guest.isAuthenticated, isFalse);
    });

    test('should provide correct descriptions', () {
      expect(ProfileViewMode.owner.description, 'Owner View');
      expect(ProfileViewMode.public.description, 'Public View');
      expect(ProfileViewMode.guest.description, 'Guest View');
    });
  });

  group('ProfileActionType extension', () {
    test('should correctly identify owner-only actions', () {
      expect(ProfileActionType.editAvatar.isOwnerOnly, isTrue);
      expect(ProfileActionType.manageAvatars.isOwnerOnly, isTrue);
      expect(ProfileActionType.viewAnalytics.isOwnerOnly, isTrue);
      expect(ProfileActionType.switchAvatar.isOwnerOnly, isTrue);
      expect(ProfileActionType.deleteAvatar.isOwnerOnly, isTrue);

      expect(ProfileActionType.follow.isOwnerOnly, isFalse);
      expect(ProfileActionType.message.isOwnerOnly, isFalse);
      expect(ProfileActionType.share.isOwnerOnly, isFalse);
    });

    test('should correctly identify actions requiring authentication', () {
      expect(ProfileActionType.follow.requiresAuth, isTrue);
      expect(ProfileActionType.message.requiresAuth, isTrue);
      expect(ProfileActionType.editAvatar.requiresAuth, isTrue);

      expect(ProfileActionType.viewProfile.requiresAuth, isFalse);
      expect(ProfileActionType.login.requiresAuth, isFalse);
    });

    test('should provide correct default labels', () {
      expect(ProfileActionType.follow.defaultLabel, 'Follow');
      expect(ProfileActionType.editAvatar.defaultLabel, 'Edit Avatar');
      expect(ProfileActionType.viewAnalytics.defaultLabel, 'View Analytics');
    });
  });

  group('ProfileAction', () {
    test('should create ProfileAction from type with defaults', () {
      final action = ProfileAction.fromType(ProfileActionType.follow);

      expect(action.type, ProfileActionType.follow);
      expect(action.label, 'Follow');
      expect(action.icon, ProfileActionType.follow.defaultIcon);
      expect(action.isPrimary, isFalse);
      expect(action.isEnabled, isTrue);
    });

    test('should create ProfileAction from type with custom values', () {
      void onTap() {}

      final action = ProfileAction.fromType(
        ProfileActionType.follow,
        onTap: onTap,
        isPrimary: true,
        isEnabled: false,
        customLabel: 'Custom Follow',
        tooltip: 'Follow this avatar',
      );

      expect(action.type, ProfileActionType.follow);
      expect(action.label, 'Custom Follow');
      expect(action.isPrimary, isTrue);
      expect(action.isEnabled, isFalse);
      expect(action.onTap, onTap);
      expect(action.tooltip, 'Follow this avatar');
    });

    test('should create copy with updated properties', () {
      final original = ProfileAction.fromType(ProfileActionType.follow);
      final copy = original.copyWith(label: 'Updated Follow', isPrimary: true);

      expect(copy.type, ProfileActionType.follow);
      expect(copy.label, 'Updated Follow');
      expect(copy.isPrimary, isTrue);
      expect(copy.icon, original.icon);
      expect(copy.isEnabled, original.isEnabled);
    });

    test('should implement equality correctly', () {
      final action1 = ProfileAction.fromType(ProfileActionType.follow);
      final action2 = ProfileAction.fromType(ProfileActionType.follow);
      final action3 = ProfileAction.fromType(ProfileActionType.unfollow);

      expect(action1, equals(action2));
      expect(action1, isNot(equals(action3)));
    });

    test('should implement toString correctly', () {
      final action = ProfileAction.fromType(ProfileActionType.follow);
      final string = action.toString();

      expect(string, contains('ProfileAction'));
      expect(string, contains('follow'));
      expect(string, contains('Follow'));
    });
  });
}
