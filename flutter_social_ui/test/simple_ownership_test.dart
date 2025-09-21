import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/models/user_model.dart';
import 'package:quanta/models/avatar_model.dart';
import 'package:quanta/models/post_model.dart';
import 'package:quanta/models/comment.dart';

void main() {
  group('Simple Model Constructor Tests', () {
    test('UserModel constructor works', () {
      final user = UserModel(
        id: 'user123',
        username: 'testuser',
        displayName: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(user.id, equals('user123'));
      expect(user.username, equals('testuser'));
    });

    test('AvatarModel constructor works', () {
      final avatar = AvatarModel(
        id: 'avatar123',
        name: 'Test Avatar',
        bio: 'Test bio',
        ownerUserId: 'user123',
        niche: AvatarNiche.tech,
        personalityTraits: [PersonalityTrait.friendly],
        personalityPrompt: 'Test prompt',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(avatar.id, equals('avatar123'));
      expect(avatar.name, equals('Test Avatar'));
      expect(avatar.ownerUserId, equals('user123'));
    });

    test('PostModel constructor works', () {
      final post = PostModel(
        id: 'post123',
        avatarId: 'avatar123',
        type: PostType.image,
        caption: 'Test post',
        hashtags: ['#test'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(post.id, equals('post123'));
      expect(post.avatarId, equals('avatar123'));
      expect(post.type, equals(PostType.image));
    });

    test('Comment constructor works', () {
      final comment = Comment(
        id: 'comment123',
        postId: 'post123',
        authorId: 'user123',
        authorType: CommentAuthorType.user,
        text: 'Test comment',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(comment.id, equals('comment123'));
      expect(comment.postId, equals('post123'));
      expect(comment.authorId, equals('user123'));
      expect(comment.authorType, equals(CommentAuthorType.user));
    });
  });
}
