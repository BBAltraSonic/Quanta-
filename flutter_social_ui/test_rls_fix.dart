// Quick test to verify RLS fix
// Run this after deploying the RPC functions

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/services/enhanced_feeds_service.dart';
import 'lib/services/interaction_service.dart';

import 'lib/utils/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (replace with your actual keys)
  await Supabase.initialize(
    url: Environment.supabaseUrl,
    anonKey: Environment.supabaseAnonKey,
  );

  // Test the services
  await testRLSFix();
}

Future<void> testRLSFix() async {
  print('🧪 Testing RLS fix with RPC functions...');

  final enhancedFeedsService = EnhancedFeedsService();
  final interactionService = InteractionService();

  try {
    // Test 1: Get some posts
    print('\n1. Getting video feed...');
    final posts = await enhancedFeedsService.getVideoFeed(limit: 5);
    print('✅ Retrieved ${posts.length} posts');

    if (posts.isNotEmpty) {
      final testPost = posts.first;
      print('   Testing with post ID: ${testPost.id}');

      // Test 2: Check interaction status
      print('\n2. Testing get_post_interaction_status RPC...');
      final supabase = Supabase.instance.client;
      final statusResult = await supabase.rpc(
        'get_post_interaction_status',
        params: {'target_post_id': testPost.id},
      );

      if (statusResult['success']) {
        print('✅ get_post_interaction_status RPC works!');
        print('   User liked: ${statusResult['data']['user_liked']}');
        print('   Likes count: ${statusResult['data']['likes_count']}');
        print('   Views count: ${statusResult['data']['views_count']}');
      } else {
        print(
          '❌ get_post_interaction_status RPC failed: ${statusResult['error']}',
        );
      }

      // Test 3: Increment view count
      print('\n3. Testing increment_view_count RPC...');
      await enhancedFeedsService.incrementViewCount(testPost.id);
      print('✅ increment_view_count completed (check logs for any errors)');

      // Test 4: Toggle like (this was causing the RLS error before)
      print('\n4. Testing like toggle with RPC functions...');
      try {
        final likeResult = await enhancedFeedsService.toggleLike(testPost.id);
        print(
          '✅ Like toggle successful! New status: ${likeResult ? 'liked' : 'unliked'}',
        );

        // Test 5: Toggle back
        print('\n5. Testing like toggle back...');
        final unlikeResult = await enhancedFeedsService.toggleLike(testPost.id);
        print(
          '✅ Unlike toggle successful! New status: ${unlikeResult ? 'liked' : 'unliked'}',
        );
      } catch (e) {
        print('❌ Like toggle failed: $e');
        print('   This suggests the RLS issue is not fully resolved.');
      }

      // Test 6: Test interaction service
      print('\n6. Testing InteractionService...');
      try {
        final interactionResult = await interactionService.toggleLike(
          testPost.id,
        );
        print(
          '✅ InteractionService like toggle successful! Status: ${interactionResult ? 'liked' : 'unliked'}',
        );
      } catch (e) {
        print('❌ InteractionService toggle failed: $e');
      }
    }

    print('\n🎉 RLS fix test completed!');
    print('If you see ✅ marks above, the RLS issue should be resolved.');
    print('If you see ❌ marks, there may still be issues to address.');
  } catch (e) {
    print('❌ Test failed with error: $e');
    print('Make sure you have:');
    print('  1. Deployed the RPC functions to your Supabase database');
    print('  2. Authenticated with a valid user');
    print('  3. Have some posts in your database');
  }
}
