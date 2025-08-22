import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/models/avatar_model.dart';
import 'package:quanta/models/post_model.dart';
import 'package:quanta/services/avatar_lru_cache_service.dart';
import 'package:quanta/services/avatar_posts_pagination_service.dart';
import 'package:quanta/store/app_state.dart';

void main() {
  group('Avatar Performance Tests', () {
    late AppState appState;
    late AvatarLRUCacheService cacheService;

    setUp(() {
      appState = AppState();
      cacheService = AvatarLRUCacheService();

      // Clear any existing state
      appState.clearAll();
      cacheService.clearAll();
    });

    group('LRU Cache Performance', () {
      test('should handle large number of avatars efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Create 1000 test avatars
        final avatars = List.generate(
          1000,
          (index) => AvatarModel(
            id: 'avatar_$index',
            name: 'Avatar $index',
            bio: 'Bio for avatar $index',
            avatarUrl: 'https://example.com/avatar_$index.jpg',
            ownerUserId:
                'user_${index % 100}', // 100 users with 10 avatars each
            niche: 'entertainment',
            personalityTraits: ['friendly', 'creative'],
            personalityPrompt: 'Test personality prompt',
            createdAt: DateTime.now().subtract(Duration(days: index)),
            updatedAt: DateTime.now(),
          ),
        );

        // Cache all avatars
        for (final avatar in avatars) {
          cacheService.cacheAvatar(avatar.id, avatar);
        }

        stopwatch.stop();

        // Should complete within reasonable time (< 100ms for 1000 avatars)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));

        // Verify cache stats
        final stats = cacheService.getCacheStats();
        expect(
          stats['avatarCacheSize'],
          equals(100),
        ); // LRU should limit to 100
      });

      test('should efficiently retrieve cached avatars', () {
        // Cache 100 avatars
        final avatars = List.generate(
          100,
          (index) => AvatarModel(
            id: 'avatar_$index',
            name: 'Avatar $index',
            bio: 'Bio for avatar $index',
            avatarUrl: 'https://example.com/avatar_$index.jpg',
            ownerUserId: 'user_$index',
            niche: 'entertainment',
            personalityTraits: ['friendly'],
            personalityPrompt: 'Test prompt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        for (final avatar in avatars) {
          cacheService.cacheAvatar(avatar.id, avatar);
        }

        final stopwatch = Stopwatch()..start();

        // Retrieve all cached avatars
        for (int i = 0; i < 100; i++) {
          final avatar = cacheService.getCachedAvatar('avatar_$i');
          expect(avatar, isNotNull);
        }

        stopwatch.stop();

        // Should complete very quickly (< 10ms for 100 retrievals)
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('should handle cache eviction efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Add more avatars than cache limit to trigger eviction
        for (int i = 0; i < 200; i++) {
          final avatar = AvatarModel(
            id: 'avatar_$i',
            name: 'Avatar $i',
            bio: 'Bio for avatar $i',
            avatarUrl: 'https://example.com/avatar_$i.jpg',
            ownerUserId: 'user_$i',
            niche: 'entertainment',
            personalityTraits: ['friendly'],
            personalityPrompt: 'Test prompt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          cacheService.cacheAvatar(avatar.id, avatar);
        }

        stopwatch.stop();

        // Should complete within reasonable time even with eviction
        expect(stopwatch.elapsedMilliseconds, lessThan(200));

        // Cache should be at max size
        final stats = cacheService.getCacheStats();
        expect(stats['avatarCacheSize'], equals(100));

        // Oldest avatars should be evicted
        expect(cacheService.getCachedAvatar('avatar_0'), isNull);
        expect(cacheService.getCachedAvatar('avatar_199'), isNotNull);
      });
    });

    group('AppState Performance with Large Data Sets', () {
      test('should handle large number of avatars in AppState efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Add 1000 avatars to AppState
        for (int i = 0; i < 1000; i++) {
          final avatar = AvatarModel(
            id: 'avatar_$i',
            name: 'Avatar $i',
            bio: 'Bio for avatar $i',
            avatarUrl: 'https://example.com/avatar_$i.jpg',
            ownerUserId: 'user_${i % 50}', // 50 users with 20 avatars each
            niche: 'entertainment',
            personalityTraits: ['friendly'],
            personalityPrompt: 'Test prompt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          appState.setAvatar(avatar);
        }

        stopwatch.stop();

        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(500));

        // Verify all avatars are stored
        expect(appState.avatars.length, equals(1000));
      });

      test('should efficiently retrieve user avatars', () {
        // Setup: Add avatars for multiple users
        for (int userId = 0; userId < 100; userId++) {
          for (int avatarIndex = 0; avatarIndex < 10; avatarIndex++) {
            final avatar = AvatarModel(
              id: 'avatar_${userId}_$avatarIndex',
              name: 'Avatar $avatarIndex for User $userId',
              bio: 'Bio',
              avatarUrl: 'https://example.com/avatar.jpg',
              ownerUserId: 'user_$userId',
              niche: 'entertainment',
              personalityTraits: ['friendly'],
              personalityPrompt: 'Test prompt',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            appState.setAvatar(avatar);
          }
        }

        final stopwatch = Stopwatch()..start();

        // Retrieve avatars for all users
        for (int userId = 0; userId < 100; userId++) {
          final userAvatars = appState.getUserAvatars('user_$userId');
          expect(userAvatars.length, equals(10));
        }

        stopwatch.stop();

        // Should complete quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('should handle large number of posts efficiently', () {
        // Create an avatar
        final avatar = AvatarModel(
          id: 'test_avatar',
          name: 'Test Avatar',
          bio: 'Test bio',
          avatarUrl: 'https://example.com/avatar.jpg',
          ownerUserId: 'test_user',
          niche: 'entertainment',
          personalityTraits: ['friendly'],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        appState.setAvatar(avatar);

        final stopwatch = Stopwatch()..start();

        // Add 1000 posts for the avatar
        for (int i = 0; i < 1000; i++) {
          final post = PostModel(
            id: 'post_$i',
            content: 'Post content $i',
            avatarId: 'test_avatar',
            createdAt: DateTime.now().subtract(Duration(minutes: i)),
            updatedAt: DateTime.now(),
            postType: 'text',
          );
          appState.setPost(post);
        }

        stopwatch.stop();

        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));

        // Verify posts are associated with avatar
        final avatarPosts = appState.getAvatarPosts('test_avatar');
        expect(avatarPosts.length, equals(1000));
      });
    });

    group('Avatar Stats Performance', () {
      test('should compute avatar stats efficiently for large datasets', () {
        // Create avatar with many posts
        final avatar = AvatarModel(
          id: 'stats_avatar',
          name: 'Stats Avatar',
          bio: 'Test bio',
          avatarUrl: 'https://example.com/avatar.jpg',
          ownerUserId: 'stats_user',
          niche: 'entertainment',
          personalityTraits: ['friendly'],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        appState.setAvatar(avatar);

        // Add many posts
        for (int i = 0; i < 500; i++) {
          final post = PostModel(
            id: 'stats_post_$i',
            content: 'Post content $i',
            avatarId: 'stats_avatar',
            likesCount: i * 2,
            commentsCount: i,
            sharesCount: i ~/ 2,
            viewsCount: i * 10,
            createdAt: DateTime.now().subtract(Duration(minutes: i)),
            updatedAt: DateTime.now(),
            postType: 'text',
          );
          appState.setPost(post);
        }

        final stopwatch = Stopwatch()..start();

        // Compute stats multiple times
        for (int i = 0; i < 100; i++) {
          final stats = appState.getAvatarStats('stats_avatar');
          expect(stats['postsCount'], equals(500));
        }

        stopwatch.stop();

        // Should complete quickly due to caching
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
      });

      test('should cache stats efficiently', () {
        final avatar = AvatarModel(
          id: 'cache_avatar',
          name: 'Cache Avatar',
          bio: 'Test bio',
          avatarUrl: 'https://example.com/avatar.jpg',
          ownerUserId: 'cache_user',
          niche: 'entertainment',
          personalityTraits: ['friendly'],
          personalityPrompt: 'Test prompt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        appState.setAvatar(avatar);

        // First call should compute and cache
        final stopwatch1 = Stopwatch()..start();
        final stats1 = appState.getAvatarStats('cache_avatar');
        stopwatch1.stop();

        // Second call should use cache
        final stopwatch2 = Stopwatch()..start();
        final stats2 = appState.getAvatarStats('cache_avatar');
        stopwatch2.stop();

        // Second call should be significantly faster
        expect(
          stopwatch2.elapsedMicroseconds,
          lessThan(stopwatch1.elapsedMicroseconds),
        );
        expect(stats1, equals(stats2));
      });
    });

    group('Memory Usage Tests', () {
      test('should maintain reasonable memory usage with large datasets', () {
        // This test would ideally measure actual memory usage
        // For now, we'll test that operations complete without issues

        // Add large number of avatars and posts
        for (int userId = 0; userId < 50; userId++) {
          for (int avatarIndex = 0; avatarIndex < 5; avatarIndex++) {
            final avatarId = 'memory_avatar_${userId}_$avatarIndex';
            final avatar = AvatarModel(
              id: avatarId,
              name: 'Avatar $avatarIndex for User $userId',
              bio: 'Bio',
              avatarUrl: 'https://example.com/avatar.jpg',
              ownerUserId: 'user_$userId',
              niche: 'entertainment',
              personalityTraits: ['friendly'],
              personalityPrompt: 'Test prompt',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            appState.setAvatar(avatar);

            // Add posts for each avatar
            for (int postIndex = 0; postIndex < 20; postIndex++) {
              final post = PostModel(
                id: 'memory_post_${userId}_${avatarIndex}_$postIndex',
                content: 'Post content',
                avatarId: avatarId,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                postType: 'text',
              );
              appState.setPost(post);
            }
          }
        }

        // Verify data integrity
        expect(appState.avatars.length, equals(250)); // 50 users * 5 avatars
        expect(appState.posts.length, equals(5000)); // 250 avatars * 20 posts

        // Test that operations still work efficiently
        final stopwatch = Stopwatch()..start();

        for (int userId = 0; userId < 50; userId++) {
          final userAvatars = appState.getUserAvatars('user_$userId');
          expect(userAvatars.length, equals(5));

          for (final avatar in userAvatars) {
            final avatarPosts = appState.getAvatarPosts(avatar.id);
            expect(avatarPosts.length, equals(20));
          }
        }

        stopwatch.stop();

        // Should still complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });

    group('Concurrent Operations Performance', () {
      test('should handle concurrent avatar operations efficiently', () async {
        final futures = <Future>[];

        // Simulate concurrent operations
        for (int i = 0; i < 100; i++) {
          futures.add(
            Future(() {
              final avatar = AvatarModel(
                id: 'concurrent_avatar_$i',
                name: 'Concurrent Avatar $i',
                bio: 'Bio',
                avatarUrl: 'https://example.com/avatar.jpg',
                ownerUserId: 'concurrent_user_$i',
                niche: 'entertainment',
                personalityTraits: ['friendly'],
                personalityPrompt: 'Test prompt',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              appState.setAvatar(avatar);

              // Immediately try to retrieve it
              final retrieved = appState.getAvatar('concurrent_avatar_$i');
              expect(retrieved, isNotNull);
              expect(retrieved!.id, equals('concurrent_avatar_$i'));
            }),
          );
        }

        final stopwatch = Stopwatch()..start();
        await Future.wait(futures);
        stopwatch.stop();

        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(500));

        // Verify all avatars were added
        expect(appState.avatars.length, equals(100));
      });
    });
  });
}
