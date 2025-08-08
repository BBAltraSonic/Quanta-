import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avatar_model.dart';
import '../models/chat_message.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/ai_service.dart';
import '../utils/environment.dart';

class ChatSession {
  final String id;
  final String userId;
  final String avatarId;
  final bool isActive;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  ChatSession({
    required this.id,
    required this.userId,
    required this.avatarId,
    required this.isActive,
    required this.lastMessageAt,
    required this.createdAt,
    this.metadata,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      avatarId: json['avatar_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'avatar_id': avatarId,
      'is_active': isActive,
      'last_message_at': lastMessageAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final AuthService _authService = AuthService();
  final AvatarService _avatarService = AvatarService();
  final AIService _aiService = AIService();
  
  SupabaseClient get _supabase => _authService.supabase;

  // Get or create chat session with avatar
  Future<ChatSession> getOrCreateChatSession(String avatarId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Check if session already exists
      final existingSession = await _supabase
          .from('chat_sessions')
          .select()
          .eq('user_id', userId)
          .eq('avatar_id', avatarId)
          .eq('is_active', true)
          .maybeSingle();

      if (existingSession != null) {
        return ChatSession.fromJson(existingSession);
      }

      // Verify avatar exists and is active
      final avatar = await _avatarService.getAvatarById(avatarId);
      if (avatar == null) {
        throw Exception('Avatar not found');
      }

      // Create new session
      final sessionData = {
        'user_id': userId,
        'avatar_id': avatarId,
        'is_active': true,
        'last_message_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('chat_sessions')
          .insert(sessionData)
          .select()
          .single();

      return ChatSession.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create chat session: $e');
    }
  }

  // Send message to avatar and get AI response
  Future<ChatMessage> sendMessageToAvatar({
    required String avatarId,
    required String messageText,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Validate message
      if (messageText.trim().isEmpty) {
        throw Exception('Message cannot be empty');
      }

      if (messageText.length > Environment.maxMessageLength) {
        throw Exception('Message too long. Maximum ${Environment.maxMessageLength} characters.');
      }

      // Check rate limiting
      await _checkRateLimit(userId);

      // Get or create chat session
      final session = await getOrCreateChatSession(avatarId);

      // Get avatar for AI response
      final avatar = await _avatarService.getAvatarById(avatarId);
      if (avatar == null) {
        throw Exception('Avatar not found');
      }

      // Get recent message history for context
      final recentMessages = await getRecentMessages(session.id, limit: 10);

      // Save user message
      final userMessage = await _saveMessage(
        sessionId: session.id,
        senderUserId: userId,
        messageText: messageText.trim(),
        isAiGenerated: false,
      );

      // Generate AI response
      final aiResponseText = await _aiService.generateAvatarResponse(
        avatar: avatar,
        userMessage: messageText.trim(),
        recentMessages: recentMessages,
      );

      // Save AI response
      final aiMessage = await _saveMessage(
        sessionId: session.id,
        senderAvatarId: avatarId,
        messageText: aiResponseText,
        isAiGenerated: true,
      );

      // Update session last message time
      await _updateSessionLastMessage(session.id);

      return aiMessage;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get chat messages for a session
  Future<List<ChatMessage>> getChatMessages({
    required String sessionId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify user owns this session
      final session = await _supabase
          .from('chat_sessions')
          .select()
          .eq('id', sessionId)
          .eq('user_id', userId)
          .single();

      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('chat_session_id', sessionId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<ChatMessage>((json) => _chatMessageFromSupabase(json))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      throw Exception('Failed to load messages: $e');
    }
  }

  // Get recent messages for context (internal use)
  Future<List<ChatMessage>> getRecentMessages(String sessionId, {int limit = 10}) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('chat_session_id', sessionId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<ChatMessage>((json) => _chatMessageFromSupabase(json))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get user's active chat sessions
  Future<List<ChatSession>> getUserChatSessions() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('chat_sessions')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_message_at', ascending: false);

      return response.map<ChatSession>((json) => ChatSession.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load chat sessions: $e');
    }
  }

  // Get chat session with avatar details
  Future<Map<String, dynamic>> getChatSessionWithAvatar(String sessionId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final sessionResponse = await _supabase
          .from('chat_sessions')
          .select()
          .eq('id', sessionId)
          .eq('user_id', userId)
          .single();

      final session = ChatSession.fromJson(sessionResponse);
      final avatar = await _avatarService.getAvatarById(session.avatarId);

      if (avatar == null) {
        throw Exception('Avatar not found');
      }

      return {
        'session': session,
        'avatar': avatar,
      };
    } catch (e) {
      throw Exception('Failed to load chat session: $e');
    }
  }

  // Check user's daily message rate limit
  Future<void> _checkRateLimit(String userId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final messageCount = await _supabase
        .from('chat_messages')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('sender_user_id', userId)
        .gte('created_at', startOfDay.toIso8601String());

    final count = messageCount.count ?? 0;
    if (count >= Environment.maxChatMessagesPerDay) {
      throw Exception(
        'Daily message limit reached (${Environment.maxChatMessagesPerDay}). Try again tomorrow!',
      );
    }
  }

  // Get user's remaining messages for today
  Future<int> getRemainingMessagesToday() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return 0;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final messageCount = await _supabase
          .from('chat_messages')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('sender_user_id', userId)
          .gte('created_at', startOfDay.toIso8601String());

      final count = messageCount.count ?? 0;
      return (Environment.maxChatMessagesPerDay - count).clamp(0, Environment.maxChatMessagesPerDay);
    } catch (e) {
      return Environment.maxChatMessagesPerDay;
    }
  }

  // Save a chat message
  Future<ChatMessage> _saveMessage({
    required String sessionId,
    String? senderUserId,
    String? senderAvatarId,
    required String messageText,
    required bool isAiGenerated,
  }) async {
    final messageData = {
      'chat_session_id': sessionId,
      'sender_user_id': senderUserId,
      'sender_avatar_id': senderAvatarId,
      'message_text': messageText,
      'is_ai_generated': isAiGenerated,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('chat_messages')
        .insert(messageData)
        .select()
        .single();

    return _chatMessageFromSupabase(response);
  }

  // Update session last message timestamp
  Future<void> _updateSessionLastMessage(String sessionId) async {
    await _supabase
        .from('chat_sessions')
        .update({
          'last_message_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId);
  }

  // Convert Supabase chat message to ChatMessage model
  ChatMessage _chatMessageFromSupabase(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['message_text'] as String,
      isMe: json['sender_user_id'] == _authService.currentUserId,
      time: DateTime.parse(json['created_at'] as String),
      avatarUrl: null, // Will be populated from avatar data if needed
      isAiGenerated: json['is_ai_generated'] as bool? ?? false,
    );
  }

  // Delete/deactivate chat session
  Future<void> deleteChatSession(String sessionId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('chat_sessions')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete chat session: $e');
    }
  }

  // Clear all messages in a session (for user)
  Future<void> clearChatHistory(String sessionId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify user owns this session
      await _supabase
          .from('chat_sessions')
          .select('id')
          .eq('id', sessionId)
          .eq('user_id', userId)
          .single();

      // Delete all messages in the session
      await _supabase
          .from('chat_messages')
          .delete()
          .eq('chat_session_id', sessionId);
    } catch (e) {
      throw Exception('Failed to clear chat history: $e');
    }
  }
}
