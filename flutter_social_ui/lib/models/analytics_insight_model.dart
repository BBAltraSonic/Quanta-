import 'analytics_insight.dart';

// Re-export the main analytics classes
export 'analytics_insight.dart';

// Additional models for the insights service
enum InsightType { engagement, growth, content, audience, performance }

enum InsightPriority { low, medium, high, critical }

enum MetricType { count, percentage, rate, duration, currency }

class AnalyticsMetric {
  final String key;
  final String label;
  final double value;
  final MetricType type;
  final String? unit;
  final double? change;
  final String? trend;

  AnalyticsMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.type,
    this.unit,
    this.change,
    this.trend,
  });

  factory AnalyticsMetric.fromJson(Map<String, dynamic> json) {
    return AnalyticsMetric(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      type: MetricType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MetricType.count,
      ),
      unit: json['unit'],
      change: json['change']?.toDouble(),
      trend: json['trend'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'value': value,
      'type': type.name,
      'unit': unit,
      'change': change,
      'trend': trend,
    };
  }
}

class EnhancedAnalyticsInsight extends AnalyticsInsight {
  final InsightType insightType;
  final InsightPriority _priority;
  final Map<String, dynamic>? _data;

  @override
  InsightPriority get priority => _priority;

  @override
  Map<String, dynamic>? get data => _data;

  EnhancedAnalyticsInsight({
    required super.id,
    required super.title,
    required super.description,
    required super.value,
    required super.type,
    required super.createdAt,
    required this.insightType,
    required InsightPriority priority,
    Map<String, dynamic>? data,
  }) : _priority = priority,
       _data = data;

  factory EnhancedAnalyticsInsight.fromJson(Map<String, dynamic> json) {
    return EnhancedAnalyticsInsight(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      type: json['type'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      insightType: InsightType.values.firstWhere(
        (e) => e.name == json['insight_type'],
        orElse: () => InsightType.performance,
      ),
      priority: InsightPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => InsightPriority.medium,
      ),
      data: json['data'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'insight_type': insightType.name,
      'priority': _priority.name,
      'data': _data,
    });
    return json;
  }
}
