import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'avatar_lru_cache_service.dart';
import 'avatar_realtime_service_simple.dart';

/// Service for monitoring avatar-related performance metrics
class AvatarPerformanceMonitoringService {
  static final AvatarPerformanceMonitoringService _instance =
      AvatarPerformanceMonitoringService._internal();
  factory AvatarPerformanceMonitoringService() => _instance;
  AvatarPerformanceMonitoringService._internal();

  // Performance metrics tracking
  final Map<String, List<Duration>> _operationTimes = {};
  final Map<String, int> _operationCounts = {};
  final Map<String, DateTime> _lastOperationTimes = {};

  // Memory usage tracking
  final Queue<_MemorySnapshot> _memorySnapshots = Queue();
  static const int _maxMemorySnapshots = 100;

  // Cache performance tracking
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheMisses = {};

  // Database query performance
  final Map<String, List<Duration>> _queryTimes = {};
  final Map<String, int> _queryErrorCounts = {};

  // Real-time subscription performance
  final Map<String, DateTime> _subscriptionStartTimes = {};
  final Map<String, int> _subscriptionEventCounts = {};

  /// Track operation performance
  Future<T> trackOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    _operationCounts[operationName] =
        (_operationCounts[operationName] ?? 0) + 1;
    _lastOperationTimes[operationName] = DateTime.now();

    try {
      final result = await operation();
      stopwatch.stop();

      // Record successful operation time
      if (!_operationTimes.containsKey(operationName)) {
        _operationTimes[operationName] = [];
      }
      _operationTimes[operationName]!.add(stopwatch.elapsed);

      // Keep only last 100 measurements
      if (_operationTimes[operationName]!.length > 100) {
        _operationTimes[operationName]!.removeAt(0);
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      // Track error but still record time
      _operationTimes[operationName] ??= [];
      _operationTimes[operationName]!.add(stopwatch.elapsed);
      rethrow;
    }
  }

  /// Track synchronous operation performance
  T trackSyncOperation<T>(String operationName, T Function() operation) {
    final stopwatch = Stopwatch()..start();
    _operationCounts[operationName] =
        (_operationCounts[operationName] ?? 0) + 1;
    _lastOperationTimes[operationName] = DateTime.now();

    try {
      final result = operation();
      stopwatch.stop();

      // Record successful operation time
      if (!_operationTimes.containsKey(operationName)) {
        _operationTimes[operationName] = [];
      }
      _operationTimes[operationName]!.add(stopwatch.elapsed);

      // Keep only last 100 measurements
      if (_operationTimes[operationName]!.length > 100) {
        _operationTimes[operationName]!.removeAt(0);
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      // Track error but still record time
      _operationTimes[operationName] ??= [];
      _operationTimes[operationName]!.add(stopwatch.elapsed);
      rethrow;
    }
  }

  /// Record cache hit
  void recordCacheHit(String cacheType) {
    _cacheHits[cacheType] = (_cacheHits[cacheType] ?? 0) + 1;
  }

  /// Record cache miss
  void recordCacheMiss(String cacheType) {
    _cacheMisses[cacheType] = (_cacheMisses[cacheType] ?? 0) + 1;
  }

  /// Track database query performance
  Future<T> trackDatabaseQuery<T>(
    String queryName,
    Future<T> Function() query,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await query();
      stopwatch.stop();

      // Record successful query time
      if (!_queryTimes.containsKey(queryName)) {
        _queryTimes[queryName] = [];
      }
      _queryTimes[queryName]!.add(stopwatch.elapsed);

      // Keep only last 50 measurements
      if (_queryTimes[queryName]!.length > 50) {
        _queryTimes[queryName]!.removeAt(0);
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      _queryErrorCounts[queryName] = (_queryErrorCounts[queryName] ?? 0) + 1;
      rethrow;
    }
  }

  /// Track subscription start
  void trackSubscriptionStart(String subscriptionName) {
    _subscriptionStartTimes[subscriptionName] = DateTime.now();
    _subscriptionEventCounts[subscriptionName] = 0;
  }

  /// Track subscription event
  void trackSubscriptionEvent(String subscriptionName) {
    _subscriptionEventCounts[subscriptionName] =
        (_subscriptionEventCounts[subscriptionName] ?? 0) + 1;
  }

  /// Track subscription end
  void trackSubscriptionEnd(String subscriptionName) {
    _subscriptionStartTimes.remove(subscriptionName);
    _subscriptionEventCounts.remove(subscriptionName);
  }

  /// Take memory snapshot
  void takeMemorySnapshot() {
    if (!kDebugMode) return; // Only in debug mode

    final snapshot = _MemorySnapshot(
      timestamp: DateTime.now(),
      // In a real implementation, you would measure actual memory usage
      // For now, we'll use placeholder values
      heapUsage: 0, // Would use dart:developer or similar
      cacheSize: _getCacheSize(),
    );

    _memorySnapshots.add(snapshot);

    // Keep only recent snapshots
    while (_memorySnapshots.length > _maxMemorySnapshots) {
      _memorySnapshots.removeFirst();
    }
  }

  /// Get comprehensive performance report
  Map<String, dynamic> getPerformanceReport() {
    return {
      'operations': _getOperationMetrics(),
      'cache': _getCacheMetrics(),
      'database': _getDatabaseMetrics(),
      'subscriptions': _getSubscriptionMetrics(),
      'memory': _getMemoryMetrics(),
      'summary': _getPerformanceSummary(),
    };
  }

  /// Get operation metrics
  Map<String, dynamic> _getOperationMetrics() {
    final metrics = <String, dynamic>{};

    for (final operationName in _operationTimes.keys) {
      final times = _operationTimes[operationName]!;
      if (times.isNotEmpty) {
        final avgTime =
            times.map((d) => d.inMicroseconds).reduce((a, b) => a + b) /
            times.length;
        final maxTime = times
            .map((d) => d.inMicroseconds)
            .reduce((a, b) => a > b ? a : b);
        final minTime = times
            .map((d) => d.inMicroseconds)
            .reduce((a, b) => a < b ? a : b);

        metrics[operationName] = {
          'count': _operationCounts[operationName] ?? 0,
          'avgTimeMs': avgTime / 1000,
          'maxTimeMs': maxTime / 1000,
          'minTimeMs': minTime / 1000,
          'lastExecuted': _lastOperationTimes[operationName]?.toIso8601String(),
        };
      }
    }

    return metrics;
  }

  /// Get cache metrics
  Map<String, dynamic> _getCacheMetrics() {
    final cacheService = AvatarLRUCacheService();
    final cacheStats = cacheService.getCacheStats();

    final hitRates = <String, double>{};
    for (final cacheType in _cacheHits.keys) {
      final hits = _cacheHits[cacheType] ?? 0;
      final misses = _cacheMisses[cacheType] ?? 0;
      final total = hits + misses;
      hitRates[cacheType] = total > 0 ? hits / total : 0.0;
    }

    return {
      'stats': cacheStats,
      'hitRates': hitRates,
      'totalHits': _cacheHits.values.fold(0, (sum, hits) => sum + hits),
      'totalMisses': _cacheMisses.values.fold(0, (sum, misses) => sum + misses),
    };
  }

  /// Get database metrics
  Map<String, dynamic> _getDatabaseMetrics() {
    final metrics = <String, dynamic>{};

    for (final queryName in _queryTimes.keys) {
      final times = _queryTimes[queryName]!;
      if (times.isNotEmpty) {
        final avgTime =
            times.map((d) => d.inMicroseconds).reduce((a, b) => a + b) /
            times.length;

        metrics[queryName] = {
          'avgTimeMs': avgTime / 1000,
          'errorCount': _queryErrorCounts[queryName] ?? 0,
          'executionCount': times.length,
        };
      }
    }

    return metrics;
  }

  /// Get subscription metrics
  Map<String, dynamic> _getSubscriptionMetrics() {
    final activeSubscriptions = <String, dynamic>{};

    for (final subscriptionName in _subscriptionStartTimes.keys) {
      final startTime = _subscriptionStartTimes[subscriptionName]!;
      final eventCount = _subscriptionEventCounts[subscriptionName] ?? 0;
      final duration = DateTime.now().difference(startTime);

      activeSubscriptions[subscriptionName] = {
        'durationMinutes': duration.inMinutes,
        'eventCount': eventCount,
        'eventsPerMinute': duration.inMinutes > 0
            ? eventCount / duration.inMinutes
            : 0,
      };
    }

    final realtimeService = AvatarRealtimeServiceSimple();
    final subscriptionStats = realtimeService.getSubscriptionStats();

    return {'active': activeSubscriptions, 'stats': subscriptionStats};
  }

  /// Get memory metrics
  Map<String, dynamic> _getMemoryMetrics() {
    if (_memorySnapshots.isEmpty) {
      return {'snapshots': 0};
    }

    final recent = _memorySnapshots.toList();
    final avgCacheSize =
        recent.map((s) => s.cacheSize).reduce((a, b) => a + b) / recent.length;

    return {
      'snapshots': recent.length,
      'avgCacheSize': avgCacheSize,
      'latestCacheSize': recent.last.cacheSize,
      'oldestSnapshot': recent.first.timestamp.toIso8601String(),
      'latestSnapshot': recent.last.timestamp.toIso8601String(),
    };
  }

  /// Get performance summary
  Map<String, dynamic> _getPerformanceSummary() {
    final totalOperations = _operationCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );
    final totalCacheHits = _cacheHits.values.fold(0, (sum, hits) => sum + hits);
    final totalCacheMisses = _cacheMisses.values.fold(
      0,
      (sum, misses) => sum + misses,
    );
    final overallCacheHitRate = (totalCacheHits + totalCacheMisses) > 0
        ? totalCacheHits / (totalCacheHits + totalCacheMisses)
        : 0.0;

    // Calculate average operation time across all operations
    double avgOperationTime = 0.0;
    int totalMeasurements = 0;
    for (final times in _operationTimes.values) {
      for (final time in times) {
        avgOperationTime += time.inMicroseconds;
        totalMeasurements++;
      }
    }
    if (totalMeasurements > 0) {
      avgOperationTime =
          (avgOperationTime / totalMeasurements) / 1000; // Convert to ms
    }

    return {
      'totalOperations': totalOperations,
      'avgOperationTimeMs': avgOperationTime,
      'overallCacheHitRate': overallCacheHitRate,
      'activeSubscriptions': _subscriptionStartTimes.length,
      'monitoringStarted': DateTime.now().toIso8601String(),
    };
  }

  /// Get current cache size (placeholder implementation)
  int _getCacheSize() {
    final cacheService = AvatarLRUCacheService();
    final stats = cacheService.getCacheStats();
    return (stats['avatarCacheSize'] as int? ?? 0) +
        (stats['avatarPostsCacheSize'] as int? ?? 0) +
        (stats['avatarStatsCacheSize'] as int? ?? 0);
  }

  /// Clear all performance data
  void clearPerformanceData() {
    _operationTimes.clear();
    _operationCounts.clear();
    _lastOperationTimes.clear();
    _memorySnapshots.clear();
    _cacheHits.clear();
    _cacheMisses.clear();
    _queryTimes.clear();
    _queryErrorCounts.clear();
    _subscriptionStartTimes.clear();
    _subscriptionEventCounts.clear();
  }

  /// Start automatic performance monitoring
  Timer? _monitoringTimer;

  void startAutomaticMonitoring({
    Duration interval = const Duration(minutes: 1),
  }) {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(interval, (_) {
      takeMemorySnapshot();

      // Log performance summary in debug mode
      if (kDebugMode) {
        final summary = _getPerformanceSummary();
        print('Avatar Performance Summary: $summary');
      }
    });
  }

  void stopAutomaticMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  void dispose() {
    stopAutomaticMonitoring();
    clearPerformanceData();
  }
}

/// Internal memory snapshot class
class _MemorySnapshot {
  final DateTime timestamp;
  final int heapUsage;
  final int cacheSize;

  _MemorySnapshot({
    required this.timestamp,
    required this.heapUsage,
    required this.cacheSize,
  });
}
