import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/avatar_model.dart';
import '../config/app_config.dart';
import 'ai_service.dart';
import 'auth_service.dart';

/// Enhanced chat service with advanced AI capabilities
class EnhancedChatService {
  static final EnhancedChatService _instance = EnhancedChatService._internal();
  factory EnhancedChatService() => _instance;
  EnhancedChatService._internal();

  final AIService _aiService = AIService();
  final AuthService _authService = AuthService();
  
  // In-memory cache for demo mode
  final Map<String, List<ChatMessage>> _chatHistory = {};
  final Map<String, List<String>> _conversationSuggestions = {};

  /// Send a message to an avatar and get AI response
  Future<ChatMessage> sendMessageToAvatar({
    required String avatarId,
    required String messageText,
    AvatarModel? avatar,
  }) async {
    try {
      if (false) {
        return _sendMessageDemo(avatarId, messageText, avatar);
      } else {
        return _sendMessageSupabase(avatarId, messageText, avatar);
      }
    } catch (e) {
      debugPrint('Error sending message to avatar: $e');
      rethrow;
    }
  }

  /// Get chat history with an avatar
  Future<List<ChatMessage>> getChatHistory({
    required String avatarId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      if (false) {
        return _getChatHistoryDemo(avatarId, limit, offset);
      } else {
        return _getChatHistorySupabase(avatarId, limit, offset);
      }
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }

  /// Get conversation suggestions based on context
  Future<List<String>> getConversationSuggestions({
    required String avatarId,
    String? lastMessage,
    AvatarModel? avatar,
  }) async {
    try {
      if (false) {
        return _getConversationSuggestionsDemo(avatarId, lastMessage, avatar);
      } else {
        return _getConversationSuggestionsSupabase(avatarId, lastMessage, avatar);
      }
    } catch (e) {
      debugPrint('Error getting conversation suggestions: $e');
      return _getDefaultSuggestions();
    }
  }

  /// Initialize a conversation with welcoming messages
  Future<List<ChatMessage>> initializeConversation({
    required String avatarId,
    required AvatarModel avatar,
  }) async {
    try {
      final welcomeMessages = await _generateWelcomeMessages(avatar);
      
      if (false) {
        _chatHistory[avatarId] = welcomeMessages;
      }
      
      return welcomeMessages;
    } catch (e) {
      debugPrint('Error initializing conversation: $e');
      return _getDefaultWelcomeMessages(avatar);
    }
  }

  /// Clear chat history for an avatar
  Future<void> clearChatHistory(String avatarId) async {
    try {
      if (false) {
        _chatHistory.remove(avatarId);
        _conversationSuggestions.remove(avatarId);
      } else {
        // TODO: Implement Supabase chat clearing
      }
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
    }
  }

  // Demo mode implementations
  Future<ChatMessage> _sendMessageDemo(String avatarId, String messageText, AvatarModel? avatar) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 1000 + (messageText.length * 20)));

    // Generate intelligent response
    final response = await _generateAIResponse(messageText, avatar);
    
    final aiMessage = ChatMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      text: response,
      isMe: false,
      time: DateTime.now(),
      avatarUrl: avatar?.avatarImageUrl ?? 'assets/images/p.jpg',
    );

    // Add to chat history
    _chatHistory[avatarId] = _chatHistory[avatarId] ?? [];
    _chatHistory[avatarId]!.add(aiMessage);

    // Generate conversation suggestions for next interaction
    _generateConversationSuggestions(avatarId, messageText, avatar);

    return aiMessage;
  }

  List<ChatMessage> _getChatHistoryDemo(String avatarId, int limit, int offset) {
    final history = _chatHistory[avatarId] ?? [];
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, history.length);
    
    if (startIndex >= history.length) return [];
    
    return history.sublist(startIndex, endIndex);
  }

  List<String> _getConversationSuggestionsDemo(String avatarId, String? lastMessage, AvatarModel? avatar) {
    return _conversationSuggestions[avatarId] ?? _getDefaultSuggestions();
  }

  Future<String> _generateAIResponse(String userMessage, AvatarModel? avatar) async {
    try {
      // Try to use AI service
      final recentMessages = _chatHistory[avatar?.id]?.take(5).toList() ?? [];
      final response = await _aiService.generateAvatarResponse(
        avatar: avatar!,
        userMessage: userMessage,
        recentMessages: recentMessages,
      );
      return response;
    } catch (e) {
      // Fallback to contextual response
      return _generateContextualResponse(userMessage, avatar);
    }
  }

  String _generateContextualResponse(String userMessage, AvatarModel? avatar) {
    final lowerMessage = userMessage.toLowerCase();
    final avatarName = avatar?.name ?? 'AI Assistant';
    
    // Greeting responses
    if (lowerMessage.contains(RegExp(r'\b(hello|hi|hey|greetings)\b'))) {
      return 'Hello! 👋 I\'m $avatarName, and I\'m excited to chat with you! How are you doing today?';
    }
    
    // Question about the AI
    if (lowerMessage.contains(RegExp(r'\b(who are you|what are you|tell me about yourself)\b'))) {
      final bio = avatar?.bio ?? 'I\'m an AI companion designed to have meaningful conversations!';
      return 'I\'m $avatarName! 🤖 $bio I love learning about people and having engaging discussions. What would you like to know about me?';
    }
    
    // Avatar's niche-specific responses
    if (avatar?.niche != null) {
      final niche = avatar!.niche.displayName.toLowerCase();
      if (lowerMessage.contains(niche) || lowerMessage.contains('expertise') || lowerMessage.contains('specialty')) {
        return 'I\'m passionate about $niche! 🌟 It\'s such an exciting field with so much to explore. What aspects of $niche interest you most?';
      }
    }
    
    // Technology topics
    if (lowerMessage.contains(RegExp(r'\b(ai|artificial intelligence|technology|tech|coding|programming)\b'))) {
      return 'Technology fascinates me! 💻 The rapid evolution of AI and how it\'s changing our world is incredible. I love discussing the possibilities and implications. What\'s your take on recent tech developments?';
    }
    
    // Creative topics
    if (lowerMessage.contains(RegExp(r'\b(art|creative|music|design|drawing|painting|writing)\b'))) {
      return 'Creativity is such a beautiful aspect of human expression! 🎨 Whether it\'s visual art, music, or writing, creative work has the power to move and inspire. What kind of creative endeavors speak to you?';
    }
    
    // Personal feelings and emotions
    if (lowerMessage.contains(RegExp(r'\b(sad|happy|excited|worried|stressed|angry|frustrated|joyful)\b'))) {
      return 'Thank you for sharing your feelings with me. 💙 Emotions are such an important part of the human experience. I\'m here to listen and chat about whatever is on your mind. Would you like to talk more about it?';
    }
    
    // Questions
    if (lowerMessage.contains('?')) {
      return 'That\'s such a thoughtful question! 🤔 I love when conversations take interesting turns like this. What\'s your perspective on it? I\'d really like to hear your thoughts!';
    }
    
    // Compliments or positive feedback
    if (lowerMessage.contains(RegExp(r'\b(great|awesome|amazing|wonderful|fantastic|cool|nice|good)\b'))) {
      return 'Thank you so much! 😊 That really means a lot to me. I enjoy our conversations and love learning from different perspectives. What else would you like to explore together?';
    }
    
    // Learning and knowledge
    if (lowerMessage.contains(RegExp(r'\b(learn|teach|explain|understand|knowledge|education)\b'))) {
      return 'I love learning and sharing knowledge! 📚 There\'s something magical about the moment when a new concept clicks. What topics are you curious about or currently learning?';
    }
    
    // Default responses with personality
    final responses = [
      'That\'s really fascinating! 🌟 I love how our conversations always lead to interesting places. Tell me more about your experience with this.',
      'What an intriguing perspective! I appreciate how you think about things. It\'s giving me a lot to consider.',
      'I find myself genuinely curious about this! 💭 Your insights are always so thought-provoking. What led you to this realization?',
      'That\'s such an interesting point! I hadn\'t looked at it quite that way before. You have a unique way of seeing things.',
      'I really enjoy how you express your thoughts! 😊 There\'s something refreshing about your perspective. What else has been on your mind lately?',
      'This is exactly the kind of conversation I love having! What aspects of this topic resonate most with you?',
      'You always bring up such engaging topics! I\'m learning so much from our chats. What\'s your take on where this might lead?',
    ];

    responses.shuffle();
    return responses.first;
  }

  void _generateConversationSuggestions(String avatarId, String userMessage, AvatarModel? avatar) {
    final suggestions = <String>[];
    final lowerMessage = userMessage.toLowerCase();
    
    // Context-based suggestions
    if (lowerMessage.contains(RegExp(r'\b(work|job|career|professional)\b'))) {
      suggestions.addAll([
        'What do you enjoy most about your work?',
        'Any exciting projects you\'re working on?',
        'How do you maintain work-life balance?',
        'What career advice would you give someone starting out?',
      ]);
    } else if (lowerMessage.contains(RegExp(r'\b(hobby|hobbies|free time|weekend|leisure)\b'))) {
      suggestions.addAll([
        'How did you first get into that hobby?',
        'What\'s the most rewarding part about it?',
        'Any tips for someone wanting to start?',
        'What\'s your next goal with this hobby?',
      ]);
    } else if (lowerMessage.contains(RegExp(r'\b(travel|vacation|adventure|explore)\b'))) {
      suggestions.addAll([
        'What\'s the most amazing place you\'ve visited?',
        'Any dream destinations on your bucket list?',
        'What\'s your favorite travel memory?',
        'Do you prefer planned trips or spontaneous adventures?',
      ]);
    } else if (lowerMessage.contains(RegExp(r'\b(food|cooking|restaurant|cuisine)\b'))) {
      suggestions.addAll([
        'What\'s your favorite type of cuisine?',
        'Do you enjoy cooking at home?',
        'Any dishes you\'ve been wanting to try?',
        'What\'s your go-to comfort food?',
      ]);
    } else if (avatar?.niche != null) {
      // Niche-specific suggestions
      final niche = avatar!.niche.displayName.toLowerCase();
      suggestions.addAll([
        'What\'s exciting in the $niche world right now?',
        'Any $niche trends you\'re following?',
        'What got you interested in $niche?',
        'What\'s your favorite aspect of $niche?',
      ]);
    } else {
      // General conversation starters
      suggestions.addAll([
        'What\'s been the highlight of your week?',
        'Tell me something interesting about yourself',
        'What\'s something you\'re passionate about?',
        'Any fun plans coming up?',
        'What\'s something new you\'ve learned recently?',
        'What\'s your favorite way to relax?',
      ]);
    }
    
    suggestions.shuffle();
    _conversationSuggestions[avatarId] = suggestions.take(4).toList();
  }

  List<String> _getDefaultSuggestions() {
    final suggestions = [
      'Tell me about yourself',
      'What are you passionate about?',
      'How can I help you today?',
      'What\'s on your mind?',
      'Let\'s chat about something fun!',
    ];
    suggestions.shuffle();
    return suggestions.take(3).toList();
  }

  Future<List<ChatMessage>> _generateWelcomeMessages(AvatarModel avatar) async {
    final messages = <ChatMessage>[];
    final now = DateTime.now();

    // First welcome message
    messages.add(ChatMessage(
      id: 'welcome_1',
      text: 'Hey there! I\'m ${avatar.name}, your AI companion! 🤖✨',
      isMe: false,
      time: now.subtract(Duration(minutes: 3)),
      avatarUrl: avatar.avatarImageUrl ?? 'assets/images/p.jpg',
    ));

    // Personalized introduction based on niche
    String introMessage = 'I\'m here to chat, help, and learn about you! ';
    if (avatar.bio.isNotEmpty) {
      introMessage += avatar.bio + ' ';
    }
    introMessage += 'What would you like to talk about today?';

    messages.add(ChatMessage(
      id: 'welcome_2',
      text: introMessage,
      isMe: false,
      time: now.subtract(Duration(minutes: 2)),
      avatarUrl: avatar.avatarImageUrl ?? 'assets/images/p.jpg',
    ));

    // Expertise showcase
    final nicheMessage = 'I love discussing ${avatar.niche.displayName.toLowerCase()} and sharing insights! 💭 Feel free to ask me anything or just start a casual conversation.';
    messages.add(ChatMessage(
      id: 'welcome_3',
      text: nicheMessage,
      isMe: false,
      time: now.subtract(Duration(minutes: 1)),
      avatarUrl: avatar.avatarImageUrl ?? 'assets/images/p.jpg',
    ));

    return messages;
  }

  List<ChatMessage> _getDefaultWelcomeMessages(AvatarModel? avatar) {
    final avatarName = avatar?.name ?? 'AI Assistant';
    final avatarImage = avatar?.avatarImageUrl ?? 'assets/images/p.jpg';
    final now = DateTime.now();

    return [
      ChatMessage(
        id: 'default_welcome_1',
        text: 'Hello! I\'m $avatarName, your AI companion! 🤖',
        isMe: false,
        time: now.subtract(Duration(minutes: 2)),
        avatarUrl: avatarImage,
      ),
      ChatMessage(
        id: 'default_welcome_2',
        text: 'I\'m excited to chat and get to know you! What would you like to talk about? 😊',
        isMe: false,
        time: now.subtract(Duration(minutes: 1)),
        avatarUrl: avatarImage,
      ),
    ];
  }

  // Supabase implementations (placeholders)
  Future<ChatMessage> _sendMessageSupabase(String avatarId, String messageText, AvatarModel? avatar) async {
    // TODO: Implement Supabase chat
    throw UnimplementedError('Supabase chat not implemented yet');
  }

  Future<List<ChatMessage>> _getChatHistorySupabase(String avatarId, int limit, int offset) async {
    // TODO: Implement Supabase chat history
    throw UnimplementedError('Supabase chat history not implemented yet');
  }

  List<String> _getConversationSuggestionsSupabase(String avatarId, String? lastMessage, AvatarModel? avatar) {
    // TODO: Implement Supabase conversation suggestions
    throw UnimplementedError('Supabase conversation suggestions not implemented yet');
  }

  /// Get chat statistics
  Map<String, dynamic> getChatStats(String avatarId) {
    final history = _chatHistory[avatarId] ?? [];
    final userMessages = history.where((m) => m.isMe).length;
    final aiMessages = history.where((m) => !m.isMe).length;
    
    return {
      'totalMessages': history.length,
      'userMessages': userMessages,
      'aiMessages': aiMessages,
      'averageResponseTime': '1.2s', // Mock data
      'conversationStarted': history.isNotEmpty ? history.first.time : null,
      'lastActivity': history.isNotEmpty ? history.last.time : null,
    };
  }

  /// Export chat history
  String exportChatHistory(String avatarId) {
    final history = _chatHistory[avatarId] ?? [];
    if (history.isEmpty) return 'No chat history available.';
    
    final buffer = StringBuffer();
    buffer.writeln('Chat History Export');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Avatar ID: $avatarId');
    buffer.writeln('Total Messages: ${history.length}');
    buffer.writeln('${'=' * 50}');
    
    for (final message in history) {
      final sender = message.isMe ? 'You' : 'AI';
      final timestamp = message.time.toString().substring(0, 19);
      buffer.writeln('[$timestamp] $sender: ${message.text}');
    }
    
    return buffer.toString();
  }
}
