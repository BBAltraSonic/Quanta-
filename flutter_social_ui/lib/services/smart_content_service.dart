import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/avatar_model.dart';
import '../models/post_model.dart';
import '../utils/environment.dart';
import 'ai_service.dart';

class ContentSuggestion {
  final String text;
  final double confidence;
  final String type;
  final Map<String, dynamic>? metadata;

  ContentSuggestion({
    required this.text,
    required this.confidence,
    required this.type,
    this.metadata,
  });
}

class HashtagSuggestion {
  final String hashtag;
  final double relevanceScore;
  final int trendingScore;
  final String category;

  HashtagSuggestion({
    required this.hashtag,
    required this.relevanceScore,
    required this.trendingScore,
    required this.category,
  });
}

class TrendingTopic {
  final String topic;
  final double trendingScore;
  final String category;
  final List<String> relatedHashtags;
  final String description;

  TrendingTopic({
    required this.topic,
    required this.trendingScore,
    required this.category,
    required this.relatedHashtags,
    required this.description,
  });
}

class ContentOptimizationTip {
  final String title;
  final String description;
  final String category;
  final double impactScore;
  final bool isActionable;

  ContentOptimizationTip({
    required this.title,
    required this.description,
    required this.category,
    required this.impactScore,
    required this.isActionable,
  });
}

class EngagementPrediction {
  final double predictedLikes;
  final double predictedComments;
  final double predictedShares;
  final double overallEngagementScore;
  final List<String> improvementSuggestions;
  final Map<String, double> factorContributions;

  EngagementPrediction({
    required this.predictedLikes,
    required this.predictedComments,
    required this.predictedShares,
    required this.overallEngagementScore,
    required this.improvementSuggestions,
    required this.factorContributions,
  });
}

class SmartContentService {
  static final SmartContentService _instance = SmartContentService._internal();
  factory SmartContentService() => _instance;
  SmartContentService._internal();

  final AIService _aiService = AIService();

  // Trending hashtags database (in production, this would come from analytics)
  static const Map<String, List<String>> _trendingHashtags = {
    'fitness': [
      '#FitnessMotivation',
      '#WorkoutWednesday',
      '#HealthyLifestyle',
      '#FitLife',
      '#GymTime',
    ],
    'tech': [
      '#TechTrends',
      '#Innovation',
      '#AI',
      '#TechTalk',
      '#DigitalTransformation',
    ],
    'cooking': [
      '#FoodieLife',
      '#CookingTips',
      '#RecipeOfTheDay',
      '#HomeCooking',
      '#FoodLover',
    ],
    'travel': [
      '#Wanderlust',
      '#TravelTips',
      '#Adventure',
      '#ExploreMore',
      '#TravelDiaries',
    ],
    'art': [
      '#ArtisticExpression',
      '#CreativeProcess',
      '#ArtDaily',
      '#Inspiration',
      '#ArtCommunity',
    ],
    'music': [
      '#MusicLovers',
      '#NewMusic',
      '#SongOfTheDay',
      '#MusicProduction',
      '#LiveMusic',
    ],
  };

  // Generate AI-powered caption suggestions
  Future<List<ContentSuggestion>> generateCaptionSuggestions({
    required String contentDescription,
    required AvatarModel avatar,
    String? existingCaption,
    int maxSuggestions = 5,
  }) async {
    try {
      final suggestions = <ContentSuggestion>[];

      // Generate personality-based captions
      final personalityCaptions = _generatePersonalityBasedCaptions(
        contentDescription,
        avatar,
        existingCaption,
      );
      suggestions.addAll(personalityCaptions);

      // Generate niche-specific captions
      final nicheCaptions = _generateNicheSpecificCaptions(
        contentDescription,
        avatar.niche,
      );
      suggestions.addAll(nicheCaptions);

      // Generate trending-style captions
      final trendingCaptions = _generateTrendingStyleCaptions(
        contentDescription,
        avatar.niche,
      );
      suggestions.addAll(trendingCaptions);

      // Sort by confidence and return top suggestions
      suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
      return suggestions.take(maxSuggestions).toList();
    } catch (e) {
      // Return fallback suggestions
      return _getFallbackCaptions(contentDescription, avatar);
    }
  }

  // Generate smart hashtag recommendations
  Future<List<HashtagSuggestion>> generateHashtagRecommendations({
    required String caption,
    required AvatarModel avatar,
    String? contentDescription,
    int maxHashtags = 10,
  }) async {
    try {
      final hashtags = <HashtagSuggestion>[];

      // Get niche-specific hashtags
      final nicheHashtags = _getNicheHashtags(avatar.niche);
      hashtags.addAll(nicheHashtags);

      // Extract content-based hashtags
      final contentHashtags = _extractContentHashtags(
        caption,
        contentDescription,
      );
      hashtags.addAll(contentHashtags);

      // Add trending hashtags
      final trendingHashtags = _getTrendingHashtags(avatar.niche);
      hashtags.addAll(trendingHashtags);

      // Add personality-based hashtags
      final personalityHashtags = _getPersonalityHashtags(
        avatar.personalityTraits,
      );
      hashtags.addAll(personalityHashtags);

      // Remove duplicates and sort by relevance
      final uniqueHashtags = _removeDuplicateHashtags(hashtags);
      uniqueHashtags.sort(
        (a, b) => b.relevanceScore.compareTo(a.relevanceScore),
      );

      return uniqueHashtags.take(maxHashtags).toList();
    } catch (e) {
      return _getFallbackHashtags(avatar.niche);
    }
  }

  // Get trending topics for content inspiration
  Future<List<TrendingTopic>> getTrendingTopics({
    AvatarNiche? niche,
    int maxTopics = 10,
  }) async {
    try {
      final topics = <TrendingTopic>[];

      // Generate trending topics based on niche
      if (niche != null) {
        topics.addAll(_getNicheTrendingTopics(niche));
      } else {
        // Get general trending topics
        for (final nicheType in AvatarNiche.values) {
          topics.addAll(_getNicheTrendingTopics(nicheType));
        }
      }

      // Sort by trending score
      topics.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
      return topics.take(maxTopics).toList();
    } catch (e) {
      return _getFallbackTrendingTopics();
    }
  }

  // Generate content optimization tips
  Future<List<ContentOptimizationTip>> generateOptimizationTips({
    required String caption,
    required AvatarModel avatar,
    String? contentDescription,
    List<String>? hashtags,
  }) async {
    try {
      final tips = <ContentOptimizationTip>[];

      // Analyze caption length
      tips.addAll(_analyzeCaptionLength(caption));

      // Analyze hashtag usage
      if (hashtags != null) {
        tips.addAll(_analyzeHashtagUsage(hashtags, avatar.niche));
      }

      // Analyze personality alignment
      tips.addAll(_analyzePersonalityAlignment(caption, avatar));

      // Analyze engagement potential
      tips.addAll(_analyzeEngagementPotential(caption, contentDescription));

      // Sort by impact score
      tips.sort((a, b) => b.impactScore.compareTo(a.impactScore));
      return tips;
    } catch (e) {
      return _getFallbackOptimizationTips();
    }
  }

  // Predict engagement for content
  Future<EngagementPrediction> predictEngagement({
    required String caption,
    required AvatarModel avatar,
    String? contentDescription,
    List<String>? hashtags,
    DateTime? postTime,
  }) async {
    try {
      // Calculate base engagement factors
      final captionScore = _calculateCaptionEngagementScore(caption);
      final hashtagScore = _calculateHashtagEngagementScore(
        hashtags ?? [],
        avatar.niche,
      );
      final personalityScore = _calculatePersonalityEngagementScore(
        caption,
        avatar,
      );
      final timingScore = _calculateTimingScore(postTime ?? DateTime.now());
      final nicheScore = _calculateNicheEngagementScore(avatar.niche);

      // Weighted combination of factors
      final factorContributions = {
        'caption_quality': captionScore * 0.3,
        'hashtag_effectiveness': hashtagScore * 0.25,
        'personality_alignment': personalityScore * 0.2,
        'posting_time': timingScore * 0.15,
        'niche_popularity': nicheScore * 0.1,
      };

      final overallScore = factorContributions.values.reduce((a, b) => a + b);

      // Predict specific metrics based on overall score
      final baseLikes = avatar.followersCount * 0.05; // 5% base engagement
      final predictedLikes = baseLikes * (1 + overallScore);
      final predictedComments =
          predictedLikes * 0.1; // 10% of likes typically comment
      final predictedShares =
          predictedLikes * 0.02; // 2% of likes typically share

      // Generate improvement suggestions
      final improvements = _generateEngagementImprovements(
        captionScore,
        hashtagScore,
        personalityScore,
        timingScore,
      );

      return EngagementPrediction(
        predictedLikes: predictedLikes,
        predictedComments: predictedComments,
        predictedShares: predictedShares,
        overallEngagementScore: overallScore,
        improvementSuggestions: improvements,
        factorContributions: factorContributions,
      );
    } catch (e) {
      return _getFallbackEngagementPrediction();
    }
  }

  // Private helper methods

  List<ContentSuggestion> _generatePersonalityBasedCaptions(
    String contentDescription,
    AvatarModel avatar,
    String? existingCaption,
  ) {
    final suggestions = <ContentSuggestion>[];
    final traits = avatar.personalityTraits;

    if (traits.contains(PersonalityTrait.friendly)) {
      suggestions.add(
        ContentSuggestion(
          text: "Hey everyone! 😊 $contentDescription What do you think?",
          confidence: 0.8,
          type: 'friendly',
        ),
      );
    }

    if (traits.contains(PersonalityTrait.humorous)) {
      suggestions.add(
        ContentSuggestion(
          text:
              "$contentDescription (and yes, I'm as surprised as you are! 😄)",
          confidence: 0.75,
          type: 'humorous',
        ),
      );
    }

    if (traits.contains(PersonalityTrait.inspiring)) {
      suggestions.add(
        ContentSuggestion(
          text:
              "✨ $contentDescription Remember, every small step counts towards your dreams! 💪",
          confidence: 0.85,
          type: 'inspiring',
        ),
      );
    }

    if (traits.contains(PersonalityTrait.professional)) {
      suggestions.add(
        ContentSuggestion(
          text: "$contentDescription Here are my thoughts on this topic.",
          confidence: 0.7,
          type: 'professional',
        ),
      );
    }

    return suggestions;
  }

  List<ContentSuggestion> _generateNicheSpecificCaptions(
    String contentDescription,
    AvatarNiche niche,
  ) {
    final suggestions = <ContentSuggestion>[];

    switch (niche) {
      case AvatarNiche.fitness:
        suggestions.add(
          ContentSuggestion(
            text:
                "💪 $contentDescription Your fitness journey starts with one step! #FitnessMotivation",
            confidence: 0.9,
            type: 'niche_fitness',
          ),
        );
        break;
      case AvatarNiche.tech:
        suggestions.add(
          ContentSuggestion(
            text:
                "🚀 $contentDescription The future of technology is here! #TechInnovation",
            confidence: 0.9,
            type: 'niche_tech',
          ),
        );
        break;
      case AvatarNiche.cooking:
        suggestions.add(
          ContentSuggestion(
            text:
                "👨‍🍳 $contentDescription Cooking is love made visible! #FoodieLife",
            confidence: 0.9,
            type: 'niche_cooking',
          ),
        );
        break;
      case AvatarNiche.travel:
        suggestions.add(
          ContentSuggestion(
            text:
                "✈️ $contentDescription Adventure awaits around every corner! #Wanderlust",
            confidence: 0.9,
            type: 'niche_travel',
          ),
        );
        break;
      case AvatarNiche.art:
        suggestions.add(
          ContentSuggestion(
            text:
                "🎨 $contentDescription Art speaks where words fail! #CreativeExpression",
            confidence: 0.9,
            type: 'niche_art',
          ),
        );
        break;
      case AvatarNiche.music:
        suggestions.add(
          ContentSuggestion(
            text:
                "🎵 $contentDescription Music is the universal language of the soul! #MusicLovers",
            confidence: 0.9,
            type: 'niche_music',
          ),
        );
        break;
      default:
        suggestions.add(
          ContentSuggestion(
            text: "$contentDescription Sharing my thoughts with you all! ✨",
            confidence: 0.6,
            type: 'general',
          ),
        );
    }

    return suggestions;
  }

  List<ContentSuggestion> _generateTrendingStyleCaptions(
    String contentDescription,
    AvatarNiche niche,
  ) {
    final trendingStyles = [
      "POV: $contentDescription 👀",
      "Tell me you $contentDescription without telling me you $contentDescription 😏",
      "This is your sign to $contentDescription ✨",
      "Nobody: \nMe: $contentDescription 😅",
      "When you realize $contentDescription 🤯",
    ];

    return trendingStyles
        .map(
          (style) => ContentSuggestion(
            text: style,
            confidence: 0.65,
            type: 'trending',
          ),
        )
        .toList();
  }

  List<HashtagSuggestion> _getNicheHashtags(AvatarNiche niche) {
    final nicheKey = niche.toString().split('.').last;
    final hashtags = _trendingHashtags[nicheKey] ?? [];

    return hashtags
        .map(
          (tag) => HashtagSuggestion(
            hashtag: tag,
            relevanceScore: 0.9,
            trendingScore: Random().nextInt(100),
            category: nicheKey,
          ),
        )
        .toList();
  }

  List<HashtagSuggestion> _extractContentHashtags(
    String caption,
    String? contentDescription,
  ) {
    final hashtags = <HashtagSuggestion>[];
    final words = ('$caption ${contentDescription ?? ''}').toLowerCase().split(
      RegExp(r'\W+'),
    );

    // Simple keyword to hashtag mapping
    final keywordMap = {
      'motivation': '#Motivation',
      'inspiration': '#Inspiration',
      'success': '#Success',
      'growth': '#PersonalGrowth',
      'learning': '#Learning',
      'creativity': '#Creativity',
      'innovation': '#Innovation',
      'community': '#Community',
      'lifestyle': '#Lifestyle',
      'wellness': '#Wellness',
    };

    for (final word in words) {
      if (keywordMap.containsKey(word)) {
        hashtags.add(
          HashtagSuggestion(
            hashtag: keywordMap[word]!,
            relevanceScore: 0.8,
            trendingScore: Random().nextInt(80),
            category: 'content_based',
          ),
        );
      }
    }

    return hashtags;
  }

  List<HashtagSuggestion> _getTrendingHashtags(AvatarNiche niche) {
    // Simulate trending hashtags (in production, this would come from real analytics)
    final trending = ['#Trending', '#Viral', '#ForYou', '#Explore', '#Daily'];

    return trending
        .map(
          (tag) => HashtagSuggestion(
            hashtag: tag,
            relevanceScore: 0.7,
            trendingScore: Random().nextInt(100) + 50, // Higher trending scores
            category: 'trending',
          ),
        )
        .toList();
  }

  List<HashtagSuggestion> _getPersonalityHashtags(
    List<PersonalityTrait> traits,
  ) {
    final hashtags = <HashtagSuggestion>[];

    for (final trait in traits) {
      switch (trait) {
        case PersonalityTrait.friendly:
          hashtags.add(
            HashtagSuggestion(
              hashtag: '#Friendly',
              relevanceScore: 0.6,
              trendingScore: 30,
              category: 'personality',
            ),
          );
          break;
        case PersonalityTrait.humorous:
          hashtags.add(
            HashtagSuggestion(
              hashtag: '#Funny',
              relevanceScore: 0.6,
              trendingScore: 40,
              category: 'personality',
            ),
          );
          break;
        case PersonalityTrait.inspiring:
          hashtags.add(
            HashtagSuggestion(
              hashtag: '#Inspiring',
              relevanceScore: 0.6,
              trendingScore: 35,
              category: 'personality',
            ),
          );
          break;
        default:
          break;
      }
    }

    return hashtags;
  }

  List<HashtagSuggestion> _removeDuplicateHashtags(
    List<HashtagSuggestion> hashtags,
  ) {
    final seen = <String>{};
    return hashtags.where((hashtag) => seen.add(hashtag.hashtag)).toList();
  }

  // Additional helper methods for optimization tips, engagement prediction, etc.
  List<ContentOptimizationTip> _analyzeCaptionLength(String caption) {
    final tips = <ContentOptimizationTip>[];

    if (caption.length < 50) {
      tips.add(
        ContentOptimizationTip(
          title: 'Caption Too Short',
          description:
              'Consider adding more context or personality to your caption. Longer captions often perform better.',
          category: 'caption_length',
          impactScore: 0.7,
          isActionable: true,
        ),
      );
    } else if (caption.length > 300) {
      tips.add(
        ContentOptimizationTip(
          title: 'Caption Might Be Too Long',
          description:
              'Very long captions can lose reader attention. Consider breaking it into paragraphs or shortening.',
          category: 'caption_length',
          impactScore: 0.5,
          isActionable: true,
        ),
      );
    }

    return tips;
  }

  List<ContentOptimizationTip> _analyzeHashtagUsage(
    List<String> hashtags,
    AvatarNiche niche,
  ) {
    final tips = <ContentOptimizationTip>[];

    if (hashtags.length < 3) {
      tips.add(
        ContentOptimizationTip(
          title: 'Add More Hashtags',
          description:
              'Using 5-10 relevant hashtags can significantly increase your content\'s discoverability.',
          category: 'hashtags',
          impactScore: 0.8,
          isActionable: true,
        ),
      );
    } else if (hashtags.length > 15) {
      tips.add(
        ContentOptimizationTip(
          title: 'Too Many Hashtags',
          description:
              'Using too many hashtags can look spammy. Focus on 5-10 highly relevant ones.',
          category: 'hashtags',
          impactScore: 0.6,
          isActionable: true,
        ),
      );
    }

    return tips;
  }

  double _calculateCaptionEngagementScore(String caption) {
    double score = 0.5; // Base score

    // Length factor
    if (caption.length >= 50 && caption.length <= 200) score += 0.2;

    // Question factor (encourages engagement)
    if (caption.contains('?')) score += 0.15;

    // Emoji factor
    final emojiCount = RegExp(
      r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]',
      unicode: true,
    ).allMatches(caption).length;
    if (emojiCount > 0 && emojiCount <= 5) score += 0.1;

    // Call to action factor
    final cta = [
      'comment',
      'share',
      'like',
      'follow',
      'tag',
      'tell me',
      'what do you think',
    ];
    for (final phrase in cta) {
      if (caption.toLowerCase().contains(phrase)) {
        score += 0.05;
        break;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  double _calculateHashtagEngagementScore(
    List<String> hashtags,
    AvatarNiche niche,
  ) {
    if (hashtags.isEmpty) return 0.3;

    double score = 0.5;

    // Optimal count bonus
    if (hashtags.length >= 5 && hashtags.length <= 10) score += 0.2;

    // Niche relevance bonus (simplified)
    final nicheHashtags =
        _trendingHashtags[niche.toString().split('.').last] ?? [];
    final relevantCount = hashtags
        .where(
          (tag) => nicheHashtags.any(
            (niche) => niche.toLowerCase().contains(
              tag.toLowerCase().replaceAll('#', ''),
            ),
          ),
        )
        .length;

    score += (relevantCount / hashtags.length) * 0.3;

    return score.clamp(0.0, 1.0);
  }

  double _calculatePersonalityEngagementScore(
    String caption,
    AvatarModel avatar,
  ) {
    double score = 0.5;
    final lowerCaption = caption.toLowerCase();

    for (final trait in avatar.personalityTraits) {
      switch (trait) {
        case PersonalityTrait.friendly:
          if (lowerCaption.contains(
            RegExp(r'\b(hi|hello|thanks|please|love)\b'),
          )) {
            score += 0.1;
          }
          break;
        case PersonalityTrait.humorous:
          if (lowerCaption.contains(RegExp(r'😄|😅|😊|haha|lol|funny'))) {
            score += 0.1;
          }
          break;
        case PersonalityTrait.inspiring:
          if (lowerCaption.contains(
            RegExp(r'\b(inspire|motivate|dream|achieve|believe)\b'),
          )) {
            score += 0.1;
          }
          break;
        default:
          break;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  double _calculateTimingScore(DateTime postTime) {
    final hour = postTime.hour;

    // Peak engagement hours (simplified)
    if ((hour >= 9 && hour <= 11) || (hour >= 19 && hour <= 21)) {
      return 0.8;
    } else if ((hour >= 12 && hour <= 14) || (hour >= 17 && hour <= 19)) {
      return 0.6;
    } else {
      return 0.4;
    }
  }

  double _calculateNicheEngagementScore(AvatarNiche niche) {
    // Simplified niche popularity scores
    switch (niche) {
      case AvatarNiche.fitness:
      case AvatarNiche.tech:
        return 0.8;
      case AvatarNiche.cooking:
      case AvatarNiche.travel:
        return 0.7;
      case AvatarNiche.art:
      case AvatarNiche.music:
        return 0.6;
      default:
        return 0.5;
    }
  }

  // Fallback methods for error cases
  List<ContentSuggestion> _getFallbackCaptions(
    String contentDescription,
    AvatarModel avatar,
  ) {
    return [
      ContentSuggestion(
        text: "$contentDescription ✨",
        confidence: 0.5,
        type: 'fallback',
      ),
      ContentSuggestion(
        text: "Sharing this with you all! $contentDescription",
        confidence: 0.4,
        type: 'fallback',
      ),
    ];
  }

  List<HashtagSuggestion> _getFallbackHashtags(AvatarNiche niche) {
    return [
      HashtagSuggestion(
        hashtag: '#Daily',
        relevanceScore: 0.5,
        trendingScore: 20,
        category: 'fallback',
      ),
      HashtagSuggestion(
        hashtag: '#Share',
        relevanceScore: 0.4,
        trendingScore: 15,
        category: 'fallback',
      ),
    ];
  }

  List<TrendingTopic> _getNicheTrendingTopics(AvatarNiche niche) {
    // Simplified trending topics by niche
    switch (niche) {
      case AvatarNiche.fitness:
        return [
          TrendingTopic(
            topic: 'Home Workouts',
            trendingScore: 0.9,
            category: 'fitness',
            relatedHashtags: [
              '#HomeWorkout',
              '#FitnessAtHome',
              '#WorkoutMotivation',
            ],
            description: 'Effective exercises you can do at home',
          ),
        ];
      case AvatarNiche.tech:
        return [
          TrendingTopic(
            topic: 'AI Innovation',
            trendingScore: 0.95,
            category: 'tech',
            relatedHashtags: ['#AI', '#Innovation', '#TechTrends'],
            description: 'Latest developments in artificial intelligence',
          ),
        ];
      default:
        return [];
    }
  }

  List<TrendingTopic> _getFallbackTrendingTopics() {
    return [
      TrendingTopic(
        topic: 'Daily Inspiration',
        trendingScore: 0.6,
        category: 'general',
        relatedHashtags: ['#Inspiration', '#Daily', '#Motivation'],
        description: 'Share your daily dose of inspiration',
      ),
    ];
  }

  List<ContentOptimizationTip> _analyzePersonalityAlignment(
    String caption,
    AvatarModel avatar,
  ) {
    // Simplified personality alignment analysis
    return [];
  }

  List<ContentOptimizationTip> _analyzeEngagementPotential(
    String caption,
    String? contentDescription,
  ) {
    // Simplified engagement potential analysis
    return [];
  }

  List<ContentOptimizationTip> _getFallbackOptimizationTips() {
    return [
      ContentOptimizationTip(
        title: 'Add a Call to Action',
        description:
            'Encourage your audience to engage by asking a question or requesting feedback.',
        category: 'engagement',
        impactScore: 0.7,
        isActionable: true,
      ),
    ];
  }

  List<String> _generateEngagementImprovements(
    double captionScore,
    double hashtagScore,
    double personalityScore,
    double timingScore,
  ) {
    final improvements = <String>[];

    if (captionScore < 0.6) {
      improvements.add(
        'Improve caption quality by adding more context or personality',
      );
    }
    if (hashtagScore < 0.6) {
      improvements.add('Use more relevant and trending hashtags');
    }
    if (personalityScore < 0.6) {
      improvements.add('Align content better with your avatar\'s personality');
    }
    if (timingScore < 0.6) {
      improvements.add('Consider posting during peak engagement hours');
    }

    return improvements;
  }

  EngagementPrediction _getFallbackEngagementPrediction() {
    return EngagementPrediction(
      predictedLikes: 10.0,
      predictedComments: 2.0,
      predictedShares: 1.0,
      overallEngagementScore: 0.5,
      improvementSuggestions: ['Add more engaging content'],
      factorContributions: {'overall': 0.5},
    );
  }
}
