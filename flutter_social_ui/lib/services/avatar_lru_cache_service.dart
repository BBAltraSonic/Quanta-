import 'dart:collection';
import '../models/avatar_model.dart';
import '../models/post_model.dart';

/// LRU (Least Recently Used) cache for avatar data
/// Provides efficient caching with automatic eviction of least recently used items
class AvatarLRUCacheService {
  static final AvatarLRUCacheService _instance =
      AvatarLRUCacheService._internal();
  factory AvatarLRUCacheService() => _instance;
  AvatarLRUCacheService._internal();

  // Cache configuration
  static const int _maxAvatarCacheSize = 100;
  static const int _maxPostsCacheSize = 500;
  static const int _maxStatsCacheSize = 200;
  static const Duration _cacheExpiry = Duration(minutes: 15);

  // Avatar data cache
  final LinkedHashMap<String, _CacheEntry<AvatarModel>> _avatarCache =
      LinkedHashMap();

  // Avatar posts cache (avatarId -> List<PostModel>)
  final LinkedHashMap<String, _CacheEntry<List<PostModel>>> _avatarPostsCache =
      LinkedHashMap();

  // Avatar stats cache (avatarId -> Map<String, dynamic>)
  final LinkedHashMap<String, _CacheEntry<Map<String, dynamic>>>
  _avatarStatsCache = LinkedHashMap();

  /// Cache an avatar
  void cacheAvatar(String avatarId, AvatarModel avatar) {
    _evictIfNeeded(_avatarCache, _maxAvatarCacheSize);
    _avatarCache[avatarId] = _CacheEntry(avatar, DateTime.now());
  }

  /// Get cached avatar
  AvatarModel? getCachedAvatar(String avatarId) {
    final entry = _avatarCache[avatarId];
    if (entry == null || _isExpired(entry)) {
      _avatarCache.remove(avatarId);
      return null;
    }

    // Move to end (most recently used)
    _avatarCache.remove(avatarId);
    _avatarCache[avatarId] = entry;

    return entry.data;
  }

  /// Cache avatar posts
  void cacheAvatarPosts(String avatarId, List<PostModel> posts) {
    _evictIfNeeded(_avatarPostsCache, _maxPostsCacheSize);
    _avatarPostsCache[avatarId] = _CacheEntry(List.from(posts), DateTime.now());
  }

  /// Get cached avatar posts
  List<PostModel>? getCachedAvatarPosts(String avatarId) {
    final entry = _avatarPostsCache[avatarId];
    if (entry == null || _isExpired(entry)) {
      _avatarPostsCache.remove(avatarId);
      return null;
    }

    // Move to end (most recently used)
    _avatarPostsCache.remove(avatarId);
    _avatarPostsCache[avatarId] = entry;

    return List.from(entry.data);
  }

  /// Cache avatar stats
  void cacheAvatarStats(String avatarId, Map<String, dynamic> stats) {
    _evictIfNeeded(_avatarStatsCache, _maxStatsCacheSize);
    _avatarStatsCache[avatarId] = _CacheEntry(Map.from(stats), DateTime.now());
  }

  /// Get cached avatar stats
  Map<String, dynamic>? getCachedAvatarStats(String avatarId) {
    final entry = _avatarStatsCache[avatarId];
    if (entry == null || _isExpired(entry)) {
      _avatarStatsCache.remove(avatarId);
      return null;
    }

    // Move to end (most recently used)
    _avatarStatsCache.remove(avatarId);
    _avatarStatsCache[avatarId] = entry;

    return Map.from(entry.data);
  }

  /// Invalidate avatar cache
  void invalidateAvatar(String avatarId) {
    _avatarCache.remove(avatarId);
    _avatarPostsCache.remove(avatarId);
    _avatarStatsCache.remove(avatarId);
  }

  /// Invalidate all avatar data for a user
  void invalidateUserAvatars(String userId) {
    // Remove all avatars owned by the user
    _avatarCache.removeWhere((key, entry) => entry.data.ownerUserId == userId);

    // Note: We can't easily filter posts cache by user, so we clear it entirely
    // This is a trade-off for simplicity vs. efficiency
    _avatarPostsCache.clear();
    _avatarStatsCache.clear();
  }

  /// Clear all caches
  void clearAll() {
    _avatarCache.clear();
    _avatarPostsCache.clear();
    _avatarStatsCache.clear();
  }

  /// Get cache statistics for monitoring
  Map<String, dynamic> getCacheStats() {
    return {
      'avatarCacheSize': _avatarCache.length,
      'avatarPostsCacheSize': _avatarPostsCache.length,
      'avatarStatsCacheSize': _avatarStatsCache.length,
      'maxAvatarCacheSize': _maxAvatarCacheSize,
      'maxPostsCacheSize': _maxPostsCacheSize,
      'maxStatsCacheSize': _maxStatsCacheSize,
      'cacheExpiryMinutes': _cacheExpiry.inMinutes,
    };
  }

  /// Evict least recently used items if cache is full
  void _evictIfNeeded<T>(
    LinkedHashMap<String, _CacheEntry<T>> cache,
    int maxSize,
  ) {
    while (cache.length >= maxSize) {
      final firstKey = cache.keys.first;
      cache.remove(firstKey);
    }
  }

  /// Check if cache entry is expired
  bool _isExpired<T>(_CacheEntry<T> entry) {
    return DateTime.now().difference(entry.timestamp) > _cacheExpiry;
  }

  /// Preload avatars into cache (for performance optimization)
  void preloadAvatars(List<AvatarModel> avatars) {
    for (final avatar in avatars) {
      cacheAvatar(avatar.id, avatar);
    }
  }

  /// Get cache hit rate for monitoring
  double getCacheHitRate() {
    // This would require tracking hits/misses in a production implementation
    // For now, return a placeholder
    return 0.0;
  }
}

/// Internal cache entry with timestamp for expiry
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);
}
