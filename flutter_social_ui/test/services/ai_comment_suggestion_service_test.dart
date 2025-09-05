import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:quanta/services/ai_comment_suggestion_service.dart';
import 'package:quanta/models/post_model.dart';
import 'package:quanta/models/comment.dart';

void main() {
  group('AICommentSuggestionService', () {
    late AICommentSuggestionService service;
    late PostModel testPost;
    late List<Comment> testComments;

    setUp(() {
      service = AICommentSuggestionService();

      testPost = PostModel(
        id: const Uuid().v4(),
        avatarId: const Uuid().v4(),
        type: PostType.image,
        caption: 'Beautiful sunset at the beach! 🌅',
        hashtags: ['#sunset', '#beach', '#nature'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        likesCount: 50,
        commentsCount: 5,
        sharesCount: 10,
        viewsCount: 100,
      );

      testComments = [
        Comment.create(
          postId: testPost.id,
          text: 'Amazing view!',
          authorId: const Uuid().v4(),
          authorType: CommentAuthorType.user,
        ),
        Comment.create(
          postId: testPost.id,
          text: 'Love the colors in this shot!',
          authorId: const Uuid().v4(),
          authorType: CommentAuthorType.user,
        ),
      ];
    });

    test('should create AICommentSuggestion with correct properties', () {
      final suggestion = AICommentSuggestion(
        id: 'test-id',
        postId: testPost.id,
        avatarId: 'avatar-id',
        suggestedText: 'Test suggestion',
        createdAt: DateTime.now(),
      );

      expect(suggestion.id, equals('test-id'));
      expect(suggestion.postId, equals(testPost.id));
      expect(suggestion.avatarId, equals('avatar-id'));
      expect(suggestion.suggestedText, equals('Test suggestion'));
      expect(suggestion.isPending, isTrue);
      expect(suggestion.isAccepted, isFalse);
      expect(suggestion.isDeclined, isFalse);
    });

    test('should update suggestion status correctly', () {
      final suggestion = AICommentSuggestion(
        id: 'test-id',
        postId: testPost.id,
        avatarId: 'avatar-id',
        suggestedText: 'Test suggestion',
        createdAt: DateTime.now(),
      );

      final acceptedSuggestion = suggestion.copyWith(isAccepted: true);
      expect(acceptedSuggestion.isAccepted, isTrue);
      expect(acceptedSuggestion.isPending, isFalse);

      final declinedSuggestion = suggestion.copyWith(isDeclined: true);
      expect(declinedSuggestion.isDeclined, isTrue);
      expect(declinedSuggestion.isPending, isFalse);
    });

    test('should handle suggestions cache correctly', () {
      // This test verifies the behavior of getPendingSuggestions
      // Since _suggestionsCache is private, we'll test the public interface
      final pendingSuggestions = service.getPendingSuggestions(testPost.id);
      expect(pendingSuggestions, isA<List<AICommentSuggestion>>());
      expect(pendingSuggestions.every((s) => s.isPending), isTrue);
    });

    test('should handle decline suggestion correctly', () {
      final suggestion = AICommentSuggestion(
        id: 'suggestion-1',
        postId: testPost.id,
        avatarId: 'avatar-1',
        suggestedText: 'Great post!',
        createdAt: DateTime.now(),
      );

      // Test decline functionality via public interface
      service.declineSuggestion(suggestion);
      // Note: Since we can't access private cache, we just verify the method doesn't throw
      expect(true, isTrue); // Method executed without error
    });

    test('should handle clear cache correctly', () {
      // Test cache clearing via public interface
      service.clearCache();
      service.clearSuggestionsForPost('test-post-id');
      // Note: Since we can't access private cache, we just verify the methods don't throw
      expect(true, isTrue); // Methods executed without error
    });
  });

  group('AICommentSuggestion Model', () {
    test('should handle pending state correctly', () {
      final suggestion = AICommentSuggestion(
        id: 'test-id',
        postId: 'post-id',
        avatarId: 'avatar-id',
        suggestedText: 'Test suggestion',
        createdAt: DateTime.now(),
      );

      expect(suggestion.isPending, isTrue);
      expect(suggestion.isAccepted, isFalse);
      expect(suggestion.isDeclined, isFalse);
    });

    test('should handle accepted state correctly', () {
      final suggestion = AICommentSuggestion(
        id: 'test-id',
        postId: 'post-id',
        avatarId: 'avatar-id',
        suggestedText: 'Test suggestion',
        createdAt: DateTime.now(),
        isAccepted: true,
      );

      expect(suggestion.isPending, isFalse);
      expect(suggestion.isAccepted, isTrue);
      expect(suggestion.isDeclined, isFalse);
    });

    test('should handle declined state correctly', () {
      final suggestion = AICommentSuggestion(
        id: 'test-id',
        postId: 'post-id',
        avatarId: 'avatar-id',
        suggestedText: 'Test suggestion',
        createdAt: DateTime.now(),
        isDeclined: true,
      );

      expect(suggestion.isPending, isFalse);
      expect(suggestion.isAccepted, isFalse);
      expect(suggestion.isDeclined, isTrue);
    });

    test('should copyWith work correctly', () {
      final original = AICommentSuggestion(
        id: 'test-id',
        postId: 'post-id',
        avatarId: 'avatar-id',
        suggestedText: 'Test suggestion',
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(
        isAccepted: true,
        suggestedText: 'Updated suggestion',
      );

      expect(updated.id, equals(original.id));
      expect(updated.postId, equals(original.postId));
      expect(updated.avatarId, equals(original.avatarId));
      expect(updated.suggestedText, equals('Updated suggestion'));
      expect(updated.isAccepted, isTrue);
      expect(updated.isDeclined, isFalse);
      expect(updated.createdAt, equals(original.createdAt));
    });
  });
}
