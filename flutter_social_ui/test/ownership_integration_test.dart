import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:quanta/utils/ownership_manager.dart';
import 'package:quanta/store/state_service_adapter.dart';
import 'package:quanta/services/ownership_guard_service.dart';
import 'package:quanta/widgets/ownership_aware_widgets.dart';
import 'package:quanta/models/user_model.dart';
import 'package:quanta/models/post_model.dart';
import 'package:quanta/models/avatar_model.dart';
import 'package:quanta/models/comment.dart';

void main() {
  group('Ownership Integration Tests', () {
    late OwnershipManager ownershipManager;
    late StateServiceAdapter stateAdapter;
    late OwnershipGuardService guardService;

    // Test data
    const currentUserId = 'user123';
    const otherUserId = 'user456';
    const avatarId = 'avatar123';
    const postId = 'post123';
    const commentId = 'comment123';

    setUp(() {
      ownershipManager = OwnershipManager();
      stateAdapter = StateServiceAdapter();
      guardService = OwnershipGuardService();

      // Setup mock current user
      final currentUser = UserModel(
        id: currentUserId,
        username: 'testuser',
        displayName: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      stateAdapter.setCurrentUser(currentUser, currentUserId);

      // Setup test data in state
      final ownAvatar = AvatarModel(
        id: avatarId,
        name: 'My Avatar',
        ownerUserId: currentUserId,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final ownPost = PostModel(
        id: postId,
        avatarId: avatarId,
        userId: currentUserId,
        caption: 'My Post',
        likesCount: 10,
        commentsCount: 5,
        sharesCount: 2,
        viewsCount: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final ownComment = Comment(
        id: commentId,
        postId: postId,
        userId: currentUserId,
        text: 'My Comment',
        likesCount: 0,
        createdAt: DateTime.now(),
      );

      stateAdapter.setAvatar(ownAvatar);
      stateAdapter.setPost(ownPost);
      stateAdapter.setComment(ownComment);
    });

    group('OwnershipManager Tests', () {
      test('correctly identifies owned profiles', () {
        expect(ownershipManager.isOwnProfile(currentUserId), isTrue);
        expect(ownershipManager.isOwnProfile(otherUserId), isFalse);
        expect(ownershipManager.isOwnProfile(null), isFalse);
      });

      test('correctly identifies owned posts', () {
        final ownPost = stateAdapter.getPost(postId);
        final otherPost = PostModel(
          id: 'other_post',
          avatarId: 'other_avatar',
          userId: otherUserId,
          caption: 'Other Post',
          likesCount: 0,
          commentsCount: 0,
          sharesCount: 0,
          viewsCount: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(ownershipManager.isOwnPost(ownPost), isTrue);
        expect(ownershipManager.isOwnPost(otherPost), isFalse);
        expect(ownershipManager.isOwnPost(null), isFalse);
      });

      test('correctly identifies owned avatars', () {
        expect(ownershipManager.isOwnAvatar(avatarId), isTrue);
        expect(ownershipManager.isOwnAvatar('other_avatar'), isFalse);
        expect(ownershipManager.isOwnAvatar(null), isFalse);
      });

      test('correctly identifies owned comments', () {
        final ownComment = stateAdapter.getComment(commentId);
        final otherComment = Comment(
          id: 'other_comment',
          postId: postId,
          userId: otherUserId,
          text: 'Other Comment',
          likesCount: 0,
          createdAt: DateTime.now(),
        );

        expect(ownershipManager.isOwnComment(ownComment), isTrue);
        expect(ownershipManager.isOwnComment(otherComment), isFalse);
        expect(ownershipManager.isOwnComment(null), isFalse);
      });

      test('correctly determines permissions', () {
        final ownPost = stateAdapter.getPost(postId);
        final otherUser = UserModel(
          id: otherUserId,
          username: 'otheruser',
          displayName: 'Other User',
          email: 'other@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Own elements - can edit/delete, cannot follow/report
        expect(ownershipManager.canEdit(ownPost), isTrue);
        expect(ownershipManager.canDelete(ownPost), isTrue);
        expect(ownershipManager.canFollowElement(ownPost), isFalse);
        expect(ownershipManager.canReportElement(ownPost), isFalse);

        // Other elements - cannot edit/delete, can follow/report
        expect(ownershipManager.canEdit(otherUser), isFalse);
        expect(ownershipManager.canDelete(otherUser), isFalse);
        expect(ownershipManager.canFollowElement(otherUser), isTrue);
        expect(ownershipManager.canReportElement(otherUser), isTrue);
      });

      test('returns correct ownership states', () {
        final ownPost = stateAdapter.getPost(postId);
        final otherUser = UserModel(
          id: otherUserId,
          username: 'otheruser',
          displayName: 'Other User',
          email: 'other@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(
          ownershipManager.getOwnershipState(ownPost),
          equals(OwnershipState.owned),
        );
        expect(
          ownershipManager.getOwnershipState(otherUser),
          equals(OwnershipState.other),
        );
        expect(
          ownershipManager.getOwnershipState(null),
          equals(OwnershipState.unknown),
        );
      });
    });

    group('StateServiceAdapter Ownership Tests', () {
      test('provides correct ownership information', () {
        expect(stateAdapter.isOwnProfile(currentUserId), isTrue);
        expect(stateAdapter.isOwnProfile(otherUserId), isFalse);

        final ownPost = stateAdapter.getPost(postId);
        expect(stateAdapter.isOwnPost(ownPost), isTrue);
        expect(stateAdapter.canEdit(ownPost), isTrue);
        expect(stateAdapter.canDelete(ownPost), isTrue);
      });

      test('correctly identifies other elements', () {
        final otherUser = UserModel(
          id: otherUserId,
          username: 'otheruser',
          displayName: 'Other User',
          email: 'other@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(stateAdapter.isOtherElement(otherUser), isTrue);
        expect(stateAdapter.canFollowElement(otherUser), isTrue);
        expect(stateAdapter.canReportElement(otherUser), isTrue);
      });
    });

    group('OwnershipGuardService Tests', () {
      test('allows authorized post edit', () async {
        // Should not throw for own post
        await expectLater(
          guardService.guardPostEdit(postId),
          completes,
        );
      });

      test('blocks unauthorized post edit', () async {
        // Create a post owned by another user
        final otherPost = PostModel(
          id: 'other_post_123',
          avatarId: 'other_avatar',
          userId: otherUserId,
          caption: 'Other Post',
          likesCount: 0,
          commentsCount: 0,
          sharesCount: 0,
          viewsCount: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        stateAdapter.setPost(otherPost);

        // Should throw UnauthorizedActionException
        await expectLater(
          guardService.guardPostEdit('other_post_123'),
          throwsA(isA<UnauthorizedActionException>()),
        );
      });

      test('blocks self-follow attempts', () async {
        // Should throw SelfActionException when trying to follow own avatar
        await expectLater(
          guardService.guardFollowAction(avatarId),
          throwsA(isA<SelfActionException>()),
        );
      });

      test('allows other-user follow attempts', () async {
        // Create avatar owned by another user
        final otherAvatar = AvatarModel(
          id: 'other_avatar_123',
          name: 'Other Avatar',
          ownerUserId: otherUserId,
          isActive: true,
          createdAt: DateTime.now(),
        );
        stateAdapter.setAvatar(otherAvatar);

        // Should not throw for other user's avatar
        await expectLater(
          guardService.guardFollowAction('other_avatar_123'),
          completes,
        );
      });

      test('blocks self-report attempts', () async {
        final ownPost = stateAdapter.getPost(postId);
        
        // Should throw SelfActionException when trying to report own content
        await expectLater(
          guardService.guardReportAction(ownPost, 'post'),
          throwsA(isA<SelfActionException>()),
        );
      });

      test('blocks self-block attempts', () async {
        // Should throw SelfActionException when trying to block self
        await expectLater(
          guardService.guardBlockAction(currentUserId),
          throwsA(isA<SelfActionException>()),
        );
      });

      test('allows other-user block attempts', () async {
        // Should not throw when blocking other user
        await expectLater(
          guardService.guardBlockAction(otherUserId),
          completes,
        );
      });

      test('executes owner-only actions safely', () async {
        final ownPost = stateAdapter.getPost(postId);
        
        String result = '';
        final actualResult = await guardService.executeOwnerOnlyAction<String>(
          action: () async {
            result = 'Action executed successfully';
            return result;
          },
          element: ownPost,
          actionName: 'test action',
          elementType: 'post',
        );

        expect(actualResult, equals('Action executed successfully'));
        expect(result, equals('Action executed successfully'));
      });

      test('blocks owner-only actions for non-owners', () async {
        final otherUser = UserModel(
          id: otherUserId,
          username: 'otheruser',
          displayName: 'Other User',
          email: 'other@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await expectLater(
          guardService.executeOwnerOnlyAction<String>(
            action: () async => 'This should not execute',
            element: otherUser,
            actionName: 'unauthorized action',
            elementType: 'user',
          ),
          throwsA(isA<UnauthorizedActionException>()),
        );
      });
    });

    group('Widget Integration Tests', () {
      testWidgets('OwnershipAwareWidget shows correct content for owned elements', (tester) async {
        final ownPost = stateAdapter.getPost(postId);
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OwnershipAwareWidget(
                element: ownPost,
                ownedBuilder: (context, element) => const Text('Owned Content'),
                otherBuilder: (context, element) => const Text('Other Content'),
              ),
            ),
          ),
        );

        expect(find.text('Owned Content'), findsOneWidget);
        expect(find.text('Other Content'), findsNothing);
      });

      testWidgets('OwnershipAwareWidget shows correct content for other elements', (tester) async {
        final otherUser = UserModel(
          id: otherUserId,
          username: 'otheruser',
          displayName: 'Other User',
          email: 'other@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OwnershipAwareWidget(
                element: otherUser,
                ownedBuilder: (context, element) => const Text('Owned Content'),
                otherBuilder: (context, element) => const Text('Other Content'),
              ),
            ),
          ),
        );

        expect(find.text('Other Content'), findsOneWidget);
        expect(find.text('Owned Content'), findsNothing);
      });

      testWidgets('OwnershipVisibility shows content based on permissions', (tester) async {
        final ownPost = stateAdapter.getPost(postId);
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  OwnershipVisibility(
                    element: ownPost,
                    permission: OwnershipPermission.canEdit,
                    child: const Text('Edit Button'),
                  ),
                  OwnershipVisibility(
                    element: ownPost,
                    permission: OwnershipPermission.canFollow,
                    child: const Text('Follow Button'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Should show edit button for own post
        expect(find.text('Edit Button'), findsOneWidget);
        
        // Should not show follow button for own post
        expect(find.text('Follow Button'), findsNothing);
      });

      testWidgets('OwnershipActionButtons shows correct actions for owned elements', (tester) async {
        final ownPost = stateAdapter.getPost(postId);
        
        bool editCalled = false;
        bool deleteCalled = false;
        bool followCalled = false;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OwnershipActionButtons(
                element: ownPost,
                onEdit: () => editCalled = true,
                onDelete: () => deleteCalled = true,
                onFollow: () => followCalled = true,
                onUnfollow: () => followCalled = true,
              ),
            ),
          ),
        );

        // Should show edit and delete buttons for own post
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsOneWidget);
        
        // Should not show follow button for own post
        expect(find.byIcon(Icons.person_add), findsNothing);

        // Test edit button functionality
        await tester.tap(find.byIcon(Icons.edit));
        expect(editCalled, isTrue);

        // Test delete button functionality
        await tester.tap(find.byIcon(Icons.delete));
        expect(deleteCalled, isTrue);
      });
    });

    group('Error Handling Tests', () {
      test('handles unauthenticated user correctly', () {
        // Clear current user
        stateAdapter.setCurrentUser(null, null);
        
        expect(ownershipManager.isAuthenticated, isFalse);
        expect(ownershipManager.isOwnProfile(currentUserId), isFalse);
        expect(ownershipManager.canEdit(stateAdapter.getPost(postId)), isFalse);
        
        // Should return unauthenticated state
        expect(
          ownershipManager.getOwnershipState(stateAdapter.getPost(postId)),
          equals(OwnershipState.unauthenticated),
        );
      });

      test('handles null elements correctly', () {
        expect(ownershipManager.isOwnElement(null), isFalse);
        expect(ownershipManager.canEdit(null), isFalse);
        expect(ownershipManager.canDelete(null), isFalse);
        expect(
          ownershipManager.getOwnershipState(null),
          equals(OwnershipState.unknown),
        );
      });

      test('throws appropriate exceptions for guard violations', () async {
        // Test unauthenticated user
        stateAdapter.setCurrentUser(null, null);
        
        await expectLater(
          guardService.guardPostEdit(postId),
          throwsA(isA<UnauthenticatedActionException>()),
        );

        // Restore authentication
        final currentUser = UserModel(
          id: currentUserId,
          username: 'testuser',
          displayName: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        stateAdapter.setCurrentUser(currentUser, currentUserId);

        // Test invalid element
        await expectLater(
          guardService.guardPostEdit('non_existent_post'),
          throwsA(isA<InvalidElementException>()),
        );
      });
    });

    group('Performance and Caching Tests', () {
      test('ownership checks use cached data efficiently', () {
        // Multiple calls should use cached data
        final post = stateAdapter.getPost(postId);
        
        // First call
        final result1 = ownershipManager.isOwnPost(post);
        
        // Subsequent calls should use cache
        final result2 = ownershipManager.isOwnPost(post);
        final result3 = ownershipManager.isOwnPost(post);
        
        expect(result1, equals(result2));
        expect(result2, equals(result3));
        expect(result1, isTrue);
      });

      test('state adapter provides consistent ownership results', () {
        final post = stateAdapter.getPost(postId);
        
        // Multiple ownership checks should be consistent
        expect(stateAdapter.isOwnElement(post), isTrue);
        expect(stateAdapter.canEdit(post), isTrue);
        expect(stateAdapter.canDelete(post), isTrue);
        expect(stateAdapter.canFollowElement(post), isFalse);
        expect(stateAdapter.canReportElement(post), isFalse);
      });
    });
  });
}

/// Test helper to create mock data
class TestDataHelper {
  static UserModel createUser(String id, String username) {
    return UserModel(
      id: id,
      username: username,
      displayName: '$username Display',
      email: '$username@test.com',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static PostModel createPost(String id, String userId, String avatarId) {
    return PostModel(
      id: id,
      avatarId: avatarId,
      userId: userId,
      caption: 'Test Post $id',
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      viewsCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static AvatarModel createAvatar(String id, String ownerUserId) {
    return AvatarModel(
      id: id,
      name: 'Test Avatar $id',
      ownerUserId: ownerUserId,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  static Comment createComment(String id, String postId, String userId) {
    return Comment(
      id: id,
      postId: postId,
      userId: userId,
      text: 'Test Comment $id',
      likesCount: 0,
      createdAt: DateTime.now(),
    );
  }
}
