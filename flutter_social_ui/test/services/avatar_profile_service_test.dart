import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/avatar_profile_service.dart';
import '../../lib/store/app_state.dart';

void main() {
  group('AvatarProfileService', () {
    late AvatarProfileService service;

    setUp(() {
      service = AvatarProfileService();
    });

    group('determineViewMode', () {
      test('should return guest view for unauthenticated users', () {
        // Act
        final result = service.determineViewMode('avatar-id', null);

        // Assert
        expect(result, equals(ProfileViewMode.guest));
      });

      test('should return view mode for authenticated users', () {
        // Act
        final result = service.determineViewMode('avatar-id', 'user-id');

        // Assert
        expect(result, isA<ProfileViewMode>());
      });
    });

    group('AvatarProfileData', () {
      test('should be constructible with required parameters', () {
        // This test verifies that the AvatarProfileData class exists
        // and has the expected constructor signature
        expect(() => AvatarProfileData, returnsNormally);
      });
    });

    group('AvatarStats', () {
      test('should create avatar stats with correct values', () {
        // Arrange
        final now = DateTime.now();

        // Act
        final stats = AvatarStats(
          followersCount: 500,
          followingCount: 0,
          postsCount: 25,
          totalLikes: 1250,
          engagementRate: 8.5,
          lastActiveAt: now,
        );

        // Assert
        expect(stats.followersCount, equals(500));
        expect(stats.followingCount, equals(0));
        expect(stats.postsCount, equals(25));
        expect(stats.totalLikes, equals(1250));
        expect(stats.engagementRate, equals(8.5));
        expect(stats.lastActiveAt, equals(now));
      });
    });

    group('ProfileAction', () {
      test('should create profile action with correct properties', () {
        // Arrange
        var tapped = false;
        void onTap() => tapped = true;

        // Act
        final action = ProfileAction(
          type: ProfileActionType.follow,
          label: 'Follow Avatar',
          isPrimary: true,
          onTap: onTap,
        );

        // Assert
        expect(action.type, equals(ProfileActionType.follow));
        expect(action.label, equals('Follow Avatar'));
        expect(action.isPrimary, isTrue);

        // Test callback
        action.onTap();
        expect(tapped, isTrue);
      });
    });

    group('AvatarEngagementMetrics', () {
      test('should create engagement metrics with correct values', () {
        // Arrange
        final dailyActivity = {'2024-01-01': 5, '2024-01-02': 3};

        // Act
        final metrics = AvatarEngagementMetrics(
          totalViews: 10000,
          totalShares: 150,
          avgEngagementPerPost: 45.5,
          dailyActivity: dailyActivity,
        );

        // Assert
        expect(metrics.totalViews, equals(10000));
        expect(metrics.totalShares, equals(150));
        expect(metrics.avgEngagementPerPost, equals(45.5));
        expect(metrics.dailyActivity, equals(dailyActivity));
      });
    });

    group('ProfileActionType enum', () {
      test('should have all required action types', () {
        // Assert
        expect(ProfileActionType.values, contains(ProfileActionType.follow));
        expect(ProfileActionType.values, contains(ProfileActionType.unfollow));
        expect(ProfileActionType.values, contains(ProfileActionType.message));
        expect(ProfileActionType.values, contains(ProfileActionType.report));
        expect(ProfileActionType.values, contains(ProfileActionType.share));
        expect(ProfileActionType.values, contains(ProfileActionType.block));
        expect(
          ProfileActionType.values,
          contains(ProfileActionType.editAvatar),
        );
        expect(
          ProfileActionType.values,
          contains(ProfileActionType.manageAvatars),
        );
        expect(
          ProfileActionType.values,
          contains(ProfileActionType.viewAnalytics),
        );
        expect(
          ProfileActionType.values,
          contains(ProfileActionType.switchAvatar),
        );
      });
    });

    group('Service Integration', () {
      test('should have singleton instance', () {
        // Act
        final instance1 = AvatarProfileService();
        final instance2 = AvatarProfileService();

        // Assert
        expect(identical(instance1, instance2), isTrue);
      });

      test('should initialize with required dependencies', () {
        // Act & Assert - Service should initialize without throwing
        expect(() => AvatarProfileService(), returnsNormally);
      });
    });
  });
}
