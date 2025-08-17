import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/store/app_state.dart';
import 'package:quanta/models/avatar_model.dart';
import 'package:quanta/models/user_model.dart';

void main() {
  group('AppState Avatar-Centric Extensions', () {
    late AppState appState;
    late AvatarModel testAvatar;
    late UserModel testUser;

    setUp(() {
      appState = AppState();
      appState.clearAll();

      testUser = UserModel(
        id: 'user1',
        username: 'testuser',
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testAvatar = AvatarModel.create(
        ownerUserId: 'user1',
        name: 'TestAvatar',
        bio: 'Test avatar bio',
        niche: AvatarNiche.tech,
        personalityTraits: [
          PersonalityTrait.friendly,
          PersonalityTrait.creative,
        ],
      );

      appState.setCurrentUser(testUser, testUser.id);
      appState.setAvatar(testAvatar);
    });

    test('should have ProfileViewMode enum', () {
      // Test that the enum exists and has the expected values
      expect(ProfileViewMode.owner, isNotNull);
      expect(ProfileViewMode.public, isNotNull);
      expect(ProfileViewMode.guest, isNotNull);
    });

    test('should set and get active avatar for user', () {
      appState.setActiveAvatarForUser('user1', testAvatar);
      expect(appState.activeAvatar, equals(testAvatar));

      final activeAvatar = appState.getActiveAvatarForUser('user1');
      expect(activeAvatar, equals(testAvatar));
    });

    test('should determine view modes correctly', () {
      // Owner view
      final ownerViewMode = appState.determineAvatarViewMode(
        testAvatar.id,
        'user1',
      );
      expect(ownerViewMode, equals(ProfileViewMode.owner));

      // Public view
      final publicViewMode = appState.determineAvatarViewMode(
        testAvatar.id,
        'user2',
      );
      expect(publicViewMode, equals(ProfileViewMode.public));

      // Guest view
      final guestViewMode = appState.determineAvatarViewMode(
        testAvatar.id,
        null,
      );
      expect(guestViewMode, equals(ProfileViewMode.guest));
    });

    test('should manage avatar follower counts', () {
      appState.updateAvatarFollowerCount(testAvatar.id, 100);
      expect(appState.getAvatarFollowerCount(testAvatar.id), equals(100));
    });

    test('should track avatar profile views', () {
      final beforeView = DateTime.now();
      appState.trackAvatarProfileView(testAvatar.id);
      final afterView = DateTime.now();

      final lastViewedAt = appState.getAvatarLastViewedAt(testAvatar.id);
      expect(lastViewedAt, isNotNull);
      expect(
        lastViewedAt!.isAfter(beforeView) ||
            lastViewedAt.isAtSameMomentAs(beforeView),
        isTrue,
      );
      expect(
        lastViewedAt.isBefore(afterView) ||
            lastViewedAt.isAtSameMomentAs(afterView),
        isTrue,
      );
    });

    test('should check avatar ownership', () {
      expect(appState.doesUserOwnAvatar('user1', testAvatar.id), isTrue);
      expect(appState.doesUserOwnAvatar('user2', testAvatar.id), isFalse);
    });

    test('should get current user avatars', () {
      final userAvatars = appState.getCurrentUserAvatars();
      expect(userAvatars.length, equals(1));
      expect(userAvatars.first, equals(testAvatar));
      expect(appState.currentUserHasAvatars, isTrue);
    });

    test('should switch active avatar', () async {
      final avatar2 = AvatarModel.create(
        ownerUserId: 'user1',
        name: 'TestAvatar2',
        bio: 'Second test avatar',
        niche: AvatarNiche.gaming,
        personalityTraits: [PersonalityTrait.energetic],
      );
      appState.setAvatar(avatar2);

      appState.setActiveAvatarForUser('user1', testAvatar);
      expect(appState.activeAvatar, equals(testAvatar));

      await appState.switchActiveAvatar(avatar2.id);
      expect(appState.activeAvatar, equals(avatar2));
    });

    test('should get avatar stats', () {
      appState.updateAvatarFollowerCount(testAvatar.id, 50);
      appState.trackAvatarProfileView(testAvatar.id);

      final stats = appState.getAvatarStats(testAvatar.id);
      expect(stats['followersCount'], equals(50));
      expect(stats['postsCount'], equals(0)); // No posts yet
      expect(stats['lastViewedAt'], isNotNull);
    });

    test('should clean up avatar state on removal', () {
      appState.updateAvatarFollowerCount(testAvatar.id, 25);
      appState.trackAvatarProfileView(testAvatar.id);

      appState.removeAvatar(testAvatar.id);

      expect(appState.getAvatar(testAvatar.id), isNull);
      expect(appState.getAvatarFollowerCount(testAvatar.id), equals(0));
      expect(appState.getAvatarLastViewedAt(testAvatar.id), isNull);
    });
  });
}
