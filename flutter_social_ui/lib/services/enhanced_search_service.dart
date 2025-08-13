import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/search_service.dart';
import '../services/auth_service.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';

/// Enhanced search service with popular searches tracking,
/// recent searches persistence, and improved error handling
class EnhancedSearchService {
  final SearchService _baseSearchService = SearchService();
  final AuthService _authService = AuthService();
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 20;
  
  // Cache for popular searches to reduce database calls
  List<String>? _cachedPopularSearches;
  DateTime? _popularSearchesCacheTime;
  static const Duration _cacheTimeout = Duration(hours: 1);

  /// Track a search query in the database and add to recent searches
  Future<void> trackSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        // Add to database-backed recent searches and track globally
        await _authService.supabase.rpc('add_recent_search', params: {
          'p_user_id': user.id,
          'search_query': query.trim(),
        });
      } else {
        // Fallback to local storage if not authenticated
        await _addToLocalRecentSearches(query);
      }
    } catch (e) {
      debugPrint('Error tracking search: $e');
      // Fallback to local storage on error
      await _addToLocalRecentSearches(query);
    }
  }

  /// Get popular searches from database with caching
  Future<List<String>> getPopularSearches({int limit = 8}) async {
    // Return cached data if still valid
    if (_cachedPopularSearches != null && 
        _popularSearchesCacheTime != null &&
        DateTime.now().difference(_popularSearchesCacheTime!) < _cacheTimeout) {
      return _cachedPopularSearches!.take(limit).toList();
    }

    try {
      final response = await _authService.supabase.rpc('get_popular_searches', params: {
        'limit_count': limit,
        'min_searches': 2,
      });

      final popularSearches = (response as List)
          .map((item) => item['query'] as String)
          .toList();

      // Cache the results
      _cachedPopularSearches = popularSearches;
      _popularSearchesCacheTime = DateTime.now();

      return popularSearches;
    } catch (e) {
      debugPrint('Error fetching popular searches: $e');
      // Return fallback popular searches
      return _getFallbackPopularSearches().take(limit).toList();
    }
  }

  /// Get user's recent searches from database or local storage
  Future<List<String>> getRecentSearches({int limit = 10}) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        // Get from database
        final response = await _authService.supabase.rpc('get_recent_searches', params: {
          'p_user_id': user.id,
          'limit_count': limit,
        });

        return (response as List)
            .map((item) => item['query'] as String)
            .toList();
      } else {
        // Fallback to local storage
        return await _getLocalRecentSearches(limit: limit);
      }
    } catch (e) {
      debugPrint('Error fetching recent searches: $e');
      // Fallback to local storage
      return await _getLocalRecentSearches(limit: limit);
    }
  }

  /// Clear all recent searches for the current user
  Future<void> clearRecentSearches() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        // Clear from database
        await _authService.supabase.rpc('clear_recent_searches', params: {
          'p_user_id': user.id,
        });
      }
      // Always clear local storage as well
      await _clearLocalRecentSearches();
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
      // Fallback to clearing local storage only
      await _clearLocalRecentSearches();
    }
  }

  /// Remove a specific recent search
  Future<void> removeRecentSearch(String query) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        // Remove from database
        await _authService.supabase.rpc('remove_recent_search', params: {
          'p_user_id': user.id,
          'search_query': query,
        });
      }
      // Also remove from local storage
      await _removeFromLocalRecentSearches(query);
    } catch (e) {
      debugPrint('Error removing recent search: $e');
      // Fallback to removing from local storage only
      await _removeFromLocalRecentSearches(query);
    }
  }

  /// Enhanced search with error handling and tracking
  Future<SearchResults> performSearch(String query, {
    int limit = 20,
    bool trackQuery = true,
  }) async {
    if (query.trim().isEmpty) {
      return SearchResults.empty();
    }

    // Track the search query
    if (trackQuery) {
      unawaited(trackSearch(query));
    }

    try {
      // Perform parallel searches
      final results = await Future.wait([
        _searchWithRetry(() => _baseSearchService.searchAvatars(query: query, limit: limit)),
        _searchWithRetry(() => _baseSearchService.searchPosts(query: query, limit: limit)),
        _searchWithRetry(() => _baseSearchService.searchHashtags(query: query, limit: limit)),
        _getHashtagsWithCounts(query, limit: limit),
      ]);

      return SearchResults(
        avatars: results[0] as List<AvatarModel>,
        posts: results[1] as List<PostModel>,
        hashtags: results[2] as List<String>,
        hashtagsWithCounts: results[3] as List<Map<String, dynamic>>,
        query: query,
        hasError: false,
      );
    } catch (e) {
      debugPrint('Search error for query "$query": $e');
      return SearchResults(
        avatars: [],
        posts: [],
        hashtags: [],
        hashtagsWithCounts: [],
        query: query,
        hasError: true,
        error: _getUserFriendlyError(e),
      );
    }
  }

  /// Get trending hashtags with enhanced error handling
  Future<List<String>> getTrendingHashtags({int limit = 20}) async {
    try {
      final hashtagsWithCounts = await _searchWithRetry(() => _baseSearchService.getTrendingHashtags(limit: limit));
      // Extract hashtag strings from the Map objects
      return hashtagsWithCounts.map<String>((item) => item['hashtag'] as String).toList();
    } catch (e) {
      debugPrint('Error fetching trending hashtags: $e');
      // Return empty list - no fallback data for production
      return [];
    }
  }

  /// Search suggestions with error handling
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      // Return recent searches and popular searches combined
      try {
        final recentFuture = getRecentSearches(limit: 5);
        final popularFuture = getPopularSearches(limit: 5);
        
        final results = await Future.wait([recentFuture, popularFuture]);
        final combined = <String>[...results[0], ...results[1]];
        
        // Remove duplicates while preserving order
        final seen = <String>{};
        return combined.where((item) => seen.add(item)).take(8).toList();
      } catch (e) {
        debugPrint('Error getting search suggestions: $e');
        return [];
      }
    }

    try {
      return await _searchWithRetry(() => _baseSearchService.getSearchSuggestions(query));
    } catch (e) {
      debugPrint('Error fetching search suggestions: $e');
      return [];
    }
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Add search to local storage (fallback)
  Future<void> _addToLocalRecentSearches(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getLocalRecentSearches();
      
      // Remove if already exists to avoid duplicates
      existing.remove(query);
      
      // Add to front
      existing.insert(0, query);
      
      // Limit size
      if (existing.length > _maxRecentSearches) {
        existing.removeRange(_maxRecentSearches, existing.length);
      }
      
      await prefs.setString(_recentSearchesKey, jsonEncode(existing));
    } catch (e) {
      debugPrint('Error saving to local recent searches: $e');
    }
  }

  /// Get recent searches from local storage
  Future<List<String>> _getLocalRecentSearches({int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_recentSearchesKey);
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.cast<String>().take(limit).toList();
      }
    } catch (e) {
      debugPrint('Error loading local recent searches: $e');
    }
    return [];
  }

  /// Clear local recent searches
  Future<void> _clearLocalRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (e) {
      debugPrint('Error clearing local recent searches: $e');
    }
  }

  /// Remove specific item from local recent searches
  Future<void> _removeFromLocalRecentSearches(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getLocalRecentSearches();
      existing.remove(query);
      await prefs.setString(_recentSearchesKey, jsonEncode(existing));
    } catch (e) {
      debugPrint('Error removing from local recent searches: $e');
    }
  }

  /// Get hashtags with counts using RPC
  Future<List<Map<String, dynamic>>> _getHashtagsWithCounts(String query, {int limit = 20}) async {
    try {
      final response = await _authService.supabase.rpc('search_hashtags', params: {
        'search_query': query.startsWith('#') ? query : query,
        'limit_count': limit,
        'offset_count': 0,
      });

      return (response as List).map<Map<String, dynamic>>((item) => {
        'hashtag': item['hashtag'] as String,
        'count': item['count'] as int,
      }).toList();
    } catch (e) {
      debugPrint('Error fetching hashtags with counts: $e');
      // Fallback to basic hashtags
      final basicResults = await _baseSearchService.searchHashtags(query: query, limit: limit);
      return basicResults.map((tag) => {'hashtag': tag, 'count': 0}).toList();
    }
  }

  /// Retry wrapper for search operations
  Future<T> _searchWithRetry<T>(Future<T> Function() operation, {int maxRetries = 2}) async {
    Exception? lastException;
    
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          // Wait before retry
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }
    
    throw lastException!;
  }

  /// Convert technical errors to user-friendly messages
  String _getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    } else if (errorString.contains('timeout')) {
      return 'Search is taking too long. Please try again.';
    } else if (errorString.contains('server') || errorString.contains('500')) {
      return 'Server error. Please try again in a moment.';
    } else if (errorString.contains('rate limit')) {
      return 'Too many searches. Please wait a moment and try again.';
    }
    
    return 'Something went wrong. Please try again.';
  }

  /// Fallback popular searches when database is unavailable
  List<String> _getFallbackPopularSearches() {
    // Return empty list - no fallback data for production
    return [];
  }

  /// Clear cache (useful for testing or forced refresh)
  void clearCache() {
    _cachedPopularSearches = null;
    _popularSearchesCacheTime = null;
  }
}

/// Search results container with error handling
class SearchResults {
  final List<AvatarModel> avatars;
  final List<PostModel> posts;
  final List<String> hashtags;
  final List<Map<String, dynamic>> hashtagsWithCounts;
  final String query;
  final bool hasError;
  final String? error;

  SearchResults({
    required this.avatars,
    required this.posts,
    required this.hashtags,
    required this.hashtagsWithCounts,
    required this.query,
    this.hasError = false,
    this.error,
  });

  factory SearchResults.empty() {
    return SearchResults(
      avatars: [],
      posts: [],
      hashtags: [],
      hashtagsWithCounts: [],
      query: '',
    );
  }

  bool get isEmpty => avatars.isEmpty && posts.isEmpty && hashtags.isEmpty;
  bool get hasResults => !isEmpty;
  int get totalResultsCount => avatars.length + posts.length + hashtags.length;
}

// Helper function for fire-and-forget operations
void unawaited(Future<void> future) {
  future.catchError((error) {
    debugPrint('Unawaited future error: $error');
  });
}
