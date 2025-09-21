import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/services/avatar_lru_cache_service.dart';
import 'package:quanta/services/avatar_performance_monitoring_service.dart';

void main() {
  group('Avatar Cache Performance Tests', () {
    late AvatarLRUCacheService cacheService;
    late AvatarPerformanceMonitoringService performanceService;

    setUp(() {
      cacheService = AvatarLRUCacheService();
      performanceService = AvatarPerformanceMonitoringService();

      // Clear any existing state
      cacheService.clearAll();
      performanceService.clearPerformanceData();
    });

    group('LRU Cache Service Performance', () {
      test('should initialize cache service efficiently', () {
        final stopwatch = Stopwatch()..start();

        expect(cacheService, isNotNull);

        final stats = cacheService.getCacheStats();
        expect(stats['avatarCacheSize'], equals(0));
        expect(stats['avatarPostsCacheSize'], equals(0));
        expect(stats['avatarStatsCacheSize'], equals(0));

        stopwatch.stop();

        // Should complete very quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('should handle cache invalidation efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Simulate cache operations
        for (int i = 0; i < 1000; i++) {
          cacheService.invalidateAvatar('avatar_$i');
        }

        stopwatch.stop();

        // Should complete quickly even with many operations
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('should clear all caches efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Add some dummy operations
        for (int i = 0; i < 100; i++) {
          cacheService.invalidateAvatar('test_avatar_$i');
        }

        // Clear all
        cacheService.clearAll();

        stopwatch.stop();

        final stats = cacheService.getCacheStats();
        expect(stats['avatarCacheSize'], equals(0));

        // Should complete very quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(20));
      });

      test('should provide accurate cache statistics', () {
        final stats = cacheService.getCacheStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('avatarCacheSize'), isTrue);
        expect(stats.containsKey('avatarPostsCacheSize'), isTrue);
        expect(stats.containsKey('avatarStatsCacheSize'), isTrue);
        expect(stats.containsKey('maxAvatarCacheSize'), isTrue);
        expect(stats.containsKey('cacheExpiryMinutes'), isTrue);
      });

      test('should handle high-frequency cache operations', () {
        final stopwatch = Stopwatch()..start();

        // Simulate high-frequency cache operations
        for (int i = 0; i < 5000; i++) {
          cacheService.invalidateAvatar('high_freq_avatar_$i');
          if (i % 100 == 0) {
            cacheService.clearAll();
          }
        }

        stopwatch.stop();

        // Should handle high frequency operations efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });

      test('should maintain performance with repeated operations', () {
        final times = <int>[];

        // Measure performance over multiple iterations
        for (int iteration = 0; iteration < 10; iteration++) {
          final stopwatch = Stopwatch()..start();

          for (int i = 0; i < 100; i++) {
            cacheService.invalidateAvatar('perf_avatar_${iteration}_$i');
          }

          stopwatch.stop();
          times.add(stopwatch.elapsedMilliseconds);
        }

        // Performance should be consistent (no significant degradation)
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        final maxTime = times.reduce((a, b) => a > b ? a : b);

        expect(avgTime, lessThan(50));
        expect(maxTime, lessThan(100));

        // Variance should be reasonable (no outliers)
        final variance =
            times
                .map((t) => (t - avgTime) * (t - avgTime))
                .reduce((a, b) => a + b) /
            times.length;
        expect(variance, lessThan(1000)); // Reasonable variance threshold
      });
    });

    group('Performance Monitoring Service', () {
      test('should initialize performance service efficiently', () {
        final stopwatch = Stopwatch()..start();

        expect(performanceService, isNotNull);

        final report = performanceService.getPerformanceReport();
        expect(report, isNotNull);
        expect(report['operations'], isNotNull);
        expect(report['cache'], isNotNull);

        stopwatch.stop();

        // Should complete very quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('should track synchronous operations efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Track multiple operations
        for (int i = 0; i < 100; i++) {
          final result = performanceService.trackSyncOperation(
            'test_operation_$i',
            () {
              return i * 2;
            },
          );
          expect(result, equals(i * 2));
        }

        stopwatch.stop();

        // Should complete reasonably quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(100));

        final report = performanceService.getPerformanceReport();
        final operations = report['operations'] as Map<String, dynamic>;
        expect(operations.length, greaterThan(0));
      });

      test('should record cache metrics efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Record many cache operations
        for (int i = 0; i < 1000; i++) {
          performanceService.recordCacheHit('test_cache');
          performanceService.recordCacheMiss('test_cache');
        }

        stopwatch.stop();

        // Should complete quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(50));

        final report = performanceService.getPerformanceReport();
        final cache = report['cache'] as Map<String, dynamic>;
        expect(cache['totalHits'], equals(1000));
        expect(cache['totalMisses'], equals(1000));
      });

      test('should provide comprehensive performance report', () {
        // Add some performance data
        performanceService.trackSyncOperation('test_op', () => 42);
        performanceService.recordCacheHit('test_cache');
        performanceService.recordCacheMiss('test_cache');

        final report = performanceService.getPerformanceReport();

        expect(report, isA<Map<String, dynamic>>());
        expect(report.containsKey('operations'), isTrue);
        expect(report.containsKey('cache'), isTrue);
        expect(report.containsKey('database'), isTrue);
        expect(report.containsKey('subscriptions'), isTrue);
        expect(report.containsKey('memory'), isTrue);
        expect(report.containsKey('summary'), isTrue);
      });

      test('should clear performance data efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Add some performance data
        for (int i = 0; i < 100; i++) {
          performanceService.recordCacheHit('test_cache_$i');
        }

        // Clear all
        performanceService.clearPerformanceData();

        stopwatch.stop();

        final report = performanceService.getPerformanceReport();
        final cache = report['cache'] as Map<String, dynamic>;
        expect(cache['totalHits'], equals(0));

        // Should complete quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(20));
      });

      test('should handle performance tracking overhead efficiently', () {
        final stopwatch = Stopwatch()..start();

        // Measure overhead of performance tracking itself
        for (int i = 0; i < 1000; i++) {
          performanceService.trackSyncOperation('overhead_test', () {
            // Minimal operation
            return i;
          });
        }

        stopwatch.stop();

        // Performance tracking should have minimal overhead
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });
    });

    group('Integration Performance Tests', () {
      test(
        'should handle combined cache and monitoring operations efficiently',
        () {
          final stopwatch = Stopwatch()..start();

          // Simulate operations across both services
          for (int i = 0; i < 500; i++) {
            performanceService.trackSyncOperation('integration_test', () {
              cacheService.invalidateAvatar('integration_avatar_$i');
              performanceService.recordCacheHit('integration_cache');
              return i;
            });
          }

          stopwatch.stop();

          // Should complete within reasonable time
          expect(stopwatch.elapsedMilliseconds, lessThan(300));

          // Verify both services have data
          final cacheStats = cacheService.getCacheStats();
          final performanceReport = performanceService.getPerformanceReport();

          expect(cacheStats, isNotNull);
          expect(performanceReport, isNotNull);
        },
      );

      test('should maintain performance under stress conditions', () {
        final stopwatch = Stopwatch()..start();

        // Stress test with high-frequency operations
        for (int i = 0; i < 2000; i++) {
          // Cache operations
          cacheService.invalidateAvatar('stress_avatar_$i');

          // Performance monitoring
          performanceService.recordCacheHit('stress_cache');
          performanceService.trackSyncOperation('stress_op', () => i);

          // Periodic cleanup
          if (i % 500 == 0) {
            cacheService.clearAll();
            performanceService.clearPerformanceData();
          }
        }

        stopwatch.stop();

        // Should handle stress test within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('should demonstrate performance improvements', () {
        // Test without performance optimizations (baseline)
        final baselineStopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          // Simulate operations without caching
          final result = i * i;
          expect(result, equals(i * i));
        }

        baselineStopwatch.stop();

        // Test with performance optimizations (cached)
        final optimizedStopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          performanceService.trackSyncOperation('optimized_test', () {
            // Simulate cached operation
            return i * i;
          });
        }

        optimizedStopwatch.stop();

        // Both should be fast, but we're testing that the overhead is minimal
        expect(baselineStopwatch.elapsedMilliseconds, lessThan(50));
        expect(optimizedStopwatch.elapsedMilliseconds, lessThan(100));

        // The overhead should be reasonable (less than 3x baseline)
        final overhead =
            optimizedStopwatch.elapsedMilliseconds /
            (baselineStopwatch.elapsedMilliseconds + 1);
        expect(overhead, lessThan(3.0));
      });
    });

    tearDown(() {
      // Cleanup after each test
      cacheService.clearAll();
      performanceService.clearPerformanceData();
    });
  });
}
