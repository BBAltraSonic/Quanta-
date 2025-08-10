import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../config/app_config.dart';
import 'search_service.dart';
import 'demo_search_service.dart';

/// Wrapper that chooses between real SearchService and DemoSearchService
/// based on AppConfig.demoMode setting
class SearchServiceWrapper {
  static final SearchServiceWrapper _instance =
      SearchServiceWrapper._internal();
  factory SearchServiceWrapper() => _instance;
  SearchServiceWrapper._internal();

  dynamic _service;
  bool _isInitialized = false;

  SearchServiceWrapper get instance => this;

  // Initialize the appropriate service
  Future<void> initialize() async {
    if (_isInitialized) {
      return; // Already initialized, skip
    }

    if (AppConfig.demoMode) {
      _service = DemoSearchService();
    } else {
      _service = SearchService();
    }

    await _service.initialize();
    _isInitialized = true;
  }

  // Comprehensive search (new method)
  Future<List<SearchResult>> search({
    required String query,
    SearchType type = SearchType.all,
    int limit = 20,
    int offset = 0,
  }) async {
    if (AppConfig.demoMode) {
      // For demo mode, convert old methods to new format
      return await _searchDemo(
        query: query,
        type: type,
        limit: limit,
        offset: offset,
      );
    } else {
      return await _service.search(
        query: query,
        type: type,
        limit: limit,
        offset: offset,
      );
    }
  }

  // Demo search conversion
  Future<List<SearchResult>> _searchDemo({
    required String query,
    SearchType type = SearchType.all,
    int limit = 20,
    int offset = 0,
  }) async {
    final results = <SearchResult>[];

    try {
      switch (type) {
        case SearchType.all:
          // Get mixed results from demo service
          final posts = await _service.searchPosts(
            query: query,
            limit: limit ~/ 2,
          );
          final avatars = await _service.searchAvatars(
            query: query,
            limit: limit ~/ 2,
          );

          // Convert to SearchResult format
          for (final post in posts) {
            results.add(SearchResult.fromPost(post));
          }
          for (final avatar in avatars) {
            if (avatar is AvatarModel) {
              results.add(SearchResult.fromAvatar(avatar));
            }
          }
          break;

        case SearchType.posts:
          final posts = await _service.searchPosts(
            query: query,
            limit: limit,
            offset: offset,
          );
          for (final post in posts) {
            results.add(SearchResult.fromPost(post));
          }
          break;

        case SearchType.avatars:
          final avatars = await _service.searchAvatars(
            query: query,
            limit: limit,
            offset: offset,
          );
          for (final avatar in avatars) {
            if (avatar is AvatarModel) {
              results.add(SearchResult.fromAvatar(avatar));
            }
          }
          break;

        case SearchType.hashtags:
          final hashtags = await _service.searchHashtags(
            query: query,
            limit: limit,
          );
          for (final hashtag in hashtags) {
            results.add(SearchResult.fromHashtag(hashtag, 1)); // Demo count
          }
          break;

        case SearchType.users:
          // Demo mode doesn't have user search, return empty
          break;
      }
    } catch (e) {
      // Return empty results on error
    }

    return results;
  }

  // Legacy methods for backward compatibility
  Future<List<PostModel>> searchPosts({
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? hashtags,
    PostType? type,
  }) async {
    if (AppConfig.demoMode) {
      return await _service.searchPosts(
        query: query,
        limit: limit,
        offset: offset,
        hashtags: hashtags,
        type: type,
      );
    } else {
      // Convert new search to old format
      final results = await _service.search(
        query: query,
        type: SearchType.posts,
        limit: limit,
        offset: offset,
      );

      return results
          .where((result) => result.type == SearchType.posts)
          .map((result) => PostModel.fromJson(result.data))
          .toList();
    }
  }

  // Search hashtags
  Future<List<String>> searchHashtags({
    required String query,
    int limit = 10,
  }) async {
    if (AppConfig.demoMode) {
      return await _service.searchHashtags(query: query, limit: limit);
    } else {
      final results = await _service.search(
        query: query,
        type: SearchType.hashtags,
        limit: limit,
      );

      return results
          .where((result) => result.type == SearchType.hashtags)
          .map((result) => result.data['hashtag'] as String)
          .toList();
    }
  }

  // Get trending hashtags
  Future<List<Map<String, dynamic>>> getTrendingHashtags({
    int limit = 20,
  }) async {
    if (AppConfig.demoMode) {
      final trending = await _service.getTrendingSearches(limit: limit);
      return trending
          .map((hashtag) => {'hashtag': hashtag, 'count': 1})
          .toList();
    } else {
      return await _service.getTrendingHashtags(limit: limit);
    }
  }

  // Get trending searches (legacy)
  Future<List<String>> getTrendingSearches({int limit = 10}) async {
    if (AppConfig.demoMode) {
      return await _service.getTrendingSearches(limit: limit);
    } else {
      final hashtags = await _service.getTrendingHashtags(limit: limit);
      return hashtags.map((item) => item['hashtag'] as String).toList();
    }
  }

  // Get search suggestions
  Future<List<String>> getSearchSuggestions({
    required String query,
    int limit = 5,
  }) async {
    if (AppConfig.demoMode) {
      return await _service.getSearchSuggestions(query: query, limit: limit);
    } else {
      return await _service.getSearchSuggestions(query);
    }
  }

  // Search avatars
  Future<List<dynamic>> searchAvatars({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    if (AppConfig.demoMode) {
      return await _service.searchAvatars(
        query: query,
        limit: limit,
        offset: offset,
      );
    } else {
      final results = await _service.search(
        query: query,
        type: SearchType.avatars,
        limit: limit,
        offset: offset,
      );

      return results
          .where((result) => result.type == SearchType.avatars)
          .map((result) => AvatarModel.fromJson(result.data))
          .toList();
    }
  }

  // Get recent searches
  List<String> getRecentSearches() {
    if (AppConfig.demoMode) {
      return []; // Demo mode doesn't persist searches
    } else {
      return _service.getRecentSearches();
    }
  }

  // Clear recent searches
  Future<void> clearRecentSearches() async {
    if (!AppConfig.demoMode) {
      await _service.clearRecentSearches();
    }
  }

  // Clear cache
  void clearCache() {
    if (!AppConfig.demoMode) {
      _service.clearCache();
    }
  }
}
