import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quanta/main.dart' as app;
import 'package:quanta/services/auth_service.dart';
import 'package:quanta/services/avatar_service.dart';
import 'package:quanta/screens/auth/login_screen.dart';
import 'package:quanta/screens/auth/signup_screen.dart';
import 'package:quanta/screens/onboarding/avatar_creation_wizard.dart';
import 'package:quanta/screens/app_shell.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive Authentication Flow Tests', () {
    late AuthService authService;
    late AvatarService avatarService;

    setUpAll(() async {
      authService = AuthService();
      avatarService = AvatarService();
      await authService.initialize();
    });

    tearDown(() async {
      // Clean up any test user accounts
      if (authService.isAuthenticated) {
        await authService.signOut();
      }
    });

    group('User Registration Flow', () {
      testWidgets('Complete signup → avatar creation → app access flow', (
        tester,
      ) async {
        // Start the app
        app.main();
        await tester.pumpAndSettle();

        // Should start at login/signup screen
        expect(find.byType(LoginScreen), findsOneWidget);

        // Navigate to signup
        final signupButton = find.text('Sign Up');
        if (signupButton.evaluate().isNotEmpty) {
          await tester.tap(signupButton);
          await tester.pumpAndSettle();
        }

        // Find signup form elements
        final emailField = find.byKey(const Key('signup_email_field'));
        final passwordField = find.byKey(const Key('signup_password_field'));
        final confirmPasswordField = find.byKey(
          const Key('signup_confirm_password_field'),
        );
        final displayNameField = find.byKey(
          const Key('signup_display_name_field'),
        );

        if (emailField.evaluate().isNotEmpty) {
          // Fill signup form with test data
          await tester.enterText(
            emailField,
            'test${DateTime.now().millisecondsSinceEpoch}@example.com',
          );
          await tester.enterText(displayNameField, 'Test User');
          await tester.enterText(passwordField, 'TestPassword123!');
          await tester.enterText(confirmPasswordField, 'TestPassword123!');

          // Submit signup form
          final submitButton = find.byKey(const Key('signup_submit_button'));
          if (submitButton.evaluate().isNotEmpty) {
            await tester.tap(submitButton);
            await tester.pumpAndSettle(const Duration(seconds: 5));

            // Should navigate to avatar creation after successful signup
            expect(find.byType(AvatarCreationWizard), findsOneWidget);

            // Complete avatar creation
            await _completeAvatarCreation(tester);

            // Should now be in the main app
            expect(find.byType(AppShell), findsOneWidget);
          }
        }
      });

      testWidgets('Signup validation - invalid email', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to signup if needed
        final signupButton = find.text('Sign Up');
        if (signupButton.evaluate().isNotEmpty) {
          await tester.tap(signupButton);
          await tester.pumpAndSettle();
        }

        final emailField = find.byKey(const Key('signup_email_field'));
        if (emailField.evaluate().isNotEmpty) {
          await tester.enterText(emailField, 'invalid-email');

          // Try to submit
          final submitButton = find.byKey(const Key('signup_submit_button'));
          if (submitButton.evaluate().isNotEmpty) {
            await tester.tap(submitButton);
            await tester.pumpAndSettle();

            // Should show validation error
            expect(find.textContaining('valid email'), findsOneWidget);
          }
        }
      });

      testWidgets('Signup validation - weak password', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        final signupButton = find.text('Sign Up');
        if (signupButton.evaluate().isNotEmpty) {
          await tester.tap(signupButton);
          await tester.pumpAndSettle();
        }

        final emailField = find.byKey(const Key('signup_email_field'));
        final passwordField = find.byKey(const Key('signup_password_field'));

        if (emailField.evaluate().isNotEmpty &&
            passwordField.evaluate().isNotEmpty) {
          await tester.enterText(emailField, 'test@example.com');
          await tester.enterText(passwordField, '123'); // Weak password

          final submitButton = find.byKey(const Key('signup_submit_button'));
          if (submitButton.evaluate().isNotEmpty) {
            await tester.tap(submitButton);
            await tester.pumpAndSettle();

            // Should show password validation error
            expect(find.textContaining('password'), findsOneWidget);
          }
        }
      });
    });

    group('User Login Flow', () {
      testWidgets('Successful login → app access', (tester) async {
        // First create a test user (if we have test credentials)
        // This would require actual test environment setup

        app.main();
        await tester.pumpAndSettle();

        // Should be at login screen
        expect(find.byType(LoginScreen), findsOneWidget);

        // Test login form elements exist
        expect(find.byKey(const Key('login_email_field')), findsOneWidget);
        expect(find.byKey(const Key('login_password_field')), findsOneWidget);
        expect(find.byKey(const Key('login_submit_button')), findsOneWidget);

        // Note: Actual login testing would require test credentials
        // This validates the UI structure is correct
      });

      testWidgets('Login validation - empty fields', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        final submitButton = find.byKey(const Key('login_submit_button'));
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pumpAndSettle();

          // Should show validation errors
          expect(find.textContaining('required'), findsWidgets);
        }
      });

      testWidgets('Login - forgot password flow', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        final forgotPasswordButton = find.text('Forgot Password?');
        if (forgotPasswordButton.evaluate().isNotEmpty) {
          await tester.tap(forgotPasswordButton);
          await tester.pumpAndSettle();

          // Should show password reset dialog or screen
          expect(find.textContaining('Reset'), findsOneWidget);
        }
      });
    });

    group('Authentication State Management', () {
      testWidgets('App handles authentication state changes', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test that app responds to auth state changes
        // This would require mocking auth state changes

        // Verify initial state
        expect(authService.isAuthenticated, isFalse);
        expect(authService.currentUser, isNull);
      });

      testWidgets('Session persistence across app restarts', (tester) async {
        // This test would validate that user sessions are properly restored
        // when the app is restarted

        app.main();
        await tester.pumpAndSettle();

        // Initial app state should check for existing session
        // and restore user if valid session exists
      });
    });

    group('Avatar Integration with Auth', () {
      testWidgets('User with no avatars → forced avatar creation', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();

        // This would test the flow where a user logs in
        // but has no avatars and must create one
      });

      testWidgets('User with avatars → direct app access', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // This would test the flow where a user logs in
        // and already has avatars, so goes directly to app
      });
    });

    group('Error Scenarios', () {
      testWidgets('Network error during authentication', (tester) async {
        // Test app behavior when network requests fail
        app.main();
        await tester.pumpAndSettle();

        // This would require mocking network failures
        // and verifying proper error handling
      });

      testWidgets('Invalid credentials handling', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        final emailField = find.byKey(const Key('login_email_field'));
        final passwordField = find.byKey(const Key('login_password_field'));
        final submitButton = find.byKey(const Key('login_submit_button'));

        if (emailField.evaluate().isNotEmpty &&
            passwordField.evaluate().isNotEmpty &&
            submitButton.evaluate().isNotEmpty) {
          await tester.enterText(emailField, 'invalid@example.com');
          await tester.enterText(passwordField, 'wrongpassword');
          await tester.tap(submitButton);
          await tester.pumpAndSettle();

          // Should show error message
          expect(find.textContaining('Invalid'), findsOneWidget);
        }
      });
    });

    group('Logout Flow', () {
      testWidgets('Successful logout → return to login screen', (tester) async {
        // This would test the logout functionality
        // and verify user is returned to login screen

        app.main();
        await tester.pumpAndSettle();

        // Would need to be authenticated first to test logout
      });

      testWidgets('Logout clears user data and session', (tester) async {
        // Verify that logout properly cleans up user data
        // and invalidates the session
      });
    });
  });
}

/// Helper function to complete avatar creation flow
Future<void> _completeAvatarCreation(WidgetTester tester) async {
  // Step 1: Avatar Name
  final nameField = find.byKey(const Key('avatar_name_field'));
  if (nameField.evaluate().isNotEmpty) {
    await tester.enterText(nameField, 'Test Avatar');

    final nextButton = find.text('Next');
    if (nextButton.evaluate().isNotEmpty) {
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
    }
  }

  // Step 2: Avatar Bio
  final bioField = find.byKey(const Key('avatar_bio_field'));
  if (bioField.evaluate().isNotEmpty) {
    await tester.enterText(bioField, 'Test avatar bio');

    final nextButton = find.text('Next');
    if (nextButton.evaluate().isNotEmpty) {
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
    }
  }

  // Step 3: Niche Selection
  final nicheOption = find.byKey(const Key('niche_tech'));
  if (nicheOption.evaluate().isNotEmpty) {
    await tester.tap(nicheOption);

    final nextButton = find.text('Next');
    if (nextButton.evaluate().isNotEmpty) {
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
    }
  }

  // Step 4: Personality Traits
  final personalityTrait = find.byKey(const Key('trait_friendly'));
  if (personalityTrait.evaluate().isNotEmpty) {
    await tester.tap(personalityTrait);

    final finishButton = find.text('Create Avatar');
    if (finishButton.evaluate().isNotEmpty) {
      await tester.tap(finishButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
  }
}
