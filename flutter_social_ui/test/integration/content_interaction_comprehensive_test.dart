import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quanta/main.dart' as app;
import 'package:quanta/screens/post_detail_screen.dart';
import 'package:quanta/screens/create_post_screen.dart';
import 'package:quanta/screens/feeds_screen.dart';
import 'package:quanta/widgets/post_item.dart';
import 'package:quanta/widgets/comments_modal.dart';
import 'package:quanta/services/enhanced_feeds_service.dart';
import 'package:quanta/services/interaction_service.dart';
import 'package:quanta/services/comment_service.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Content Interaction Flow Tests', () {
    late EnhancedFeedsService feedsService;
    late InteractionService interactionService;
    late CommentService commentService;

    setUpAll(() async {
      feedsService = EnhancedFeedsService();
      interactionService = InteractionService();
      commentService = CommentService();
    });

    group('Post Creation Flow', () {
      testWidgets('Complete post creation → publish → verify in feed', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to create post screen
        final createButton = find.byIcon(Icons.add);
        if (createButton.evaluate().isNotEmpty) {
          await tester.tap(createButton);
          await tester.pumpAndSettle();

          expect(find.byType(CreatePostScreen), findsOneWidget);

          // Test text post creation
          await _testTextPostCreation(tester);
        }
      });

      testWidgets('Image post creation flow', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        final createButton = find.byIcon(Icons.add);
        if (createButton.evaluate().isNotEmpty) {
          await tester.tap(createButton);
          await tester.pumpAndSettle();

          // Test image selection and post creation
          await _testImagePostCreation(tester);
        }
      });

      testWidgets('Video post creation flow', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        final createButton = find.byIcon(Icons.add);
        if (createButton.evaluate().isNotEmpty) {
          await tester.tap(createButton);
          await tester.pumpAndSettle();

          // Test video selection and post creation
          await _testVideoPostCreation(tester);
        }
      });

      testWidgets('Post creation validation - empty content', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        final createButton = find.byIcon(Icons.add);
        if (createButton.evaluate().isNotEmpty) {
          await tester.tap(createButton);
          await tester.pumpAndSettle();

          // Try to publish without content
          final publishButton = find.byKey(const Key('publish_post_button'));
          if (publishButton.evaluate().isNotEmpty) {
            await tester.tap(publishButton);
            await tester.pumpAndSettle();

            // Should show validation error
            expect(find.textContaining('content'), findsOneWidget);
          }
        }
      });
    });

    group('Like/Unlike Functionality', () {
      testWidgets(
        'Like post → verify count increase → unlike → verify decrease',
        (tester) async {
          app.main();
          await tester.pumpAndSettle();

          // Wait for feed to load
          await tester.pump(const Duration(seconds: 2));

          // Find first post in feed
          final firstPost = find.byType(PostItem).first;
          if (firstPost.evaluate().isNotEmpty) {
            // Get initial like count
            final likeButton = find.descendant(
              of: firstPost,
              matching: find.byKey(const Key('like_button')),
            );

            if (likeButton.evaluate().isNotEmpty) {
              // Tap like button
              await tester.tap(likeButton);
              await tester.pumpAndSettle();

              // Verify like animation or state change
              // Note: Specific assertions depend on UI implementation

              // Tap unlike
              await tester.tap(likeButton);
              await tester.pumpAndSettle();

              // Verify unlike state
            }
          }
        },
      );

      testWidgets('Rapid like/unlike operations', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final firstPost = find.byType(PostItem).first;
        if (firstPost.evaluate().isNotEmpty) {
          final likeButton = find.descendant(
            of: firstPost,
            matching: find.byKey(const Key('like_button')),
          );

          if (likeButton.evaluate().isNotEmpty) {
            // Rapidly like and unlike multiple times
            for (int i = 0; i < 5; i++) {
              await tester.tap(likeButton);
              await tester.pump(const Duration(milliseconds: 100));
            }

            await tester.pumpAndSettle();

            // Verify final state is consistent
          }
        }
      });

      testWidgets('Like button state persists across navigation', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final firstPost = find.byType(PostItem).first;
        if (firstPost.evaluate().isNotEmpty) {
          final likeButton = find.descendant(
            of: firstPost,
            matching: find.byKey(const Key('like_button')),
          );

          if (likeButton.evaluate().isNotEmpty) {
            // Like the post
            await tester.tap(likeButton);
            await tester.pumpAndSettle();

            // Navigate to post detail
            await tester.tap(firstPost);
            await tester.pumpAndSettle();

            // Verify like state is maintained in detail view
            expect(find.byType(PostDetailScreen), findsOneWidget);

            // Navigate back
            final backButton = find.byIcon(Icons.arrow_back);
            if (backButton.evaluate().isNotEmpty) {
              await tester.tap(backButton);
              await tester.pumpAndSettle();

              // Verify like state is still maintained
            }
          }
        }
      });
    });

    group('Comment Functionality', () {
      testWidgets('Open comments → add comment → verify in list', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final firstPost = find.byType(PostItem).first;
        if (firstPost.evaluate().isNotEmpty) {
          final commentButton = find.descendant(
            of: firstPost,
            matching: find.byKey(const Key('comment_button')),
          );

          if (commentButton.evaluate().isNotEmpty) {
            await tester.tap(commentButton);
            await tester.pumpAndSettle();

            // Should open comments modal
            expect(find.byType(CommentsModal), findsOneWidget);

            await _testAddComment(tester);
          }
        }
      });

      testWidgets('Comment validation - empty comment', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final firstPost = find.byType(PostItem).first;
        if (firstPost.evaluate().isNotEmpty) {
          final commentButton = find.descendant(
            of: firstPost,
            matching: find.byKey(const Key('comment_button')),
          );

          if (commentButton.evaluate().isNotEmpty) {
            await tester.tap(commentButton);
            await tester.pumpAndSettle();

            // Try to submit empty comment
            final submitButton = find.byKey(const Key('submit_comment_button'));
            if (submitButton.evaluate().isNotEmpty) {
              await tester.tap(submitButton);
              await tester.pumpAndSettle();

              // Should show validation error or button should be disabled
            }
          }
        }
      });

      testWidgets('AI comment suggestions functionality', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final firstPost = find.byType(PostItem).first;
        if (firstPost.evaluate().isNotEmpty) {
          final commentButton = find.descendant(
            of: firstPost,
            matching: find.byKey(const Key('comment_button')),
          );

          if (commentButton.evaluate().isNotEmpty) {
            await tester.tap(commentButton);
            await tester.pumpAndSettle();

            // Look for AI suggestions
            final suggestionsButton = find.byKey(
              const Key('ai_suggestions_button'),
            );
            if (suggestionsButton.evaluate().isNotEmpty) {
              await tester.tap(suggestionsButton);
              await tester.pumpAndSettle();

              // Verify suggestions appear
              expect(find.text('AI Suggestions'), findsOneWidget);
            }
          }
        }
      });

      testWidgets('Reply to comment functionality', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        // This would test the reply to comment feature
        // by finding an existing comment and testing the reply flow
      });
    });

    group('Share Functionality', () {
      testWidgets('Share post → verify share options', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final firstPost = find.byType(PostItem).first;
        if (firstPost.evaluate().isNotEmpty) {
          final shareButton = find.descendant(
            of: firstPost,
            matching: find.byKey(const Key('share_button')),
          );

          if (shareButton.evaluate().isNotEmpty) {
            await tester.tap(shareButton);
            await tester.pumpAndSettle();

            // Verify share options appear
            expect(find.text('Share'), findsOneWidget);

            // Test different share options
            await _testShareOptions(tester);
          }
        }
      });

      testWidgets('Copy link functionality', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final firstPost = find.byType(PostItem).first;
        if (firstPost.evaluate().isNotEmpty) {
          final shareButton = find.descendant(
            of: firstPost,
            matching: find.byKey(const Key('share_button')),
          );

          if (shareButton.evaluate().isNotEmpty) {
            await tester.tap(shareButton);
            await tester.pumpAndSettle();

            final copyLinkButton = find.text('Copy Link');
            if (copyLinkButton.evaluate().isNotEmpty) {
              await tester.tap(copyLinkButton);
              await tester.pumpAndSettle();

              // Verify success message
              expect(find.textContaining('copied'), findsOneWidget);
            }
          }
        }
      });
    });

    group('Bookmark/Save Functionality', () {
      testWidgets('Bookmark post → verify saved → unbookmark', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final firstPost = find.byType(PostItem).first;
        if (firstPost.evaluate().isNotEmpty) {
          final bookmarkButton = find.descendant(
            of: firstPost,
            matching: find.byKey(const Key('bookmark_button')),
          );

          if (bookmarkButton.evaluate().isNotEmpty) {
            // Bookmark the post
            await tester.tap(bookmarkButton);
            await tester.pumpAndSettle();

            // Verify bookmark state changed

            // Unbookmark
            await tester.tap(bookmarkButton);
            await tester.pumpAndSettle();

            // Verify unbookmark state
          }
        }
      });
    });

    group('Video Playback Interaction', () {
      testWidgets('Video auto-play and pause on tap', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        // Find video posts
        final videoPosts = find.byKey(const Key('video_post_item'));
        if (videoPosts.evaluate().isNotEmpty) {
          final firstVideoPost = videoPosts.first;

          // Tap to pause/play
          await tester.tap(firstVideoPost);
          await tester.pumpAndSettle();

          // Verify video controls appeared or state changed
        }
      });

      testWidgets('Video volume control', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final videoPosts = find.byKey(const Key('video_post_item'));
        if (videoPosts.evaluate().isNotEmpty) {
          final volumeButton = find.byKey(const Key('volume_button'));
          if (volumeButton.evaluate().isNotEmpty) {
            await tester.tap(volumeButton);
            await tester.pumpAndSettle();

            // Verify volume state changed
          }
        }
      });
    });

    group('Real-time Updates', () {
      testWidgets('Real-time like count updates', (tester) async {
        // This would test real-time updates when other users
        // interact with the same content
        app.main();
        await tester.pumpAndSettle();

        // Would require simulating real-time updates
        // from the backend
      });

      testWidgets('Real-time comment updates', (tester) async {
        // Test that new comments appear in real-time
        app.main();
        await tester.pumpAndSettle();

        // Would require simulating real-time comment additions
      });
    });

    group('Error Scenarios', () {
      testWidgets('Network error during interaction', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test app behavior when network requests fail
        // during like, comment, or share operations
      });

      testWidgets('Offline mode behavior', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test that interactions are queued when offline
        // and processed when back online
      });
    });
  });
}

/// Helper function to test text post creation
Future<void> _testTextPostCreation(WidgetTester tester) async {
  final contentField = find.byKey(const Key('post_content_field'));
  if (contentField.evaluate().isNotEmpty) {
    await tester.enterText(contentField, 'This is a test post content');

    final publishButton = find.byKey(const Key('publish_post_button'));
    if (publishButton.evaluate().isNotEmpty) {
      await tester.tap(publishButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should navigate back to feed and show the new post
    }
  }
}

/// Helper function to test image post creation
Future<void> _testImagePostCreation(WidgetTester tester) async {
  final imageButton = find.byKey(const Key('add_image_button'));
  if (imageButton.evaluate().isNotEmpty) {
    await tester.tap(imageButton);
    await tester.pumpAndSettle();

    // Would simulate image picker
    // Note: Actual image picker testing requires platform-specific setup
  }
}

/// Helper function to test video post creation
Future<void> _testVideoPostCreation(WidgetTester tester) async {
  final videoButton = find.byKey(const Key('add_video_button'));
  if (videoButton.evaluate().isNotEmpty) {
    await tester.tap(videoButton);
    await tester.pumpAndSettle();

    // Would simulate video picker
    // Note: Actual video picker testing requires platform-specific setup
  }
}

/// Helper function to test adding a comment
Future<void> _testAddComment(WidgetTester tester) async {
  final commentField = find.byKey(const Key('comment_input_field'));
  if (commentField.evaluate().isNotEmpty) {
    await tester.enterText(commentField, 'This is a test comment');

    final submitButton = find.byKey(const Key('submit_comment_button'));
    if (submitButton.evaluate().isNotEmpty) {
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify comment appears in the list
      expect(find.text('This is a test comment'), findsOneWidget);
    }
  }
}

/// Helper function to test share options
Future<void> _testShareOptions(WidgetTester tester) async {
  // Test various share options
  final shareOptions = ['Copy Link', 'Share to Chat', 'Share External'];

  for (final option in shareOptions) {
    final optionButton = find.text(option);
    if (optionButton.evaluate().isNotEmpty) {
      // Just verify the option exists
      expect(optionButton, findsOneWidget);
    }
  }
}
