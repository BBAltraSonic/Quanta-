import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_social_ui/services/enhanced_feeds_service.dart';
import 'package:flutter_social_ui/services/auth_service.dart';
import 'package:flutter_social_ui/models/post_model.dart';
import 'package:flutter_social_ui/config/db_config.dart';

// Generate mocks
@GenerateMocks([SupabaseClient, AuthService])
import 'enhanced_feeds_service_test.mocks.dart';

void main() {
  group('EnhancedFeedsService Tests', () {
    late EnhancedFeedsService feedsService;
    late MockSupabaseClient mockSupabaseClient;
    late MockAuthService mockAuthService;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockAuthService = MockAuthService();
      feedsService = EnhancedFeedsService();
      
      // Mock authenticated user
      when(mockAuthService.currentUserId).thenReturn('test-user-id');
      when(mockAuthService.isAuthenticated).thenReturn(true);
    });

    group('Like Toggle Tests', () {
      test('should toggle like optimistically and revert on failure', () async {
        // Arrange
        const postId = 'test-post-id';
        
        // Mock initial state - post is not liked
        when(mockSupabaseClient
            .from(DbConfig.likesTable)
            .select()
            .eq('post_id', postId)
            .eq('user_id', 'test-user-id')
            .maybeSingle())
            .thenAnswer((_) async => null);
        
        // Mock successful like creation
        when(mockSupabaseClient
            .from(DbConfig.likesTable)
            .insert(any))
            .thenAnswer((_) async => []);
        
        // Mock RPC call for incrementing likes count
        when(mockSupabaseClient.rpc('increment_likes_count', params: any))
            .thenAnswer((_) async => null);

        // Act
        final result = await feedsService.toggleLike(postId);

        // Assert
        expect(result, isTrue);
        verify(mockSupabaseClient.from(DbConfig.likesTable).insert(any)).called(1);
        verify(mockSupabaseClient.rpc('increment_likes_count', params: any)).called(1);
      });

      test('should handle like toggle failure gracefully', () async {
        // Arrange
        const postId = 'test-post-id';
        
        // Mock initial state - post is not liked
        when(mockSupabaseClient
            .from(DbConfig.likesTable)
            .select()
            .eq('post_id', postId)
            .eq('user_id', 'test-user-id')
            .maybeSingle())
            .thenAnswer((_) async => null);
        
        // Mock failure on like creation
        when(mockSupabaseClient
            .from(DbConfig.likesTable)
            .insert(any))
            .thenThrow(Exception('Network error'));

        // Act & Assert
        expect(() => feedsService.toggleLike(postId), throwsException);
      });

      test('should unlike when post is already liked', () async {
        // Arrange
        const postId = 'test-post-id';
        
        // Mock initial state - post is liked
        when(mockSupabaseClient
            .from(DbConfig.likesTable)
            .select()
            .eq('post_id', postId)
            .eq('user_id', 'test-user-id')
            .maybeSingle())
            .thenAnswer((_) async => {'id': 'like-id'});
        
        // Mock successful like deletion
        when(mockSupabaseClient
            .from(DbConfig.likesTable)
            .delete()
            .eq('post_id', postId)
            .eq('user_id', 'test-user-id'))
            .thenAnswer((_) async => []);
        
        // Mock RPC call for decrementing likes count
        when(mockSupabaseClient.rpc('decrement_likes_count', params: any))
            .thenAnswer((_) async => null);

        // Act
        final result = await feedsService.toggleLike(postId);

        // Assert
        expect(result, isFalse);
        verify(mockSupabaseClient.from(DbConfig.likesTable).delete()).called(1);
        verify(mockSupabaseClient.rpc('decrement_likes_count', params: any)).called(1);
      });
    });

    group('Comment Tests', () {
      test('should add comment successfully', () async {
        // Arrange
        const postId = 'test-post-id';
        const commentText = 'Test comment';
        final mockCommentResponse = {
          'id': 'comment-id',
          'post_id': postId,
          'user_id': 'test-user-id',
          'text': commentText,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        // Mock successful comment creation
        when(mockSupabaseClient
            .from(DbConfig.commentsTable)
            .insert(any)
            .select()
            .single())
            .thenAnswer((_) async => mockCommentResponse);
        
        // Mock RPC call for incrementing comments count
        when(mockSupabaseClient.rpc('increment_comments_count', params: any))
            .thenAnswer((_) async => null);

        // Act
        final result = await feedsService.addComment(postId, commentText);

        // Assert
        expect(result, isNotNull);
        expect(result!.text, equals(commentText));
        expect(result.postId, equals(postId));
        verify(mockSupabaseClient.from(DbConfig.commentsTable).insert(any)).called(1);
        verify(mockSupabaseClient.rpc('increment_comments_count', params: any)).called(1);
      });

      test('should handle comment creation failure', () async {
        // Arrange
        const postId = 'test-post-id';
        const commentText = 'Test comment';
        
        // Mock failure on comment creation
        when(mockSupabaseClient
            .from(DbConfig.commentsTable)
            .insert(any)
            .select()
            .single())
            .thenThrow(Exception('Network error'));

        // Act
        final result = await feedsService.addComment(postId, commentText);

        // Assert
        expect(result, isNull);
      });
    });

    group('Follow Tests', () {
      test('should follow avatar successfully', () async {
        // Arrange
        const avatarId = 'test-avatar-id';
        
        // Mock initial state - not following
        when(mockSupabaseClient
            .from(DbConfig.followsTable)
            .select()
            .eq('avatar_id', avatarId)
            .eq('user_id', 'test-user-id')
            .maybeSingle())
            .thenAnswer((_) async => null);
        
        // Mock successful follow creation
        when(mockSupabaseClient
            .from(DbConfig.followsTable)
            .insert(any))
            .thenAnswer((_) async => []);

        // Act
        final result = await feedsService.toggleFollow(avatarId);

        // Assert
        expect(result, isTrue);
        verify(mockSupabaseClient.from(DbConfig.followsTable).insert(any)).called(1);
      });

      test('should unfollow when already following', () async {
        // Arrange
        const avatarId = 'test-avatar-id';
        
        // Mock initial state - already following
        when(mockSupabaseClient
            .from(DbConfig.followsTable)
            .select()
            .eq('avatar_id', avatarId)
            .eq('user_id', 'test-user-id')
            .maybeSingle())
            .thenAnswer((_) async => {'id': 'follow-id'});
        
        // Mock successful unfollow
        when(mockSupabaseClient
            .from(DbConfig.followsTable)
            .delete()
            .eq('avatar_id', avatarId)
            .eq('user_id', 'test-user-id'))
            .thenAnswer((_) async => []);

        // Act
        final result = await feedsService.toggleFollow(avatarId);

        // Assert
        expect(result, isFalse);
        verify(mockSupabaseClient.from(DbConfig.followsTable).delete()).called(1);
      });
    });

    group('Batch Status Tests', () {
      test('should return correct liked status for multiple posts', () async {
        // Arrange
        final postIds = ['post1', 'post2', 'post3'];
        final mockLikedPosts = [
          {'post_id': 'post1'},
          {'post_id': 'post3'},
        ];
        
        when(mockSupabaseClient
            .from(DbConfig.likesTable)
            .select('post_id')
            .eq('user_id', 'test-user-id')
            .inFilter('post_id', postIds))
            .thenAnswer((_) async => mockLikedPosts);

        // Act
        final result = await feedsService.getLikedStatusBatch(postIds);

        // Assert
        expect(result['post1'], isTrue);
        expect(result['post2'], isFalse);
        expect(result['post3'], isTrue);
      });
    });

    group('Error Handling Tests', () {
      test('should throw exception when user not authenticated', () async {
        // Arrange
        when(mockAuthService.currentUserId).thenReturn(null);
        when(mockAuthService.isAuthenticated).thenReturn(false);

        // Act & Assert
        expect(() => feedsService.toggleLike('post-id'), 
               throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('not authenticated'))));
      });
    });
  });
}
