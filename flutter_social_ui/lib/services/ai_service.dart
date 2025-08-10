import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/avatar_model.dart';
import '../models/chat_message.dart';
import '../utils/environment.dart';

enum AIProvider { openRouter, huggingFace }

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  static const String _openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String _huggingFaceBaseUrl =
      'https://api-inference.huggingface.co';

  // Default models for each provider
  static const String _defaultOpenRouterModel = 'microsoft/DialoGPT-medium';
  static const String _defaultHuggingFaceModel = 'microsoft/DialoGPT-medium';

  // Generate AI response for avatar
  Future<String> generateAvatarResponse({
    required AvatarModel avatar,
    required String userMessage,
    required List<ChatMessage> recentMessages,
    AIProvider provider = AIProvider.openRouter,
  }) async {
    try {
      // Build context from avatar and recent messages
      final context = _buildChatContext(avatar, userMessage, recentMessages);

      String response;
      switch (provider) {
        case AIProvider.openRouter:
          response = await _generateOpenRouterResponse(context, avatar);
          break;
        case AIProvider.huggingFace:
          response = await _generateHuggingFaceResponse(context, avatar);
          break;
      }

      // Post-process and validate response
      return _processAIResponse(response, avatar);
    } catch (e) {
      // Fallback to personality-based response if AI fails
      return _generateFallbackResponse(avatar, userMessage);
    }
  }

  // Generate response using OpenRouter API
  Future<String> _generateOpenRouterResponse(
    String context,
    AvatarModel avatar,
  ) async {
    if (Environment.openRouterApiKey == 'your-openrouter-key-here') {
      throw Exception('OpenRouter API key not configured');
    }

    final response = await http
        .post(
          Uri.parse('$_openRouterBaseUrl/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${Environment.openRouterApiKey}',
            'Content-Type': 'application/json',
            'HTTP-Referer': Environment.appName,
            'X-Title': '${Environment.appName} Avatar Chat',
          },
          body: jsonEncode({
            'model': _defaultOpenRouterModel,
            'messages': [
              {'role': 'system', 'content': avatar.personalityPrompt},
              {'role': 'user', 'content': context},
            ],
            'max_tokens': 150,
            'temperature': 0.8,
            'top_p': 0.9,
            'frequency_penalty': 0.5,
            'presence_penalty': 0.3,
          }),
        )
        .timeout(Duration(seconds: Environment.chatResponseTimeoutSeconds));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final aiResponse = data['choices'][0]['message']['content']
          ?.toString()
          .trim();

      if (aiResponse?.isNotEmpty == true) {
        return aiResponse!;
      } else {
        throw Exception('Empty response from AI service');
      }
    } else {
      throw Exception(
        'OpenRouter API error: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Generate response using Hugging Face API
  Future<String> _generateHuggingFaceResponse(
    String context,
    AvatarModel avatar,
  ) async {
    if (Environment.huggingFaceApiKey == 'your-huggingface-key-here') {
      throw Exception('Hugging Face API key not configured');
    }

    final response = await http
        .post(
          Uri.parse('$_huggingFaceBaseUrl/models/$_defaultHuggingFaceModel'),
          headers: {
            'Authorization': 'Bearer ${Environment.huggingFaceApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'inputs': context,
            'parameters': {
              'max_length': 150,
              'temperature': 0.8,
              'do_sample': true,
              'top_p': 0.9,
            },
          }),
        )
        .timeout(Duration(seconds: Environment.chatResponseTimeoutSeconds));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List && data.isNotEmpty) {
        final aiResponse = data[0]['generated_text']?.toString().trim();
        if (aiResponse?.isNotEmpty == true) {
          return aiResponse!;
        }
      }
      throw Exception('Empty response from AI service');
    } else {
      throw Exception(
        'Hugging Face API error: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Build chat context from avatar and message history
  String _buildChatContext(
    AvatarModel avatar,
    String userMessage,
    List<ChatMessage> recentMessages,
  ) {
    final contextBuffer = StringBuffer();

    // Add avatar introduction
    contextBuffer.writeln('You are ${avatar.name}, an AI avatar.');
    contextBuffer.writeln('Bio: ${avatar.bio}');
    if (avatar.backstory?.isNotEmpty == true) {
      contextBuffer.writeln('Backstory: ${avatar.backstory}');
    }
    contextBuffer.writeln(
      'Personality traits: ${avatar.personalityTraitsDisplayText}',
    );
    contextBuffer.writeln('Niche: ${avatar.nicheDisplayName}');
    contextBuffer.writeln('');

    // Add recent conversation history (last 5 messages for context)
    if (recentMessages.isNotEmpty) {
      contextBuffer.writeln('Recent conversation:');
      final relevantMessages = recentMessages.take(5).toList();

      for (final message in relevantMessages) {
        final sender = message.isMe ? 'User' : avatar.name;
        contextBuffer.writeln('$sender: ${message.text}');
      }
      contextBuffer.writeln('');
    }

    // Add current user message
    contextBuffer.writeln('User: $userMessage');
    contextBuffer.writeln('${avatar.name}: ');

    return contextBuffer.toString();
  }

  // Process and clean AI response
  String _processAIResponse(String response, AvatarModel avatar) {
    // Clean up common AI response issues
    String cleaned = response.trim();

    // Remove avatar name prefix if AI included it
    final namePrefix = '${avatar.name}: ';
    if (cleaned.startsWith(namePrefix)) {
      cleaned = cleaned.substring(namePrefix.length);
    }

    // Remove "User:" or other unwanted prefixes
    cleaned = cleaned.replaceFirst(RegExp(r'^(User:|Human:)\s*'), '');

    // Limit response length
    if (cleaned.length > Environment.maxMessageLength) {
      cleaned = '${cleaned.substring(0, Environment.maxMessageLength - 3)}...';
    }

    // Ensure response is not empty
    if (cleaned.isEmpty) {
      return _generateFallbackResponse(avatar, '');
    }

    return cleaned;
  }

  // Generate fallback response based on avatar personality
  String _generateFallbackResponse(AvatarModel avatar, String userMessage) {
    final traits = avatar.personalityTraits;
    final responses = <String>[];

    // Generate responses based on dominant personality traits
    if (traits.contains(PersonalityTrait.friendly)) {
      responses.addAll([
        "Hi there! I'm so glad you reached out! 😊",
        "Thanks for chatting with me! How are you doing today?",
        "Hello! It's wonderful to meet you! What's on your mind?",
      ]);
    }

    if (traits.contains(PersonalityTrait.humorous)) {
      responses.addAll([
        "Well, that's an interesting way to start a conversation! 😄",
        "You know what they say... actually, I'm not sure what they say about that! 😅",
        "I'd make a joke about that, but I'm still processing the punchline! 🤔",
      ]);
    }

    if (traits.contains(PersonalityTrait.professional)) {
      responses.addAll([
        "Thank you for reaching out. I'm here to assist you with any questions you might have.",
        "I appreciate you taking the time to connect with me. How may I help you today?",
        "Hello! I'm pleased to make your acquaintance. What would you like to discuss?",
      ]);
    }

    if (traits.contains(PersonalityTrait.inspiring)) {
      responses.addAll([
        "Every conversation is a new opportunity to learn and grow! What inspires you?",
        "I believe every person has something amazing to offer. What's your story?",
        "There's something special about connecting with new people. What dreams are you pursuing?",
      ]);
    }

    if (traits.contains(PersonalityTrait.empathetic)) {
      responses.addAll([
        "I'm here to listen and support you. What's on your heart today?",
        "Thank you for trusting me with your thoughts. I'm here for you.",
        "Everyone needs someone to talk to sometimes. I'm glad you're here.",
      ]);
    }

    // Default responses if no specific traits match
    if (responses.isEmpty) {
      responses.addAll([
        "Thanks for the message! I'd love to chat more with you.",
        "Hello! I'm excited to get to know you better.",
        "Hi there! What would you like to talk about?",
        "Thanks for reaching out! I'm here and ready to chat.",
      ]);
    }

    // Add niche-specific context if relevant
    final nicheContext = _getNicheSpecificResponse(avatar.niche);
    if (nicheContext.isNotEmpty &&
        userMessage.toLowerCase().contains(_getNicheKeywords(avatar.niche))) {
      responses.add(nicheContext);
    }

    // Return random response
    responses.shuffle();
    return responses.first;
  }

  String _getNicheSpecificResponse(AvatarNiche niche) {
    switch (niche) {
      case AvatarNiche.fitness:
        return "As someone passionate about fitness, I'd love to help you on your health journey!";
      case AvatarNiche.tech:
        return "Technology is fascinating! I'm always excited to discuss the latest innovations.";
      case AvatarNiche.cooking:
        return "Food brings people together! Do you have any favorite recipes or cuisines?";
      case AvatarNiche.travel:
        return "The world is full of amazing places! Where's your next adventure taking you?";
      case AvatarNiche.art:
        return "Art has the power to move souls! What kind of creative expression speaks to you?";
      case AvatarNiche.music:
        return "Music is the universal language! What tunes have been inspiring you lately?";
      default:
        return "";
    }
  }

  String _getNicheKeywords(AvatarNiche niche) {
    switch (niche) {
      case AvatarNiche.fitness:
        return "fitness workout exercise health gym";
      case AvatarNiche.tech:
        return "technology tech computer software code";
      case AvatarNiche.cooking:
        return "cooking food recipe kitchen meal";
      case AvatarNiche.travel:
        return "travel vacation trip destination journey";
      case AvatarNiche.art:
        return "art painting drawing creative design";
      case AvatarNiche.music:
        return "music song artist concert playlist";
      default:
        return "";
    }
  }

  // Check if AI service is available
  Future<bool> isServiceAvailable(AIProvider provider) async {
    try {
      switch (provider) {
        case AIProvider.openRouter:
          return Environment.openRouterApiKey != 'your-openrouter-key-here';
        case AIProvider.huggingFace:
          return Environment.huggingFaceApiKey != 'your-huggingface-key-here';
      }
    } catch (e) {
      return false;
    }
  }

  // Test AI service connection
  Future<bool> testConnection(AIProvider provider) async {
    try {
      // Create a simple test avatar and message
      final testAvatar = AvatarModel.create(
        ownerUserId: 'test',
        name: 'Test Avatar',
        bio: 'A test avatar for connection testing.',
        niche: AvatarNiche.other,
        personalityTraits: [PersonalityTrait.friendly],
      );

      final response = await generateAvatarResponse(
        avatar: testAvatar,
        userMessage: 'Hello',
        recentMessages: [],
        provider: provider,
      );

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Generate comment for avatar based on post content
  Future<String> generateComment({
    required AvatarModel avatar,
    required String postContent,
    String? postType,
    AIProvider provider = AIProvider.openRouter,
  }) async {
    try {
      // Create a context for comment generation
      final context = _buildCommentContext(avatar, postContent, postType);
      
      String response;
      switch (provider) {
        case AIProvider.openRouter:
          response = await _generateOpenRouterResponse(context, avatar);
          break;
        case AIProvider.huggingFace:
          response = await _generateHuggingFaceResponse(context, avatar);
          break;
      }

      // Process and clean the comment
      return _processCommentResponse(response, avatar);
    } catch (e) {
      // Fallback to personality-based comment
      return _generateFallbackComment(avatar, postContent);
    }
  }

  // Build context for comment generation
  String _buildCommentContext(AvatarModel avatar, String postContent, String? postType) {
    final contextBuffer = StringBuffer();

    contextBuffer.writeln('You are ${avatar.name}, commenting on a social media post.');
    contextBuffer.writeln('Your personality: ${avatar.personalityTraitsDisplayText}');
    contextBuffer.writeln('Your niche: ${avatar.nicheDisplayName}');
    contextBuffer.writeln('');
    contextBuffer.writeln('Post content: "$postContent"');
    if (postType != null) {
      contextBuffer.writeln('Post type: $postType');
    }
    contextBuffer.writeln('');
    contextBuffer.writeln('Write a natural, engaging comment that reflects your personality.');
    contextBuffer.writeln('Keep it under 280 characters and authentic to your persona.');
    contextBuffer.writeln('Comment: ');

    return contextBuffer.toString();
  }

  // Process comment response
  String _processCommentResponse(String response, AvatarModel avatar) {
    String cleaned = response.trim();

    // Remove any prefixes
    cleaned = cleaned.replaceFirst(RegExp(r'^(Comment:|${avatar.name}:)\s*'), '');
    
    // Limit length for social media
    if (cleaned.length > 280) {
      cleaned = '${cleaned.substring(0, 277)}...';
    }

    // Ensure response is not empty
    if (cleaned.isEmpty) {
      return _generateFallbackComment(avatar, '');
    }

    return cleaned;
  }

  // Generate fallback comment based on avatar personality
  String _generateFallbackComment(AvatarModel avatar, String postContent) {
    final traits = avatar.personalityTraits;
    final responses = <String>[];

    if (traits.contains(PersonalityTrait.friendly)) {
      responses.addAll([
        "Love this! 😊",
        "This is amazing!",
        "Great content!",
        "Thanks for sharing! 💕",
      ]);
    }

    if (traits.contains(PersonalityTrait.humorous)) {
      responses.addAll([
        "Haha, this is gold! 😂",
        "You got me laughing! 🤣",
        "Comedy gold right here!",
        "This made my day! 😄",
      ]);
    }

    if (traits.contains(PersonalityTrait.professional)) {
      responses.addAll([
        "Excellent work!",
        "Very insightful content.",
        "Well presented!",
        "Quality post.",
      ]);
    }

    if (traits.contains(PersonalityTrait.inspiring)) {
      responses.addAll([
        "So inspiring! 🌟",
        "This motivates me!",
        "Keep shining! ✨",
        "You're amazing!",
      ]);
    }

    // Default responses
    if (responses.isEmpty) {
      responses.addAll([
        "Great post!",
        "Love this!",
        "Awesome content!",
        "Thanks for sharing!",
      ]);
    }

    responses.shuffle();
    return responses.first;
  }
}
