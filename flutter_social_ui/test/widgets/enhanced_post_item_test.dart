import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_social_ui/widgets/enhanced_post_item.dart';
import 'package:flutter_social_ui/models/post_model.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import 'package:flutter_social_ui/services/enhanced_video_service.dart';

// Generate mocks
@GenerateMocks([EnhancedVideoService])
import 'enhanced_post_item_test.mocks.dart';

void main() {
  group('EnhancedPostItem Widget Tests', () {
    late MockEnhancedVideoService mockVideoService;
    late PostModel testPost;
    late AvatarModel testAvatar;

    setUp(() {
      mockVideoService = MockEnhancedVideoService();
      
      testPost = PostModel(
        id: 'test-post-id',
        avatarId: 'test-avatar-id',
        type: PostType.video,
        videoUrl: 'https://example.com/video.mp4',
        caption: 'Test post caption',
        hashtags: ['test', 'flutter'],
        viewsCount: 100,
        likesCount: 50,
        commentsCount: 25,
        sharesCount: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testAvatar = AvatarModel(
        id: 'test-avatar-id',
        ownerUserId: 'test-user-id',
        name: 'Test Avatar',
        bio: 'Test avatar bio',
        niche: AvatarNiche.tech,
        personalityTraits: [PersonalityTrait.friendly],
        personalityPrompt: 'Test prompt',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    Widget createTestWidget({
      bool isLiked = false,
      bool isFollowing = false,
      bool isBookmarked = false,
      VoidCallback? onLike,
      VoidCallback? onComment,
      VoidCallback? onShare,
      VoidCallback? onSave,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: EnhancedPostItem(
            post: testPost,
            avatar: testAvatar,
            isLiked: isLiked,
            isFollowing: isFollowing,
            isBookmarked: isBookmarked,
            onLike: onLike,
            onComment: onComment,
            onShare: onShare,
            onSave: onSave,
          ),
        ),
      );
    }

    testWidgets('should display post content correctly', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Assert
      expect(find.text('Test Avatar'), findsOneWidget);
      expect(find.text('Test post caption'), findsOneWidget);
      expect(find.text('#test'), findsOneWidget);
      expect(find.text('#flutter'), findsOneWidget);
      expect(find.text('50'), findsOneWidget); // likes count
      expect(find.text('25'), findsOneWidget); // comments count
    });

    testWidgets('should show follow button when not following', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createTestWidget(isFollowing: false));
      await tester.pump();

      // Assert
      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets('should hide follow button when already following', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createTestWidget(isFollowing: true));
      await tester.pump();

      // Assert
      expect(find.text('Follow'), findsNothing);
    });

    testWidgets('should call onLike when like button is tapped', (WidgetTester tester) async {
      // Arrange
      bool likeCalled = false;
      
      // Act
      await tester.pumpWidget(createTestWidget(
        onLike: () => likeCalled = true,
      ));
      await tester.pump();

      // Find and tap the like button
      final likeButton = find.byWidgetPredicate((widget) =>
          widget is GestureDetector &&
          widget.child.toString().contains('heart'));
      
      await tester.tap(likeButton.first);
      await tester.pump();

      // Assert
      expect(likeCalled, isTrue);
    });

    testWidgets('should call onComment when comment button is tapped', (WidgetTester tester) async {
      // Arrange
      bool commentCalled = false;
      
      // Act
      await tester.pumpWidget(createTestWidget(
        onComment: () => commentCalled = true,
      ));
      await tester.pump();

      // Find and tap the comment button
      final commentButton = find.byWidgetPredicate((widget) =>
          widget is GestureDetector &&
          widget.child.toString().contains('chat'));
      
      await tester.tap(commentButton.first);
      await tester.pump();

      // Assert
      expect(commentCalled, isTrue);
    });

    testWidgets('should call onShare when share button is tapped', (WidgetTester tester) async {
      // Arrange
      bool shareCalled = false;
      
      // Act
      await tester.pumpWidget(createTestWidget(
        onShare: () => shareCalled = true,
      ));
      await tester.pump();

      // Find and tap the share button
      final shareButton = find.byWidgetPredicate((widget) =>
          widget is GestureDetector &&
          widget.child.toString().contains('reply'));
      
      await tester.tap(shareButton.first);
      await tester.pump();

      // Assert
      expect(shareCalled, isTrue);
    });

    testWidgets('should call onSave when save button is tapped', (WidgetTester tester) async {
      // Arrange
      bool saveCalled = false;
      
      // Act
      await tester.pumpWidget(createTestWidget(
        onSave: () => saveCalled = true,
      ));
      await tester.pump();

      // Find and tap the save button
      final saveButton = find.byWidgetPredicate((widget) =>
          widget is GestureDetector &&
          widget.child.toString().contains('bookmark'));
      
      await tester.tap(saveButton.first);
      await tester.pump();

      // Assert
      expect(saveCalled, isTrue);
    });

    testWidgets('should handle double tap for like', (WidgetTester tester) async {
      // Arrange
      bool likeCalled = false;
      
      // Act
      await tester.pumpWidget(createTestWidget(
        onLike: () => likeCalled = true,
      ));
      await tester.pump();

      // Double tap anywhere on the post
      await tester.tap(find.byType(EnhancedPostItem));
      await tester.tap(find.byType(EnhancedPostItem));
      await tester.pump();

      // Assert
      expect(likeCalled, isTrue);
    });

    testWidgets('should display correct counts with formatting', (WidgetTester tester) async {
      // Arrange
      final postWithLargeCounts = testPost.copyWith(
        likesCount: 1500,
        commentsCount: 2500000,
      );

      // Act
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EnhancedPostItem(
            post: postWithLargeCounts,
            avatar: testAvatar,
          ),
        ),
      ));
      await tester.pump();

      // Assert
      expect(find.text('1.5K'), findsOneWidget); // likes count formatted
      expect(find.text('2.5M'), findsOneWidget); // comments count formatted
    });

    testWidgets('should show AI indicator for avatar', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Assert
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
    });

    testWidgets('should handle image posts correctly', (WidgetTester tester) async {
      // Arrange
      final imagePost = testPost.copyWith(
        type: PostType.image,
        videoUrl: null,
        imageUrl: 'https://example.com/image.jpg',
      );

      // Act
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EnhancedPostItem(
            post: imagePost,
            avatar: testAvatar,
          ),
        ),
      ));
      await tester.pump();

      // Assert - Should not show video controls for image posts
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('should show bookmark state correctly', (WidgetTester tester) async {
      // Test unbookmarked state
      await tester.pumpWidget(createTestWidget(isBookmarked: false));
      await tester.pump();
      
      // Should show regular bookmark icon
      expect(find.byWidgetPredicate((widget) =>
          widget.toString().contains('bookmark')), findsOneWidget);

      // Test bookmarked state
      await tester.pumpWidget(createTestWidget(isBookmarked: true));
      await tester.pump();
      
      // Should still show bookmark icon but with different color
      expect(find.byWidgetPredicate((widget) =>
          widget.toString().contains('bookmark')), findsOneWidget);
    });
  });
}
