import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/screens/profile_screen.dart';
import 'package:quanta/models/avatar_model.dart';

void main() {
  group('ProfileScreen Avatar-Centric Tests', () {
    testWidgets('ProfileScreen should accept avatarId parameter', (
      tester,
    ) async {
      // Test that ProfileScreen can be created with avatarId parameter
      const profileScreen = ProfileScreen(avatarId: 'test-avatar-id');

      expect(profileScreen.avatarId, equals('test-avatar-id'));
      expect(profileScreen.userId, isNull);
    });

    testWidgets(
      'ProfileScreen should maintain backward compatibility with userId',
      (tester) async {
        // Test that ProfileScreen still works with legacy userId parameter
        const profileScreen = ProfileScreen(userId: 'test-user-id');

        expect(profileScreen.userId, equals('test-user-id'));
        expect(profileScreen.avatarId, isNull);
      },
    );

    testWidgets(
      'ProfileScreen should handle both avatarId and userId parameters',
      (tester) async {
        // Test that ProfileScreen can handle both parameters
        const profileScreen = ProfileScreen(
          avatarId: 'test-avatar-id',
          userId: 'test-user-id',
        );

        expect(profileScreen.avatarId, equals('test-avatar-id'));
        expect(profileScreen.userId, equals('test-user-id'));
      },
    );

    testWidgets('ProfileScreen should handle null parameters', (tester) async {
      // Test that ProfileScreen can be created with no parameters (current user's active avatar)
      const profileScreen = ProfileScreen();

      expect(profileScreen.avatarId, isNull);
      expect(profileScreen.userId, isNull);
    });
  });
}
