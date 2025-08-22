import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/widgets/error_widgets.dart';

void main() {
  group('Error Widgets', () {
    group('AvatarNotFoundWidget', () {
      testWidgets('should display avatar not found message', (tester) async {
        bool retryCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarNotFoundWidget(
                message: 'Test avatar not found',
                onRetry: () => retryCallbackCalled = true,
              ),
            ),
          ),
        );

        expect(find.text('Avatar Not Found'), findsOneWidget);
        expect(find.text('Test avatar not found'), findsOneWidget);
        expect(find.byIcon(Icons.person_off), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Test retry callback
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(retryCallbackCalled, isTrue);
      });
    });

    group('PermissionDeniedWidget', () {
      testWidgets('should display permission denied message', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PermissionDeniedWidget(
                message: 'Access denied to this avatar',
              ),
            ),
          ),
        );

        expect(find.text('Access Denied'), findsOneWidget);
        expect(find.text('Access denied to this avatar'), findsOneWidget);
        expect(find.byIcon(Icons.lock), findsOneWidget);
      });
    });

    group('NetworkErrorWidget', () {
      testWidgets('should display network error message', (tester) async {
        bool retryCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NetworkErrorWidget(
                message: 'Network connection failed',
                onRetry: () => retryCallbackCalled = true,
              ),
            ),
          ),
        );

        expect(find.text('Connection Error'), findsOneWidget);
        expect(find.text('Network connection failed'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Test retry callback
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(retryCallbackCalled, isTrue);
      });
    });

    group('CacheErrorWidget', () {
      testWidgets('should display cache error with refresh option', (
        tester,
      ) async {
        bool refreshCallbackCalled = false;
        bool retryCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CacheErrorWidget(
                message: 'Cache loading failed',
                onRefresh: () => refreshCallbackCalled = true,
                onRetry: () => retryCallbackCalled = true,
              ),
            ),
          ),
        );

        expect(find.text('Data Loading Issue'), findsOneWidget);
        expect(find.text('Cache loading failed'), findsOneWidget);
        expect(find.byIcon(Icons.cached), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);

        // Test refresh callback
        await tester.tap(find.text('Refresh'));
        await tester.pump();
        expect(refreshCallbackCalled, isTrue);

        // Test retry callback
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(retryCallbackCalled, isTrue);
      });
    });

    group('StateSyncErrorWidget', () {
      testWidgets('should display state sync error', (tester) async {
        bool refreshCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StateSyncErrorWidget(
                message: 'State synchronization failed',
                onRefresh: () => refreshCallbackCalled = true,
              ),
            ),
          ),
        );

        expect(find.text('Sync Error'), findsOneWidget);
        expect(find.text('State synchronization failed'), findsOneWidget);
        expect(find.byIcon(Icons.sync_problem), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);

        // Test refresh callback
        await tester.tap(find.text('Refresh'));
        await tester.pump();
        expect(refreshCallbackCalled, isTrue);
      });
    });

    group('DatabaseErrorWidget', () {
      testWidgets('should display database error', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DatabaseErrorWidget(message: 'Database connection failed'),
            ),
          ),
        );

        expect(find.text('Server Error'), findsOneWidget);
        expect(find.text('Database connection failed'), findsOneWidget);
        expect(find.byIcon(Icons.storage), findsOneWidget);
      });
    });

    group('AuthenticationRequiredWidget', () {
      testWidgets('should display authentication required message', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthenticationRequiredWidget(
                message: 'Please log in to continue',
              ),
            ),
            routes: {
              '/login': (context) => const Scaffold(body: Text('Login Screen')),
            },
          ),
        );

        expect(find.text('Login Required'), findsOneWidget);
        expect(find.text('Please log in to continue'), findsOneWidget);
        expect(find.byIcon(Icons.login), findsAtLeastNWidgets(1));
        expect(find.text('Login'), findsOneWidget);

        // Test login navigation
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();
        expect(find.text('Login Screen'), findsOneWidget);
      });
    });

    group('AvatarOwnershipErrorWidget', () {
      testWidgets('should display avatar ownership error', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarOwnershipErrorWidget(
                message: 'You do not own this avatar',
              ),
            ),
          ),
        );

        expect(find.text('Ownership Error'), findsOneWidget);
        expect(find.text('You do not own this avatar'), findsOneWidget);
        expect(find.byIcon(Icons.person_remove), findsOneWidget);
      });
    });

    group('InvalidAvatarDataWidget', () {
      testWidgets('should display invalid data error', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InvalidAvatarDataWidget(
                message: 'Avatar data is corrupted',
              ),
            ),
          ),
        );

        expect(find.text('Invalid Data'), findsOneWidget);
        expect(find.text('Avatar data is corrupted'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });
    });

    group('RateLimitErrorWidget', () {
      testWidgets('should display rate limit error', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RateLimitErrorWidget(message: 'Too many requests'),
            ),
          ),
        );

        expect(find.text('Rate Limited'), findsOneWidget);
        expect(find.text('Too many requests'), findsOneWidget);
        expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      });
    });

    group('GenericErrorWidget', () {
      testWidgets('should display generic error', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenericErrorWidget(
                message: 'Something unexpected happened',
              ),
            ),
          ),
        );

        expect(find.text('Something Went Wrong'), findsOneWidget);
        expect(find.text('Something unexpected happened'), findsOneWidget);
        expect(find.byIcon(Icons.error), findsOneWidget);
      });
    });

    group('CompactErrorWidget', () {
      testWidgets('should display compact error', (tester) async {
        bool retryCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CompactErrorWidget(
                message: 'Compact error message',
                onRetry: () => retryCallbackCalled = true,
                icon: Icons.warning,
              ),
            ),
          ),
        );

        expect(find.text('Compact error message'), findsOneWidget);
        expect(find.byIcon(Icons.warning), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        // Test retry callback
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pump();
        expect(retryCallbackCalled, isTrue);
      });

      testWidgets('should use default icon when none provided', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CompactErrorWidget(message: 'Compact error message'),
            ),
          ),
        );

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('should not show retry button when callback is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CompactErrorWidget(message: 'Compact error message'),
            ),
          ),
        );

        expect(find.byIcon(Icons.refresh), findsNothing);
      });
    });

    group('ErrorBannerWidget', () {
      testWidgets('should display error banner', (tester) async {
        bool dismissCallbackCalled = false;
        bool retryCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorBannerWidget(
                message: 'Banner error message',
                onDismiss: () => dismissCallbackCalled = true,
                onRetry: () => retryCallbackCalled = true,
                isVisible: true,
              ),
            ),
          ),
        );

        expect(find.text('Banner error message'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Test retry callback
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(retryCallbackCalled, isTrue);

        // Test dismiss callback
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(dismissCallbackCalled, isTrue);
      });

      testWidgets('should not display when not visible', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorBannerWidget(
                message: 'Banner error message',
                isVisible: false,
              ),
            ),
          ),
        );

        expect(find.text('Banner error message'), findsNothing);
      });

      testWidgets('should not show retry button when callback is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorBannerWidget(
                message: 'Banner error message',
                isVisible: true,
              ),
            ),
          ),
        );

        expect(find.text('Retry'), findsNothing);
      });

      testWidgets('should not show dismiss button when callback is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorBannerWidget(
                message: 'Banner error message',
                isVisible: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.close), findsNothing);
      });
    });

    group('Widget Styling', () {
      testWidgets('should apply theme colors correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                error: Colors.red,
                onSurface: Colors.black,
              ),
            ),
            home: Scaffold(body: GenericErrorWidget(message: 'Test error')),
          ),
        );

        // Find the error icon and verify it uses the error color
        final iconFinder = find.byIcon(Icons.error);
        expect(iconFinder, findsOneWidget);

        final Icon icon = tester.widget(iconFinder);
        expect(icon.color, Colors.red);
      });
    });
  });
}
