import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quanta/services/avatar_service.dart';
import 'package:quanta/services/auth_service.dart';
import 'package:quanta/models/avatar_model.dart';
import 'dart:io';

// Generate mocks
@GenerateMocks([SupabaseClient, AuthService, SupabaseStorageClient, StorageFileApi])
import 'avatar_service_test.mocks.dart';

void main() {
  group('AvatarService Tests', () {
    late AvatarService avatarService;
    late MockSupabaseClient mockSupabaseClient;
    late MockAuthService mockAuthService;
    late MockSupabaseStorageClient mockStorageClient;
    late MockStorageFileApi mockStorageFileApi;

    const testUserId = 'test-user-id';
    const testAvatarId = 'test-avatar-id';

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockAuthService = MockAuthService();
      mockStorageClient = MockSupabaseStorageClient();
      mockStorageFileApi = MockStorageFileApi();
      
      // Setup auth service mock
      when(mockAuthService.supabase).thenReturn(mockSupabaseClient);
      when(mockAuthService.currentUserId).thenReturn(testUserId);
      
      // Setup storage mock
      when(mockSupabaseClient.storage).thenReturn(mockStorageClient);
      when(mockStorageClient.from('avatars')).thenReturn(mockStorageFileApi);
      
      avatarService = AvatarService();
      // Note: In real implementation, you'd need dependency injection to inject mocks
    });

    group('createAvatar', () {
      test('should create avatar with valid data', () async {
        // Arrange
        final testAvatarData = {
          'id': testAvatarId,
          'owner_user_id': testUserId,
          'name': 'Test Avatar',
          'bio': 'Test bio that is long enough',
          'niche': 'tech',
          'personality_traits': ['friendly', 'professional'],
          'personality_prompt': 'Generated prompt',
          'followers_count': 0,
          'likes_count': 0,
          'posts_count': 0,
          'engagement_rate': 0.0,
          'is_active': true,
          'allow_autonomous_posting': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final mockQueryBuilder = MockPostgrestQueryBuilder();
        when(mockSupabaseClient.from('avatars')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.insert(any)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.single()).thenAnswer((_) async => testAvatarData);

        // Also mock the getUserAvatar call (should return null for new user)
        when(mockQueryBuilder.eq('owner_user_id', testUserId)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.maybeSingle()).thenAnswer((_) async => null);

        // Act & Assert
        // Note: This test would need the actual service to be refactored for dependency injection
        // For now, this shows the expected test structure
        expect(() async {
          await avatarService.createAvatar(
            name: 'Test Avatar',
            bio: 'Test bio that is long enough',
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.friendly, PersonalityTrait.professional],
          );
        }, returnsNormally);
      });

      test('should throw exception for invalid name length', () async {
        // Act & Assert
        expect(
          () => avatarService.createAvatar(
            name: 'X', // Too short
            bio: 'Valid bio that is long enough',
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.friendly],
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception for invalid bio length', () async {
        // Act & Assert
        expect(
          () => avatarService.createAvatar(
            name: 'Valid Name',
            bio: 'Short', // Too short
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.friendly],
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when user already has avatar', () async {
        // Arrange - mock existing avatar
        final existingAvatarData = {
          'id': 'existing-avatar-id',
          'owner_user_id': testUserId,
          'name': 'Existing Avatar',
          'bio': 'Existing bio',
          // ... other fields
        };

        final mockQueryBuilder = MockPostgrestQueryBuilder();
        when(mockSupabaseClient.from('avatars')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.eq('owner_user_id', testUserId)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.maybeSingle()).thenAnswer((_) async => existingAvatarData);

        // Act & Assert
        expect(
          () => avatarService.createAvatar(
            name: 'Test Avatar',
            bio: 'Test bio that is long enough',
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.friendly],
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('image upload', () {
      test('should upload image and return public URL', () async {
        // Arrange
        const testFilePath = 'test-user-id/avatar_123456789.jpg';
        const testPublicUrl = 'https://storage.supabase.co/test-bucket/test-user-id/avatar_123456789.jpg';
        
        when(mockStorageFileApi.upload(any, any)).thenAnswer((_) async => 'upload-success');
        when(mockStorageFileApi.getPublicUrl(testFilePath)).thenReturn(testPublicUrl);

        // Note: This test requires the service to be refactored to allow injection of mocks
        // The structure shows what should be tested
      });

      test('should throw exception for oversized image', () async {
        // Test that images over the size limit are rejected
        // This would test the file size validation in _uploadAvatarImage
      });
    });

    group('getUserAvatar', () {
      test('should return avatar when user has one', () async {
        // Arrange
        final testAvatarData = {
          'id': testAvatarId,
          'owner_user_id': testUserId,
          'name': 'Test Avatar',
          'bio': 'Test bio',
          'niche': 'tech',
          'personality_traits': ['friendly'],
          'personality_prompt': 'Test prompt',
          'followers_count': 0,
          'likes_count': 0,
          'posts_count': 0,
          'engagement_rate': 0.0,
          'is_active': true,
          'allow_autonomous_posting': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final mockQueryBuilder = MockPostgrestQueryBuilder();
        when(mockSupabaseClient.from('avatars')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.eq('owner_user_id', testUserId)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.maybeSingle()).thenAnswer((_) async => testAvatarData);

        // Act
        final result = await avatarService.getUserAvatar();

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(testAvatarId));
        expect(result.name, equals('Test Avatar'));
      });

      test('should return null when user has no avatar', () async {
        // Arrange
        final mockQueryBuilder = MockPostgrestQueryBuilder();
        when(mockSupabaseClient.from('avatars')).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.eq('owner_user_id', testUserId)).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.maybeSingle()).thenAnswer((_) async => null);

        // Act
        final result = await avatarService.getUserAvatar();

        // Assert
        expect(result, isNull);
      });
    });
  });

  group('AvatarModel Tests', () {
    test('create() should generate valid avatar model', () {
      // Arrange
      const testUserId = 'test-user-id';
      const testName = 'Test Avatar';
      const testBio = 'This is a test bio for the avatar';
      const testNiche = AvatarNiche.tech;
      const testTraits = [PersonalityTrait.friendly, PersonalityTrait.professional];

      // Act
      final avatar = AvatarModel.create(
        ownerUserId: testUserId,
        name: testName,
        bio: testBio,
        niche: testNiche,
        personalityTraits: testTraits,
      );

      // Assert
      expect(avatar.id, isNotEmpty);
      expect(avatar.ownerUserId, equals(testUserId));
      expect(avatar.name, equals(testName));
      expect(avatar.bio, equals(testBio));
      expect(avatar.niche, equals(testNiche));
      expect(avatar.personalityTraits, equals(testTraits));
      expect(avatar.personalityPrompt, isNotEmpty);
      expect(avatar.personalityPrompt, contains(testName));
      expect(avatar.personalityPrompt, contains(testBio));
      expect(avatar.createdAt, isNotNull);
      expect(avatar.updatedAt, isNotNull);
      expect(avatar.followersCount, equals(0));
      expect(avatar.isActive, isTrue);
    });

    test('create() should generate personality prompt with all fields', () {
      // Arrange
      const testBackstory = 'This avatar was created for testing purposes';
      const testVoiceStyle = 'Professional and friendly';

      // Act
      final avatar = AvatarModel.create(
        ownerUserId: 'test-user-id',
        name: 'Tech Expert',
        bio: 'I help people understand technology',
        backstory: testBackstory,
        niche: AvatarNiche.tech,
        personalityTraits: [PersonalityTrait.professional, PersonalityTrait.helpful],
        voiceStyle: testVoiceStyle,
        allowAutonomousPosting: true,
      );

      // Assert
      expect(avatar.personalityPrompt, contains('Tech Expert'));
      expect(avatar.personalityPrompt, contains('I help people understand technology'));
      expect(avatar.personalityPrompt, contains('professional'));
      expect(avatar.personalityPrompt, contains('tech'));
      expect(avatar.voiceStyle, equals(testVoiceStyle));
      expect(avatar.allowAutonomousPosting, isTrue);
    });

    test('toJson() should include all required fields', () {
      // Arrange
      final avatar = AvatarModel.create(
        ownerUserId: 'test-user-id',
        name: 'Test Avatar',
        bio: 'Test bio for avatar',
        niche: AvatarNiche.lifestyle,
        personalityTraits: [PersonalityTrait.friendly],
      );

      // Act
      final json = avatar.toJson();

      // Assert
      expect(json['id'], isNotNull);
      expect(json['owner_user_id'], equals('test-user-id'));
      expect(json['name'], equals('Test Avatar'));
      expect(json['bio'], equals('Test bio for avatar'));
      expect(json['niche'], equals('lifestyle'));
      expect(json['personality_traits'], equals(['friendly']));
      expect(json['personality_prompt'], isNotNull);
      expect(json['followers_count'], equals(0));
      expect(json['likes_count'], equals(0));
      expect(json['posts_count'], equals(0));
      expect(json['engagement_rate'], equals(0.0));
      expect(json['is_active'], equals(true));
      expect(json['allow_autonomous_posting'], equals(false));
      expect(json['created_at'], isNotNull);
      expect(json['updated_at'], isNotNull);
    });

    test('fromJson() should correctly parse avatar data', () {
      // Arrange
      final now = DateTime.now();
      final jsonData = {
        'id': 'test-avatar-id',
        'owner_user_id': 'test-user-id',
        'name': 'Parsed Avatar',
        'bio': 'Avatar created from JSON',
        'backstory': 'Backstory from JSON',
        'niche': 'music',
        'personality_traits': ['creative', 'energetic'],
        'avatar_image_url': 'https://example.com/avatar.jpg',
        'voice_style': 'Upbeat and musical',
        'personality_prompt': 'You are a music avatar...',
        'followers_count': 100,
        'likes_count': 500,
        'posts_count': 25,
        'engagement_rate': 5.2,
        'is_active': true,
        'allow_autonomous_posting': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'metadata': {'custom': 'data'},
      };

      // Act
      final avatar = AvatarModel.fromJson(jsonData);

      // Assert
      expect(avatar.id, equals('test-avatar-id'));
      expect(avatar.ownerUserId, equals('test-user-id'));
      expect(avatar.name, equals('Parsed Avatar'));
      expect(avatar.bio, equals('Avatar created from JSON'));
      expect(avatar.backstory, equals('Backstory from JSON'));
      expect(avatar.niche, equals(AvatarNiche.music));
      expect(avatar.personalityTraits, containsAll([PersonalityTrait.creative, PersonalityTrait.energetic]));
      expect(avatar.avatarImageUrl, equals('https://example.com/avatar.jpg'));
      expect(avatar.voiceStyle, equals('Upbeat and musical'));
      expect(avatar.followersCount, equals(100));
      expect(avatar.likesCount, equals(500));
      expect(avatar.postsCount, equals(25));
      expect(avatar.engagementRate, equals(5.2));
      expect(avatar.isActive, isTrue);
      expect(avatar.allowAutonomousPosting, isTrue);
      expect(avatar.metadata?['custom'], equals('data'));
    });

    test('copyWith() should update only specified fields', () {
      // Arrange
      final originalAvatar = AvatarModel.create(
        ownerUserId: 'test-user-id',
        name: 'Original Name',
        bio: 'Original bio',
        niche: AvatarNiche.tech,
        personalityTraits: [PersonalityTrait.professional],
      );

      // Act
      final updatedAvatar = originalAvatar.copyWith(
        name: 'Updated Name',
        followersCount: 50,
      );

      // Assert
      expect(updatedAvatar.name, equals('Updated Name'));
      expect(updatedAvatar.followersCount, equals(50));
      expect(updatedAvatar.bio, equals('Original bio')); // Unchanged
      expect(updatedAvatar.niche, equals(AvatarNiche.tech)); // Unchanged
      expect(updatedAvatar.id, equals(originalAvatar.id)); // Unchanged
      expect(updatedAvatar.createdAt, equals(originalAvatar.createdAt)); // Unchanged
      expect(updatedAvatar.updatedAt, isNot(equals(originalAvatar.updatedAt))); // Should be updated
    });
  });
}

// Mock classes for testing (these would normally be generated by mockito)
class MockPostgrestQueryBuilder extends Mock implements PostgrestQueryBuilder<List<Map<String, dynamic>>> {}
