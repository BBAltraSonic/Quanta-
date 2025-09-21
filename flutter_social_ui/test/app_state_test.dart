import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/store/app_state.dart';
import 'package:quanta/models/avatar_model.dart';
import 'package:quanta/models/post_model.dart';
import 'package:quanta/models/user_model.dart';

void main() {
  group('AppState Avatar-Centric State Management', () {
    late AppState appState;
    late AvatarModel testAvatar1;
    late AvatarModel testAvatar2;
    late UserModel testUser;
    late PostModel testPost;

    setUp(() {
      appState = AppState();
      appState.clearAll(); // Ensure clean state

      testUser = UserModel(
        id: 'user1',
        username: 'testuser',
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testAvatar1 = AvatarModel.create(
        ownerUserId: 'user1',
        name: 'TestAvatar1',
        bio: 'Test avatar bio',
        niche: AvatarNiche.tech,
        personalityTraits: [
          PersonalityTrait.friendly,
          PersonalityTrait.creative,
        ],
      );

      testAvatar2 = AvatarModel.create(
        ownerUserId: 'user1',
        name: 'TestAvatar2',
        bio: 'Second test avatar',
        niche: AvatarNiche.gaming,
        personalityTraits: [
          PersonalityTrait.energetic,
          PersonalityTrait.humorous,
        ],
      );

      testPost = PostModel(
        id: 'post1',
        avatarId: testAvatar1.id,
        type: PostType.image,
        caption: 'Test post content',
        hashtags: ['#test'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Set up initial state
      appState.setCurrentUser(testUser, testUser.id);
      appState.setAvatar(testAvatar1);
      appState.setAvatar(testAvatar2);
    });

    group('Active Avatar Management', () {
      test('should set active avatar for user', () {
        appState.setActiveAvatarForUser('user1', testAvatar1);

        expect(appState.activeAvatar, equals(testAvatar1));
        expect(appState.getActiveAvatarForUser('user1'), equals(testAvatar1));
      });

      test('should throw error when setting avatar for wrong user', () {
        final wrongUserAvatar = AvatarModel.create(
          ownerUserId: 'user2',
          name: 'WrongUserAvatar',
          bio: 'Wrong user avatar',
          niche: AvatarNiche.art,
          personalityTraits: [PersonalityTrait.creative],
        );

        expect(
          () => appState.setActiveAvatarForUser('user1', wrongUserAvatar),
          throwsArgumentError,
        );
      });

      test('should switch active avatar', () async {
        appState.setActiveAvatarForUser('user1', testAvatar1);
        expect(appState.activeAvatar, equals(testAvatar1));

        await appState.switchActiveAvatar(testAvatar2.id);
        expect(appState.activeAvatar, equals(testAvatar2));
      });

      test(
        'should throw error when switching to non-existent avatar',
        () async {
          expect(
            () => appState.switchActiveAvatar('nonexistent'),
            throwsArgumentError,
          );
        },
      );

      test(
        'should throw error when switching to avatar not owned by current user',
        () async {
          final otherUserAvatar = AvatarModel.create(
            ownerUserId: 'user2',
            name: 'OtherUserAvatar',
            bio: 'Other user avatar',
            niche: AvatarNiche.fitness,
            personalityTraits: [PersonalityTrait.energetic],
          );
          appState.setAvatar(otherUserAvatar);

          expect(
            () => appState.switchActiveAvatar(otherUserAvatar.id),
            throwsArgumentError,
          );
        },
      );

      test('should get current user avatars', () {
        final userAvatars = appState.getCurrentUserAvatars();

        expect(userAvatars.length, equals(2));
        expect(userAvatars.contains(testAvatar1), isTrue);
        expect(userAvatars.contains(testAvatar2), isTrue);
      });

      test('should check if current user has avatars', () {
        expect(appState.currentUserHasAvatars, isTrue);

        appState.clearAll();
        expect(appState.currentUserHasAvatars, isFalse);
      });
    });

    group('Avatar View Mode Management', () {
      test('should determine owner view mode for avatar owner', () {
        final viewMode = appState.determineAvatarViewMode(
          testAvatar1.id,
          'user1',
        );
        expect(viewMode, equals(ProfileViewMode.owner));
      });

      test('should determine public view mode for other users', () {
        final viewMode = appState.determineAvatarViewMode(
          testAvatar1.id,
          'user2',
        );
        expect(viewMode, equals(ProfileViewMode.public));
      });

      test('should determine guest view mode for unauthenticated users', () {
        final viewMode = appState.determineAvatarViewMode(testAvatar1.id, null);
        expect(viewMode, equals(ProfileViewMode.guest));
      });

      test('should cache view mode', () {
        appState.setAvatarViewMode(testAvatar1.id, ProfileViewMode.owner);
        final cachedViewMode = appState.getAvatarViewMode(testAvatar1.id);
        expect(cachedViewMode, equals(ProfileViewMode.owner));
      });

      test('should compute view mode if not cached', () {
        final viewMode = appState.getAvatarViewMode(testAvatar1.id);
        expect(
          viewMode,
          equals(ProfileViewMode.owner),
        ); // Current user owns the avatar
      });
    });

    group('Avatar Content Association', () {
      test('should associate content with avatar', () {
        appState.associateContentWithAvatar(testAvatar1.id, testPost.id);

        final avatarPosts = appState.getAvatarPosts(testAvatar1.id);
        expect(avatarPosts.length, equals(0)); // Post not in _posts yet

        // Add post to _posts and associate
        appState.setPost(testPost);
        final avatarPostsAfterSet = appState.getAvatarPosts(testAvatar1.id);
        expect(avatarPostsAfterSet.length, equals(1));
        expect(avatarPostsAfterSet.first.id, equals(testPost.id));
      });

      test('should not duplicate content association', () {
        appState.setPost(testPost);
        appState.associateContentWithAvatar(testAvatar1.id, testPost.id);
        appState.associateContentWithAvatar(
          testAvatar1.id,
          testPost.id,
        ); // Duplicate

        final avatarPosts = appState.getAvatarPosts(testAvatar1.id);
        expect(avatarPosts.length, equals(1));
      });

      test('should remove content from avatar', () {
        appState.setPost(testPost);
        appState.removeContentFromAvatar(testAvatar1.id, testPost.id);

        final avatarPosts = appState.getAvatarPosts(testAvatar1.id);
        expect(avatarPosts.length, equals(0));
      });

      test(
        'should automatically associate post with avatar when setting post',
        () {
          appState.setPost(testPost);

          final avatarPosts = appState.getAvatarPosts(testAvatar1.id);
          expect(avatarPosts.length, equals(1));
          expect(avatarPosts.first.id, equals(testPost.id));
        },
      );

      test('should remove avatar content association when removing post', () {
        appState.setPost(testPost);
        expect(appState.getAvatarPosts(testAvatar1.id).length, equals(1));

        appState.removePost(testPost.id);
        expect(appState.getAvatarPosts(testAvatar1.id).length, equals(0));
      });
    });

    group('Avatar Stats and Metrics', () {
      test('should update avatar follower count', () {
        appState.updateAvatarFollowerCount(testAvatar1.id, 100);

        expect(appState.getAvatarFollowerCount(testAvatar1.id), equals(100));

        // Should also update the avatar model
        final updatedAvatar = appState.getAvatar(testAvatar1.id);
        expect(updatedAvatar?.followersCount, equals(100));
      });

      test('should track avatar profile view', () {
        final beforeView = DateTime.now();
        appState.trackAvatarProfileView(testAvatar1.id);
        final afterView = DateTime.now();

        final lastViewedAt = appState.getAvatarLastViewedAt(testAvatar1.id);
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

      test('should get avatar stats', () {
        appState.setPost(testPost);
        appState.updateAvatarFollowerCount(testAvatar1.id, 50);
        appState.trackAvatarProfileView(testAvatar1.id);

        final stats = appState.getAvatarStats(testAvatar1.id);

        expect(stats['followersCount'], equals(50));
        expect(stats['postsCount'], equals(1));
        expect(stats['likesCount'], equals(0)); // Default from avatar
        expect(stats['engagementRate'], equals(0.0)); // Default from avatar
        expect(stats['lastViewedAt'], isNotNull);
      });

      test('should check avatar ownership', () {
        expect(appState.doesUserOwnAvatar('user1', testAvatar1.id), isTrue);
        expect(appState.doesUserOwnAvatar('user2', testAvatar1.id), isFalse);
        expect(appState.doesUserOwnAvatar('user1', 'nonexistent'), isFalse);
      });
    });

    group('State Cleanup', () {
      test('should clean up avatar-specific state when removing avatar', () {
        // Set up avatar state
        appState.setAvatarViewMode(testAvatar1.id, ProfileViewMode.owner);
        appState.associateContentWithAvatar(testAvatar1.id, 'post1');
        appState.updateAvatarFollowerCount(testAvatar1.id, 25);
        appState.trackAvatarProfileView(testAvatar1.id);

        // Remove avatar
        appState.removeAvatar(testAvatar1.id);

        // Verify cleanup
        expect(appState.getAvatar(testAvatar1.id), isNull);
        expect(
          appState.getAvatarViewMode(testAvatar1.id),
          equals(ProfileViewMode.guest),
        ); // Default for non-existent
        expect(appState.getAvatarPosts(testAvatar1.id).length, equals(0));
        expect(appState.getAvatarFollowerCount(testAvatar1.id), equals(0));
        expect(appState.getAvatarLastViewedAt(testAvatar1.id), isNull);
      });

      test('should clear all avatar-centric state on clearAll', () {
        // Set up state
        appState.setActiveAvatarForUser('user1', testAvatar1);
        appState.setAvatarViewMode(testAvatar1.id, ProfileViewMode.owner);
        appState.associateContentWithAvatar(testAvatar1.id, 'post1');
        appState.updateAvatarFollowerCount(testAvatar1.id, 30);
        appState.trackAvatarProfileView(testAvatar1.id);

        // Clear all
        appState.clearAll();

        // Verify everything is cleared
        expect(appState.activeAvatar, isNull);
        expect(appState.avatars.isEmpty, isTrue);
        expect(appState.getCurrentUserAvatars().isEmpty, isTrue);
        expect(appState.currentUserHasAvatars, isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle getting active avatar for user with no avatars', () {
        appState.clearAll();
        appState.setCurrentUser(testUser, testUser.id);

        final activeAvatar = appState.getActiveAvatarForUser('user1');
        expect(activeAvatar, isNull);
      });

      test('should handle getting avatar posts for non-existent avatar', () {
        final posts = appState.getAvatarPosts('nonexistent');
        expect(posts.isEmpty, isTrue);
      });

      test('should handle getting follower count for non-existent avatar', () {
        final count = appState.getAvatarFollowerCount('nonexistent');
        expect(count, equals(0));
      });

      test('should handle view mode determination for non-existent avatar', () {
        final viewMode = appState.determineAvatarViewMode(
          'nonexistent',
          'user1',
        );
        expect(
          viewMode,
          equals(ProfileViewMode.public),
        ); // Default when avatar not found
      });

      test('should handle ownership check for non-existent avatar', () {
        final owns = appState.doesUserOwnAvatar('user1', 'nonexistent');
        expect(owns, isFalse);
      });
    });
  });
}
