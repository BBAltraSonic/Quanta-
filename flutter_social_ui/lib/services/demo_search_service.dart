import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';

/// Demo search service that works without Supabase
/// This is used when AppConfig.demoMode is true
class DemoSearchService {
  static final DemoSearchService _instance = DemoSearchService._internal();
  factory DemoSearchService() => _instance;
  DemoSearchService._internal();

  // Initialize demo search service
  Future<void> initialize() async {
    debugPrint('🎭 Initializing Demo Search Service');
  }

  // Search posts (demo version)
  Future<List<PostModel>> searchPosts({
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? hashtags,
    PostType? type,
  }) async {
    try {
      debugPrint('🎭 Demo search posts: $query');

      // Return demo search results
      return [
        PostModel.create(
          avatarId: 'demo-avatar-1',
          type: PostType.image,
          imageUrl: 'https://demo.image.url',
          caption: 'Demo search result for "$query" #demo #search',
          hashtags: ['#demo', '#search', '#$query'],
        ),
        PostModel.create(
          avatarId: 'demo-avatar-2',
          type: PostType.video,
          videoUrl: 'https://demo.video.url',
          caption: 'Another demo result matching "$query" #ai #demo',
          hashtags: ['#ai', '#demo', '#$query'],
        ),
      ];
    } catch (e) {
      debugPrint('❌ Demo error searching posts: $e');
      return [];
    }
  }

  // Search hashtags (demo version)
  Future<List<String>> searchHashtags({
    required String query,
    int limit = 10,
  }) async {
    try {
      debugPrint('🎭 Demo search hashtags: $query');

      return ['#${query.toLowerCase()}', '#demo', '#ai', '#avatar', '#search'];
    } catch (e) {
      debugPrint('❌ Demo error searching hashtags: $e');
      return [];
    }
  }

  // Get trending searches (demo version)
  Future<List<String>> getTrendingSearches({int limit = 10}) async {
    try {
      debugPrint('🎭 Demo get trending searches');

      return [
        'ai avatars',
        'demo content',
        'flutter app',
        'social media',
        'trending now',
      ];
    } catch (e) {
      debugPrint('❌ Demo error getting trending searches: $e');
      return [];
    }
  }

  // Get search suggestions (demo version)
  Future<List<String>> getSearchSuggestions({
    required String query,
    int limit = 5,
  }) async {
    try {
      debugPrint('🎭 Demo get search suggestions: $query');

      if (query.isEmpty) return [];

      return [
        '$query demo',
        '$query ai',
        '$query avatar',
        '$query content',
        '$query social',
      ];
    } catch (e) {
      debugPrint('❌ Demo error getting search suggestions: $e');
      return [];
    }
  }

  // Search avatars (demo version)
  Future<List<AvatarModel>> searchAvatars({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('🎭 Demo search avatars: $query');

      // Return demo avatar search results as AvatarModel objects
      return [
        AvatarModel.create(
          ownerUserId: 'demo-user-1',
          name: 'Alex Tech',
          bio: 'AI enthusiast exploring the future of technology. Matching "$query"',
          niche: AvatarNiche.tech,
          personalityTraits: [PersonalityTrait.friendly, PersonalityTrait.analytical],
          avatarImageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        ).copyWith(
          followersCount: 1250,
          postsCount: 45,
          engagementRate: 0.08,
        ),
        AvatarModel.create(
          ownerUserId: 'demo-user-2',
          name: 'Maya Fitness',
          bio: 'Fitness coach helping you achieve your health goals. Found for "$query"',
          niche: AvatarNiche.fitness,
          personalityTraits: [PersonalityTrait.energetic, PersonalityTrait.inspiring],
          avatarImageUrl: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face',
        ).copyWith(
          followersCount: 2100,
          postsCount: 78,
          engagementRate: 0.12,
        ),
        AvatarModel.create(
          ownerUserId: 'demo-user-3',
          name: 'Chef Marco',
          bio: 'Culinary artist sharing delicious recipes and cooking tips. Related to "$query"',
          niche: AvatarNiche.cooking,
          personalityTraits: [PersonalityTrait.creative, PersonalityTrait.friendly],
          avatarImageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        ).copyWith(
          followersCount: 3400,
          postsCount: 92,
          engagementRate: 0.15,
        ),
        AvatarModel.create(
          ownerUserId: 'demo-user-4',
          name: 'Luna Art',
          bio: 'Digital artist creating stunning visual experiences. Matches "$query"',
          niche: AvatarNiche.art,
          personalityTraits: [PersonalityTrait.creative, PersonalityTrait.mysterious],
          avatarImageUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        ).copyWith(
          followersCount: 1890,
          postsCount: 67,
          engagementRate: 0.11,
        ),
      ].take(limit).toList();
    } catch (e) {
      debugPrint('❌ Demo error searching avatars: $e');
      return [];
    }
  }
}
