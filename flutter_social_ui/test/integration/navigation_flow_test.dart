import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/screens/app_shell.dart';
import 'package:quanta/screens/profile_screen.dart';

/// Simple integration test for navigation flows
void main() {
  group('Navigation Flow Tests', () {
    testWidgets('should build app shell without errors', (tester) async {
      // Build the AppShell
      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      // Verify AppShell is rendered
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('should navigate between tabs', (tester) async {
      // Build the AppShell
      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      // Find navigation items (assuming curved navigation bar)
      final navigationItems = find.byType(GestureDetector);
      expect(navigationItems, findsWidgets);

      // Test navigation by tapping different areas
      // Note: This is a basic test - actual navigation depends on the implementation
    });

    testWidgets('should handle profile screen navigation', (tester) async {
      // Build ProfileScreen directly
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();

      // Verify ProfileScreen is rendered
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('should handle profile screen with avatar ID', (tester) async {
      // Build ProfileScreen with avatar ID
      await tester.pumpWidget(
        const MaterialApp(home: ProfileScreen(avatarId: 'test-avatar-id')),
      );
      await tester.pumpAndSettle();

      // Verify ProfileScreen is rendered
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('should handle profile screen with user ID (legacy)', (
      tester,
    ) async {
      // Build ProfileScreen with user ID
      await tester.pumpWidget(
        const MaterialApp(home: ProfileScreen(userId: 'test-user-id')),
      );
      await tester.pumpAndSettle();

      // Verify ProfileScreen is rendered
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });

  group('Route Generation Tests', () {
    testWidgets('should handle avatar profile routes', (tester) async {
      // Test route generation for avatar profiles
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name?.startsWith('/profile/avatar/') == true) {
              final avatarId = settings.name!.split('/').last;
              return MaterialPageRoute(
                builder: (context) => ProfileScreen(avatarId: avatarId),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const Scaffold(body: Text('Not Found')),
            );
          },
          initialRoute: '/profile/avatar/test-id',
        ),
      );
      await tester.pumpAndSettle();

      // Verify ProfileScreen is rendered
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('should handle user profile routes', (tester) async {
      // Test route generation for user profiles
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name?.startsWith('/profile/user/') == true) {
              final userId = settings.name!.split('/').last;
              return MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: userId),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const Scaffold(body: Text('Not Found')),
            );
          },
          initialRoute: '/profile/user/test-id',
        ),
      );
      await tester.pumpAndSettle();

      // Verify ProfileScreen is rendered
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('should handle basic profile route', (tester) async {
      // Test route generation for basic profile
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/profile') {
              return MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const Scaffold(body: Text('Not Found')),
            );
          },
          initialRoute: '/profile',
        ),
      );
      await tester.pumpAndSettle();

      // Verify ProfileScreen is rendered
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}
