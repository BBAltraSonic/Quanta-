import 'package:flutter/foundation.dart';
import '../models/avatar_model.dart';
import '../services/avatar_profile_service.dart';
import '../services/avatar_profile_error_handler.dart';

/// Cache entry with expiration and metadata
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;
  final int accessCount;
  final DateTime lastAccessed;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
    this.accessCount = 0,
    DateTime? lastAccessed,
  }) : lastAccessed = lastAccessed ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;

  CacheEntry<T> copyWithAccess() {
    return CacheEntry<T>(
      data: data,
      timestamp: timestamp,
      ttl: ttl,
      accessCount: accessCount + 1,
      lastAccessed: DateTime.now(),
    );
  }
}

/// LRU Cache with TTL support for avatar data
class AvatarCacheService {
  static final AvatarCacheService _instance = AvatarCacheService._internal();
  factory AvatarCacheService() => _instance;
  AvatarCacheService._internal();

  final AvatarProfileErrorHandler _errorHandler = AvatarProfileErrorHandler();

  // Cache configurations
  static const int _maxCacheSize = 100;
  static const Duration _defaultTtl = Duration(minutes: 15);
  static const Duration _profileDataTtl = Duration(minutes: 10);
  static const Duration _statsTtl = Duration(minutes: 5);

  // Cache storage
  final Map<String, CacheEntry<AvatarModel>> _avatarCache = {};
  final Map<String, CacheEntry<AvatarProfileData>> _profileDataCache = {};
  final Map<String, CacheEntry<AvatarStats>> _statsCache = {};
  final Map<String, CacheEntry<List<AvatarModel>>> _userAvatarsCache = {};

  // Cache statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  /// Get cached avatar or null if not found/expired
  AvatarModel? getCachedAvatar(String avatarId) {
    final entry = _avatarCache[avatarId];
    if (entry == null || entry.isExpired) {
      if (entry?.isExpired == true) {
        _avatarCache.remove(avatarId);
      }
      _misses++;
      return null;
    }

    _avatarCache[avatarId] = entry.copyWithAccess();
    _hits++;
    return entry.data;
  }

  /// Cache avatar data
  void cacheAvatar(AvatarModel avatar, {Duration? ttl}) {
    _ensureCacheSpace(_avatarCache);
    _avatarCache[avatar.id] = CacheEntry(
      data: avatar,
      timestamp: DateTime.now(),
      ttl: ttl ?? _defaultTtl,
    );
  }

  /// Get cached profile data or null if not found/expired
  AvatarProfileData? getCachedProfileData(String avatarId) {
    final entry = _profileDataCache[avatarId];
    if (entry == null || entry.isExpired) {
      if (entry?.isExpired == true) {
        _profileDataCache.remove(avatarId);
      }
      _misses++;
      return null;
    }

    _profileDataCache[avatarId] = entry.copyWithAccess();
    _hits++;
    return entry.data;
  }

  /// Cache profile data
  void cacheProfileData(String avatarId, AvatarProfileData data) {
    _ensureCacheSpace(_profileDataCache);
    _profileDataCache[avatarId] = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      ttl: _profileDataTtl,
    );
  }

  /// Get cached stats or null if not found/expired
  AvatarStats? getCachedStats(String avatarId) {
    final entry = _statsCache[avatarId];
    if (entry == null || entry.isExpired) {
      if (entry?.isExpired == true) {
        _statsCache.remove(avatarId);
      }
      _misses++;
      return null;
    }

    _statsCache[avatarId] = entry.copyWithAccess();
    _hits++;
    return entry.data;
  }

  /// Cache stats data
  void cacheStats(String avatarId, AvatarStats stats) {
    _ensureCacheSpace(_statsCache);
    _statsCache[avatarId] = CacheEntry(
      data: stats,
      timestamp: DateTime.now(),
      ttl: _statsTtl,
    );
  }

  /// Get cached user avatars or null if not found/expired
  List<AvatarModel>? getCachedUserAvatars(String userId) {
    final entry = _userAvatarsCache[userId];
    if (entry == null || entry.isExpired) {
      if (entry?.isExpired == true) {
        _userAvatarsCache.remove(userId);
      }
      _misses++;
      return null;
    }

    _userAvatarsCache[userId] = entry.copyWithAccess();
    _hits++;
    return entry.data;
  }

  /// Cache user avatars
  void cacheUserAvatars(String userId, List<AvatarModel> avatars) {
    _ensureCacheSpace(_userAvatarsCache);
    _userAvatarsCache[userId] = CacheEntry(
      data: List.from(avatars), // Create a copy to avoid mutations
      timestamp: DateTime.now(),
      ttl: _defaultTtl,
    );
  }

  /// Invalidate specific avatar cache
  void invalidateAvatar(String avatarId) {
    _avatarCache.remove(avatarId);
    _profileDataCache.remove(avatarId);
    _statsCache.remove(avatarId);
  }

  /// Invalidate user avatars cache
  void invalidateUserAvatars(String userId) {
    _userAvatarsCache.remove(userId);
  }

  /// Invalidate all cache for a user (when they update avatars)
  void invalidateUserCache(String userId) {
    invalidateUserAvatars(userId);

    // Remove all avatars owned by this user
    final avatarsToRemove = <String>[];
    for (final entry in _avatarCache.entries) {
      if (entry.value.data.ownerUserId == userId) {
        avatarsToRemove.add(entry.key);
      }
    }

    for (final avatarId in avatarsToRemove) {
      invalidateAvatar(avatarId);
    }
  }

  /// Clear all caches
  void clearAll() {
    _avatarCache.clear();
    _profileDataCache.clear();
    _statsCache.clear();
    _userAvatarsCache.clear();
    _resetStats();
  }

  /// Clear expired entries from all caches
  void clearExpired() {
    _clearExpiredFromCache(_avatarCache);
    _clearExpiredFromCache(_profileDataCache);
    _clearExpiredFromCache(_statsCache);
    _clearExpiredFromCache(_userAvatarsCache);
  }

  /// Ensure cache doesn't exceed maximum size using LRU eviction
  void _ensureCacheSpace<T>(Map<String, CacheEntry<T>> cache) {
    if (cache.length >= _maxCacheSize) {
      // Find least recently used entry
      String? lruKey;
      DateTime? oldestAccess;

      for (final entry in cache.entries) {
        if (oldestAccess == null ||
            entry.value.lastAccessed.isBefore(oldestAccess)) {
          oldestAccess = entry.value.lastAccessed;
          lruKey = entry.key;
        }
      }

      if (lruKey != null) {
        cache.remove(lruKey);
        _evictions++;
      }
    }
  }

  /// Clear expired entries from a specific cache
  void _clearExpiredFromCache<T>(Map<String, CacheEntry<T>> cache) {
    final expiredKeys = <String>[];
    for (final entry in cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      cache.remove(key);
    }
  }

  /// Reset cache statistics
  void _resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final totalRequests = _hits + _misses;
    final hitRate = totalRequests > 0 ? (_hits / totalRequests) * 100 : 0.0;

    return {
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'hitRate': hitRate,
      'totalRequests': totalRequests,
      'cacheSize': {
        'avatars': _avatarCache.length,
        'profileData': _profileDataCache.length,
        'stats': _statsCache.length,
        'userAvatars': _userAvatarsCache.length,
      },
    };
  }

  /// Preload avatar data into cache
  Future<void> preloadAvatar(String avatarId) async {
    try {
      // Check if already cached and not expired
      if (getCachedAvatar(avatarId) != null) {
        return;
      }

      // This would typically call the avatar service to load the data
      // For now, we'll just log the preload request
      debugPrint('Preloading avatar: $avatarId');
    } catch (e) {
      _errorHandler.logError(e, context: 'preload avatar');
    }
  }

  /// Refresh cache entry by forcing reload
  Future<void> refreshCacheEntry(String key, String type) async {
    try {
      switch (type) {
        case 'avatar':
          _avatarCache.remove(key);
          break;
        case 'profileData':
          _profileDataCache.remove(key);
          break;
        case 'stats':
          _statsCache.remove(key);
          break;
        case 'userAvatars':
          _userAvatarsCache.remove(key);
          break;
        default:
          throw AvatarProfileErrorHandler.cacheError(
            'Unknown cache type: $type',
          );
      }
    } catch (e) {
      _errorHandler.logError(e, context: 'refresh cache entry');
      throw AvatarProfileErrorHandler.cacheError(
        'Failed to refresh cache entry',
        e,
      );
    }
  }

  /// Get cache health status
  bool get isHealthy {
    final stats = getCacheStats();
    final hitRate = stats['hitRate'] as double;
    final totalSize = (stats['cacheSize'] as Map<String, int>).values.reduce(
      (a, b) => a + b,
    );

    // Consider cache healthy if hit rate > 50% and not too full
    return hitRate > 50.0 && totalSize < _maxCacheSize * 0.9;
  }

  /// Perform cache maintenance
  void performMaintenance() {
    clearExpired();

    // Log cache statistics in debug mode
    if (kDebugMode) {
      final stats = getCacheStats();
      debugPrint('Avatar Cache Stats: $stats');
    }
  }
}
