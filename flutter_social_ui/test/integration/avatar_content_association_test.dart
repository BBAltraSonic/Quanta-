import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quanta/services/avatar_content_service.dart';
import 'package:quanta/services/enhanced_feeds_service.dart';
import 'package:quanta/services/auth_service.dart';
import 'package:quanta/services/avatar_service.dart';
import 'package:quanta/models/post_model.dart';
import 'package:quanta/models/avatar_model.dart';
import 'package:quanta/store/app_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Avatar Content Association Integration Tests', () {
    late AvatarContentService avatarContentService;
    late EnhancedFeedsService feedsService;
    late AuthService authService;
    late AvatarService avatarService;
    late AppState appState;

    setUpAll(() async {
      avatarContentService = AvatarContentService();
      feedsService = EnhancedFeedsService();
      authService = AuthService();
      avatarService = AvatarService();
      appState = AppState();
    });

    group('Content Creation and Association', () {
      testWidgets('should create post associated with active avatar', (
        tester,
      ) async {
        // This test would require a real database connection and authentication
        // For now, we'll test the logic flow

        // Arrange - Mock user authentication
        const userId = 'test-user-123';
        const avatarId = 'test-avatar-123';

        // Create a test avatar
        final testAvatar = AvatarModel(
          id: avatarId,
          ownerUserId: userId,
          name: 'Test Avatar',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set up app state
        appState.setCurrentUser(null, userId);
        appState.setAvatar(testAvatar);
        appState.setActiveAvatar(testAvatar);

        // Act - Create a post
        final post = await avatarContentService.createAvatarPost(
          avatarId: avatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/test-image.jpg',
          caption: 'Test post for avatar content association',
          hashtags: ['#test', '#avatar', '#content'],
        );

        // Assert
        expect(post, isNotNull);
        if (post != null) {
          expect(post.avatarId, equals(avatarId));
          expect(post.caption, contains('Test post'));
          expect(post.hashtags, contains('#avatar'));

          // Verify the post is associated with the avatar in app state
          final avatarPosts = appState.getAvatarPosts(avatarId);
          expect(avatarPosts, contains(post));
        }
      });

      testWidgets('should only show posts for specific avatar', (tester) async {
        // Arrange - Create multiple avatars and posts
        const userId = 'test-user-123';
        const avatar1Id = 'test-avatar-1';
        const avatar2Id = 'test-avatar-2';

        final avatar1 = AvatarModel(
          id: avatar1Id,
          ownerUserId: userId,
          name: 'Avatar 1',
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
          niche: AvatarNiche.art,
          personalityTraits: [PersonalityTrait.creative],
          personalityPrompt: 'Avatar 2 prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set up app state
        appState.setAvatar(avatar1);
        appState.setAvatar(avatar2);

        // Create posts for each avatar
        final post1 = PostModel.create(
          avatarId: avatar1Id,
          type: PostType.image,
          imageUrl: 'https://example.com/image1.jpg',
          caption: 'Post from Avatar 1',
          hashtags: ['#avatar1'],
        );

        final post2 = PostModel.create(
          avatarId: avatar2Id,
          type: PostType.image,
          imageUrl: 'https://example.com/image2.jpg',
          caption: 'Post from Avatar 2',
          hashtags: ['#avatar2'],
        );

        // Add posts to app state
        appState.setPost(post1);
        appState.setPost(post2);
        appState.associateContentWithAvatar(avatar1Id, post1.id);
        appState.associateContentWithAvatar(avatar2Id, post2.id);

        // Act - Get posts for avatar 1
        final avatar1Posts = appState.getAvatarPosts(avatar1Id);
        final avatar2Posts = appState.getAvatarPosts(avatar2Id);

        // Assert
        expect(avatar1Posts, hasLength(1));
        expect(avatar1Posts.first.id, equals(post1.id));
        expect(avatar1Posts.first.caption, contains('Avatar 1'));

        expect(avatar2Posts, hasLength(1));
        expect(avatar2Posts.first.id, equals(post2.id));
        expect(avatar2Posts.first.caption, contains('Avatar 2'));

        // Verify posts are not mixed between avatars
        expect(avatar1Posts, isNot(contains(post2)));
        expect(avatar2Posts, isNot(contains(post1)));
      });
    });

    group('Content Transfer and Migration', () {
      testWidgets('should transfer content between avatars', (tester) async {
        // Arrange
        const userId = 'test-user-123';
        const fromAvatarId = 'from-avatar-123';
        const toAvatarId = 'to-avatar-123';

        final fromAvatar = AvatarModel(
          id: fromAvatarId,
          ownerUserId: userId,
          name: 'From Avatar',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'From avatar prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final toAvatar = AvatarModel(
          id: toAvatarId,
          ownerUserId: userId,
          name: 'To Avatar',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.professional],
          personalityPrompt: 'To avatar prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set up app state
        appState.setAvatar(fromAvatar);
        appState.setAvatar(toAvatar);

        // Create posts for the from avatar
        final post1 = PostModel.create(
          avatarId: fromAvatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/image1.jpg',
          caption: 'Post 1 to transfer',
          hashtags: ['#transfer'],
        );

        final post2 = PostModel.create(
          avatarId: fromAvatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/image2.jpg',
          caption: 'Post 2 to transfer',
          hashtags: ['#transfer'],
        );

        appState.setPost(post1);
        appState.setPost(post2);
        appState.associateContentWithAvatar(fromAvatarId, post1.id);
        appState.associateContentWithAvatar(fromAvatarId, post2.id);

        // Verify initial state
        final initialFromPosts = appState.getAvatarPosts(fromAvatarId);
        final initialToPosts = appState.getAvatarPosts(toAvatarId);

        expect(initialFromPosts, hasLength(2));
        expect(initialToPosts, isEmpty);

        // Act - Transfer content (simulate the transfer logic)
        // In a real test, this would call avatarContentService.transferAvatarContent
        // For now, we'll simulate the app state changes
        appState.removeContentFromAvatar(fromAvatarId, post1.id);
        appState.removeContentFromAvatar(fromAvatarId, post2.id);
        appState.associateContentWithAvatar(toAvatarId, post1.id);
        appState.associateContentWithAvatar(toAvatarId, post2.id);

        // Assert
        final finalFromPosts = appState.getAvatarPosts(fromAvatarId);
        final finalToPosts = appState.getAvatarPosts(toAvatarId);

        expect(finalFromPosts, isEmpty);
        expect(finalToPosts, hasLength(2));
        expect(
          finalToPosts.map((p) => p.id),
          containsAll([post1.id, post2.id]),
        );
      });

      testWidgets('should maintain content integrity during avatar deletion', (
        tester,
      ) async {
        // Arrange
        const userId = 'test-user-123';
        const avatarId = 'avatar-to-delete-123';
        const backupAvatarId = 'backup-avatar-123';

        final avatarToDelete = AvatarModel(
          id: avatarId,
          ownerUserId: userId,
          name: 'Avatar to Delete',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Avatar to delete prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final backupAvatar = AvatarModel(
          id: backupAvatarId,
          ownerUserId: userId,
          name: 'Backup Avatar',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.professional],
          personalityPrompt: 'Backup avatar prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set up app state
        appState.setAvatar(avatarToDelete);
        appState.setAvatar(backupAvatar);

        // Create posts for the avatar to be deleted
        final post1 = PostModel.create(
          avatarId: avatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/image1.jpg',
          caption: 'Important post 1',
          hashtags: ['#important'],
        );

        final post2 = PostModel.create(
          avatarId: avatarId,
          type: PostType.video,
          videoUrl: 'https://example.com/video1.mp4',
          caption: 'Important post 2',
          hashtags: ['#important'],
        );

        appState.setPost(post1);
        appState.setPost(post2);
        appState.associateContentWithAvatar(avatarId, post1.id);
        appState.associateContentWithAvatar(avatarId, post2.id);

        // Verify initial state
        final initialPosts = appState.getAvatarPosts(avatarId);
        expect(initialPosts, hasLength(2));

        // Act - Simulate content transfer before avatar deletion
        // Option 1: Transfer to backup avatar
        appState.removeContentFromAvatar(avatarId, post1.id);
        appState.removeContentFromAvatar(avatarId, post2.id);
        appState.associateContentWithAvatar(backupAvatarId, post1.id);
        appState.associateContentWithAvatar(backupAvatarId, post2.id);

        // Remove the avatar
        appState.removeAvatar(avatarId);

        // Assert
        final deletedAvatarPosts = appState.getAvatarPosts(avatarId);
        final backupAvatarPosts = appState.getAvatarPosts(backupAvatarId);

        expect(deletedAvatarPosts, isEmpty);
        expect(backupAvatarPosts, hasLength(2));
        expect(
          backupAvatarPosts.map((p) => p.id),
          containsAll([post1.id, post2.id]),
        );

        // Verify the avatar is removed but content is preserved
        expect(appState.getAvatar(avatarId), isNull);
        expect(appState.getAvatar(backupAvatarId), isNotNull);
      });
    });

    group('Content Ownership Validation', () {
      testWidgets('should validate content ownership correctly', (
        tester,
      ) async {
        // Arrange
        const userId = 'test-user-123';
        const otherUserId = 'other-user-456';
        const avatarId = 'test-avatar-123';
        const otherAvatarId = 'other-avatar-456';

        final userAvatar = AvatarModel(
          id: avatarId,
          ownerUserId: userId,
          name: 'User Avatar',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'User avatar prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final otherAvatar = AvatarModel(
          id: otherAvatarId,
          ownerUserId: otherUserId,
          name: 'Other Avatar',
          niche: AvatarNiche.art,
          personalityTraits: [PersonalityTrait.creative],
          personalityPrompt: 'Other avatar prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set up app state
        appState.setAvatar(userAvatar);
        appState.setAvatar(otherAvatar);

        // Create posts
        final userPost = PostModel.create(
          avatarId: avatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/user-image.jpg',
          caption: 'User post',
          hashtags: ['#user'],
        );

        final otherPost = PostModel.create(
          avatarId: otherAvatarId,
          type: PostType.image,
          imageUrl: 'https://example.com/other-image.jpg',
          caption: 'Other user post',
          hashtags: ['#other'],
        );

        appState.setPost(userPost);
        appState.setPost(otherPost);

        // Act & Assert - Test ownership validation logic
        expect(appState.doesUserOwnAvatar(userId, avatarId), isTrue);
        expect(appState.doesUserOwnAvatar(userId, otherAvatarId), isFalse);
        expect(appState.doesUserOwnAvatar(otherUserId, avatarId), isFalse);
        expect(appState.doesUserOwnAvatar(otherUserId, otherAvatarId), isTrue);

        // Test content association validation
        final userAvatarPosts = appState.getAvatarPosts(avatarId);
        final otherAvatarPosts = appState.getAvatarPosts(otherAvatarId);

        // Initially no posts are associated
        expect(userAvatarPosts, isEmpty);
        expect(otherAvatarPosts, isEmpty);

        // Associate posts with correct avatars
        appState.associateContentWithAvatar(avatarId, userPost.id);
        appState.associateContentWithAvatar(otherAvatarId, otherPost.id);

        // Verify correct associations
        final updatedUserPosts = appState.getAvatarPosts(avatarId);
        final updatedOtherPosts = appState.getAvatarPosts(otherAvatarId);

        expect(updatedUserPosts, hasLength(1));
        expect(updatedUserPosts.first.id, equals(userPost.id));
        expect(updatedOtherPosts, hasLength(1));
        expect(updatedOtherPosts.first.id, equals(otherPost.id));
      });
    });

    group('App State Consistency', () {
      testWidgets('should maintain consistent state during avatar operations', (
        tester,
      ) async {
        // Arrange
        const userId = 'test-user-123';
        const avatar1Id = 'avatar-1-123';
        const avatar2Id = 'avatar-2-123';

        final avatar1 = AvatarModel(
          id: avatar1Id,
          ownerUserId: userId,
          name: 'Avatar 1',
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
          niche: AvatarNiche.art,
          personalityTraits: [PersonalityTrait.creative],
          personalityPrompt: 'Avatar 2 prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Set up initial state
        appState.setCurrentUser(null, userId);
        appState.setAvatar(avatar1);
        appState.setAvatar(avatar2);
        appState.setActiveAvatar(avatar1);

        // Create posts for both avatars
        final post1 = PostModel.create(
          avatarId: avatar1Id,
          type: PostType.image,
          imageUrl: 'https://example.com/image1.jpg',
          caption: 'Post from Avatar 1',
          hashtags: ['#avatar1'],
        );

        final post2 = PostModel.create(
          avatarId: avatar2Id,
          type: PostType.image,
          imageUrl: 'https://example.com/image2.jpg',
          caption: 'Post from Avatar 2',
          hashtags: ['#avatar2'],
        );

        // Add posts and associations
        appState.setPost(post1);
        appState.setPost(post2);
        appState.associateContentWithAvatar(avatar1Id, post1.id);
        appState.associateContentWithAvatar(avatar2Id, post2.id);

        // Act & Assert - Test various state operations

        // 1. Test active avatar switching
        expect(appState.activeAvatar?.id, equals(avatar1Id));

        await appState.switchActiveAvatar(avatar2Id);
        expect(appState.activeAvatar?.id, equals(avatar2Id));

        // 2. Test avatar stats
        final avatar1Stats = appState.getAvatarStats(avatar1Id);
        final avatar2Stats = appState.getAvatarStats(avatar2Id);

        expect(avatar1Stats['postsCount'], equals(1));
        expect(avatar2Stats['postsCount'], equals(1));

        // 3. Test user avatar retrieval
        final userAvatars = appState.getCurrentUserAvatars();
        expect(userAvatars, hasLength(2));
        expect(
          userAvatars.map((a) => a.id),
          containsAll([avatar1Id, avatar2Id]),
        );

        // 4. Test content removal
        appState.removePost(post1.id);
        final updatedAvatar1Posts = appState.getAvatarPosts(avatar1Id);
        expect(updatedAvatar1Posts, isEmpty);

        // Avatar 2 posts should remain unaffected
        final avatar2Posts = appState.getAvatarPosts(avatar2Id);
        expect(avatar2Posts, hasLength(1));

        // 5. Test avatar removal
        appState.removeAvatar(avatar1Id);
        expect(appState.getAvatar(avatar1Id), isNull);
        expect(
          appState.activeAvatar,
          isNull,
        ); // Should clear active avatar if it was removed

        // Avatar 2 should remain unaffected
        expect(appState.getAvatar(avatar2Id), isNotNull);
      });
    });
  });
}
