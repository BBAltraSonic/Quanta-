import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'analytics_service.dart';

enum FeedbackType { feature, improvement, bug, general, rating }

enum FeedbackPriority { low, medium, high }

class UserFeedback {
  final String id;
  final String? userId;
  final String? userEmail;
  final FeedbackType type;
  final FeedbackPriority priority;
  final String title;
  final String description;
  final int? rating; // 1-5 stars
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String status;

  UserFeedback({
    required this.id,
    this.userId,
    this.userEmail,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    this.rating,
    required this.metadata,
    required this.createdAt,
    this.status = 'submitted',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'description': description,
      'rating': rating,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }
}

class UserFeedbackService {
  static final UserFeedbackService _instance = UserFeedbackService._internal();
  factory UserFeedbackService() => _instance;
  UserFeedbackService._internal();

  final List<UserFeedback> _localFeedback = [];
  final AuthService _authService = AuthService();
  final AnalyticsService _analyticsService = AnalyticsService();

  /// Submit user feedback
  Future<String> submitFeedback({
    required FeedbackType type,
    required String title,
    required String description,
    int? rating,
    FeedbackPriority priority = FeedbackPriority.medium,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final user = _authService.currentUser;
    final feedbackId = const Uuid().v4();

    // Collect system metadata
    final metadata = {
      'app_version': '1.0.0+1',
      'platform': 'flutter',
      'timestamp': DateTime.now().toIso8601String(),
      'user_agent': 'Quanta Mobile App',
      ...?additionalMetadata,
    };

    final feedback = UserFeedback(
      id: feedbackId,
      userId: user?.id,
      userEmail: user?.email,
      type: type,
      priority: priority,
      title: title,
      description: description,
      rating: rating,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    // Store locally first
    _localFeedback.add(feedback);

    try {
      // Send to backend/email service
      await _sendFeedbackToBackend(feedback);

      // Track analytics event
      _analyticsService.trackEvent('feedback_submitted', {
        'feedback_type': type.name,
        'feedback_priority': priority.name,
        'has_rating': rating != null,
        'user_id': user?.id,
      });

      return feedbackId;
    } catch (e) {
      debugPrint('Failed to send feedback to backend: $e');
      // Keep in local storage for retry later
      return feedbackId;
    }
  }

  /// Submit app rating
  Future<void> submitAppRating(int rating, {String? comment}) async {
    await submitFeedback(
      type: FeedbackType.rating,
      title: 'App Rating',
      description: comment ?? 'User rated the app $rating stars',
      rating: rating,
      priority: FeedbackPriority.low,
      additionalMetadata: {
        'rating_stars': rating,
        'has_comment': comment != null,
      },
    );
  }

  /// Submit feature request
  Future<String> submitFeatureRequest({
    required String title,
    required String description,
    FeedbackPriority priority = FeedbackPriority.medium,
  }) async {
    return await submitFeedback(
      type: FeedbackType.feature,
      title: title,
      description: description,
      priority: priority,
      additionalMetadata: {'is_feature_request': true},
    );
  }

  /// Submit improvement suggestion
  Future<String> submitImprovement({
    required String title,
    required String description,
    String? currentBehavior,
    String? suggestedBehavior,
  }) async {
    return await submitFeedback(
      type: FeedbackType.improvement,
      title: title,
      description: description,
      priority: FeedbackPriority.medium,
      additionalMetadata: {
        'current_behavior': currentBehavior,
        'suggested_behavior': suggestedBehavior,
        'is_improvement': true,
      },
    );
  }

  /// Get local feedback history
  List<UserFeedback> getLocalFeedback() {
    return List.from(_localFeedback);
  }

  /// Check if user should be prompted for feedback
  bool shouldPromptForFeedback() {
    // Simple logic - can be enhanced with more sophisticated timing
    final lastFeedback = _getLastFeedbackTime();
    if (lastFeedback == null) return true;

    final daysSinceLastFeedback = DateTime.now()
        .difference(lastFeedback)
        .inDays;
    return daysSinceLastFeedback >= 30; // Prompt every 30 days
  }

  /// Check if user should be prompted for rating
  bool shouldPromptForRating() {
    // Prompt for rating after significant app usage
    final lastRating = _getLastRatingTime();
    if (lastRating == null) {
      // Check if user has used app enough times
      return _hasUsedAppSignificantly();
    }

    final daysSinceLastRating = DateTime.now().difference(lastRating).inDays;
    return daysSinceLastRating >= 90; // Prompt every 3 months
  }

  /// Send feedback to backend service
  Future<void> _sendFeedbackToBackend(UserFeedback feedback) async {
    // In a real implementation, this would send to your backend API
    // For now, we'll simulate by printing the feedback
    debugPrint('Sending feedback to backend: ${feedback.toJson()}');

    // You could also send via email service
    await _sendFeedbackViaEmail(feedback);
  }

  /// Send feedback via email
  Future<void> _sendFeedbackViaEmail(UserFeedback feedback) async {
    try {
      // This would integrate with your email service
      // For example, using a service like SendGrid, Mailgun, etc.

      final emailBody =
          '''
Feedback Submission - ${feedback.type.name.toUpperCase()}

Title: ${feedback.title}
Priority: ${feedback.priority.name}
${feedback.rating != null ? 'Rating: ${feedback.rating}/5 stars' : ''}

Description:
${feedback.description}

User Information:
- User ID: ${feedback.userId ?? 'Anonymous'}
- Email: ${feedback.userEmail ?? 'Not provided'}
- Submitted: ${feedback.createdAt}

Technical Information:
${feedback.metadata.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}
''';

      debugPrint('Would send email with body: $emailBody');

      // Actual email sending would happen here
      // await emailService.send(
      //   to: 'feedback@quanta-app.com',
      //   subject: 'User Feedback: ${feedback.title}',
      //   body: emailBody,
      // );
    } catch (e) {
      debugPrint('Failed to send feedback email: $e');
      rethrow;
    }
  }

  /// Get last feedback submission time
  DateTime? _getLastFeedbackTime() {
    if (_localFeedback.isEmpty) return null;

    final sortedFeedback = List<UserFeedback>.from(_localFeedback)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedFeedback.first.createdAt;
  }

  /// Get last rating submission time
  DateTime? _getLastRatingTime() {
    final ratings = _localFeedback
        .where((f) => f.type == FeedbackType.rating)
        .toList();

    if (ratings.isEmpty) return null;

    ratings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ratings.first.createdAt;
  }

  /// Check if user has used app significantly
  bool _hasUsedAppSignificantly() {
    // This would check analytics data for user engagement
    // For example: posts created, time spent, sessions, etc.

    // Simple implementation - assume significant usage after 7 days
    // In real app, this would check actual usage metrics
    return true; // Placeholder
  }

  /// Get feedback type display name
  static String getFeedbackTypeDisplayName(FeedbackType type) {
    switch (type) {
      case FeedbackType.feature:
        return 'Feature Request';
      case FeedbackType.improvement:
        return 'Improvement Suggestion';
      case FeedbackType.bug:
        return 'Bug Report';
      case FeedbackType.general:
        return 'General Feedback';
      case FeedbackType.rating:
        return 'App Rating';
    }
  }

  /// Get feedback priority display name
  static String getFeedbackPriorityDisplayName(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.low:
        return 'Low Priority';
      case FeedbackPriority.medium:
        return 'Medium Priority';
      case FeedbackPriority.high:
        return 'High Priority';
    }
  }

  /// Get feedback type color
  static Color getFeedbackTypeColor(FeedbackType type) {
    switch (type) {
      case FeedbackType.feature:
        return Colors.blue;
      case FeedbackType.improvement:
        return Colors.green;
      case FeedbackType.bug:
        return Colors.red;
      case FeedbackType.general:
        return Colors.grey;
      case FeedbackType.rating:
        return Colors.amber;
    }
  }

  /// Get feedback priority color
  static Color getFeedbackPriorityColor(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.low:
        return Colors.green;
      case FeedbackPriority.medium:
        return Colors.orange;
      case FeedbackPriority.high:
        return Colors.red;
    }
  }

  /// Show rating prompt dialog
  static void showRatingPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Quanta'),
        content: const Text(
          'Enjoying your experience with AI avatars? Please rate us in the app store!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Open app store rating
              _openStoreRating();
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  /// Open store rating
  static void _openStoreRating() {
    // This would open the appropriate app store
    // iOS: App Store
    // Android: Google Play Store
    debugPrint('Would open store rating');
  }

  /// Show feedback prompt dialog
  static void showFeedbackPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Your Feedback'),
        content: const Text(
          'Help us improve Quanta! Share your thoughts, suggestions, or report any issues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to feedback screen
              // Navigator.pushNamed(context, '/feedback');
            },
            child: const Text('Give Feedback'),
          ),
        ],
      ),
    );
  }
}
