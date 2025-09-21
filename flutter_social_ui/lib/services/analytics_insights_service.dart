import 'package:flutter/foundation.dart';
import '../models/analytics_insight.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import 'profile_service.dart';
import 'analytics_service.dart';

/// Simplified analytics insights service for profile analytics
class AnalyticsInsightsService {
  static final AnalyticsInsightsService _instance =
      AnalyticsInsightsService._internal();
  factory AnalyticsInsightsService() => _instance;
  AnalyticsInsightsService._internal();

  final ProfileService _profileService = ProfileService();
  final AnalyticsService _analyticsService = AnalyticsService();

  /// Get comprehensive analytics data for a user's profile
  Future<Map<String, dynamic>> getProfileAnalytics({
    required String userId,
    AnalyticsPeriod period = AnalyticsPeriod.month,
    bool includeComparisons = true,
  }) async {
    try {
      // Track analytics view
      await _analyticsService.trackEvent('profile_analytics_view', {
        'target_user_id': userId,
        'period': period.name,
      });

      // Get basic profile data
      final profileData = await _profileService.getUserProfileData(userId);
      final user = profileData['user'] as UserModel;
      final avatars = profileData['avatars'] as List<AvatarModel>;
      final activeAvatar = profileData['active_avatar'] as AvatarModel?;

      // Get basic metrics
      final metrics = await _getBasicMetrics(userId, period);
      final insights = await _generateBasicInsights(userId, metrics);

      return {
        'user': user,
        'avatars': avatars,
        'active_avatar': activeAvatar,
        'metrics': metrics,
        'insights': insights,
        'period': period,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting profile analytics: $e');
      return {
        'error': e.toString(),
        'metrics': <AnalyticsMetric>[],
        'insights': <AnalyticsInsight>[],
      };
    }
  }

  /// Get basic metrics for a user
  Future<List<AnalyticsMetric>> _getBasicMetrics(
    String userId,
    AnalyticsPeriod period,
  ) async {
    try {
      // Return basic metrics
      return [
        AnalyticsMetric(
          name: 'Profile Views',
          value: 150.0,
          unit: 'views',
          change: 12.5,
          trend: 'up',
        ),
        AnalyticsMetric(
          name: 'Engagement Rate',
          value: 3.2,
          unit: '%',
          change: -0.5,
          trend: 'down',
        ),
        AnalyticsMetric(
          name: 'Followers',
          value: 1250.0,
          unit: 'followers',
          change: 25.0,
          trend: 'up',
        ),
      ];
    } catch (e) {
      debugPrint('Error getting basic metrics: $e');
      return [];
    }
  }

  /// Generate basic insights
  Future<List<AnalyticsInsight>> _generateBasicInsights(
    String userId,
    List<AnalyticsMetric> metrics,
  ) async {
    final insights = <AnalyticsInsight>[];
    final now = DateTime.now();

    try {
      // Find engagement metric
      final engagementMetric = metrics
          .where((m) => m.name == 'Engagement Rate')
          .firstOrNull;

      if (engagementMetric != null && engagementMetric.value < 3.0) {
        insights.add(
          AnalyticsInsight(
            id: 'low_engagement_${now.millisecondsSinceEpoch}',
            title: '📈 Boost Your Engagement',
            description:
                'Your engagement rate is ${engagementMetric.value.toStringAsFixed(1)}%. Try posting more interactive content.',
            value: engagementMetric.value,
            type: 'engagement',
            createdAt: now,
          ),
        );
      }

      // Find follower growth
      final followersMetric = metrics
          .where((m) => m.name == 'Followers')
          .firstOrNull;

      if (followersMetric != null && (followersMetric.change ?? 0) > 20) {
        insights.add(
          AnalyticsInsight(
            id: 'growth_surge_${now.millisecondsSinceEpoch}',
            title: '🚀 Growth Surge Detected!',
            description:
                'Your follower count increased by ${followersMetric.change?.toStringAsFixed(0) ?? '0'}! Keep up the momentum.',
            value: followersMetric.change ?? 0,
            type: 'growth',
            createdAt: now,
          ),
        );
      }

      return insights;
    } catch (e) {
      debugPrint('Error generating insights: $e');
      return [];
    }
  }
}
