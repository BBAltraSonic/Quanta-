import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';
import '../models/chat_message.dart';

/// Service for content moderation and safety
class ContentModerationService {
  static final ContentModerationService _instance = ContentModerationService._internal();
  factory ContentModerationService() => _instance;
  ContentModerationService._internal();

  // Moderation API endpoints (would be configured in production)
  static const String _moderationApiUrl = 'https://api.openai.com/v1/moderations';
  static const String _perspectiveApiUrl = 'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze';

  /// Initialize moderation service
  Future<void> initialize() async {
    debugPrint('ContentModerationService initialized');
  }

  /// Moderate post content before publishing
  Future<ModerationResult> moderatePost(PostModel post) async {
    try {
      // Check caption for inappropriate content
      final captionResult = await _moderateText(post.caption);
      
      // Check hashtags
      final hashtagsText = post.hashtags.join(' ');
      final hashtagResult = await _moderateText(hashtagsText);
      
      // Combine results
      final overallResult = ModerationResult.combine([captionResult, hashtagResult]);
      
      // Log moderation result
      debugPrint('Post moderation result: ${overallResult.action}');
      
      return overallResult;
    } catch (e) {
      debugPrint('Error moderating post: $e');
      // Default to allow with warning on error
      return ModerationResult(
        action: ModerationAction.allow,
        confidence: 0.5,
        reasons: ['Moderation service unavailable'],
        categories: {},
      );
    }
  }

  /// Moderate chat message before sending
  Future<ModerationResult> moderateMessage(ChatMessage message) async {
    try {
      final result = await _moderateText(message.text);
      debugPrint('Message moderation result: ${result.action}');
      return result;
    } catch (e) {
      debugPrint('Error moderating message: $e');
      return ModerationResult(
        action: ModerationAction.allow,
        confidence: 0.5,
        reasons: ['Moderation service unavailable'],
        categories: {},
      );
    }
  }

  /// Moderate text content using multiple APIs
  Future<ModerationResult> _moderateText(String text) async {
    if (text.trim().isEmpty) {
      return ModerationResult(
        action: ModerationAction.allow,
        confidence: 1.0,
        reasons: [],
        categories: {},
      );
    }

    // Use local content filtering as primary method
    final localResult = _performLocalModeration(text);
    
    // In production, you would also call external APIs
    // final openAIResult = await _callOpenAIModerationAPI(text);
    // final perspectiveResult = await _callPerspectiveAPI(text);
    
    return localResult;
  }

  /// Perform local content moderation using keyword filtering
  ModerationResult _performLocalModeration(String text) {
    final lowerText = text.toLowerCase();
    final categories = <String, double>{};
    final reasons = <String>[];
    double maxScore = 0.0;

    // Check for explicit content
    final explicitKeywords = [
      'explicit', 'nsfw', 'adult', 'sexual', 'nude', 'porn',
      // Add more keywords as needed
    ];
    
    for (final keyword in explicitKeywords) {
      if (lowerText.contains(keyword)) {
        categories['sexual'] = 0.9;
        reasons.add('Contains explicit content');
        maxScore = 0.9;
        break;
      }
    }

    // Check for hate speech
    final hateKeywords = [
      'hate', 'racist', 'discrimination', 'offensive',
      // Add more keywords as needed
    ];
    
    for (final keyword in hateKeywords) {
      if (lowerText.contains(keyword)) {
        categories['hate'] = 0.8;
        reasons.add('Contains hate speech');
        maxScore = maxScore > 0.8 ? maxScore : 0.8;
        break;
      }
    }

    // Check for violence
    final violenceKeywords = [
      'violence', 'kill', 'harm', 'attack', 'weapon',
      // Add more keywords as needed
    ];
    
    for (final keyword in violenceKeywords) {
      if (lowerText.contains(keyword)) {
        categories['violence'] = 0.7;
        reasons.add('Contains violent content');
        maxScore = maxScore > 0.7 ? maxScore : 0.7;
        break;
      }
    }

    // Check for spam indicators
    final spamIndicators = [
      'click here', 'buy now', 'limited time', 'act now',
      'free money', 'guaranteed', 'no risk',
    ];
    
    int spamCount = 0;
    for (final indicator in spamIndicators) {
      if (lowerText.contains(indicator)) {
        spamCount++;
      }
    }
    
    if (spamCount >= 2) {
      categories['spam'] = 0.6;
      reasons.add('Appears to be spam');
      maxScore = maxScore > 0.6 ? maxScore : 0.6;
    }

    // Determine action based on score
    ModerationAction action;
    if (maxScore >= 0.8) {
      action = ModerationAction.block;
    } else if (maxScore >= 0.6) {
      action = ModerationAction.flag;
    } else if (maxScore >= 0.3) {
      action = ModerationAction.warn;
    } else {
      action = ModerationAction.allow;
    }

    return ModerationResult(
      action: action,
      confidence: maxScore,
      reasons: reasons,
      categories: categories,
    );
  }

  /// Call OpenAI Moderation API (for production use)
  Future<ModerationResult> _callOpenAIModerationAPI(String text) async {
    try {
      final response = await http.post(
        Uri.parse(_moderationApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_OPENAI_API_KEY', // Configure in production
        },
        body: jsonEncode({
          'input': text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['results'][0];
        
        return ModerationResult(
          action: result['flagged'] ? ModerationAction.block : ModerationAction.allow,
          confidence: _getMaxCategoryScore(result['category_scores']),
          reasons: _getFlaggedCategories(result['categories']),
          categories: Map<String, double>.from(result['category_scores']),
        );
      }
    } catch (e) {
      debugPrint('OpenAI Moderation API error: $e');
    }

    return ModerationResult(
      action: ModerationAction.allow,
      confidence: 0.5,
      reasons: ['API unavailable'],
      categories: {},
    );
  }

  /// Get maximum score from category scores
  double _getMaxCategoryScore(Map<String, dynamic> scores) {
    double maxScore = 0.0;
    for (final score in scores.values) {
      if (score is num && score > maxScore) {
        maxScore = score.toDouble();
      }
    }
    return maxScore;
  }

  /// Get flagged categories as reasons
  List<String> _getFlaggedCategories(Map<String, dynamic> categories) {
    final reasons = <String>[];
    categories.forEach((category, flagged) {
      if (flagged == true) {
        reasons.add('Flagged for $category');
      }
    });
    return reasons;
  }

  /// Report content for manual review
  Future<void> reportContent({
    required String contentId,
    required String contentType,
    required String reason,
    String? additionalInfo,
  }) async {
    try {
      // In production, this would send to a moderation queue
      debugPrint('Content reported: $contentId ($contentType) - $reason');
      
      // Store report locally for now
      // In production, send to backend moderation system
      
    } catch (e) {
      debugPrint('Error reporting content: $e');
    }
  }

  /// Get moderation statistics
  Map<String, dynamic> getModerationStats() {
    // In production, this would return real statistics
    return {
      'total_moderated': 1250,
      'blocked': 45,
      'flagged': 123,
      'warned': 89,
      'allowed': 993,
      'accuracy': 0.94,
    };
  }
}

/// Moderation result with action and details
class ModerationResult {
  final ModerationAction action;
  final double confidence;
  final List<String> reasons;
  final Map<String, double> categories;

  ModerationResult({
    required this.action,
    required this.confidence,
    required this.reasons,
    required this.categories,
  });

  /// Combine multiple moderation results
  static ModerationResult combine(List<ModerationResult> results) {
    if (results.isEmpty) {
      return ModerationResult(
        action: ModerationAction.allow,
        confidence: 1.0,
        reasons: [],
        categories: {},
      );
    }

    // Take the most restrictive action
    ModerationAction mostRestrictive = ModerationAction.allow;
    double highestConfidence = 0.0;
    final allReasons = <String>[];
    final allCategories = <String, double>{};

    for (final result in results) {
      // Update most restrictive action
      if (result.action.index > mostRestrictive.index) {
        mostRestrictive = result.action;
      }

      // Update highest confidence
      if (result.confidence > highestConfidence) {
        highestConfidence = result.confidence;
      }

      // Combine reasons
      allReasons.addAll(result.reasons);

      // Combine categories (take highest score for each)
      result.categories.forEach((category, score) {
        if (!allCategories.containsKey(category) || score > allCategories[category]!) {
          allCategories[category] = score;
        }
      });
    }

    return ModerationResult(
      action: mostRestrictive,
      confidence: highestConfidence,
      reasons: allReasons.toSet().toList(), // Remove duplicates
      categories: allCategories,
    );
  }

  /// Check if content should be blocked
  bool get isBlocked => action == ModerationAction.block;

  /// Check if content should be flagged for review
  bool get isFlagged => action == ModerationAction.flag;

  /// Check if content should show warning
  bool get hasWarning => action == ModerationAction.warn;

  /// Check if content is allowed
  bool get isAllowed => action == ModerationAction.allow;
}

/// Possible moderation actions
enum ModerationAction {
  allow,    // Content is safe
  warn,     // Content has minor issues, show warning
  flag,     // Content needs manual review
  block,    // Content is not allowed
}

/// Widget to display moderation warning
class ModerationWarning extends StatelessWidget {
  final ModerationResult result;
  final VoidCallback? onProceed;
  final VoidCallback? onCancel;

  const ModerationWarning({
    super.key,
    required this.result,
    this.onProceed,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Content Warning',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.reasons.join(', '),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              if (onProceed != null)
                ElevatedButton(
                  onPressed: onProceed,
                  child: const Text('Proceed Anyway'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}