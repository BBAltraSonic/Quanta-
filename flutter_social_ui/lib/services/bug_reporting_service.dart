import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'auth_service.dart';

enum BugSeverity { low, medium, high, critical }

enum BugCategory {
  ui,
  functionality,
  performance,
  crash,
  login,
  avatar,
  content,
  network,
  other,
}

class BugReport {
  final String id;
  final String title;
  final String description;
  final BugCategory category;
  final BugSeverity severity;
  final String? userId;
  final String? userEmail;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> appInfo;
  final List<String> steps;
  final String? expectedBehavior;
  final String? actualBehavior;
  final List<String> screenshots;
  final DateTime createdAt;
  final String status;

  BugReport({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    this.userId,
    this.userEmail,
    required this.deviceInfo,
    required this.appInfo,
    required this.steps,
    this.expectedBehavior,
    this.actualBehavior,
    required this.screenshots,
    required this.createdAt,
    this.status = 'open',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.toString(),
      'severity': severity.toString(),
      'userId': userId,
      'userEmail': userEmail,
      'deviceInfo': deviceInfo,
      'appInfo': appInfo,
      'steps': steps,
      'expectedBehavior': expectedBehavior,
      'actualBehavior': actualBehavior,
      'screenshots': screenshots,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }
}

class BugReportingService {
  static final BugReportingService _instance = BugReportingService._internal();
  factory BugReportingService() => _instance;
  BugReportingService._internal();

  final AuthService _authService = AuthService();
  final List<BugReport> _localReports = [];

  /// Submit a bug report
  Future<String> submitBugReport(BugReport report) async {
    try {
      // Store locally first
      _localReports.add(report);

      // In a real implementation, send to backend
      await _sendToBackend(report);

      // Send to crash reporting service if available
      await _sendToCrashReporting(report);

      debugPrint('Bug report submitted successfully: ${report.id}');
      return report.id;
    } catch (e) {
      debugPrint('Failed to submit bug report: $e');
      rethrow;
    }
  }

  /// Create a bug report with system information
  Future<BugReport> createBugReport({
    required String title,
    required String description,
    required BugCategory category,
    required BugSeverity severity,
    required List<String> steps,
    String? expectedBehavior,
    String? actualBehavior,
    List<String> screenshots = const [],
  }) async {
    final user = _authService.currentUser;

    return BugReport(
      id: _generateReportId(),
      title: title,
      description: description,
      category: category,
      severity: severity,
      userId: user?.id,
      userEmail: user?.email,
      deviceInfo: await _collectDeviceInfo(),
      appInfo: _collectAppInfo(),
      steps: steps,
      expectedBehavior: expectedBehavior,
      actualBehavior: actualBehavior,
      screenshots: screenshots,
      createdAt: DateTime.now(),
    );
  }

  /// Get device information for debugging
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    try {
      return {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
        'isPhysicalDevice': !kIsWeb,
        'environment': kDebugMode ? 'debug' : 'release',
      };
    } catch (e) {
      return {
        'platform': 'unknown',
        'error': 'Could not collect device info: $e',
      };
    }
  }

  /// Get app information
  Map<String, dynamic> _collectAppInfo() {
    return {
      'version': '1.0.0+1',
      'buildMode': kDebugMode ? 'debug' : 'release',
      'platform': kIsWeb ? 'web' : 'mobile',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Generate unique report ID
  String _generateReportId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'BUG-$random';
  }

  /// Send report to backend (mock implementation)
  Future<void> _sendToBackend(BugReport report) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // In a real implementation, this would send to your backend API
    debugPrint('Sending bug report to backend: ${report.toJson()}');

    // For now, we'll just log it
    // You would replace this with actual HTTP request to your server
  }

  /// Send to crash reporting service
  Future<void> _sendToCrashReporting(BugReport report) async {
    try {
      // Send to Firebase Crashlytics as custom log
      // FirebaseCrashlytics.instance.log('Bug Report: ${report.title}');
      // FirebaseCrashlytics.instance.setCustomKey('bug_report_id', report.id);
      // FirebaseCrashlytics.instance.setCustomKey('bug_category', report.category.toString());
      // FirebaseCrashlytics.instance.setCustomKey('bug_severity', report.severity.toString());

      debugPrint('Bug report sent to crash reporting: ${report.id}');
    } catch (e) {
      debugPrint('Failed to send to crash reporting: $e');
    }
  }

  /// Get all local bug reports
  List<BugReport> getLocalReports() {
    return List.from(_localReports);
  }

  /// Clear local reports
  void clearLocalReports() {
    _localReports.clear();
  }

  /// Get bug category display name
  static String getCategoryDisplayName(BugCategory category) {
    switch (category) {
      case BugCategory.ui:
        return 'User Interface';
      case BugCategory.functionality:
        return 'Functionality';
      case BugCategory.performance:
        return 'Performance';
      case BugCategory.crash:
        return 'App Crash';
      case BugCategory.login:
        return 'Login/Authentication';
      case BugCategory.avatar:
        return 'Avatar Creation';
      case BugCategory.content:
        return 'Content Upload/Display';
      case BugCategory.network:
        return 'Network/Connectivity';
      case BugCategory.other:
        return 'Other';
    }
  }

  /// Get bug severity display name
  static String getSeverityDisplayName(BugSeverity severity) {
    switch (severity) {
      case BugSeverity.low:
        return 'Low';
      case BugSeverity.medium:
        return 'Medium';
      case BugSeverity.high:
        return 'High';
      case BugSeverity.critical:
        return 'Critical';
    }
  }

  /// Get severity color
  static Color getSeverityColor(BugSeverity severity) {
    switch (severity) {
      case BugSeverity.low:
        return Colors.green;
      case BugSeverity.medium:
        return Colors.orange;
      case BugSeverity.high:
        return Colors.red;
      case BugSeverity.critical:
        return Colors.red.shade900;
    }
  }

  /// Get category icon
  static IconData getCategoryIcon(BugCategory category) {
    switch (category) {
      case BugCategory.ui:
        return Icons.design_services;
      case BugCategory.functionality:
        return Icons.build;
      case BugCategory.performance:
        return Icons.speed;
      case BugCategory.crash:
        return Icons.error_outline;
      case BugCategory.login:
        return Icons.login;
      case BugCategory.avatar:
        return Icons.smart_toy;
      case BugCategory.content:
        return Icons.content_copy;
      case BugCategory.network:
        return Icons.wifi_off;
      case BugCategory.other:
        return Icons.help_outline;
    }
  }
}
