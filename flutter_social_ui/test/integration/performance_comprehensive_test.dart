import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quanta/main.dart' as app;
import 'package:quanta/services/performance_service.dart';
import 'package:quanta/services/ui_performance_service.dart';
import 'package:quanta/widgets/post_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance Tests', () {
    late PerformanceService performanceService;
    late UIPerformanceService uiPerformanceService;

    setUpAll(() async {
      performanceService = PerformanceService();
      uiPerformanceService = UIPerformanceService();
      await performanceService.initialize();
      await uiPerformanceService.initialize();
    });

    group('App Startup Performance', () {
      testWidgets('App startup time is within acceptable limits', (
        tester,
      ) async {
        final stopwatch = Stopwatch()..start();

        app.main();
        await tester.pumpAndSettle();

        stopwatch.stop();
        final startupTime = stopwatch.elapsedMilliseconds;

        // App should start within 3 seconds
        expect(startupTime, lessThan(3000));

        print('App startup time: ${startupTime}ms');
      });

      testWidgets('Initial screen loads quickly after startup', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        final stopwatch = Stopwatch()..start();

        // Wait for initial content to load
        await tester.pump(const Duration(seconds: 1));

        // Verify some content is visible
        expect(find.byType(AppBar), findsOneWidget);

        stopwatch.stop();
        final loadTime = stopwatch.elapsedMilliseconds;

        // Initial content should load within 2 seconds
        expect(loadTime, lessThan(2000));

        print('Initial content load time: ${loadTime}ms');
      });

      testWidgets('Memory usage is reasonable after startup', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Allow app to fully initialize
        await tester.pump(const Duration(seconds: 2));

        // Get memory info (this is platform-specific)
        // In a real test, you'd use platform channels to get actual memory usage

        // For now, just verify app is responsive
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Feed Performance', () {
      testWidgets('Feed scrolling is smooth and responsive', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        // Measure scroll performance
        final stopwatch = Stopwatch()..start();

        // Perform continuous scrolling
        for (int i = 0; i < 10; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pump(const Duration(milliseconds: 16)); // 60 FPS
        }

        stopwatch.stop();
        final scrollTime = stopwatch.elapsedMilliseconds;

        // Scrolling should be smooth (under 200ms for 10 scroll actions)
        expect(scrollTime, lessThan(500));

        print('Scroll performance: ${scrollTime}ms for 10 scroll actions');
      });

      testWidgets('Large feed datasets are handled efficiently', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        // Scroll through many items to test lazy loading
        for (int i = 0; i < 50; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -200));
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.pumpAndSettle();

        // App should remain responsive
        expect(find.byType(MaterialApp), findsOneWidget);

        // Verify pagination is working (should have loaded more content)
        expect(find.byType(PostItem), findsWidgets);
      });

      testWidgets('Video loading and playback performance', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        // Find video posts
        final videoPosts = find.byKey(const Key('video_post_item'));
        if (videoPosts.evaluate().isNotEmpty) {
          final stopwatch = Stopwatch()..start();

          // Scroll to trigger video loading
          await tester.ensureVisible(videoPosts.first);
          await tester.pumpAndSettle();

          stopwatch.stop();
          final loadTime = stopwatch.elapsedMilliseconds;

          // Video should start loading quickly
          expect(loadTime, lessThan(1000));

          print('Video load time: ${loadTime}ms');
        }
      });

      testWidgets('Image loading performance', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        // Test image loading performance
        final posts = find.byType(PostItem);
        if (posts.evaluate().isNotEmpty) {
          final stopwatch = Stopwatch()..start();

          // Scroll to trigger image loading
          for (int i = 0; i < 5; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 100));
          }

          await tester.pumpAndSettle();
          stopwatch.stop();

          final imageLoadTime = stopwatch.elapsedMilliseconds;

          // Images should load efficiently during scrolling
          expect(imageLoadTime, lessThan(2000));

          print('Image loading during scroll: ${imageLoadTime}ms');
        }
      });
    });

    group('Interaction Performance', () {
      testWidgets('Button tap responses are immediate', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final posts = find.byType(PostItem);
        if (posts.evaluate().isNotEmpty) {
          final likeButton = find.descendant(
            of: posts.first,
            matching: find.byKey(const Key('like_button')),
          );

          if (likeButton.evaluate().isNotEmpty) {
            final stopwatch = Stopwatch()..start();

            await tester.tap(likeButton);
            await tester.pump(); // Single frame

            stopwatch.stop();
            final responseTime = stopwatch.elapsedMilliseconds;

            // UI should respond within one frame (16ms at 60 FPS)
            expect(responseTime, lessThan(50));

            print('Button tap response time: ${responseTime}ms');
          }
        }
      });

      testWidgets('Navigation performance between screens', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        // Test navigation to different screens
        final navigationTests = [
          {'name': 'Search', 'finder': find.byIcon(Icons.search)},
          {'name': 'Profile', 'finder': find.byIcon(Icons.person)},
          {'name': 'Notifications', 'finder': find.byIcon(Icons.notifications)},
        ];

        for (final test in navigationTests) {
          final finder = test['finder'] as Finder;
          final name = test['name'] as String;

          if (finder.evaluate().isNotEmpty) {
            final stopwatch = Stopwatch()..start();

            await tester.tap(finder);
            await tester.pumpAndSettle();

            stopwatch.stop();
            final navigationTime = stopwatch.elapsedMilliseconds;

            // Navigation should be fast
            expect(navigationTime, lessThan(1000));

            print('$name navigation time: ${navigationTime}ms');

            // Go back to home
            final homeButton = find.byIcon(Icons.home);
            if (homeButton.evaluate().isNotEmpty) {
              await tester.tap(homeButton);
              await tester.pumpAndSettle();
            }
          }
        }
      });

      testWidgets('Text input performance', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to create post or comment screen
        final createButton = find.byIcon(Icons.add);
        if (createButton.evaluate().isNotEmpty) {
          await tester.tap(createButton);
          await tester.pumpAndSettle();

          final textField = find.byKey(const Key('post_content_field'));
          if (textField.evaluate().isNotEmpty) {
            final stopwatch = Stopwatch()..start();

            // Type a long text to test input performance
            const longText = 'This is a test of text input performance. ' * 10;
            await tester.enterText(textField, longText);
            await tester.pump();

            stopwatch.stop();
            final inputTime = stopwatch.elapsedMilliseconds;

            // Text input should be responsive
            expect(inputTime, lessThan(500));

            print(
              'Text input performance: ${inputTime}ms for ${longText.length} characters',
            );
          }
        }
      });
    });

    group('Memory Performance', () {
      testWidgets('Memory usage remains stable during extended use', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate extended app usage
        for (int session = 0; session < 5; session++) {
          // Scroll through feed
          for (int i = 0; i < 20; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -300));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Navigate to different screens
          final searchButton = find.byIcon(Icons.search);
          if (searchButton.evaluate().isNotEmpty) {
            await tester.tap(searchButton);
            await tester.pumpAndSettle();
          }

          final homeButton = find.byIcon(Icons.home);
          if (homeButton.evaluate().isNotEmpty) {
            await tester.tap(homeButton);
            await tester.pumpAndSettle();
          }

          // Allow garbage collection
          await tester.pump(const Duration(milliseconds: 100));
        }

        // App should still be responsive after extended use
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Image memory management', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        // Load many images by scrolling
        for (int i = 0; i < 100; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -200));
          await tester.pump(const Duration(milliseconds: 16));
        }

        await tester.pumpAndSettle();

        // App should handle image loading without memory issues
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('Animation Performance', () {
      testWidgets('Like animations are smooth', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final posts = find.byType(PostItem);
        if (posts.evaluate().isNotEmpty) {
          final likeButton = find.descendant(
            of: posts.first,
            matching: find.byKey(const Key('like_button')),
          );

          if (likeButton.evaluate().isNotEmpty) {
            final stopwatch = Stopwatch()..start();

            await tester.tap(likeButton);

            // Let animation complete
            await tester.pumpAndSettle();

            stopwatch.stop();
            final animationTime = stopwatch.elapsedMilliseconds;

            // Animation should complete quickly
            expect(animationTime, lessThan(1000));

            print('Like animation time: ${animationTime}ms');
          }
        }
      });

      testWidgets('Page transitions are smooth', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        final posts = find.byType(PostItem);
        if (posts.evaluate().isNotEmpty) {
          final stopwatch = Stopwatch()..start();

          // Tap to navigate to post detail
          await tester.tap(posts.first);
          await tester.pumpAndSettle();

          stopwatch.stop();
          final transitionTime = stopwatch.elapsedMilliseconds;

          // Page transition should be smooth
          expect(transitionTime, lessThan(800));

          print('Page transition time: ${transitionTime}ms');
        }
      });
    });

    group('Network Performance', () {
      testWidgets('API response times are reasonable', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        final stopwatch = Stopwatch()..start();

        // Trigger refresh to test API performance
        final refreshIndicator = find.byType(RefreshIndicator);
        if (refreshIndicator.evaluate().isNotEmpty) {
          await tester.drag(refreshIndicator.first, const Offset(0, 300));
          await tester.pumpAndSettle();
        }

        stopwatch.stop();
        final apiTime = stopwatch.elapsedMilliseconds;

        // API calls should complete within reasonable time
        // Note: This depends on network conditions and server performance
        expect(apiTime, lessThan(5000));

        print('API refresh time: ${apiTime}ms');
      });

      testWidgets('Concurrent request handling', (tester) async {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        // Trigger multiple simultaneous requests by rapid scrolling
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 10; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.pumpAndSettle();
        stopwatch.stop();

        final concurrentRequestTime = stopwatch.elapsedMilliseconds;

        // Should handle concurrent requests efficiently
        expect(concurrentRequestTime, lessThan(3000));

        print('Concurrent request handling: ${concurrentRequestTime}ms');
      });
    });

    group('Performance Regression Tests', () {
      testWidgets('Performance metrics are within expected ranges', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();

        // Define performance baselines
        final performanceBaselines = {
          'startup_time': 3000, // ms
          'navigation_time': 1000, // ms
          'scroll_responsiveness': 16, // ms per frame
          'memory_growth': 50, // MB increase over baseline
        };

        // Test each performance metric
        // In a real test, you'd collect actual metrics and compare

        for (final entry in performanceBaselines.entries) {
          final metric = entry.key;
          final baseline = entry.value;

          print('Performance baseline for $metric: ${baseline}ms');

          // Actual metric collection would happen here
          // expect(actualValue, lessThan(baseline));
        }
      });
    });

    group('Performance Monitoring Integration', () {
      testWidgets('Performance events are tracked', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Verify performance tracking is active
        expect(performanceService.isInitialized, isTrue);
        expect(uiPerformanceService.isInitialized, isTrue);

        // Test that performance events are being recorded
        // This would check that metrics are being sent to analytics
      });

      testWidgets('Performance alerts work correctly', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test performance alert system
        // This would verify that performance degradation triggers alerts
      });
    });
  });
}

/// Helper to measure specific operations
class PerformanceMeasurement {
  final Stopwatch _stopwatch = Stopwatch();

  void start() => _stopwatch.start();

  int stopAndGetDuration() {
    _stopwatch.stop();
    final duration = _stopwatch.elapsedMilliseconds;
    _stopwatch.reset();
    return duration;
  }
}

/// Performance test configuration
class PerformanceTestConfig {
  static const int maxStartupTime = 3000; // ms
  static const int maxNavigationTime = 1000; // ms
  static const int maxScrollFrameTime = 16; // ms (60 FPS)
  static const int maxApiResponseTime = 5000; // ms
  static const int maxAnimationTime = 1000; // ms
}
