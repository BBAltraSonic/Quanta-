import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/avatar_cache_service.dart';
import '../../lib/services/avatar_profile_service.dart';
import '../../lib/services/avatar_profile_error_handler.dart';
import '../../lib/models/avatar_model.dart';

void main() {
  group('AvatarCacheService', () {
    late AvatarCacheService cacheService;

    setUp(() {
      cacheService = AvatarCacheService();
      cacheService.clearAll(); // Start with clean cache
    });

    tearDown(() {
      cacheService.clearAll();
    });

    group('Avatar Caching', () {
      test('should cache and retrieve avatar', () {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Cache avatar
        cacheService.cacheAvatar(avatar);

        // Retrieve avatar
        final cachedAvatar = cacheService.getCachedAvatar('test-avatar-1');
        expect(cachedAvatar, isNotNull);
        expect(cachedAvatar!.id, 'test-avatar-1');
        expect(cachedAvatar.name, 'Test Avatar');
      });

      test('should return null for non-existent avatar', () {
        final cachedAvatar = cacheService.getCachedAvatar('non-existent');
        expect(cachedAvatar, isNull);
      });

      test('should handle avatar cache expiration', () async {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Cache with very short TTL
        cacheService.cacheAvatar(avatar, ttl: const Duration(milliseconds: 1));

        // Wait for expiration
        await Future.delayed(const Duration(milliseconds: 2));

        // Should return null due to expiration
        final cachedAvatar = cacheService.getCachedAvatar('test-avatar-1');
        expect(cachedAvatar, isNull);
      });
    });

    group('Profile Data Caching', () {
      test('should cache and retrieve profile data', () {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final stats = AvatarStats(
          followersCount: 100,
          followingCount: 0,
          postsCount: 10,
          totalLikes: 500,
          engagementRate: 0.5,
          lastActiveAt: DateTime.now(),
        );

        final profileData = AvatarProfileData(
          avatar: avatar,
          stats: stats,
          recentPosts: [],
          viewMode: ProfileViewMode.public,
          availableActions: [],
        );

        // Cache profile data
        cacheService.cacheProfileData('test-avatar-1', profileData);

        // Retrieve profile data
        final cachedData = cacheService.getCachedProfileData('test-avatar-1');
        expect(cachedData, isNotNull);
        expect(cachedData!.avatar.id, 'test-avatar-1');
        expect(cachedData.stats.followersCount, 100);
      });
    });

    group('Stats Caching', () {
      test('should cache and retrieve stats', () {
        final stats = AvatarStats(
          followersCount: 100,
          followingCount: 0,
          postsCount: 10,
          totalLikes: 500,
          engagementRate: 0.5,
          lastActiveAt: DateTime.now(),
        );

        // Cache stats
        cacheService.cacheStats('test-avatar-1', stats);

        // Retrieve stats
        final cachedStats = cacheService.getCachedStats('test-avatar-1');
        expect(cachedStats, isNotNull);
        expect(cachedStats!.followersCount, 100);
        expect(cachedStats.postsCount, 10);
      });
    });

    group('User Avatars Caching', () {
      test('should cache and retrieve user avatars', () {
        final avatars = [
          AvatarModel(
            id: 'test-avatar-1',
            ownerUserId: 'test-user-1',
            name: 'Test Avatar 1',
            bio: 'Test bio 1',
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.friendly],
            personalityPrompt: 'Test prompt',
            avatarImageUrl: 'test-url-1',
            followersCount: 100,
            engagementRate: 0.5,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          AvatarModel(
            id: 'test-avatar-2',
            ownerUserId: 'test-user-1',
            name: 'Test Avatar 2',
            bio: 'Test bio 2',
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.creative],
            personalityPrompt: 'Test prompt',
            avatarImageUrl: 'test-url-2',
            followersCount: 200,
            engagementRate: 0.7,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Cache user avatars
        cacheService.cacheUserAvatars('test-user-1', avatars);

        // Retrieve user avatars
        final cachedAvatars = cacheService.getCachedUserAvatars('test-user-1');
        expect(cachedAvatars, isNotNull);
        expect(cachedAvatars!.length, 2);
        expect(cachedAvatars[0].id, 'test-avatar-1');
        expect(cachedAvatars[1].id, 'test-avatar-2');
      });
    });

    group('Cache Invalidation', () {
      test('should invalidate specific avatar cache', () {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final stats = AvatarStats(
          followersCount: 100,
          followingCount: 0,
          postsCount: 10,
          totalLikes: 500,
          engagementRate: 0.5,
          lastActiveAt: DateTime.now(),
        );

        // Cache data
        cacheService.cacheAvatar(avatar);
        cacheService.cacheStats('test-avatar-1', stats);

        // Verify cached
        expect(cacheService.getCachedAvatar('test-avatar-1'), isNotNull);
        expect(cacheService.getCachedStats('test-avatar-1'), isNotNull);

        // Invalidate
        cacheService.invalidateAvatar('test-avatar-1');

        // Should be null after invalidation
        expect(cacheService.getCachedAvatar('test-avatar-1'), isNull);
        expect(cacheService.getCachedStats('test-avatar-1'), isNull);
      });

      test('should invalidate user avatars cache', () {
        final avatars = [
          AvatarModel(
            id: 'test-avatar-1',
            ownerUserId: 'test-user-1',
            name: 'Test Avatar 1',
            bio: 'Test bio 1',
            niche: AvatarNiche.tech,
            personalityTraits: [PersonalityTrait.friendly],
            personalityPrompt: 'Test prompt',
            avatarImageUrl: 'test-url-1',
            followersCount: 100,
            engagementRate: 0.5,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Cache user avatars
        cacheService.cacheUserAvatars('test-user-1', avatars);
        expect(cacheService.getCachedUserAvatars('test-user-1'), isNotNull);

        // Invalidate
        cacheService.invalidateUserAvatars('test-user-1');
        expect(cacheService.getCachedUserAvatars('test-user-1'), isNull);
      });

      test('should clear all caches', () {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Cache some data
        cacheService.cacheAvatar(avatar);
        cacheService.cacheUserAvatars('test-user-1', [avatar]);

        // Verify cached
        expect(cacheService.getCachedAvatar('test-avatar-1'), isNotNull);
        expect(cacheService.getCachedUserAvatars('test-user-1'), isNotNull);

        // Clear all
        cacheService.clearAll();

        // Should be null after clearing
        expect(cacheService.getCachedAvatar('test-avatar-1'), isNull);
        expect(cacheService.getCachedUserAvatars('test-user-1'), isNull);
      });
    });

    group('Cache Statistics', () {
      test('should track cache hits and misses', () {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Initial stats should be zero
        var stats = cacheService.getCacheStats();
        expect(stats['hits'], 0);
        expect(stats['misses'], 0);

        // Cache miss
        cacheService.getCachedAvatar('test-avatar-1');
        stats = cacheService.getCacheStats();
        expect(stats['misses'], 1);

        // Cache avatar
        cacheService.cacheAvatar(avatar);

        // Cache hit
        cacheService.getCachedAvatar('test-avatar-1');
        stats = cacheService.getCacheStats();
        expect(stats['hits'], 1);
      });

      test('should calculate hit rate correctly', () {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        cacheService.cacheAvatar(avatar);

        // 2 hits, 1 miss = 66.67% hit rate
        cacheService.getCachedAvatar('test-avatar-1'); // hit
        cacheService.getCachedAvatar('test-avatar-1'); // hit
        cacheService.getCachedAvatar('non-existent'); // miss

        final stats = cacheService.getCacheStats();
        expect(stats['hitRate'], closeTo(66.67, 0.1));
      });
    });

    group('Cache Maintenance', () {
      test('should clear expired entries', () async {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Cache with short TTL
        cacheService.cacheAvatar(avatar, ttl: const Duration(milliseconds: 1));

        // Wait for expiration
        await Future.delayed(const Duration(milliseconds: 2));

        // Clear expired entries
        cacheService.clearExpired();

        // Should be removed from cache
        final stats = cacheService.getCacheStats();
        expect(stats['cacheSize']['avatars'], 0);
      });

      test('should perform maintenance', () {
        // This test mainly ensures the method runs without error
        expect(() => cacheService.performMaintenance(), returnsNormally);
      });
    });

    group('Cache Health', () {
      test('should report healthy cache with good hit rate', () {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        cacheService.cacheAvatar(avatar);

        // Create good hit rate (>50%)
        for (int i = 0; i < 10; i++) {
          cacheService.getCachedAvatar('test-avatar-1'); // hits
        }
        for (int i = 0; i < 3; i++) {
          cacheService.getCachedAvatar('non-existent-$i'); // misses
        }

        expect(cacheService.isHealthy, isTrue);
      });
    });

    group('Cache Refresh', () {
      test('should refresh cache entries', () async {
        final avatar = AvatarModel(
          id: 'test-avatar-1',
          ownerUserId: 'test-user-1',
          name: 'Test Avatar',
          bio: 'Test bio',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly],
          personalityPrompt: 'Test prompt',
          avatarImageUrl: 'test-url',
          followersCount: 100,
          engagementRate: 0.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Cache avatar
        cacheService.cacheAvatar(avatar);
        expect(cacheService.getCachedAvatar('test-avatar-1'), isNotNull);

        // Refresh cache entry
        await cacheService.refreshCacheEntry('test-avatar-1', 'avatar');
        expect(cacheService.getCachedAvatar('test-avatar-1'), isNull);
      });

      test('should handle invalid cache type', () async {
        expect(() async {
          await cacheService.refreshCacheEntry('test-key', 'invalid-type');
        }, throwsA(isA<AvatarProfileException>()));
      });
    });
  });
}
