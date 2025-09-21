import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/avatar_profile_error_handler.dart';
import '../../lib/widgets/error_widgets.dart';

void main() {
  group('AvatarProfileErrorHandler', () {
    late AvatarProfileErrorHandler errorHandler;

    setUp(() {
      errorHandler = AvatarProfileErrorHandler();
    });

    group('Exception Creation', () {
      test('should create avatar not found exception', () {
        final exception = AvatarProfileErrorHandler.avatarNotFound('test-id');

        expect(exception.type, AvatarProfileErrorType.avatarNotFound);
        expect(exception.message, contains('test-id'));
        expect(exception.message, contains('not found'));
      });

      test('should create permission denied exception', () {
        final exception = AvatarProfileErrorHandler.permissionDenied(
          'test operation',
        );

        expect(exception.type, AvatarProfileErrorType.permissionDenied);
        expect(exception.message, contains('Permission denied'));
        expect(exception.message, contains('test operation'));
      });

      test('should create network error exception', () {
        final exception = AvatarProfileErrorHandler.networkError(
          'test operation',
        );

        expect(exception.type, AvatarProfileErrorType.networkError);
        expect(exception.message, contains('Network error'));
        expect(exception.message, contains('test operation'));
      });

      test('should create cache error exception', () {
        final exception = AvatarProfileErrorHandler.cacheError(
          'test operation',
        );

        expect(exception.type, AvatarProfileErrorType.cacheError);
        expect(exception.message, contains('Cache error'));
        expect(exception.message, contains('test operation'));
      });

      test('should create state sync error exception', () {
        final exception = AvatarProfileErrorHandler.stateSyncError(
          'test details',
        );

        expect(exception.type, AvatarProfileErrorType.stateSyncError);
        expect(exception.message, contains('State synchronization error'));
        expect(exception.message, contains('test details'));
      });

      test('should create database error exception', () {
        final exception = AvatarProfileErrorHandler.databaseError(
          'test operation',
        );

        expect(exception.type, AvatarProfileErrorType.databaseError);
        expect(exception.message, contains('Database error'));
        expect(exception.message, contains('test operation'));
      });

      test('should create authentication required exception', () {
        final exception = AvatarProfileErrorHandler.authenticationRequired();

        expect(exception.type, AvatarProfileErrorType.authenticationRequired);
        expect(exception.message, contains('Authentication required'));
      });

      test('should create avatar ownership error exception', () {
        final exception = AvatarProfileErrorHandler.avatarOwnershipError(
          'test-id',
        );

        expect(exception.type, AvatarProfileErrorType.avatarOwnershipError);
        expect(exception.message, contains('does not own'));
        expect(exception.message, contains('test-id'));
      });

      test('should create invalid avatar data exception', () {
        final exception = AvatarProfileErrorHandler.invalidAvatarData(
          'test details',
        );

        expect(exception.type, AvatarProfileErrorType.invalidAvatarData);
        expect(exception.message, contains('Invalid avatar data'));
        expect(exception.message, contains('test details'));
      });

      test('should create rate limit exceeded exception', () {
        final exception = AvatarProfileErrorHandler.rateLimitExceeded();

        expect(exception.type, AvatarProfileErrorType.rateLimitExceeded);
        expect(exception.message, contains('Rate limit exceeded'));
      });
    });

    group('Error Widget Handling', () {
      testWidgets('should handle avatar not found error', (tester) async {
        final exception = AvatarProfileErrorHandler.avatarNotFound('test-id');
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<AvatarNotFoundWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Avatar Not Found'), findsOneWidget);
      });

      testWidgets('should handle permission denied error', (tester) async {
        final exception = AvatarProfileErrorHandler.permissionDenied(
          'test operation',
        );
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<PermissionDeniedWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Access Denied'), findsOneWidget);
      });

      testWidgets('should handle network error', (tester) async {
        final exception = AvatarProfileErrorHandler.networkError(
          'test operation',
        );
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<NetworkErrorWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Connection Error'), findsOneWidget);
      });

      testWidgets('should handle cache error', (tester) async {
        final exception = AvatarProfileErrorHandler.cacheError(
          'test operation',
        );
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<CacheErrorWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Data Loading Issue'), findsOneWidget);
      });

      testWidgets('should handle state sync error', (tester) async {
        final exception = AvatarProfileErrorHandler.stateSyncError(
          'test details',
        );
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<StateSyncErrorWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Sync Error'), findsOneWidget);
      });

      testWidgets('should handle database error', (tester) async {
        final exception = AvatarProfileErrorHandler.databaseError(
          'test operation',
        );
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<DatabaseErrorWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Server Error'), findsOneWidget);
      });

      testWidgets('should handle authentication required error', (
        tester,
      ) async {
        final exception = AvatarProfileErrorHandler.authenticationRequired();
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<AuthenticationRequiredWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Login Required'), findsOneWidget);
      });

      testWidgets('should handle avatar ownership error', (tester) async {
        final exception = AvatarProfileErrorHandler.avatarOwnershipError(
          'test-id',
        );
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<AvatarOwnershipErrorWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Ownership Error'), findsOneWidget);
      });

      testWidgets('should handle invalid avatar data error', (tester) async {
        final exception = AvatarProfileErrorHandler.invalidAvatarData(
          'test details',
        );
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<InvalidAvatarDataWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Invalid Data'), findsOneWidget);
      });

      testWidgets('should handle rate limit error', (tester) async {
        final exception = AvatarProfileErrorHandler.rateLimitExceeded();
        final widget = errorHandler.handleError(exception);

        expect(widget, isA<RateLimitErrorWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Rate Limited'), findsOneWidget);
      });

      testWidgets('should handle generic error', (tester) async {
        final widget = errorHandler.handleError(Exception('Generic error'));

        expect(widget, isA<GenericErrorWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Something Went Wrong'), findsOneWidget);
      });

      testWidgets('should handle format exception', (tester) async {
        final widget = errorHandler.handleError(
          const FormatException('Invalid format'),
        );

        expect(widget, isA<InvalidAvatarDataWidget>());

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        expect(find.text('Invalid Data'), findsOneWidget);
      });
    });

    group('Error Recovery', () {
      test('should identify recoverable errors', () {
        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.networkError('test'),
          ),
          isTrue,
        );

        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.cacheError('test'),
          ),
          isTrue,
        );

        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.stateSyncError('test'),
          ),
          isTrue,
        );

        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.databaseError('test'),
          ),
          isTrue,
        );

        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.rateLimitExceeded(),
          ),
          isTrue,
        );
      });

      test('should identify non-recoverable errors', () {
        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.avatarNotFound('test'),
          ),
          isFalse,
        );

        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.permissionDenied('test'),
          ),
          isFalse,
        );

        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.authenticationRequired(),
          ),
          isFalse,
        );

        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.avatarOwnershipError('test'),
          ),
          isFalse,
        );

        expect(
          errorHandler.isRecoverableError(
            AvatarProfileErrorHandler.invalidAvatarData('test'),
          ),
          isFalse,
        );
      });

      test('should assume generic errors are recoverable', () {
        expect(errorHandler.isRecoverableError(Exception('Generic')), isTrue);
        expect(errorHandler.isRecoverableError('String error'), isTrue);
      });
    });

    group('User-Friendly Messages', () {
      test('should provide user-friendly message for avatar not found', () {
        final exception = AvatarProfileErrorHandler.avatarNotFound('test');
        final message = errorHandler.getUserFriendlyMessage(exception);

        expect(message, contains('could not be found'));
        expect(message, contains('deleted or moved'));
      });

      test('should provide user-friendly message for permission denied', () {
        final exception = AvatarProfileErrorHandler.permissionDenied('test');
        final message = errorHandler.getUserFriendlyMessage(exception);

        expect(message, contains('don\'t have permission'));
      });

      test('should provide user-friendly message for network error', () {
        final exception = AvatarProfileErrorHandler.networkError('test');
        final message = errorHandler.getUserFriendlyMessage(exception);

        expect(message, contains('Network connection'));
        expect(message, contains('internet connection'));
      });

      test('should provide user-friendly message for cache error', () {
        final exception = AvatarProfileErrorHandler.cacheError('test');
        final message = errorHandler.getUserFriendlyMessage(exception);

        expect(message, contains('Data loading issue'));
        expect(message, contains('refreshing'));
      });

      test('should provide user-friendly message for state sync error', () {
        final exception = AvatarProfileErrorHandler.stateSyncError('test');
        final message = errorHandler.getUserFriendlyMessage(exception);

        expect(message, contains('synchronization issue'));
        expect(message, contains('refreshing'));
      });

      test('should provide user-friendly message for database error', () {
        final exception = AvatarProfileErrorHandler.databaseError('test');
        final message = errorHandler.getUserFriendlyMessage(exception);

        expect(message, contains('Server issue'));
        expect(message, contains('try again'));
      });

      test(
        'should provide user-friendly message for authentication required',
        () {
          final exception = AvatarProfileErrorHandler.authenticationRequired();
          final message = errorHandler.getUserFriendlyMessage(exception);

          expect(message, contains('log in'));
        },
      );

      test(
        'should provide user-friendly message for avatar ownership error',
        () {
          final exception = AvatarProfileErrorHandler.avatarOwnershipError(
            'test',
          );
          final message = errorHandler.getUserFriendlyMessage(exception);

          expect(message, contains('your own avatars'));
        },
      );

      test('should provide user-friendly message for invalid avatar data', () {
        final exception = AvatarProfileErrorHandler.invalidAvatarData('test');
        final message = errorHandler.getUserFriendlyMessage(exception);

        expect(message, contains('corrupted or invalid'));
      });

      test('should provide user-friendly message for rate limit exceeded', () {
        final exception = AvatarProfileErrorHandler.rateLimitExceeded();
        final message = errorHandler.getUserFriendlyMessage(exception);

        expect(message, contains('Too many requests'));
        expect(message, contains('wait a moment'));
      });

      test(
        'should provide generic user-friendly message for unknown errors',
        () {
          final message = errorHandler.getUserFriendlyMessage(
            Exception('Unknown'),
          );

          expect(message, contains('unexpected error'));
          expect(message, contains('try again'));
        },
      );
    });

    group('Error Logging', () {
      test('should log errors without throwing', () {
        expect(() => errorHandler.logError('Test error'), returnsNormally);
        expect(
          () => errorHandler.logError(Exception('Test exception')),
          returnsNormally,
        );
        expect(
          () => errorHandler.logError('Test error', context: 'test context'),
          returnsNormally,
        );
      });
    });

    group('Widget Callbacks', () {
      testWidgets('should call retry callback when retry button is pressed', (
        tester,
      ) async {
        bool retryCallbackCalled = false;

        final widget = errorHandler.handleError(
          AvatarProfileErrorHandler.networkError('test'),
          onRetry: () => retryCallbackCalled = true,
        );

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        final retryButton = find.text('Retry');
        expect(retryButton, findsOneWidget);

        await tester.tap(retryButton);
        await tester.pump();

        expect(retryCallbackCalled, isTrue);
      });

      testWidgets(
        'should call refresh callback when refresh button is pressed',
        (tester) async {
          bool refreshCallbackCalled = false;

          final widget = errorHandler.handleError(
            AvatarProfileErrorHandler.cacheError('test'),
            onRefresh: () => refreshCallbackCalled = true,
          );

          await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

          final refreshButton = find.text('Refresh');
          expect(refreshButton, findsOneWidget);

          await tester.tap(refreshButton);
          await tester.pump();

          expect(refreshCallbackCalled, isTrue);
        },
      );
    });
  });
}
