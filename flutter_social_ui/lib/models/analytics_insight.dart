import 'package:flutter/material.dart';

class AnalyticsInsight {
  final String id;
  final String title;
  final String description;
  final double value;
  final String type;
  final DateTime createdAt;

  AnalyticsInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.value,
    required this.type,
    required this.createdAt,
  });

  // Additional getters for compatibility
  Map<String, dynamic>? get data => null;
  Map<String, dynamic>? get actionData => null;
  String? get actionLabel => null;
  bool get isActionable => false;

  // Mock priority and type extensions for compatibility
  InsightPriority get priority => InsightPriority.medium;

  factory AnalyticsInsight.fromJson(Map<String, dynamic> json) {
    return AnalyticsInsight(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      type: json['type'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'value': value,
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum InsightPriority {
  low,
  medium,
  high,
  critical;

  String get label {
    switch (this) {
      case InsightPriority.low:
        return 'Low';
      case InsightPriority.medium:
        return 'Medium';
      case InsightPriority.high:
        return 'High';
      case InsightPriority.critical:
        return 'Critical';
    }
  }

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
}

class AnalyticsMetric {
  final String name;
  final double value;
  final String unit;
  final double? change;
  final String? trend;

  AnalyticsMetric({
    required this.name,
    required this.value,
    required this.unit,
    this.change,
    this.trend,
  });

  // Additional getters for compatibility
  double? get changePercentage => change;
  String? get changeText => change != null
      ? '${change! > 0 ? '+' : ''}${change!.toStringAsFixed(1)}%'
      : null;
  bool get isPositiveChange => (change ?? 0) > 0;

  factory AnalyticsMetric.fromJson(Map<String, dynamic> json) {
    return AnalyticsMetric(
      name: json['name'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      change: json['change']?.toDouble(),
      trend: json['trend'],
    );
  }
}

enum AnalyticsPeriod {
  day,
  week,
  month,
  year;

  String get label {
    switch (this) {
      case AnalyticsPeriod.day:
        return 'Daily';
      case AnalyticsPeriod.week:
        return 'Weekly';
      case AnalyticsPeriod.month:
        return 'Monthly';
      case AnalyticsPeriod.year:
        return 'Yearly';
    }
  }

  String get shortLabel {
    switch (this) {
      case AnalyticsPeriod.day:
        return '1D';
      case AnalyticsPeriod.week:
        return '1W';
      case AnalyticsPeriod.month:
        return '1M';
      case AnalyticsPeriod.year:
        return '1Y';
    }
  }
}

// Extensions for String type compatibility
extension InsightTypeExtension on String {
  Color get color {
    switch (this) {
      case 'engagement':
        return Colors.blue;
      case 'growth':
        return Colors.green;
      case 'content':
        return Colors.purple;
      case 'audience':
        return Colors.orange;
      case 'performance':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case 'engagement':
        return Icons.favorite;
      case 'growth':
        return Icons.trending_up;
      case 'content':
        return Icons.article;
      case 'audience':
        return Icons.people;
      case 'performance':
        return Icons.analytics;
      default:
        return Icons.info;
    }
  }
}

// Additional data point class for analytics
class AnalyticsDataPoint {
  final DateTime date;
  final double value;
  final String? label;

  AnalyticsDataPoint({required this.date, required this.value, this.label});

  factory AnalyticsDataPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsDataPoint(
      date: DateTime.parse(json['date']),
      value: (json['value'] ?? 0).toDouble(),
      label: json['label'],
    );
  }
}
