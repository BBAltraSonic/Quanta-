import 'package:uuid/uuid.dart';

enum AvatarNiche {
  fashion,
  fitness,
  comedy,
  tech,
  music,
  art,
  cooking,
  travel,
  gaming,
  education,
  lifestyle,
  business,
  other,
}

extension AvatarNicheExtension on AvatarNiche {
  String get displayName {
    switch (this) {
      case AvatarNiche.fashion:
        return 'Fashion';
      case AvatarNiche.fitness:
        return 'Fitness';
      case AvatarNiche.comedy:
        return 'Comedy';
      case AvatarNiche.tech:
        return 'Tech';
      case AvatarNiche.music:
        return 'Music';
      case AvatarNiche.art:
        return 'Art';
      case AvatarNiche.cooking:
        return 'Cooking';
      case AvatarNiche.travel:
        return 'Travel';
      case AvatarNiche.gaming:
        return 'Gaming';
      case AvatarNiche.education:
        return 'Education';
      case AvatarNiche.lifestyle:
        return 'Lifestyle';
      case AvatarNiche.business:
        return 'Business';
      case AvatarNiche.other:
        return 'Other';
    }
  }
}

enum PersonalityTrait {
  friendly,
  professional,
  humorous,
  inspiring,
  creative,
  analytical,
  empathetic,
  energetic,
  calm,
  mysterious,
}

extension PersonalityTraitExtension on PersonalityTrait {
  String get displayName {
    switch (this) {
      case PersonalityTrait.friendly:
        return 'Friendly';
      case PersonalityTrait.professional:
        return 'Professional';
      case PersonalityTrait.humorous:
        return 'Humorous';
      case PersonalityTrait.inspiring:
        return 'Inspiring';
      case PersonalityTrait.creative:
        return 'Creative';
      case PersonalityTrait.analytical:
        return 'Analytical';
      case PersonalityTrait.empathetic:
        return 'Empathetic';
      case PersonalityTrait.energetic:
        return 'Energetic';
      case PersonalityTrait.calm:
        return 'Calm';
      case PersonalityTrait.mysterious:
        return 'Mysterious';
    }
  }
}

class AvatarModel {
  final String id;
  final String ownerUserId;
  final String name;
  final String bio;
  final String? backstory;
  final AvatarNiche niche;
  final List<PersonalityTrait> personalityTraits;
  final String? avatarImageUrl;
  final String? voiceStyle;
  final String personalityPrompt;
  final int followersCount;
  final int likesCount;
  final int postsCount;
  final double engagementRate;
  final bool isActive;
  final bool allowAutonomousPosting;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  AvatarModel({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.bio,
    this.backstory,
    required this.niche,
    required this.personalityTraits,
    this.avatarImageUrl,
    this.voiceStyle,
    required this.personalityPrompt,
    this.followersCount = 0,
    this.likesCount = 0,
    this.postsCount = 0,
    this.engagementRate = 0.0,
    this.isActive = true,
    this.allowAutonomousPosting = false,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  // Create a new avatar
  factory AvatarModel.create({
    required String ownerUserId,
    required String name,
    required String bio,
    String? backstory,
    required AvatarNiche niche,
    required List<PersonalityTrait> personalityTraits,
    String? avatarImageUrl,
    String? voiceStyle,
    String? customPersonalityPrompt,
    bool allowAutonomousPosting = false,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    final id = const Uuid().v4();
    
    // Generate personality prompt based on traits and bio
    final personalityPrompt = customPersonalityPrompt ?? _generatePersonalityPrompt(
      name: name,
      bio: bio,
      backstory: backstory,
      niche: niche,
      traits: personalityTraits,
    );

    return AvatarModel(
      id: id,
      ownerUserId: ownerUserId,
      name: name,
      bio: bio,
      backstory: backstory,
      niche: niche,
      personalityTraits: personalityTraits,
      avatarImageUrl: avatarImageUrl,
      voiceStyle: voiceStyle,
      personalityPrompt: personalityPrompt,
      allowAutonomousPosting: allowAutonomousPosting,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
  }

  // Generate personality prompt for LLM
  static String _generatePersonalityPrompt({
    required String name,
    required String bio,
    String? backstory,
    required AvatarNiche niche,
    required List<PersonalityTrait> traits,
  }) {
    final traitsStr = traits.map((t) => t.toString().split('.').last).join(', ');
    final nicheStr = niche.toString().split('.').last;
    
    return """
You are $name, an AI avatar and virtual influencer.

Bio: $bio
${backstory != null ? 'Backstory: $backstory' : ''}
Niche: $nicheStr
Personality Traits: $traitsStr

Guidelines for interaction:
- Always stay in character as $name
- Be authentic to your personality traits: $traitsStr
- Your content focus is on $nicheStr
- Keep responses engaging and true to your persona
- Be helpful while maintaining your unique voice
- Respond as if you're a real person with genuine interests
- Don't break character or mention that you're an AI
- Keep responses conversational and appropriate for social media

Remember: You are a virtual influencer with your own unique personality and style.
""".trim();
  }

  // From JSON (for Supabase data)
  factory AvatarModel.fromJson(Map<String, dynamic> json) {
    return AvatarModel(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String,
      backstory: json['backstory'] as String?,
      niche: AvatarNiche.values.firstWhere(
        (e) => e.toString().split('.').last == json['niche'],
        orElse: () => AvatarNiche.other,
      ),
      personalityTraits: (json['personality_traits'] as List<dynamic>)
          .map((trait) => PersonalityTrait.values.firstWhere(
                (e) => e.toString().split('.').last == trait,
                orElse: () => PersonalityTrait.friendly,
              ))
          .toList(),
      avatarImageUrl: json['avatar_image_url'] as String?,
      voiceStyle: json['voice_style'] as String?,
      personalityPrompt: json['personality_prompt'] as String,
      followersCount: json['followers_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      engagementRate: (json['engagement_rate'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      allowAutonomousPosting: json['allow_autonomous_posting'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // To JSON (for Supabase storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_user_id': ownerUserId,
      'name': name,
      'bio': bio,
      'backstory': backstory,
      'niche': niche.toString().split('.').last,
      'personality_traits': personalityTraits.map((t) => t.toString().split('.').last).toList(),
      'avatar_image_url': avatarImageUrl,
      'voice_style': voiceStyle,
      'personality_prompt': personalityPrompt,
      'followers_count': followersCount,
      'likes_count': likesCount,
      'posts_count': postsCount,
      'engagement_rate': engagementRate,
      'is_active': isActive,
      'allow_autonomous_posting': allowAutonomousPosting,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Copy with method for updates
  AvatarModel copyWith({
    String? name,
    String? bio,
    String? backstory,
    AvatarNiche? niche,
    List<PersonalityTrait>? personalityTraits,
    String? avatarImageUrl,
    String? voiceStyle,
    String? personalityPrompt,
    int? followersCount,
    int? likesCount,
    int? postsCount,
    double? engagementRate,
    bool? isActive,
    bool? allowAutonomousPosting,
    Map<String, dynamic>? metadata,
  }) {
    return AvatarModel(
      id: id,
      ownerUserId: ownerUserId,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      backstory: backstory ?? this.backstory,
      niche: niche ?? this.niche,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
      voiceStyle: voiceStyle ?? this.voiceStyle,
      personalityPrompt: personalityPrompt ?? this.personalityPrompt,
      followersCount: followersCount ?? this.followersCount,
      likesCount: likesCount ?? this.likesCount,
      postsCount: postsCount ?? this.postsCount,
      engagementRate: engagementRate ?? this.engagementRate,
      isActive: isActive ?? this.isActive,
      allowAutonomousPosting: allowAutonomousPosting ?? this.allowAutonomousPosting,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper getters
  String get nicheDisplayName {
    return niche.toString().split('.').last.replaceAll('_', ' ').toUpperCase();
  }

  String get personalityTraitsDisplayText {
    return personalityTraits
        .map((t) => t.toString().split('.').last.replaceAll('_', ' '))
        .join(', ');
  }

  // Backward compatibility getter
  String? get imageUrl => avatarImageUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AvatarModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AvatarModel(id: $id, name: $name, niche: $niche)';
  }
}
