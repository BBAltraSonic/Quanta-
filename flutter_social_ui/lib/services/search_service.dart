import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum SearchType {
  all,
  avatars,
  posts,
  users,
  hashtags,
}

class SearchResult {
  final String id;
  final SearchType type;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Map<String, dynamic> data;
  final double relevanceScore;

  SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.data,
    this.relevanceScore = 0.0,
  });

  factory SearchResult.fromAvatar(AvatarModel avatar) {
    return SearchResult(
      id: avatar.id,
      type: SearchType.avatars,
      title: avatar.name,
      subtitle: '${avatar.niche.displayName} • ${avatar.followersCount} followers',
      imageUrl: avatar.avatarImageUrl,
      data: avatar.toJson(),
      relevanceScore: _calculateAvatarRelevance(avatar),
    );
  }

  factory SearchResult.fromPost(PostModel post, {String? avatarName}) {
    return SearchResult(
      id: post.id,
      type: SearchType.posts,
      title: avatarName ?? 'Post',
      subtitle: post.caption.length > 100 
          ? '${post.caption.substring(0, 100)}...' 
          : post.caption,
      imageUrl: post.type == PostType.image ? post.imageUrl : post.thumbnailUrl,
      data: post.toJson(),
      relevanceScore: _calculatePostRelevance(post),
    );
  }

  factory SearchResult.fromUser(UserModel user) {
    return SearchResult(
      id: user.id,
      type: SearchType.users,
      title: user.displayName ?? user.username,
      subtitle: '@${user.username}',
      imageUrl: user.profileImageUrl,
      data: user.toJson(),
      relevanceScore: 1.0,
    );
  }

  factory SearchResult.fromHashtag(String hashtag, int count) {
    return SearchResult(
      id: hashtag,
      type: SearchType.hashtags,
      title: hashtag,
      subtitle: '$count posts',
      data: {'hashtag': hashtag, 'count': count},
      relevanceScore: count.toDouble(),
    );
  }

  static double _calculateAvatarRelevance(AvatarModel avatar) {
    // Simple relevance scoring based on followers and engagement
    final followerScore = (avatar.followersCount / 1000).clamp(0.0, 10.0);
    final engagementScore = avatar.engagementRate / 10;
    return (followerScore + engagementScore).clamp(0.0, 10.0);
  }

  static double _calculatePostRelevance(PostModel post) {
    // Simple relevance scoring based on engagement
    final likeScore = (post.likesCount / 100).clamp(0.0, 5.0);
    final commentScore = (post.commentsCount / 10).clamp(0.0, 3.0);
    final viewScore = (post.viewsCount / 1000).clamp(0.0, 2.0);
    return (likeScore + commentScore + viewScore).clamp(0.0, 10.0);
  }
}

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final AuthService _authService = AuthService();
  SupabaseClient get _supabase => _authService.supabase;

  // Cache for recent searches and trending data
  List<String> _recentSearches = [];
  List<String>? _trendingHashtags;
  DateTime? _trendingCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 15);

  // Initialize search service
  Future<void> initialize() async {
    try {
      debugPrint('🔍 Initializing Search Service');
      await _loadRecentSearches();
      await _loadTrendingHashtags();
    } catch (e) {
      debugPrint('❌ Error initializing search service: $e');
    }
  }

  // Comprehensive search across all content types
  Future<List<SearchResult>> search({
    required String query,
    SearchType type = SearchType.all,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (query.trim().isEmpty) {
        return await _getDefaultResults(type: type, limit: limit);
      }

      final results = <SearchResult>[];
      final cleanQuery = query.trim().toLowerCase();

      // Save search query
      await _saveRecentSearch(cleanQuery);

      switch (type) {
        case SearchType.all:
          // Search all types and combine results
          final avatarResults = await _searchAvatars(cleanQuery, limit: limit ~/ 4);
          final postResults = await _searchPosts(cleanQuery, limit: limit ~/ 4);
          final userResults = await _searchUsers(cleanQuery, limit: limit ~/ 4);
          final hashtagResults = await _searchHashtags(cleanQuery, limit: limit ~/ 4);
          
          results.addAll(avatarResults);
          results.addAll(postResults);
          results.addAll(userResults);
          results.addAll(hashtagResults);
          break;

        case SearchType.avatars:
          results.addAll(await _searchAvatars(cleanQuery, limit: limit, offset: offset));
          break;

        case SearchType.posts:
          results.addAll(await _searchPosts(cleanQuery, limit: limit, offset: offset));
          break;

        case SearchType.users:
          results.addAll(await _searchUsers(cleanQuery, limit: limit, offset: offset));
          break;

        case SearchType.hashtags:
          results.addAll(await _searchHashtags(cleanQuery, limit: limit, offset: offset));
          break;
      }

      // Sort by relevance score
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      debugPrint('✅ Search completed: ${results.length} results for "$query"');
      return results.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error performing search: $e');
      return [];
    }
  }

  // Search avatars
  Future<List<SearchResult>> _searchAvatars(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('avatars')
          .select()
          .eq('is_active', true)
          .or('name.ilike.%$query%,bio.ilike.%$query%,niche.ilike.%$query%')
          .order('followers_count', ascending: false)
          .order('engagement_rate', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<SearchResult>((json) => SearchResult.fromAvatar(AvatarModel.fromJson(json)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error searching avatars: $e');
      return [];
    }
  }

  // Search posts
  Future<List<SearchResult>> _searchPosts(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('''
            *,
            avatars:avatar_id (name, avatar_image_url)
          ''')
          .eq('is_active', true)
          .eq('status', 'published')
          .or('caption.ilike.%$query%,hashtags.cs.{"#${query.toLowerCase()}"}')
          .order('engagement_rate', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<SearchResult>((json) {
        final post = PostModel.fromJson(json);
        final avatarName = json['avatars']?['name'] as String?;
        return SearchResult.fromPost(post, avatarName: avatarName);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error searching posts: $e');
      return [];
    }
  }

  // Search users
  Future<List<SearchResult>> _searchUsers(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<SearchResult>((json) => SearchResult.fromUser(UserModel.fromJson(json)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      return [];
    }
  }

  // Search hashtags
  Future<List<SearchResult>> _searchHashtags(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Use a stored procedure or raw SQL for hashtag aggregation
      final response = await _supabase.rpc('search_hashtags', params: {
        'search_query': query.startsWith('#') ? query : '#$query',
        'limit_count': limit,
        'offset_count': offset,
      });

      return (response as List).map<SearchResult>((item) {
        return SearchResult.fromHashtag(
          item['hashtag'] as String,
          item['count'] as int,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error searching hashtags: $e');
      // Fallback: search in posts table directly
      return await _searchHashtagsFallback(query, limit: limit, offset: offset);
    }
  }

  // Fallback hashtag search
  Future<List<SearchResult>> _searchHashtagsFallback(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final searchTag = query.startsWith('#') ? query : '#$query';
      
      final response = await _supabase
          .from('posts')
          .select('hashtags')
          .eq('is_active', true)
          .eq('status', 'published')
          .contains('hashtags', [searchTag]);

      // Count hashtag occurrences
      final hashtagCounts = <String, int>{};
      for (final post in response) {
        final hashtags = post['hashtags'] as List<dynamic>?;
        if (hashtags != null) {
          for (final hashtag in hashtags) {
            final tag = hashtag.toString().toLowerCase();
            if (tag.contains(query.toLowerCase())) {
              hashtagCounts[tag] = (hashtagCounts[tag] ?? 0) + 1;
            }
          }
        }
      }

      // Convert to search results and sort by count
      final results = hashtagCounts.entries
          .map((entry) => SearchResult.fromHashtag(entry.key, entry.value))
          .toList();
      
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      
      return results.skip(offset).take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error in hashtag fallback search: $e');
      return [];
    }
  }

  // Get default results when no query is provided
  Future<List<SearchResult>> _getDefaultResults({
    SearchType type = SearchType.all,
    int limit = 20,
  }) async {
    try {
      final results = <SearchResult>[];

      switch (type) {
        case SearchType.all:
          // Show trending avatars and recent posts
          final trendingAvatars = await _getTrendingAvatars(limit: limit ~/ 2);
          final recentPosts = await _getRecentPosts(limit: limit ~/ 2);
          results.addAll(trendingAvatars);
          results.addAll(recentPosts);
          break;

        case SearchType.avatars:
          results.addAll(await _getTrendingAvatars(limit: limit));
          break;

        case SearchType.posts:
          results.addAll(await _getRecentPosts(limit: limit));
          break;

        case SearchType.users:
          results.addAll(await _getRecentUsers(limit: limit));
          break;

        case SearchType.hashtags:
          results.addAll(await _getTrendingHashtagResults(limit: limit));
          break;
      }

      return results;
    } catch (e) {
      debugPrint('❌ Error getting default results: $e');
      return [];
    }
  }

  // Get trending avatars
  Future<List<SearchResult>> _getTrendingAvatars({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('avatars')
          .select()
          .eq('is_active', true)
          .order('engagement_rate', ascending: false)
          .order('followers_count', ascending: false)
          .limit(limit);

      return response
          .map<SearchResult>((json) => SearchResult.fromAvatar(AvatarModel.fromJson(json)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting trending avatars: $e');
      return [];
    }
  }

  // Get recent posts
  Future<List<SearchResult>> _getRecentPosts({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('''
            *,
            avatars:avatar_id (name, avatar_image_url)
          ''')
          .eq('is_active', true)
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map<SearchResult>((json) {
        final post = PostModel.fromJson(json);
        final avatarName = json['avatars']?['name'] as String?;
        return SearchResult.fromPost(post, avatarName: avatarName);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting recent posts: $e');
      return [];
    }
  }

  // Get recent users
  Future<List<SearchResult>> _getRecentUsers({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<SearchResult>((json) => SearchResult.fromUser(UserModel.fromJson(json)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting recent users: $e');
      return [];
    }
  }

  // Get trending hashtags as search results
  Future<List<SearchResult>> _getTrendingHashtagResults({int limit = 10}) async {
    final hashtags = await getTrendingHashtags(limit: limit);
    return hashtags.map((item) => SearchResult.fromHashtag(
      item['hashtag'] as String,
      item['count'] as int,
    )).toList();
  }

  // Get trending hashtags
  Future<List<Map<String, dynamic>>> getTrendingHashtags({int limit = 20}) async {
    try {
      // Check cache first
      if (_trendingHashtags != null && 
          _trendingCacheTime != null &&
          DateTime.now().difference(_trendingCacheTime!) < _cacheExpiry) {
        return _trendingHashtags!
            .take(limit)
            .map((hashtag) => {'hashtag': hashtag, 'count': 0})
            .toList();
      }

      // Try to use stored procedure
      try {
        final response = await _supabase.rpc('get_trending_hashtags', params: {
          'limit_count': limit,
        });

        final results = List<Map<String, dynamic>>.from(response);
        _trendingHashtags = results.map((item) => item['hashtag'] as String).toList();
        _trendingCacheTime = DateTime.now();
        
        return results;
      } catch (e) {
        debugPrint('⚠️ Stored procedure not available, using fallback: $e');
        return await _getTrendingHashtagsFallback(limit: limit);
      }
    } catch (e) {
      debugPrint('❌ Error getting trending hashtags: $e');
      return [];
    }
  }

  // Fallback method for trending hashtags
  Future<List<Map<String, dynamic>>> _getTrendingHashtagsFallback({int limit = 20}) async {
    try {
      // Get recent posts with hashtags
      final response = await _supabase
          .from('posts')
          .select('hashtags')
          .eq('is_active', true)
          .eq('status', 'published')
          .gte('created_at', DateTime.now().subtract(Duration(days: 7)).toIso8601String())
          .not('hashtags', 'is', null);

      // Count hashtag occurrences
      final hashtagCounts = <String, int>{};
      for (final post in response) {
        final hashtags = post['hashtags'] as List<dynamic>?;
        if (hashtags != null) {
          for (final hashtag in hashtags) {
            final tag = hashtag.toString().toLowerCase();
            hashtagCounts[tag] = (hashtagCounts[tag] ?? 0) + 1;
          }
        }
      }

      // Sort by count and return top results
      final sortedHashtags = hashtagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final results = sortedHashtags
          .take(limit)
          .map((entry) => {'hashtag': entry.key, 'count': entry.value})
          .toList();

      // Cache results
      _trendingHashtags = results.map((item) => item['hashtag'] as String).toList();
      _trendingCacheTime = DateTime.now();

      return results;
    } catch (e) {
      debugPrint('❌ Error in trending hashtags fallback: $e');
      return [];
    }
  }

  // Get search suggestions
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      if (query.trim().isEmpty) {
        return _recentSearches.take(5).toList();
      }

      final suggestions = <String>[];
      final cleanQuery = query.trim().toLowerCase();

      // Add matching recent searches
      suggestions.addAll(
        _recentSearches
            .where((search) => search.toLowerCase().contains(cleanQuery))
            .take(3),
      );

      // Add trending hashtags that match
      final trendingHashtags = await getTrendingHashtags(limit: 10);
      suggestions.addAll(
        trendingHashtags
            .map((item) => item['hashtag'] as String)
            .where((hashtag) => hashtag.toLowerCase().contains(cleanQuery))
            .take(3),
      );

      // Add avatar names that match
      try {
        final avatarResponse = await _supabase
            .from('avatars')
            .select('name')
            .eq('is_active', true)
            .ilike('name', '%$cleanQuery%')
            .limit(3);

        suggestions.addAll(
          avatarResponse.map((item) => item['name'] as String),
        );
      } catch (e) {
        debugPrint('⚠️ Error getting avatar suggestions: $e');
      }

      // Remove duplicates and return
      return suggestions.toSet().take(8).toList();
    } catch (e) {
      debugPrint('❌ Error getting search suggestions: $e');
      return _recentSearches.take(5).toList();
    }
  }

  // Get recent searches
  List<String> getRecentSearches() {
    return List.from(_recentSearches);
  }

  // Clear recent searches
  Future<void> clearRecentSearches() async {
    try {
      _recentSearches.clear();
      await _saveRecentSearches();
      debugPrint('✅ Recent searches cleared');
    } catch (e) {
      debugPrint('❌ Error clearing recent searches: $e');
    }
  }

  // Save recent search
  Future<void> _saveRecentSearch(String query) async {
    try {
      // Remove if already exists
      _recentSearches.remove(query);
      
      // Add to beginning
      _recentSearches.insert(0, query);
      
      // Keep only last 20 searches
      if (_recentSearches.length > 20) {
        _recentSearches = _recentSearches.take(20).toList();
      }
      
      await _saveRecentSearches();
    } catch (e) {
      debugPrint('❌ Error saving recent search: $e');
    }
  }

  // Load recent searches from storage
  Future<void> _loadRecentSearches() async {
    try {
      // In a real app, this would load from SharedPreferences or similar
      // For now, we'll keep it in memory
      debugPrint('📝 Recent searches loaded');
    } catch (e) {
      debugPrint('❌ Error loading recent searches: $e');
    }
  }

  // Save recent searches to storage
  Future<void> _saveRecentSearches() async {
    try {
      // In a real app, this would save to SharedPreferences or similar
      // For now, we'll keep it in memory
      debugPrint('💾 Recent searches saved');
    } catch (e) {
      debugPrint('❌ Error saving recent searches: $e');
    }
  }

  // Load trending hashtags
  Future<void> _loadTrendingHashtags() async {
    try {
      await getTrendingHashtags(limit: 20);
      debugPrint('📈 Trending hashtags loaded');
    } catch (e) {
      debugPrint('❌ Error loading trending hashtags: $e');
    }
  }

  // Clear cache
  void clearCache() {
    _trendingHashtags = null;
    _trendingCacheTime = null;
    debugPrint('🗑️ Search cache cleared');
  }
}