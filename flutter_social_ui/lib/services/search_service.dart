import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../services/auth_service.dart';

enum SearchType { all, posts, avatars, hashtags }
enum TrendingPeriod { hour, day, week, month }

class SearchResult {
  final List<PostModel> posts;
  final List<AvatarModel> avatars;
  final List<HashtagInfo> hashtags;
  final int totalResults;
  final String query;
  final SearchType type;

  SearchResult({
    required this.posts,
    required this.avatars,
    required this.hashtags,
    required this.totalResults,
    required this.query,
    required this.type,
  });
}

class HashtagInfo {
  final String hashtag;
  final int postCount;
  final int totalEngagement;
  final double trendingScore;
  final DateTime lastUsed;
  final List<String> relatedHashtags;

  HashtagInfo({
    required this.hashtag,
    required this.postCount,
    required this.totalEngagement,
    required this.trendingScore,
    required this.lastUsed,
    required this.relatedHashtags,
  });

  factory HashtagInfo.fromJson(Map<String, dynamic> json) {
    return HashtagInfo(
      hashtag: json['hashtag'] as String,
      postCount: json['post_count'] as int? ?? 0,
      totalEngagement: json['total_engagement'] as int? ?? 0,
      trendingScore: (json['trending_score'] as num?)?.toDouble() ?? 0.0,
      lastUsed: DateTime.parse(json['last_used'] as String),
      relatedHashtags: (json['related_hashtags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class TrendingData {
  final List<HashtagInfo> trendingHashtags;
  final List<PostModel> trendingPosts;
  final List<AvatarModel> trendingAvatars;
  final Map<String, dynamic> analytics;

  TrendingData({
    required this.trendingHashtags,
    required this.trendingPosts,
    required this.trendingAvatars,
    required this.analytics,
  });
}

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Cache for recent searches and trending data
  final Map<String, SearchResult> _searchCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  TrendingData? _cachedTrendingData;
  DateTime? _trendingCacheTimestamp;

  static const Duration _cacheExpiration = Duration(minutes: 5);
  static const Duration _trendingCacheExpiration = Duration(minutes: 15);

  // Comprehensive search functionality
  Future<SearchResult> search({
    required String query,
    SearchType type = SearchType.all,
    int limit = 20,
    int offset = 0,
    Map<String, dynamic>? filters,
  }) async {
    try {
      // Check cache first
      final cacheKey = '${query}_${type.name}_${limit}_$offset';
      if (_isValidCache(cacheKey)) {
        return _searchCache[cacheKey]!;
      }

      debugPrint('🔍 Searching: "$query" (type: ${type.name})');

      List<PostModel> posts = [];
      List<AvatarModel> avatars = [];
      List<HashtagInfo> hashtags = [];

      if (type == SearchType.all || type == SearchType.posts) {
        posts = await _searchPosts(query, limit: limit, offset: offset, filters: filters);
      }

      if (type == SearchType.all || type == SearchType.avatars) {
        avatars = await _searchAvatars(query, limit: limit, offset: offset, filters: filters);
      }

      if (type == SearchType.all || type == SearchType.hashtags) {
        hashtags = await _searchHashtags(query, limit: limit, offset: offset);
      }

      final result = SearchResult(
        posts: posts,
        avatars: avatars,
        hashtags: hashtags,
        totalResults: posts.length + avatars.length + hashtags.length,
        query: query,
        type: type,
      );

      // Cache the result
      _searchCache[cacheKey] = result;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Save search history
      await _saveSearchHistory(query, type);

      return result;

    } catch (e) {
      debugPrint('❌ Search error: $e');
      return SearchResult(
        posts: [],
        avatars: [],
        hashtags: [],
        totalResults: 0,
        query: query,
        type: type,
      );
    }
  }

  // Search posts with advanced filters
  Future<List<PostModel>> _searchPosts(
    String query, {
    int limit = 20,
    int offset = 0,
    Map<String, dynamic>? filters,
  }) async {
    var searchQuery = _supabase
        .from('posts')
        .select('*')
        .eq('is_active', true);

    // Text search in caption
    if (query.isNotEmpty) {
      searchQuery = searchQuery.ilike('caption', '%$query%');
    }

    // Apply filters
    if (filters != null) {
      if (filters['post_type'] != null) {
        searchQuery = searchQuery.eq('type', filters['post_type']);
      }
      if (filters['date_from'] != null) {
        searchQuery = searchQuery.gte('created_at', filters['date_from']);
      }
      if (filters['date_to'] != null) {
        searchQuery = searchQuery.lte('created_at', filters['date_to']);
      }
      if (filters['min_engagement'] != null) {
        searchQuery = searchQuery.gte('engagement_rate', filters['min_engagement']);
      }
      if (filters['hashtags'] != null && filters['hashtags'] is List) {
        searchQuery = searchQuery.overlaps('hashtags', filters['hashtags']);
      }
    }

    final response = await searchQuery
        .order('engagement_rate', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map<PostModel>((json) => PostModel.fromJson(json)).toList();
  }

  // Search avatars by name, niche, or traits
  Future<List<AvatarModel>> _searchAvatars(
    String query, {
    int limit = 20,
    int offset = 0,
    Map<String, dynamic>? filters,
  }) async {
    var searchQuery = _supabase
        .from('avatars')
        .select('*')
        .eq('is_active', true);

    if (query.isNotEmpty) {
      searchQuery = searchQuery.or('name.ilike.%$query%,niche.ilike.%$query%,bio.ilike.%$query%');
    }

    // Apply filters
    if (filters != null) {
      if (filters['niche'] != null) {
        searchQuery = searchQuery.eq('niche', filters['niche']);
      }
      if (filters['personality_traits'] != null && filters['personality_traits'] is List) {
        searchQuery = searchQuery.overlaps('personality_traits', filters['personality_traits']);
      }
      if (filters['min_followers'] != null) {
        searchQuery = searchQuery.gte('followers_count', filters['min_followers']);
      }
    }

    final response = await searchQuery
        .order('followers_count', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map<AvatarModel>((json) => AvatarModel.fromJson(json)).toList();
  }

  // Search hashtags with trending data
  Future<List<HashtagInfo>> _searchHashtags(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .rpc('search_hashtags', params: {
            'search_term': query.startsWith('#') ? query : '#$query',
            'limit_count': limit,
            'offset_count': offset,
          });

      return List<HashtagInfo>.from(
        response.map((json) => HashtagInfo.fromJson(json))
      );

    } catch (e) {
      debugPrint('❌ Hashtag search error: $e');
      return [];
    }
  }

  // Get trending data for different periods
  Future<TrendingData> getTrendingData({
    TrendingPeriod period = TrendingPeriod.day,
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache
      if (!forceRefresh && _isValidTrendingCache()) {
        return _cachedTrendingData!;
      }

      debugPrint('📈 Fetching trending data for period: ${period.name}');

      final periodHours = _getPeriodHours(period);
      
      // Get trending hashtags
      final hashtagsResponse = await _supabase
          .rpc('get_trending_hashtags_period', params: {
            'period_hours': periodHours,
            'limit_count': 20,
          });
      
      final trendingHashtags = List<HashtagInfo>.from(
        hashtagsResponse.map((json) => HashtagInfo.fromJson(json))
      );

      // Get trending posts
      final postsResponse = await _supabase
          .rpc('get_trending_posts', params: {
            'period_hours': periodHours,
            'limit_count': 15,
          });
      
      final trendingPosts = postsResponse
          .map<PostModel>((json) => PostModel.fromJson(json))
          .toList();

      // Get trending avatars
      final avatarsResponse = await _supabase
          .rpc('get_trending_avatars', params: {
            'period_hours': periodHours,
            'limit_count': 10,
          });
      
      final trendingAvatars = avatarsResponse
          .map<AvatarModel>((json) => AvatarModel.fromJson(json))
          .toList();

      // Get analytics data
      final analyticsResponse = await _supabase
          .rpc('get_platform_analytics', params: {
            'period_hours': periodHours,
          });

      final analytics = analyticsResponse as Map<String, dynamic>;

      final trendingData = TrendingData(
        trendingHashtags: trendingHashtags,
        trendingPosts: trendingPosts,
        trendingAvatars: trendingAvatars,
        analytics: analytics,
      );

      // Cache the data
      _cachedTrendingData = trendingData;
      _trendingCacheTimestamp = DateTime.now();

      return trendingData;

    } catch (e) {
      debugPrint('❌ Trending data error: $e');
      return TrendingData(
        trendingHashtags: [],
        trendingPosts: [],
        trendingAvatars: [],
        analytics: {},
      );
    }
  }

  // Get search suggestions based on query
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.length < 2) return [];

    try {
      final response = await _supabase
          .rpc('get_search_suggestions', params: {
            'search_term': query,
            'limit_count': 10,
          });

      return List<String>.from(response);

    } catch (e) {
      debugPrint('❌ Search suggestions error: $e');
      return [];
    }
  }

  // Get user's search history
  Future<List<String>> getSearchHistory({int limit = 10}) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('search_history')
          .select('query')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map<String>((json) => json['query'] as String).toList();

    } catch (e) {
      debugPrint('❌ Search history error: $e');
      return [];
    }
  }

  // Clear search history
  Future<void> clearSearchHistory() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await _supabase
          .from('search_history')
          .delete()
          .eq('user_id', user.id);

      debugPrint('✅ Search history cleared');

    } catch (e) {
      debugPrint('❌ Clear search history error: $e');
    }
  }

  // Get popular searches
  Future<List<String>> getPopularSearches({int limit = 10}) async {
    try {
      final response = await _supabase
          .rpc('get_popular_searches', params: {
            'limit_count': limit,
            'period_hours': 168, // Last week
          });

      return List<String>.from(response.map((json) => json['query']));

    } catch (e) {
      debugPrint('❌ Popular searches error: $e');
      return [];
    }
  }

  // Advanced search with multiple criteria
  Future<SearchResult> advancedSearch({
    String? textQuery,
    List<String>? hashtags,
    List<String>? niches,
    List<String>? personalityTraits,
    PostType? postType,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minEngagementRate,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final filters = <String, dynamic>{};
      
      if (postType != null) {
        filters['post_type'] = postType.toString().split('.').last;
      }
      if (dateFrom != null) {
        filters['date_from'] = dateFrom.toIso8601String();
      }
      if (dateTo != null) {
        filters['date_to'] = dateTo.toIso8601String();
      }
      if (minEngagementRate != null) {
        filters['min_engagement'] = minEngagementRate;
      }
      if (hashtags != null && hashtags.isNotEmpty) {
        filters['hashtags'] = hashtags;
      }
      if (niches != null && niches.isNotEmpty) {
        filters['niche'] = niches.first; // Simplified for now
      }
      if (personalityTraits != null && personalityTraits.isNotEmpty) {
        filters['personality_traits'] = personalityTraits;
      }

      return await search(
        query: textQuery ?? '',
        type: SearchType.all,
        limit: limit,
        offset: offset,
        filters: filters,
      );

    } catch (e) {
      debugPrint('❌ Advanced search error: $e');
      return SearchResult(
        posts: [],
        avatars: [],
        hashtags: [],
        totalResults: 0,
        query: textQuery ?? '',
        type: SearchType.all,
      );
    }
  }

  // Save search to history
  Future<void> _saveSearchHistory(String query, SearchType type) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await _supabase.from('search_history').upsert({
        'user_id': user.id,
        'query': query,
        'search_type': type.name,
        'created_at': DateTime.now().toIso8601String(),
      });

    } catch (e) {
      debugPrint('⚠️ Could not save search history: $e');
    }
  }

  // Clear expired cache entries
  void _cleanupCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheExpiration)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _searchCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  // Helper methods
  bool _isValidCache(String key) {
    _cleanupCache();
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheExpiration;
  }

  bool _isValidTrendingCache() {
    if (_cachedTrendingData == null || _trendingCacheTimestamp == null) {
      return false;
    }
    
    return DateTime.now().difference(_trendingCacheTimestamp!) < _trendingCacheExpiration;
  }

  int _getPeriodHours(TrendingPeriod period) {
    switch (period) {
      case TrendingPeriod.hour:
        return 1;
      case TrendingPeriod.day:
        return 24;
      case TrendingPeriod.week:
        return 168;
      case TrendingPeriod.month:
        return 720;
    }
  }

  // Clear all caches
  void clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
    _cachedTrendingData = null;
    _trendingCacheTimestamp = null;
    debugPrint('🧹 Search cache cleared');
  }
}
