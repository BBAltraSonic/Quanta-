import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CacheItem {
  final Uint8List data;
  final DateTime cachedAt;
  final String contentType;
  final int size;

  CacheItem({
    required this.data,
    required this.cachedAt,
    required this.contentType,
    required this.size,
  });

  bool get isExpired {
    final now = DateTime.now();
    final maxAge = Duration(hours: 24); // Cache for 24 hours
    return now.difference(cachedAt) > maxAge;
  }

  Map<String, dynamic> toJson() {
    return {
      'data': base64Encode(data),
      'cachedAt': cachedAt.toIso8601String(),
      'contentType': contentType,
      'size': size,
    };
  }

  factory CacheItem.fromJson(Map<String, dynamic> json) {
    return CacheItem(
      data: base64Decode(json['data']),
      cachedAt: DateTime.parse(json['cachedAt']),
      contentType: json['contentType'],
      size: json['size'],
    );
  }
}

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final Map<String, CacheItem> _memoryCache = {};
  final int _maxMemoryCacheSize = 50 * 1024 * 1024; // 50MB
  int _currentMemoryCacheSize = 0;
  Directory? _cacheDirectory;

  // Initialize the service
  Future<void> initialize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDirectory = Directory('${tempDir.path}/image_cache');
      
      if (!await _cacheDirectory!.exists()) {
        await _cacheDirectory!.create(recursive: true);
      }
      
      // Clean up expired cache files on startup
      await _cleanupExpiredCache();
    } catch (e) {
      debugPrint('Error initializing PerformanceService: $e');
    }
  }

  // Generate cache key from URL
  String _generateCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Get cached image data
  Future<Uint8List?> getCachedImage(String url) async {
    final cacheKey = _generateCacheKey(url);
    
    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      final item = _memoryCache[cacheKey]!;
      if (!item.isExpired) {
        return item.data;
      } else {
        // Remove expired item from memory cache
        _currentMemoryCacheSize -= item.size;
        _memoryCache.remove(cacheKey);
      }
    }
    
    // Check disk cache
    if (_cacheDirectory != null) {
      final cacheFile = File('${_cacheDirectory!.path}/$cacheKey.cache');
      if (await cacheFile.exists()) {
        try {
          final jsonString = await cacheFile.readAsString();
          final jsonData = jsonDecode(jsonString);
          final cacheItem = CacheItem.fromJson(jsonData);
          
          if (!cacheItem.isExpired) {
            // Add to memory cache if there's space
            if (_currentMemoryCacheSize + cacheItem.size <= _maxMemoryCacheSize) {
              _memoryCache[cacheKey] = cacheItem;
              _currentMemoryCacheSize += cacheItem.size;
            }
            return cacheItem.data;
          } else {
            // Delete expired cache file
            await cacheFile.delete();
          }
        } catch (e) {
          debugPrint('Error reading cache file: $e');
          // Delete corrupted cache file
          try {
            await cacheFile.delete();
          } catch (_) {}
        }
      }
    }
    
    return null;
  }

  // Cache image data
  Future<void> cacheImage(String url, Uint8List data, String contentType) async {
    final cacheKey = _generateCacheKey(url);
    final cacheItem = CacheItem(
      data: data,
      cachedAt: DateTime.now(),
      contentType: contentType,
      size: data.length,
    );
    
    // Add to memory cache if there's space
    if (_currentMemoryCacheSize + cacheItem.size <= _maxMemoryCacheSize) {
      // Remove oldest items if necessary
      while (_currentMemoryCacheSize + cacheItem.size > _maxMemoryCacheSize && _memoryCache.isNotEmpty) {
        _evictOldestMemoryCacheItem();
      }
      
      _memoryCache[cacheKey] = cacheItem;
      _currentMemoryCacheSize += cacheItem.size;
    }
    
    // Save to disk cache
    if (_cacheDirectory != null) {
      try {
        final cacheFile = File('${_cacheDirectory!.path}/$cacheKey.cache');
        final jsonString = jsonEncode(cacheItem.toJson());
        await cacheFile.writeAsString(jsonString);
      } catch (e) {
        debugPrint('Error writing cache file: $e');
      }
    }
  }

  // Evict oldest item from memory cache
  void _evictOldestMemoryCacheItem() {
    if (_memoryCache.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _memoryCache.entries) {
      if (oldestTime == null || entry.value.cachedAt.isBefore(oldestTime)) {
        oldestTime = entry.value.cachedAt;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      final item = _memoryCache.remove(oldestKey)!;
      _currentMemoryCacheSize -= item.size;
    }
  }

  // Clean up expired cache files
  Future<void> _cleanupExpiredCache() async {
    if (_cacheDirectory == null) return;
    
    try {
      final files = await _cacheDirectory!.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.cache')) {
          try {
            final jsonString = await file.readAsString();
            final jsonData = jsonDecode(jsonString);
            final cacheItem = CacheItem.fromJson(jsonData);
            
            if (cacheItem.isExpired) {
              await file.delete();
            }
          } catch (e) {
            // Delete corrupted cache files
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up cache: $e');
    }
  }

  // Clear all cache
  Future<void> clearCache() async {
    // Clear memory cache
    _memoryCache.clear();
    _currentMemoryCacheSize = 0;
    
    // Clear disk cache
    if (_cacheDirectory != null) {
      try {
        if (await _cacheDirectory!.exists()) {
          await _cacheDirectory!.delete(recursive: true);
          await _cacheDirectory!.create(recursive: true);
        }
      } catch (e) {
        debugPrint('Error clearing disk cache: $e');
      }
    }
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'memory_cache_items': _memoryCache.length,
      'memory_cache_size_mb': (_currentMemoryCacheSize / (1024 * 1024)).toStringAsFixed(2),
      'memory_cache_limit_mb': (_maxMemoryCacheSize / (1024 * 1024)).toStringAsFixed(2),
    };
  }

  // Preload images for better performance
  Future<void> preloadImages(List<String> urls) async {
    for (final url in urls) {
      try {
        final cachedData = await getCachedImage(url);
        if (cachedData == null) {
          // Image not cached, could trigger background download
          // This would be implemented with actual network requests
          debugPrint('Image not cached, would preload: $url');
        }
      } catch (e) {
        debugPrint('Error preloading image $url: $e');
      }
    }
  }

  // Add haptic feedback
  static void lightHaptic() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Haptic feedback not available: $e');
    }
  }

  static void mediumHaptic() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Haptic feedback not available: $e');
    }
  }

  static void heavyHaptic() {
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Haptic feedback not available: $e');
    }
  }

  static void selectionHaptic() {
    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Haptic feedback not available: $e');
    }
  }

  // Memory management utilities
  static void optimizeMemory() {
    // Force garbage collection (not directly available in Dart, but can help with memory pressure)
    try {
      // Clear image cache if memory pressure is high
      // This would be implemented with actual memory monitoring
      debugPrint('Memory optimization triggered');
    } catch (e) {
      debugPrint('Error optimizing memory: $e');
    }
  }

  // App startup optimization
  static Future<void> warmupApp() async {
    try {
      // Preload critical resources
      await Future.wait([
        // Preload fonts
        _preloadFonts(),
        // Preload critical images
        _preloadCriticalAssets(),
        // Initialize services
        _initializeCriticalServices(),
      ]);
    } catch (e) {
      debugPrint('Error during app warmup: $e');
    }
  }

  static Future<void> _preloadFonts() async {
    // Preload custom fonts if any
    try {
      // This would preload any custom fonts used in the app
      await Future.delayed(Duration(milliseconds: 10));
    } catch (e) {
      debugPrint('Error preloading fonts: $e');
    }
  }

  static Future<void> _preloadCriticalAssets() async {
    try {
      // Preload critical app assets
      final criticalAssets = [
        'assets/images/We.jpg',
        'assets/images/p.jpg',
        // Add other critical assets
      ];
      
      for (final asset in criticalAssets) {
        try {
          await rootBundle.load(asset);
        } catch (e) {
          debugPrint('Error preloading asset $asset: $e');
        }
      }
    } catch (e) {
      debugPrint('Error preloading critical assets: $e');
    }
  }

  static Future<void> _initializeCriticalServices() async {
    try {
      // Initialize performance service
      await PerformanceService().initialize();
      
      // Initialize other critical services
      await Future.delayed(Duration(milliseconds: 10));
    } catch (e) {
      debugPrint('Error initializing critical services: $e');
    }
  }

  /// Get cached image as ImageProvider
  Future<ImageProvider> getCachedImageProvider(String imageUrl) async {
    try {
      final bytes = await getCachedImage(imageUrl);
      if (bytes != null) {
        return MemoryImage(bytes);
      }
    } catch (e) {
      debugPrint('Error getting cached image: $e');
    }
    
    // Fallback to appropriate image provider
    if (imageUrl.startsWith('http')) {
      return NetworkImage(imageUrl);
    } else {
      return AssetImage(imageUrl);
    }
  }

  /// Trigger haptic feedback
  void triggerHapticFeedback() {
    lightHaptic();
  }
}