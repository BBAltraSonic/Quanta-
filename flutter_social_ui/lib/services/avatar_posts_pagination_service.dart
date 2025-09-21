import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../store/app_state.dart';

/// Service for efficient avatar posts loading with pagination
class AvatarPostsPaginationService {
  static final AvatarPostsPaginationService _instance =
      AvatarPostsPaginationService._internal();
  factory AvatarPostsPaginationService() => _instance;
  AvatarPostsPaginationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final AppState _appState = AppState();

  // Pagination configuration
  static const int _defaultPageSize = 20;
  static const int _maxPageSize = 50;

  // Track pagination state per avatar
  final Map<String, _PaginationState> _paginationStates = {};

  /// Load avatar posts with pagination
  Future<List<PostModel>> loadAvatarPosts(
    String avatarId, {
    int page = 0,
    int pageSize = _defaultPageSize,
    bool refresh = false,
  }) async {
    // Validate page size
    final validPageSize = pageSize.clamp(1, _maxPageSize);

    // Get or create pagination state
    final paginationKey = avatarId;
    if (!_paginationStates.containsKey(paginationKey) || refresh) {
      _paginationStates[paginationKey] = _PaginationState();
    }

    final state = _paginationStates[paginationKey]!;

    // Check if we already have this page or if there's no more data
    if (!refresh && (state.loadedPages.contains(page) || !state.hasMoreData)) {
      return _getPostsFromCache(avatarId, page, validPageSize);
    }

    try {
      // Set loading state
      _appState.setLoadingState('avatar_posts_$avatarId', true);

      // Calculate offset
      final offset = page * validPageSize;

      // Query posts with optimized selection
      final response = await _supabase
          .from('posts')
          .select('''
            id,
            content,
            media_urls,
            avatar_id,
            created_at,
            updated_at,
            likes_count,
            comments_count,
            shares_count,
            views_count,
            post_type,
            avatars!inner(
              id,
              name,
              avatar_url,
              owner_user_id
            )
          ''')
          .eq('avatar_id', avatarId)
          .order('created_at', ascending: false)
          .range(offset, offset + validPageSize - 1);

      final List<dynamic> data = response as List<dynamic>;

      // Convert to PostModel objects
      final posts = data.map((json) => PostModel.fromJson(json)).toList();

      // Update pagination state
      state.loadedPages.add(page);
      state.hasMoreData = posts.length == validPageSize;
      state.lastLoadedAt = DateTime.now();

      // Cache posts in AppState
      for (final post in posts) {
        _appState.setPost(post);
      }

      // Update AppState pagination info
      _appState.setPaginationState(
        'avatar_posts_$avatarId',
        page,
        state.hasMoreData,
      );

      return posts;
    } catch (e) {
      // Handle error
      _appState.setError('Failed to load avatar posts: $e');
      rethrow;
    } finally {
      // Clear loading state
      _appState.setLoadingState('avatar_posts_$avatarId', false);
    }
  }

  /// Load next page of posts for an avatar
  Future<List<PostModel>> loadNextPage(String avatarId) async {
    final state = _paginationStates[avatarId];
    if (state == null || !state.hasMoreData) {
      return [];
    }

    final nextPage = state.loadedPages.isEmpty
        ? 0
        : state.loadedPages.reduce((a, b) => a > b ? a : b) + 1;
    return loadAvatarPosts(avatarId, page: nextPage);
  }

  /// Refresh avatar posts (reload from beginning)
  Future<List<PostModel>> refreshAvatarPosts(String avatarId) async {
    // Clear pagination state
    _paginationStates.remove(avatarId);

    // Clear cached posts for this avatar
    _clearAvatarPostsCache(avatarId);

    // Load first page
    return loadAvatarPosts(avatarId, page: 0, refresh: true);
  }

  /// Check if more posts are available for an avatar
  bool hasMorePosts(String avatarId) {
    final state = _paginationStates[avatarId];
    return state?.hasMoreData ?? true;
  }

  /// Get current page for an avatar
  int getCurrentPage(String avatarId) {
    final state = _paginationStates[avatarId];
    if (state == null || state.loadedPages.isEmpty) {
      return 0;
    }
    return state.loadedPages.reduce((a, b) => a > b ? a : b);
  }

  /// Preload next page in background for better UX
  Future<void> preloadNextPage(String avatarId) async {
    if (!hasMorePosts(avatarId)) return;

    try {
      await loadNextPage(avatarId);
    } catch (e) {
      // Silently fail for preloading
      print('Failed to preload next page for avatar $avatarId: $e');
    }
  }

  /// Get posts from cache for a specific page
  List<PostModel> _getPostsFromCache(String avatarId, int page, int pageSize) {
    final allPosts = _appState.getAvatarPosts(avatarId);
    final startIndex = page * pageSize;
    final endIndex = startIndex + pageSize;

    if (startIndex >= allPosts.length) {
      return [];
    }

    return allPosts.sublist(
      startIndex,
      endIndex > allPosts.length ? allPosts.length : endIndex,
    );
  }

  /// Clear cached posts for an avatar
  void _clearAvatarPostsCache(String avatarId) {
    // This would need to be implemented in AppState
    // For now, we'll rely on the cache service invalidation
    final posts = _appState.getAvatarPosts(avatarId);
    for (final post in posts) {
      _appState.removePost(post.id);
    }
  }

  /// Get pagination statistics for monitoring
  Map<String, dynamic> getPaginationStats() {
    return {
      'totalAvatarsWithPagination': _paginationStates.length,
      'averageLoadedPages': _paginationStates.values.isEmpty
          ? 0.0
          : _paginationStates.values
                    .map((s) => s.loadedPages.length)
                    .reduce((a, b) => a + b) /
                _paginationStates.length,
      'avatarsWithMoreData': _paginationStates.values
          .where((s) => s.hasMoreData)
          .length,
    };
  }

  /// Clear pagination state for an avatar
  void clearAvatarPagination(String avatarId) {
    _paginationStates.remove(avatarId);
  }

  /// Clear all pagination state
  void clearAllPagination() {
    _paginationStates.clear();
  }
}

/// Internal pagination state tracking
class _PaginationState {
  final Set<int> loadedPages = <int>{};
  bool hasMoreData = true;
  DateTime? lastLoadedAt;
}
