import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/services/avatar_content_service.dart';
import 'package:quanta/models/post_model.dart';
import 'package:quanta/models/avatar_model.dart';
import 'package:quanta/store/app_state.dart';

void main() {
  group('AvatarContentService', () {
    late AvatarContentService service;
    late AppState appState;

    setUp(() {
      service = AvatarContentService();
      appState = AppState();
      // Clear all state before each test
      appState.clearAll();
    });

    group('Content Association Logic', () {
      test('should validate avatar ownership correctly', () {
        // Arrange
        const userId = 'user-123';
        const avatarId = 'avatar-123';

        final avatar = AvatarModel(
          id: avatarId,
          ownerUserId: userId,
          name: 'Test Avatar',
          bio: 'Test avatar bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        appState.setAvatar(avatar);
        final ownsAvatar = appState.doesUserOwnAvatar(userId, avatarId);
        final doesNotOwnAvatar = appState.doesUserOwnAvatar(
          'other-user',
          avatarId,
        );

        // Assert
        expect(ownsAvatar, isTrue);
        expect(doesNotOwnAvatar, isFalse);
      });

      test('should associate content with avatar correctly', () {
        // Arrange
        const avatarId = 'avatar-123';

        final post = PostModel.create(
          avatarId: avatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/image.jpg',
          caption: 'Test post',
          hashtags: ['#test'],
        );

        // Act
        appState.setPost(post);
        appState.associateContentWithAvatar(avatarId, post.id);

        final avatarPosts = appState.getAvatarPosts(avatarId);

        // Assert
        expect(avatarPosts, hasLength(1));
        expect(avatarPosts.first.id, equals(post.id));
      });

      test('should remove content association correctly', () {
        // Arrange
        const avatarId = 'avatar-123';

        final post = PostModel.create(
          avatarId: avatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/image.jpg',
          caption: 'Test post',
          hashtags: ['#test'],
        );

        appState.setPost(post);
        appState.associateContentWithAvatar(avatarId, post.id);

        // Verify initial state
        expect(appState.getAvatarPosts(avatarId), hasLength(1));

        // Act
        appState.removeContentFromAvatar(avatarId, post.id);

        final avatarPosts = appState.getAvatarPosts(avatarId);

        // Assert
        expect(avatarPosts, isEmpty);
      });

      test('should maintain separate content for different avatars', () {
        // Arrange
        const avatar1Id = 'avatar-1';
        const avatar2Id = 'avatar-2';

        final post1 = PostModel.create(
          avatarId: avatar1Id,
          type: PostType.image,
          imageUrl: 'https://example.com/image1.jpg',
          caption: 'Post 1',
          hashtags: ['#test1'],
        );

        final post2 = PostModel.create(
          avatarId: avatar2Id,
          type: PostType.image,
          imageUrl: 'https://example.com/image2.jpg',
          caption: 'Post 2',
          hashtags: ['#test2'],
        );

        // Act
        appState.setPost(post1);
        appState.setPost(post2);
        appState.associateContentWithAvatar(avatar1Id, post1.id);
        appState.associateContentWithAvatar(avatar2Id, post2.id);

        final avatar1Posts = appState.getAvatarPosts(avatar1Id);
        final avatar2Posts = appState.getAvatarPosts(avatar2Id);

        // Assert
        expect(avatar1Posts, hasLength(1));
        expect(avatar2Posts, hasLength(1));
        expect(avatar1Posts.first.id, equals(post1.id));
        expect(avatar2Posts.first.id, equals(post2.id));

        // Verify posts are not mixed between avatars
        expect(avatar1Posts.any((p) => p.id == post2.id), isFalse);
        expect(avatar2Posts.any((p) => p.id == post1.id), isFalse);
      });

      test('should handle content transfer between avatars', () {
        // Arrange
        const fromAvatarId = 'from-avatar';
        const toAvatarId = 'to-avatar';

        final post = PostModel.create(
          avatarId: fromAvatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/image.jpg',
          caption: 'Test post',
          hashtags: ['#test'],
        );

        appState.setPost(post);
        appState.associateContentWithAvatar(fromAvatarId, post.id);

        // Verify initial state
        expect(appState.getAvatarPosts(fromAvatarId), hasLength(1));
        expect(appState.getAvatarPosts(toAvatarId), isEmpty);

        // Act - Transfer content
        appState.removeContentFromAvatar(fromAvatarId, post.id);
        appState.associateContentWithAvatar(toAvatarId, post.id);

        // Assert
        expect(appState.getAvatarPosts(fromAvatarId), isEmpty);
        expect(appState.getAvatarPosts(toAvatarId), hasLength(1));
        expect(appState.getAvatarPosts(toAvatarId).first.id, equals(post.id));
      });

      test('should clean up content when avatar is removed', () {
        // Arrange
        const userId = 'user-123';
        const avatarId = 'avatar-123';

        final avatar = AvatarModel(
          id: avatarId,
          ownerUserId: userId,
          name: 'Test Avatar',
          bio: 'Test avatar bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final post = PostModel.create(
          avatarId: avatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/image.jpg',
          caption: 'Test post',
          hashtags: ['#test'],
        );

        appState.setAvatar(avatar);
        appState.setPost(post);
        appState.associateContentWithAvatar(avatarId, post.id);

        // Verify initial state
        expect(appState.getAvatar(avatarId), isNotNull);
        expect(appState.getAvatarPosts(avatarId), hasLength(1));

        // Act - Remove avatar
        appState.removeAvatar(avatarId);

        // Assert
        expect(appState.getAvatar(avatarId), isNull);
        expect(appState.getAvatarPosts(avatarId), isEmpty);
      });
    });

    group('Avatar Stats and Content Metrics', () {
      test('should calculate avatar stats correctly', () {
        // Arrange
        const avatarId = 'avatar-123';
        const userId = 'user-123';

        final avatar = AvatarModel(
          id: avatarId,
          ownerUserId: userId,
          name: 'Test Avatar',
          bio: 'Test avatar bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          followersCount: 100,
          likesCount: 500,
          engagementRate: 0.25,
        );

        final post1 = PostModel.create(
          avatarId: avatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/image1.jpg',
          caption: 'Post 1',
          hashtags: ['#test1'],
        );

        final post2 = PostModel.create(
          avatarId: avatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/image2.jpg',
          caption: 'Post 2',
          hashtags: ['#test2'],
        );

        // Act
        appState.setAvatar(avatar);
        appState.setPost(post1);
        appState.setPost(post2);
        appState.associateContentWithAvatar(avatarId, post1.id);
        appState.associateContentWithAvatar(avatarId, post2.id);

        final stats = appState.getAvatarStats(avatarId);

        // Assert
        expect(stats['followersCount'], equals(100));
        expect(stats['postsCount'], equals(2));
        expect(stats['likesCount'], equals(500));
        expect(stats['engagementRate'], equals(0.25));
      });

      test('should update follower count correctly', () {
        // Arrange
        const avatarId = 'avatar-123';
        const userId = 'user-123';

        final avatar = AvatarModel(
          id: avatarId,
          ownerUserId: userId,
          name: 'Test Avatar',
          bio: 'Test avatar bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          followersCount: 100,
        );

        appState.setAvatar(avatar);

        // Act
        appState.updateAvatarFollowerCount(avatarId, 150);

        final updatedCount = appState.getAvatarFollowerCount(avatarId);
        final updatedAvatar = appState.getAvatar(avatarId);

        // Assert
        expect(updatedCount, equals(150));
        expect(updatedAvatar?.followersCount, equals(150));
      });
    });

    group('Active Avatar Management', () {
      test('should set and get active avatar correctly', () {
        // Arrange
        const userId = 'user-123';
        const avatarId = 'avatar-123';

        final avatar = AvatarModel(
          id: avatarId,
          ownerUserId: userId,
          name: 'Test Avatar',
          bio: 'Test avatar bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        appState.setAvatar(avatar);
        appState.setActiveAvatarForUser(userId, avatar);

        final activeAvatar = appState.getActiveAvatarForUser(userId);

        // Assert
        expect(activeAvatar, isNotNull);
        expect(activeAvatar?.id, equals(avatarId));
        expect(appState.activeAvatar?.id, equals(avatarId));
      });

      test('should switch active avatar correctly', () async {
        // Arrange
        const userId = 'user-123';
        const avatar1Id = 'avatar-1';
        const avatar2Id = 'avatar-2';

        final avatar1 = AvatarModel(
          id: avatar1Id,
          ownerUserId: userId,
          name: 'Avatar 1',
          bio: 'Avatar 1 bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Avatar 1 prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final avatar2 = AvatarModel(
          id: avatar2Id,
          ownerUserId: userId,
          name: 'Avatar 2',
          bio: 'Avatar 2 bio',
          niche: AvatarNiche.art,
          personalityTraits: [PersonalityTrait.creative],
          personalityPrompt: 'Avatar 2 prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        appState.setCurrentUser(null, userId);
        appState.setAvatar(avatar1);
        appState.setAvatar(avatar2);
        appState.setActiveAvatar(avatar1);

        // Verify initial state
        expect(appState.activeAvatar?.id, equals(avatar1Id));

        // Act
        await appState.switchActiveAvatar(avatar2Id);

        // Assert
        expect(appState.activeAvatar?.id, equals(avatar2Id));
      });

      test('should prevent switching to avatar not owned by user', () async {
        // Arrange
        const userId = 'user-123';
        const otherUserId = 'user-456';
        const avatarId = 'avatar-123';

        final avatar = AvatarModel(
          id: avatarId,
          ownerUserId: otherUserId, // Different user owns this avatar
          name: 'Other Avatar',
          bio: 'Other avatar bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Other avatar prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        appState.setCurrentUser(null, userId);
        appState.setAvatar(avatar);

        // Act & Assert
        expect(
          () async => await appState.switchActiveAvatar(avatarId),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('View Mode Management', () {
      test('should determine view mode correctly for owner', () {
        // Arrange
        const userId = 'user-123';
        const avatarId = 'avatar-123';

        final avatar = AvatarModel(
          id: avatarId,
          ownerUserId: userId,
          name: 'Test Avatar',
          bio: 'Test avatar bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        appState.setAvatar(avatar);

        // Act
        final viewMode = appState.determineAvatarViewMode(avatarId, userId);

        // Assert
        expect(viewMode, equals(ProfileViewMode.owner));
      });

      test('should determine view mode correctly for public user', () {
        // Arrange
        const ownerId = 'owner-123';
        const viewerId = 'viewer-456';
        const avatarId = 'avatar-123';

        final avatar = AvatarModel(
          id: avatarId,
          ownerUserId: ownerId,
          name: 'Test Avatar',
          bio: 'Test avatar bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        appState.setAvatar(avatar);

        // Act
        final viewMode = appState.determineAvatarViewMode(avatarId, viewerId);

        // Assert
        expect(viewMode, equals(ProfileViewMode.public));
      });

      test('should determine view mode correctly for guest user', () {
        // Arrange
        const ownerId = 'owner-123';
        const avatarId = 'avatar-123';

        final avatar = AvatarModel(
          id: avatarId,
          ownerUserId: ownerId,
          name: 'Test Avatar',
          bio: 'Test avatar bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        appState.setAvatar(avatar);

        // Act
        final viewMode = appState.determineAvatarViewMode(avatarId, null);

        // Assert
        expect(viewMode, equals(ProfileViewMode.guest));
      });
    });
  });
}
