import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_insight_model.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import 'auth_service.dart';
import 'profile_service.dart';
import 'analytics_service.dart';

/// Enhanced analytics insights service for profile analytics
class AnalyticsInsightsService {
  static final AnalyticsInsightsService _instance = AnalyticsInsightsService._internal();
  factory AnalyticsInsightsService() => _instance;
  AnalyticsInsightsService._internal();

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final SupabaseClient _supabase = Supabase.instance.client;

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

      // Get advanced metrics
      final metrics = await _getAdvancedMetrics(userId, period);
      final insights = await _generateInsights(userId, metrics, avatars);
      final chartData = await _getChartData(userId, period);
      final comparisons = includeComparisons ? await _getComparisons(userId, period) : null;

      return {
        'user': user,
        'avatars': avatars,
        'active_avatar': activeAvatar,
        'metrics': metrics,
        'insights': insights,
        'chart_data': chartData,
        'comparisons': comparisons,
        'period': period,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting profile analytics: $e');
      rethrow;
    }
  }

  /// Get advanced analytics metrics
  Future<List<AnalyticsMetric>> _getAdvancedMetrics(
    String userId,
    AnalyticsPeriod period,
  ) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(period.duration);
    final previousStartDate = startDate.subtract(period.duration);

    try {
      // Get current period metrics
      final currentMetrics = await _getMetricsForPeriod(userId, startDate, endDate);
      final previousMetrics = await _getMetricsForPeriod(userId, previousStartDate, startDate);

      // Combine current and previous for comparison
      final combinedMetrics = <AnalyticsMetric>[];
      
      for (final metric in currentMetrics) {
        final previousMetric = previousMetrics.firstWhere(
          (m) => m.key == metric.key,
          orElse: () => AnalyticsMetric(
            key: metric.key,
            label: metric.label,
            value: 0,
            type: metric.type,
          ),
        );
        
        combinedMetrics.add(AnalyticsMetric(
          key: metric.key,
          label: metric.label,
          value: metric.value,
          previousValue: previousMetric.value,
          unit: metric.unit,
          type: metric.type,
          isGoodDirection: metric.isGoodDirection,
        ));
      }

      return combinedMetrics;
    } catch (e) {
      debugPrint('Error getting advanced metrics: $e');
      return _getFallbackMetrics(userId);
    }
  }

  /// Get metrics for a specific time period
  Future<List<AnalyticsMetric>> _getMetricsForPeriod(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Simulate analytics queries - in real app, these would be database queries
    final stats = await _profileService.getUserStats(userId);
    
    return [
      AnalyticsMetric(
        key: 'profile_views',
        label: 'Profile Views',
        value: _generateRealisticValue(stats['followers_count'] ?? 0, 0.1, 2.0),
        type: MetricType.count,
      ),
      AnalyticsMetric(
        key: 'engagement_rate',
        label: 'Engagement Rate',
        value: _generateEngagementRate(stats['followers_count'] ?? 0),
        type: MetricType.percentage,
        unit: '%',
      ),
      AnalyticsMetric(
        key: 'reach',
        label: 'Reach',
        value: _generateRealisticValue(stats['followers_count'] ?? 0, 0.8, 3.0),
        type: MetricType.count,
      ),
      AnalyticsMetric(
        key: 'impressions',
        label: 'Impressions',
        value: _generateRealisticValue(stats['followers_count'] ?? 0, 2.0, 8.0),
        type: MetricType.count,
      ),
      AnalyticsMetric(
        key: 'post_likes',
        label: 'Total Likes',
        value: _generateRealisticValue(stats['posts_count'] ?? 0, 3.0, 25.0),
        type: MetricType.count,
      ),
      AnalyticsMetric(
        key: 'post_comments',
        label: 'Total Comments',
        value: _generateRealisticValue(stats['posts_count'] ?? 0, 0.5, 5.0),
        type: MetricType.count,
      ),
      AnalyticsMetric(
        key: 'post_shares',
        label: 'Total Shares',
        value: _generateRealisticValue(stats['posts_count'] ?? 0, 0.2, 2.0),
        type: MetricType.count,
      ),
      AnalyticsMetric(
        key: 'follower_growth',
        label: 'New Followers',
        value: _generateRealisticValue(stats['followers_count'] ?? 0, 0.01, 0.05),
        type: MetricType.count,
      ),
      AnalyticsMetric(
        key: 'content_completion_rate',
        label: 'Content Completion',
        value: _generateCompletionRate(),
        type: MetricType.percentage,
        unit: '%',
      ),
      AnalyticsMetric(
        key: 'avg_watch_time',
        label: 'Avg. Watch Time',
        value: _generateWatchTime(),
        type: MetricType.duration,
        unit: 's',
      ),
    ];
  }

  /// Generate realistic analytics insights based on metrics
  Future<List<AnalyticsInsight>> _generateInsights(
    String userId,
    List<AnalyticsMetric> metrics,
    List<AvatarModel> avatars,
  ) async {
    final insights = <AnalyticsInsight>[];
    final now = DateTime.now();

    // Engagement insights
    final engagementMetric = metrics.firstWhere(
      (m) => m.key == 'engagement_rate',
      orElse: () => AnalyticsMetric(key: 'engagement_rate', label: 'Engagement Rate', value: 0, type: MetricType.percentage),
    );

    if (engagementMetric.value < 2.0) {
      insights.add(AnalyticsInsight(
        id: 'low_engagement_${now.millisecondsSinceEpoch}',
        title: '📈 Boost Your Engagement',
        description: 'Your engagement rate is ${engagementMetric.value.toStringAsFixed(1)}%. Try posting more interactive content like polls and Q&As.',
        type: InsightType.engagement,
        priority: InsightPriority.high,
        data: {'current_rate': engagementMetric.value, 'target_rate': 3.5},
        createdAt: now,
        isActionable: true,
        actionLabel: 'View Tips',
        actionData: {'type': 'engagement_tips'},
      ));
    }

    // Growth insights
    final followerGrowth = metrics.firstWhere(
      (m) => m.key == 'follower_growth',
      orElse: () => AnalyticsMetric(key: 'follower_growth', label: 'New Followers', value: 0, type: MetricType.count),
    );

    if (followerGrowth.changePercentage != null && followerGrowth.changePercentage! > 20) {
      insights.add(AnalyticsInsight(
        id: 'growth_surge_${now.millisecondsSinceEpoch}',
        title: '🚀 Growth Surge Detected!',
        description: 'Your follower growth increased by ${followerGrowth.changeText}! Keep up the momentum with consistent posting.',
        type: InsightType.growth,
        priority: InsightPriority.medium,
        data: {'growth_rate': followerGrowth.changePercentage},
        createdAt: now,
        isActionable: true,
        actionLabel: 'Optimize Strategy',
        actionData: {'type': 'growth_strategy'},
      ));
    }

    // Content performance insights
    final postsMetric = metrics.firstWhere(
      (m) => m.key == 'post_likes',
      orElse: () => AnalyticsMetric(key: 'post_likes', label: 'Total Likes', value: 0, type: MetricType.count),
    );

    if (avatars.isNotEmpty) {
      final topAvatar = avatars.first;
      insights.add(AnalyticsInsight(
        id: 'top_performer_${now.millisecondsSinceEpoch}',
        title: '⭐ Top Performing Avatar',
        description: '${topAvatar.name} is your highest-performing avatar with ${_formatNumber(topAvatar.followersCount)} followers.',
        type: InsightType.performance,
        priority: InsightPriority.low,
        data: {
          'avatar_id': topAvatar.id,
          'avatar_name': topAvatar.name,
          'followers': topAvatar.followersCount,
        },
        createdAt: now,
      ));
    }

    // Audience insights
    final reachMetric = metrics.firstWhere(
      (m) => m.key == 'reach',
      orElse: () => AnalyticsMetric(key: 'reach', label: 'Reach', value: 0, type: MetricType.count),
    );

    if (reachMetric.changePercentage != null && reachMetric.changePercentage! < -10) {
      insights.add(AnalyticsInsight(
        id: 'reach_decline_${now.millisecondsSinceEpoch}',
        title: '📉 Reach Declining',
        description: 'Your reach decreased by ${reachMetric.changeText}. Consider posting at different times or using trending hashtags.',
        type: InsightType.audience,
        priority: InsightPriority.high,
        data: {'decline_percentage': reachMetric.changePercentage},
        createdAt: now,
        isActionable: true,
        actionLabel: 'Improve Reach',
        actionData: {'type': 'reach_optimization'},
      ));
    }

    // Best time to post insight
    insights.add(AnalyticsInsight(
      id: 'best_time_${now.millisecondsSinceEpoch}',
      title: '⏰ Optimal Posting Time',
      description: 'Your audience is most active between 6-8 PM on weekdays. Schedule your posts for maximum engagement.',
      type: InsightType.audience,
      priority: InsightPriority.medium,
      data: {
        'best_days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday'],
        'best_hours': [18, 19, 20],
        'timezone': 'UTC',
      },
      createdAt: now,
      isActionable: true,
      actionLabel: 'Schedule Posts',
      actionData: {'type': 'post_scheduling'},
    ));

    return insights.take(5).toList(); // Limit to 5 insights
  }

  /// Get chart data for visualization
  Future<Map<String, List<AnalyticsDataPoint>>> _getChartData(
    String userId,
    AnalyticsPeriod period,
  ) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(period.duration);
    final days = period.duration.inDays;

    // Generate realistic chart data
    final followers = <AnalyticsDataPoint>[];
    final engagement = <AnalyticsDataPoint>[];
    final reach = <AnalyticsDataPoint>[];

    final stats = await _profileService.getUserStats(userId);
    final baseFollowers = stats['followers_count'] ?? 100;
    final baseReach = baseFollowers * 2.5;

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      
      // Add some realistic variation
      final followerVariation = (i / days) * baseFollowers * 0.1;
      final reachVariation = (_generateRealisticValue(100, 0.8, 1.2) - 100) / 100;
      final engagementValue = _generateEngagementRate(baseFollowers + followerVariation.toInt());

      followers.add(AnalyticsDataPoint(
        timestamp: date,
        value: baseFollowers + followerVariation,
      ));

      reach.add(AnalyticsDataPoint(
        timestamp: date,
        value: baseReach * (1 + reachVariation),
      ));

      engagement.add(AnalyticsDataPoint(
        timestamp: date,
        value: engagementValue,
      ));
    }

    return {
      'followers': followers,
      'engagement': engagement,
      'reach': reach,
    };
  }

  /// Get comparison data with other users/avatars
  Future<Map<String, dynamic>?> _getComparisons(
    String userId,
    AnalyticsPeriod period,
  ) async {
    try {
      // In a real app, this would compare with similar users/avatars
      final stats = await _profileService.getUserStats(userId);
      final userFollowers = stats['followers_count'] ?? 0;
      
      // Generate realistic industry averages
      return {
        'industry_averages': {
          'engagement_rate': 3.2,
          'follower_growth_rate': 2.1,
          'post_frequency': 5.5, // posts per week
        },
        'user_percentile': _calculatePercentile(userFollowers),
        'category': _determineUserCategory(userFollowers),
        'benchmark_message': _getBenchmarkMessage(userFollowers),
      };
    } catch (e) {
      debugPrint('Error getting comparisons: $e');
      return null;
    }
  }

  /// Get fallback metrics when real data isn't available
  List<AnalyticsMetric> _getFallbackMetrics(String userId) {
    return [
      AnalyticsMetric(
        key: 'profile_views',
        label: 'Profile Views',
        value: 124,
        previousValue: 98,
        type: MetricType.count,
      ),
      AnalyticsMetric(
        key: 'engagement_rate',
        label: 'Engagement Rate',
        value: 2.8,
        previousValue: 2.3,
        type: MetricType.percentage,
        unit: '%',
      ),
      AnalyticsMetric(
        key: 'reach',
        label: 'Reach',
        value: 856,
        previousValue: 743,
        type: MetricType.count,
      ),
      AnalyticsMetric(
        key: 'impressions',
        label: 'Impressions',
        value: 2341,
        previousValue: 2156,
        type: MetricType.count,
      ),
    ];
  }

  // Helper methods for realistic data generation
  double _generateRealisticValue(int base, double minMultiplier, double maxMultiplier) {
    if (base == 0) base = 1;
    final multiplier = minMultiplier + (maxMultiplier - minMultiplier) * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000;
    return (base * multiplier).roundToDouble();
  }

  double _generateEngagementRate(int followers) {
    // Engagement rate typically decreases with more followers
    if (followers < 100) return 5.0 + (DateTime.now().millisecondsSinceEpoch % 30) / 10;
    if (followers < 1000) return 4.0 + (DateTime.now().millisecondsSinceEpoch % 25) / 10;
    if (followers < 10000) return 3.0 + (DateTime.now().millisecondsSinceEpoch % 20) / 10;
    return 2.0 + (DateTime.now().millisecondsSinceEpoch % 15) / 10;
  }

  double _generateCompletionRate() {
    return 65.0 + (DateTime.now().millisecondsSinceEpoch % 30);
  }

  double _generateWatchTime() {
    return 45.0 + (DateTime.now().millisecondsSinceEpoch % 60);
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  int _calculatePercentile(int followers) {
    if (followers < 100) return 25;
    if (followers < 1000) return 50;
    if (followers < 10000) return 75;
    if (followers < 100000) return 90;
    return 95;
  }

  String _determineUserCategory(int followers) {
    if (followers < 100) return 'Emerging Creator';
    if (followers < 1000) return 'Growing Creator';
    if (followers < 10000) return 'Established Creator';
    if (followers < 100000) return 'Influencer';
    return 'Top Creator';
  }

  String _getBenchmarkMessage(int followers) {
    final category = _determineUserCategory(followers);
    switch (category) {
      case 'Emerging Creator':
        return 'You\'re just getting started! Focus on consistent posting and engaging with your audience.';
      case 'Growing Creator':
        return 'Great progress! You\'re building a solid foundation. Keep experimenting with content types.';
      case 'Established Creator':
        return 'You\'ve built a strong following! Focus on maintaining engagement and exploring new formats.';
      case 'Influencer':
        return 'Impressive reach! You\'re in the top tier. Consider partnering with brands and other creators.';
      default:
        return 'Outstanding! You\'re among the top creators. Your influence is significant!';
    }
  }

  /// Get detailed avatar performance analytics
  Future<Map<String, dynamic>> getAvatarAnalytics({
    required String avatarId,
    AnalyticsPeriod period = AnalyticsPeriod.month,
  }) async {
    try {
      // This would fetch detailed analytics for a specific avatar
      // For now, return simulated data
      return {
        'avatar_id': avatarId,
        'period': period.name,
        'metrics': {
          'total_posts': 15,
          'total_likes': 847,
          'total_comments': 123,
          'total_shares': 34,
          'engagement_rate': 4.2,
          'reach': 2340,
          'impressions': 8765,
        },
        'top_posts': [], // Would contain top performing posts
        'audience_demographics': {
          'age_groups': {'18-24': 35, '25-34': 40, '35-44': 20, '45+': 5},
          'locations': {'US': 45, 'UK': 15, 'CA': 12, 'AU': 8, 'Other': 20},
        },
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting avatar analytics: $e');
      rethrow;
    }
  }
}
