import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_social_ui/services/content_upload_service.dart';
import 'package:flutter_social_ui/models/post_model.dart';

void main() {
  group('ContentUploadService Integration Tests', () {
    late ContentUploadService contentService;

    setUp(() {
      contentService = ContentUploadService();
    });

    test('should extract hashtags from caption', () {
      const caption = 'This is a test #flutter #ai #content creation';
      final hashtags = contentService.extractHashtags(caption);
      
      expect(hashtags, contains('#flutter'));
      expect(hashtags, contains('#ai'));
      expect(hashtags, contains('#content'));
    });

    test('should validate content with proper constraints', () async {
      // Test valid content
      final validResult = await contentService.validateContent(
        caption: 'Valid caption',
        externalUrl: 'https://example.com/image.jpg',
        type: PostType.image,
      );
      
      expect(validResult.isValid, true);
      expect(validResult.errors, isEmpty);

      // Test invalid content (empty caption)
      final invalidResult = await contentService.validateContent(
        caption: '',
        externalUrl: 'https://example.com/image.jpg',
        type: PostType.image,
      );
      
      expect(invalidResult.isValid, false);
      expect(invalidResult.errors, contains('Caption is required'));
    });

    test('should get supported platforms', () {
      final platforms = contentService.getSupportedPlatforms();
      
      expect(platforms, isNotEmpty);
      expect(platforms.any((p) => p.id == 'huggingface'), true);
      expect(platforms.any((p) => p.id == 'runway'), true);
      expect(platforms.any((p) => p.id == 'midjourney'), true);
    });

    test('should suggest relevant hashtags', () {
      final mockAvatar = AvatarModel.create(
        ownerUserId: 'test-user',
        name: 'Test Avatar',
        bio: 'Test bio',
        niche: AvatarNiche.tech,
        personalityTraits: ['creative'],
        personalityPrompt: 'Test prompt',
      );

      final suggestions = contentService.suggestHashtags('AI art creation', mockAvatar);
      
      expect(suggestions, isNotEmpty);
      expect(suggestions.any((tag) => tag.toLowerCase().contains('ai')), true);
      expect(suggestions.any((tag) => tag.toLowerCase().contains('tech')), true);
    });
  });
}
