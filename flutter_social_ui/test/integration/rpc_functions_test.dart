import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quanta/config/db_config.dart';
import 'package:quanta/utils/environment.dart';

void main() {
  group('RPC Functions Integration Tests', () {
    late SupabaseClient supabase;
    String? testUserId;
    String? testPostId;
    String? testAvatarId;

    setUpAll(() async {
      // Initialize Supabase client for testing
      await Supabase.initialize(
        url: Environment.supabaseUrl,
        anonKey: Environment.supabaseAnonKey,
      );
      supabase = Supabase.instance.client;
    });

    setUp(() async {
      // Create test user and authenticate
      final authResponse = await supabase.auth.signUp(
        email: 'test_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'test123456',
      );

      expect(authResponse.user, isNotNull);
      testUserId = authResponse.user!.id;

      // Create test user profile
      await supabase.from('users').insert({
        'id': testUserId,
        'email': authResponse.user!.email,
        'username': 'test_user_${DateTime.now().millisecondsSinceEpoch}',
        'display_name': 'Test User',
      });

      // Create test avatar
      final avatarResponse = await supabase
          .from('avatars')
          .insert({
            'owner_user_id': testUserId,
            'name': 'Test Avatar',
            'bio': 'Test avatar for integration tests',
            'niche': 'tech',
            'personality_traits': ['friendly', 'helpful'],
            'personality_prompt': 'You are a helpful test avatar.',
          })
          .select()
          .single();

      testAvatarId = avatarResponse['id'];

      // Create test post
      final postResponse = await supabase
          .from('posts')
          .insert({
            'avatar_id': testAvatarId,
            'video_url': 'https://example.com/test_video.mp4',
            'caption': 'Test post for RPC function testing',
            'hashtags': ['test', 'integration'],
          })
          .select()
          .single();

      testPostId = postResponse['id'];
    });

    tearDown(() async {
      // Clean up test data
      if (testPostId != null) {
        await supabase.from('posts').delete().eq('id', testPostId!);
      }
      if (testAvatarId != null) {
        await supabase.from('avatars').delete().eq('id', testAvatarId!);
      }
      if (testUserId != null) {
        await supabase.from('users').delete().eq('id', testUserId!);
      }

      // Sign out
      await supabase.auth.signOut();
    });

    group('increment_view_count', () {
      test('should increment view count for valid post', () async {
        // Get initial view count
        final initialPost = await supabase
            .from('posts')
            .select('views_count')
            .eq('id', testPostId!)
            .single();
        final initialViews = initialPost['views_count'] as int;

        // Call RPC function
        final result = await supabase.rpc(
          'increment_view_count',
          params: {'target_post_id': testPostId!},
        );

        // Verify response structure
        expect(result['success'], isTrue);
        expect(result['data'], isNotNull);
        expect(result['data']['post_id'], equals(testPostId));
        expect(result['data']['views_count'], equals(initialViews + 1));

        // Verify database was updated
        final updatedPost = await supabase
            .from('posts')
            .select('views_count')
            .eq('id', testPostId!)
            .single();
        expect(updatedPost['views_count'], equals(initialViews + 1));
      });

      test('should fail for non-existent post', () async {
        final fakePostId = '00000000-0000-0000-0000-000000000000';

        final result = await supabase.rpc(
          'increment_view_count',
          params: {'target_post_id': fakePostId},
        );

        expect(result['success'], isFalse);
        expect(result['error'], contains('Post not found'));
        expect(result['code'], equals('POST_NOT_FOUND'));
      });

      test('should fail when not authenticated', () async {
        // Sign out to test unauthenticated access
        await supabase.auth.signOut();

        final result = await supabase.rpc(
          'increment_view_count',
          params: {'target_post_id': testPostId!},
        );

        expect(result['success'], isFalse);
        expect(result['error'], contains('Authentication required'));
        expect(result['code'], equals('AUTH_REQUIRED'));
      });
    });

    group('increment_likes_count', () {
      test('should increment likes count for valid post', () async {
        // Get initial likes count
        final initialPost = await supabase
            .from('posts')
            .select('likes_count')
            .eq('id', testPostId!)
            .single();
        final initialLikes = initialPost['likes_count'] as int;

        // Call RPC function
        final result = await supabase.rpc(
          'increment_likes_count',
          params: {'target_post_id': testPostId!},
        );

        // Verify response structure
        expect(result['success'], isTrue);
        expect(result['data'], isNotNull);
        expect(result['data']['post_id'], equals(testPostId));
        expect(result['data']['likes_count'], equals(initialLikes + 1));
        expect(result['data']['user_liked'], isTrue);

        // Verify database was updated
        final updatedPost = await supabase
            .from('posts')
            .select('likes_count')
            .eq('id', testPostId!)
            .single();
        expect(updatedPost['likes_count'], equals(initialLikes + 1));

        // Verify like record was created
        final likeRecord = await supabase
            .from('likes')
            .select()
            .eq('user_id', testUserId!)
            .eq('post_id', testPostId!)
            .maybeSingle();
        expect(likeRecord, isNotNull);
      });

      test('should fail when trying to like same post twice', () async {
        // Like the post first time
        await supabase.rpc(
          'increment_likes_count',
          params: {'target_post_id': testPostId!},
        );

        // Try to like again
        final result = await supabase.rpc(
          'increment_likes_count',
          params: {'target_post_id': testPostId!},
        );

        expect(result['success'], isFalse);
        expect(result['error'], contains('already liked'));
        expect(result['code'], equals('ALREADY_LIKED'));
      });

      test('should fail for non-existent post', () async {
        final fakePostId = '00000000-0000-0000-0000-000000000000';

        final result = await supabase.rpc(
          'increment_likes_count',
          params: {'target_post_id': fakePostId},
        );

        expect(result['success'], isFalse);
        expect(result['error'], contains('Post not found'));
        expect(result['code'], equals('POST_NOT_FOUND'));
      });

      test('should fail when not authenticated', () async {
        // Sign out to test unauthenticated access
        await supabase.auth.signOut();

        final result = await supabase.rpc(
          'increment_likes_count',
          params: {'target_post_id': testPostId!},
        );

        expect(result['success'], isFalse);
        expect(result['error'], contains('Authentication required'));
        expect(result['code'], equals('AUTH_REQUIRED'));
      });
    });

    group('decrement_likes_count', () {
      test('should decrement likes count for previously liked post', () async {
        // First like the post
        await supabase.rpc(
          'increment_likes_count',
          params: {'target_post_id': testPostId!},
        );

        // Get likes count after liking
        final likedPost = await supabase
            .from('posts')
            .select('likes_count')
            .eq('id', testPostId!)
            .single();
        final likedCount = likedPost['likes_count'] as int;

        // Call decrement RPC function
        final result = await supabase.rpc(
          'decrement_likes_count',
          params: {'target_post_id': testPostId!},
        );

        // Verify response structure
        expect(result['success'], isTrue);
        expect(result['data'], isNotNull);
        expect(result['data']['post_id'], equals(testPostId));
        expect(result['data']['likes_count'], equals(likedCount - 1));
        expect(result['data']['user_liked'], isFalse);

        // Verify database was updated
        final updatedPost = await supabase
            .from('posts')
            .select('likes_count')
            .eq('id', testPostId!)
            .single();
        expect(updatedPost['likes_count'], equals(likedCount - 1));

        // Verify like record was removed
        final likeRecord = await supabase
            .from('likes')
            .select()
            .eq('user_id', testUserId!)
            .eq('post_id', testPostId!)
            .maybeSingle();
        expect(likeRecord, isNull);
      });

      test(
        'should fail when trying to unlike a post that was not liked',
        () async {
          final result = await supabase.rpc(
            'decrement_likes_count',
            params: {'target_post_id': testPostId!},
          );

          expect(result['success'], isFalse);
          expect(result['error'], contains('not liked'));
          expect(result['code'], equals('NOT_LIKED'));
        },
      );

      test('should fail for non-existent post', () async {
        final fakePostId = '00000000-0000-0000-0000-000000000000';

        final result = await supabase.rpc(
          'decrement_likes_count',
          params: {'target_post_id': fakePostId},
        );

        expect(result['success'], isFalse);
        expect(result['error'], contains('Post not found'));
        expect(result['code'], equals('POST_NOT_FOUND'));
      });

      test('should fail when not authenticated', () async {
        // Sign out to test unauthenticated access
        await supabase.auth.signOut();

        final result = await supabase.rpc(
          'decrement_likes_count',
          params: {'target_post_id': testPostId!},
        );

        expect(result['success'], isFalse);
        expect(result['error'], contains('Authentication required'));
        expect(result['code'], equals('AUTH_REQUIRED'));
      });
    });

    group('get_post_interaction_status', () {
      test('should return correct status for liked post', () async {
        // Like the post first
        await supabase.rpc(
          'increment_likes_count',
          params: {'target_post_id': testPostId!},
        );

        // Get interaction status
        final result = await supabase.rpc(
          'get_post_interaction_status',
          params: {'target_post_id': testPostId!},
        );

        expect(result['success'], isTrue);
        expect(result['data'], isNotNull);
        expect(result['data']['id'], equals(testPostId));
        expect(result['data']['user_liked'], isTrue);
        expect(result['data']['likes_count'], isA<int>());
        expect(result['data']['views_count'], isA<int>());
        expect(result['data']['comments_count'], isA<int>());
      });

      test('should return correct status for non-liked post', () async {
        final result = await supabase.rpc(
          'get_post_interaction_status',
          params: {'target_post_id': testPostId!},
        );

        expect(result['success'], isTrue);
        expect(result['data'], isNotNull);
        expect(result['data']['id'], equals(testPostId));
        expect(result['data']['user_liked'], isFalse);
        expect(result['data']['likes_count'], isA<int>());
        expect(result['data']['views_count'], isA<int>());
        expect(result['data']['comments_count'], isA<int>());
      });

      test('should fail for non-existent post', () async {
        final fakePostId = '00000000-0000-0000-0000-000000000000';

        final result = await supabase.rpc(
          'get_post_interaction_status',
          params: {'target_post_id': fakePostId},
        );

        expect(result['success'], isFalse);
        expect(result['error'], contains('Post not found'));
        expect(result['code'], equals('POST_NOT_FOUND'));
      });

      test('should fail when not authenticated', () async {
        // Sign out to test unauthenticated access
        await supabase.auth.signOut();

        final result = await supabase.rpc(
          'get_post_interaction_status',
          params: {'target_post_id': testPostId!},
        );

        expect(result['success'], isFalse);
        expect(result['error'], contains('Authentication required'));
        expect(result['code'], equals('AUTH_REQUIRED'));
      });
    });

    group('Integration Flow Tests', () {
      test('should handle complete like/unlike flow correctly', () async {
        // Get initial state
        var status = await supabase.rpc(
          'get_post_interaction_status',
          params: {'target_post_id': testPostId!},
        );
        expect(status['data']['user_liked'], isFalse);
        final initialLikes = status['data']['likes_count'] as int;

        // Like the post
        final likeResult = await supabase.rpc(
          'increment_likes_count',
          params: {'target_post_id': testPostId!},
        );
        expect(likeResult['success'], isTrue);
        expect(likeResult['data']['likes_count'], equals(initialLikes + 1));

        // Check status after like
        status = await supabase.rpc(
          'get_post_interaction_status',
          params: {'target_post_id': testPostId!},
        );
        expect(status['data']['user_liked'], isTrue);
        expect(status['data']['likes_count'], equals(initialLikes + 1));

        // Unlike the post
        final unlikeResult = await supabase.rpc(
          'decrement_likes_count',
          params: {'target_post_id': testPostId!},
        );
        expect(unlikeResult['success'], isTrue);
        expect(unlikeResult['data']['likes_count'], equals(initialLikes));

        // Check final status
        status = await supabase.rpc(
          'get_post_interaction_status',
          params: {'target_post_id': testPostId!},
        );
        expect(status['data']['user_liked'], isFalse);
        expect(status['data']['likes_count'], equals(initialLikes));
      });

      test('should handle multiple view increments correctly', () async {
        // Get initial views
        var status = await supabase.rpc(
          'get_post_interaction_status',
          params: {'target_post_id': testPostId!},
        );
        final initialViews = status['data']['views_count'] as int;

        // Increment views multiple times
        for (int i = 1; i <= 3; i++) {
          final result = await supabase.rpc(
            'increment_view_count',
            params: {'target_post_id': testPostId!},
          );
          expect(result['success'], isTrue);
          expect(result['data']['views_count'], equals(initialViews + i));
        }

        // Verify final count
        status = await supabase.rpc(
          'get_post_interaction_status',
          params: {'target_post_id': testPostId!},
        );
        expect(status['data']['views_count'], equals(initialViews + 3));
      });
    });
  });
}
