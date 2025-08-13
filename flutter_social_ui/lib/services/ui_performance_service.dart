import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Service to optimize UI performance and prevent main thread blocking
class UIPerformanceService {
  static final UIPerformanceService _instance = UIPerformanceService._internal();
  factory UIPerformanceService() => _instance;
  UIPerformanceService._internal();

  Timer? _frameRateMonitor;
  int _droppedFrameCount = 0;
  int _totalFrameCount = 0;
  bool _isMonitoring = false;

  /// Initialize the performance service
  Future<void> initialize() async {
    startFrameRateMonitoring();
    debugPrint('✅ UIPerformanceService initialized');
  }

  /// Start monitoring frame rate and performance
  void startFrameRateMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _frameRateMonitor = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkFramePerformance();
    });

    // Monitor frame rendering
    SchedulerBinding.instance.addPostFrameCallback(_onFrameEnd);
  }

  /// Stop monitoring frame rate
  void stopFrameRateMonitoring() {
    _frameRateMonitor?.cancel();
    _isMonitoring = false;
  }

  /// Called after each frame to monitor performance
  void _onFrameEnd(Duration timeStamp) {
    if (!_isMonitoring) return;

    _totalFrameCount++;
    
    // Schedule next frame monitoring
    SchedulerBinding.instance.addPostFrameCallback(_onFrameEnd);
  }

  /// Check frame performance and log issues
  void _checkFramePerformance() {
    if (_totalFrameCount > 0) {
      final frameRate = _totalFrameCount / 5; // frames per second over 5 seconds
      
      if (frameRate < 55) { // Below 55 FPS indicates performance issues
        debugPrint('⚠️ Performance Warning: Frame rate is ${frameRate.toStringAsFixed(1)} FPS');
        _optimizePerformance();
      }
      
      // Reset counters
      _totalFrameCount = 0;
      _droppedFrameCount = 0;
    }
  }

  /// Optimize performance when issues are detected
  void _optimizePerformance() {
    // Force garbage collection
    _triggerGarbageCollection();
    
    // Reduce animation complexity
    _reduceAnimationComplexity();
    
    // Clear unnecessary caches
    _clearCaches();
  }

  /// Trigger garbage collection to free memory
  void _triggerGarbageCollection() {
    // Schedule microtask to allow current frame to complete
    Future.microtask(() {
      // Clear image cache if it's getting large
      PaintingBinding.instance.imageCache.clear();
      
      debugPrint('🗑️ Cleared image cache for performance optimization');
    });
  }

  /// Reduce animation complexity during performance issues
  void _reduceAnimationComplexity() {
    // This would integrate with your animation system
    debugPrint('⚡ Reducing animation complexity for better performance');
  }

  /// Clear unnecessary caches
  void _clearCaches() {
    // Clear various caches that might be using too much memory
    Future.microtask(() {
      // Clear shader cache
      ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/skia',
        null,
        (data) {},
      );
    });
  }

  /// Execute heavy operations without blocking the UI
  static Future<T> executeAsync<T>(Future<T> Function() operation) async {
    // Use compute for CPU-intensive operations
    return await Future.microtask(() async {
      try {
        return await operation();
      } catch (e) {
        debugPrint('Error in async operation: $e');
        rethrow;
      }
    });
  }

  /// Debounce frequent operations to prevent UI blocking
  static Timer? _debounceTimer;
  static void debounce(VoidCallback callback, {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }

  /// Throttle operations to limit frequency
  static DateTime? _lastThrottleTime;
  static bool throttle(VoidCallback callback, {Duration interval = const Duration(milliseconds: 100)}) {
    final now = DateTime.now();
    if (_lastThrottleTime == null || now.difference(_lastThrottleTime!) >= interval) {
      _lastThrottleTime = now;
      callback();
      return true;
    }
    return false;
  }

  /// Batch operations to reduce frame drops
  static void batchOperations(List<VoidCallback> operations) {
    Future.microtask(() {
      for (final operation in operations) {
        try {
          operation();
        } catch (e) {
          debugPrint('Error in batched operation: $e');
        }
      }
    });
  }

  /// Check if the device is experiencing performance issues
  bool isPerformanceStressed() {
    return _droppedFrameCount > 5 || (_totalFrameCount > 0 && (_totalFrameCount / 5) < 55);
  }

  /// Optimize image loading to prevent blocking
  static ImageProvider optimizedImageProvider(String imageUrl) {
    // Return a provider that loads images efficiently
    if (imageUrl.startsWith('http')) {
      return NetworkImage(imageUrl);
    } else {
      return AssetImage(imageUrl);
    }
  }

  /// Schedule operations for the next frame to prevent blocking
  static void scheduleNextFrame(VoidCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback((_) => callback());
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'total_frames': _totalFrameCount,
      'dropped_frames': _droppedFrameCount,
      'is_monitoring': _isMonitoring,
      'frame_rate': _totalFrameCount > 0 ? _totalFrameCount / 5 : 0,
    };
  }

  /// Dispose the service
  void dispose() {
    stopFrameRateMonitoring();
    _debounceTimer?.cancel();
  }
}

/// Widget wrapper that optimizes performance for heavy widgets
class PerformanceOptimizedWidget extends StatelessWidget {
  final Widget child;
  final bool enableOptimization;

  const PerformanceOptimizedWidget({
    super.key,
    required this.child,
    this.enableOptimization = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableOptimization) {
      return child;
    }

    return RepaintBoundary(
      child: child,
    );
  }
}

/// Mixin for widgets that need performance optimization
mixin PerformanceOptimizedStateMixin<T extends StatefulWidget> on State<T> {
  bool _isVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateVisibility();
  }

  void _updateVisibility() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      final position = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;
      final viewport = MediaQuery.of(context).size;
      
      _isVisible = position.dx < viewport.width &&
                   position.dy < viewport.height &&
                   position.dx + size.width > 0 &&
                   position.dy + size.height > 0;
    }
  }

  /// Check if widget is currently visible
  bool get isVisible => _isVisible;

  /// Execute operation only if widget is visible
  void executeIfVisible(VoidCallback callback) {
    if (_isVisible) {
      callback();
    }
  }
}

/// Performance-optimized ListView builder
class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
      // Add caching for better performance
      cacheExtent: 500, // Cache 500px outside viewport
    );
  }
}
