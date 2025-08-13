import 'package:flutter/material.dart';

/// Represents an analytics insight for display in profile screen
class AnalyticsInsight {
  final String id;
  final String title;
  final String description;
  final InsightType type;
  final Map<String, dynamic> data;
  final InsightPriority priority;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActionable;
  final String? actionLabel;
  final Map<String, dynamic>? actionData;

  const AnalyticsInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.data,
    required this.priority,
    required this.createdAt,
    this.expiresAt,
    this.isActionable = false,
    this.actionLabel,
    this.actionData,
  });

  factory AnalyticsInsight.fromJson(Map<String, dynamic> json) {
    return AnalyticsInsight(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: InsightType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => InsightType.general,
      ),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      priority: InsightPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => InsightPriority.medium,
      ),
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : null,
      isActionable: json['is_actionable'] ?? false,
      actionLabel: json['action_label'],
      actionData: json['action_data'] != null
          ? Map<String, dynamic>.from(json['action_data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'data': data,
      'priority': priority.name,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_actionable': isActionable,
      'action_label': actionLabel,
      'action_data': actionData,
    };
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

/// Types of analytics insights
enum InsightType {
  engagement,
  growth,
  content,
  audience,
  monetization,
  performance,
  trending,
  comparison,
  general,
}

/// Priority levels for insights
enum InsightPriority {
  low,
  medium,
  high,
  critical,
}

/// Extension to get UI properties for insight types
extension InsightTypeUI on InsightType {
  Color get color {
    switch (this) {
      case InsightType.engagement:
        return Colors.blue;
      case InsightType.growth:
        return Colors.green;
      case InsightType.content:
        return Colors.purple;
      case InsightType.audience:
        return Colors.orange;
      case InsightType.monetization:
        return Colors.amber;
      case InsightType.performance:
        return Colors.cyan;
      case InsightType.trending:
        return Colors.pink;
      case InsightType.comparison:
        return Colors.indigo;
      case InsightType.general:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case InsightType.engagement:
        return Icons.favorite;
      case InsightType.growth:
        return Icons.trending_up;
      case InsightType.content:
        return Icons.content_copy;
      case InsightType.audience:
        return Icons.people;
      case InsightType.monetization:
        return Icons.monetization_on;
      case InsightType.performance:
        return Icons.analytics;
      case InsightType.trending:
        return Icons.whatshot;
      case InsightType.comparison:
        return Icons.compare_arrows;
      case InsightType.general:
        return Icons.info;
    }
  }
}

/// Extension to get UI properties for priority levels
extension InsightPriorityUI on InsightPriority {
  Color get color {
    switch (this) {
      case InsightPriority.low:
        return Colors.grey;
      case InsightPriority.medium:
        return Colors.blue;
      case InsightPriority.high:
        return Colors.orange;
      case InsightPriority.critical:
        return Colors.red;
    }
  }

  String get label {
    switch (this) {
      case InsightPriority.low:
        return 'Low Priority';
      case InsightPriority.medium:
        return 'Medium Priority';
      case InsightPriority.high:
        return 'High Priority';
      case InsightPriority.critical:
        return 'Critical';
    }
  }
}

/// Analytics metrics model for performance tracking
class AnalyticsMetric {
  final String key;
  final String label;
  final dynamic value;
  final dynamic previousValue;
  final String unit;
  final MetricType type;
  final bool isGoodDirection;

  const AnalyticsMetric({
    required this.key,
    required this.label,
    required this.value,
    this.previousValue,
    this.unit = '',
    required this.type,
    this.isGoodDirection = true,
  });

  /// Calculate percentage change from previous value
  double? get changePercentage {
    if (previousValue == null || previousValue == 0) return null;
    return ((value - previousValue) / previousValue) * 100;
  }

  /// Get formatted change string
  String? get changeText {
    final change = changePercentage;
    if (change == null) return null;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }

  /// Check if the change is positive (good)
  bool get isPositiveChange {
    final change = changePercentage;
    if (change == null) return false;
    return isGoodDirection ? change >= 0 : change < 0;
  }

  factory AnalyticsMetric.fromJson(Map<String, dynamic> json) {
    return AnalyticsMetric(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      value: json['value'],
      previousValue: json['previous_value'],
      unit: json['unit'] ?? '',
      type: MetricType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MetricType.count,
      ),
      isGoodDirection: json['is_good_direction'] ?? true,
    );
  }
}

/// Types of metrics
enum MetricType {
  count,
  percentage,
  duration,
  currency,
  rate,
}

/// Time period for analytics
enum AnalyticsPeriod {
  day,
  week,
  month,
  quarter,
  year,
  allTime,
}

extension AnalyticsPeriodUI on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.day:
        return 'Today';
      case AnalyticsPeriod.week:
        return 'This Week';
      case AnalyticsPeriod.month:
        return 'This Month';
      case AnalyticsPeriod.quarter:
        return 'This Quarter';
      case AnalyticsPeriod.year:
        return 'This Year';
      case AnalyticsPeriod.allTime:
        return 'All Time';
    }
  }

  String get shortLabel {
    switch (this) {
      case AnalyticsPeriod.day:
        return '1D';
      case AnalyticsPeriod.week:
        return '7D';
      case AnalyticsPeriod.month:
        return '30D';
      case AnalyticsPeriod.quarter:
        return '90D';
      case AnalyticsPeriod.year:
        return '1Y';
      case AnalyticsPeriod.allTime:
        return 'All';
    }
  }

  Duration get duration {
    switch (this) {
      case AnalyticsPeriod.day:
        return const Duration(days: 1);
      case AnalyticsPeriod.week:
        return const Duration(days: 7);
      case AnalyticsPeriod.month:
        return const Duration(days: 30);
      case AnalyticsPeriod.quarter:
        return const Duration(days: 90);
      case AnalyticsPeriod.year:
        return const Duration(days: 365);
      case AnalyticsPeriod.allTime:
        return const Duration(days: 10000); // Arbitrarily large
    }
  }
}

/// Chart data point for analytics visualizations
class AnalyticsDataPoint {
  final DateTime timestamp;
  final double value;
  final Map<String, dynamic>? metadata;

  const AnalyticsDataPoint({
    required this.timestamp,
    required this.value,
    this.metadata,
  });

  factory AnalyticsDataPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsDataPoint(
      timestamp: DateTime.parse(json['timestamp']),
      value: (json['value'] ?? 0).toDouble(),
      metadata: json['metadata'],
    );
  }
}
