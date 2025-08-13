import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../models/avatar_model.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';

/// Conversation summary for messages list
class Conversation {
  final String id;
  final String sessionId;
  final AvatarModel avatar;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime lastActivity;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  Conversation({
    required this.id,
    required this.sessionId,
    required this.avatar,
    this.lastMessage,
    this.unreadCount = 0,
    required this.lastActivity,
    this.isActive = true,
    this.metadata,
  });

  factory Conversation.fromJson(Map<String, dynamic> json, AvatarModel avatar) {
    return Conversation(
      id: json['id'] as String,
      sessionId: json['id'] as String,
      avatar: avatar,
      lastActivity: DateTime.parse(json['last_message_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Paginated conversation result
class ConversationPage {
  final List<Conversation> conversations;
  final bool hasMore;
  final String? nextCursor;

  ConversationPage({
    required this.conversations,
    required this.hasMore,
    this.nextCursor,
  });
}

/// Public chat entry that can be shared
class PublicChatEntry {
  final String id;
  final String sessionId;
  final String messageId;
  final String avatarId;
  final String userId;
  final String messageText;
  final String? avatarResponse;
  final DateTime createdAt;
  final bool isPublic;
  final String visibility; // 'avatar', 'creator', 'private'
  final Map<String, dynamic>? metadata;

  PublicChatEntry({
    required this.id,
    required this.sessionId,
    required this.messageId,
    required this.avatarId,
    required this.userId,
    required this.messageText,
    this.avatarResponse,
    required this.createdAt,
    this.isPublic = false,
    this.visibility = 'private',
    this.metadata,
  });

  factory PublicChatEntry.fromJson(Map<String, dynamic> json) {
    return PublicChatEntry(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      messageId: json['message_id'] as String,
      avatarId: json['avatar_id'] as String,
      userId: json['user_id'] as String,
      messageText: json['message_text'] as String,
      avatarResponse: json['avatar_response'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPublic: json['is_public'] as bool? ?? false,
      visibility: json['visibility'] as String? ?? 'private',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Service for managing messages and conversations
class MessagesService {
  static final MessagesService _instance = MessagesService._internal();
  factory MessagesService() => _instance;
  MessagesService._internal();

  final AuthService _authService = AuthService();
  final AvatarService _avatarService = AvatarService();

  SupabaseClient get _supabase => _authService.supabase;

  /// Get conversations stream for real-time updates
  Stream<List<Conversation>> getConversationsStream({
    int limit = 20,
  }) {
    final userId = _authService.currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    try {
      // Use a periodic stream instead of real-time for production stability
      return Stream.periodic(const Duration(seconds: 5))
          .asyncMap((_) => getConversations(limit: limit))
          .handleError((error) {
            debugPrint('Error in conversations stream: $error');
            return <Conversation>[];
          });
    } catch (e) {
      debugPrint('Error setting up conversations stream: $e');
      return Stream.value([]);
    }
  }

  /// Get all conversations for the current user
  Future<List<Conversation>> getConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get chat sessions with latest message data
      final sessionsResponse = await _supabase
          .from('chat_sessions')
          .select('''
            *,
            latest_message:chat_messages(
              id,
              message_text,
              is_ai_generated,
              created_at,
              sender_user_id,
              sender_avatar_id
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_message_at', ascending: false)
          .range(offset, offset + limit - 1);

      final conversations = <Conversation>[];

      for (final sessionData in sessionsResponse) {
        try {
          // Get avatar details
          final avatarId = sessionData['avatar_id'] as String;
          final avatar = await _avatarService.getAvatarById(avatarId);

          if (avatar != null) {
            // Get latest message if available
            ChatMessage? lastMessage;
            if (sessionData['latest_message'] != null && 
                sessionData['latest_message'].isNotEmpty) {
              final msgData = sessionData['latest_message'][0];
              lastMessage = ChatMessage(
                id: msgData['id'] as String,
                text: msgData['message_text'] as String,
                isMe: msgData['sender_user_id'] == userId,
                time: DateTime.parse(msgData['created_at'] as String),
                isAiGenerated: msgData['is_ai_generated'] as bool? ?? false,
              );
            }

            // Get unread count (messages after user's last read)
            final unreadCount = await _getUnreadCount(sessionData['id'] as String);

            conversations.add(Conversation(
              id: sessionData['id'] as String,
              sessionId: sessionData['id'] as String,
              avatar: avatar,
              lastMessage: lastMessage,
              unreadCount: unreadCount,
              lastActivity: DateTime.parse(sessionData['last_message_at'] as String),
              isActive: sessionData['is_active'] as bool? ?? true,
              metadata: sessionData['metadata'] as Map<String, dynamic>?,
            ));
          }
        } catch (e) {
          debugPrint('Error processing conversation ${sessionData['id']}: $e');
          continue;
        }
      }

      return conversations;
    } catch (e) {
      debugPrint('Error getting conversations: $e');
      return [];
    }
  }

  /// Get unread message count for a session
  Future<int> _getUnreadCount(String sessionId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return 0;

      // Get the last read message for this user + session
      final lastRead = await _supabase
          .from('user_read_messages')
          .select('message_id, read_at')
          .eq('user_id', userId)
          .eq('session_id', sessionId)
          .order('read_at', ascending: false)
          .limit(1)
          .maybeSingle();

      DateTime? lastReadTime;
      if (lastRead != null) {
        final lastReadMessageId = lastRead['message_id'] as String;
        final msg = await _supabase
            .from('chat_messages')
            .select('created_at')
            .eq('id', lastReadMessageId)
            .single();
        lastReadTime = DateTime.parse(msg['created_at'] as String);
      }

      var query = _supabase
          .from('chat_messages')
          .select('id')
          .eq('chat_session_id', sessionId);

      if (lastReadTime != null) {
        query = query.gt('created_at', lastReadTime.toIso8601String());
      }

      final unread = await query;
      return unread.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark a conversation as read
  Future<void> markConversationAsRead(String sessionId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final latest = await _supabase
          .from('chat_messages')
          .select('id, created_at')
          .eq('chat_session_id', sessionId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latest != null) {
        await _supabase
            .from('user_read_messages')
            .upsert({
              'user_id': userId,
              'session_id': sessionId,
              'message_id': latest['id'] as String,
              'read_at': DateTime.now().toIso8601String(),
            }, onConflict: 'user_id,message_id');
      }
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
      rethrow;
    }
  }

  /// Make a chat message/conversation public
  Future<PublicChatEntry?> makeMessagePublic({
    required String sessionId,
    required String messageId,
    required String visibility, // 'avatar', 'creator'
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get the message details
      final messageResponse = await _supabase
          .from('chat_messages')
          .select('*')
          .eq('id', messageId)
          .eq('chat_session_id', sessionId)
          .single();

      // Get the session details to verify ownership
      final sessionResponse = await _supabase
          .from('chat_sessions')
          .select('*')
          .eq('id', sessionId)
          .eq('user_id', userId)
          .single();

      // Get AI response if this is a user message
      String? avatarResponse;
      if (messageResponse['sender_user_id'] != null) {
        // Find the next AI message in the conversation
        final nextMessages = await _supabase
            .from('chat_messages')
            .select('*')
            .eq('chat_session_id', sessionId)
            .eq('is_ai_generated', true)
            .gt('created_at', messageResponse['created_at'])
            .order('created_at', ascending: true)
            .limit(1);

        if (nextMessages.isNotEmpty) {
          avatarResponse = nextMessages[0]['message_text'] as String;
        }
      }

      // Create public chat entry
      final publicEntryData = {
        'session_id': sessionId,
        'message_id': messageId,
        'avatar_id': sessionResponse['avatar_id'],
        'user_id': userId,
        'message_text': messageResponse['message_text'],
        'avatar_response': avatarResponse,
        'is_public': true,
        'visibility': visibility,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('public_chat_entries')
          .insert(publicEntryData)
          .select()
          .single();

      return PublicChatEntry.fromJson(response);
    } catch (e) {
      debugPrint('Error making message public: $e');
      return null;
    }
  }

  /// Remove message from public visibility
  Future<bool> makeMessagePrivate(String publicEntryId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('public_chat_entries')
          .delete()
          .eq('id', publicEntryId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error making message private: $e');
      return false;
    }
  }

  /// Get public chat entries for an avatar (for showcasing)
  Future<List<PublicChatEntry>> getAvatarPublicChats({
    required String avatarId,
    String visibility = 'avatar',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('public_chat_entries')
          .select('*')
          .eq('avatar_id', avatarId)
          .eq('visibility', visibility)
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<PublicChatEntry>((json) => PublicChatEntry.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting avatar public chats: $e');
      return [];
    }
  }

  /// Get user's public chat entries
  Future<List<PublicChatEntry>> getUserPublicChats({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('public_chat_entries')
          .select('*')
          .eq('user_id', userId)
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<PublicChatEntry>((json) => PublicChatEntry.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting user public chats: $e');
      return [];
    }
  }

  /// Delete a conversation
  Future<bool> deleteConversation(String sessionId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Deactivate the session instead of deleting
      await _supabase
          .from('chat_sessions')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      return false;
    }
  }

  /// Search conversations
  Future<List<Conversation>> searchConversations(String query) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Search in avatar names and recent messages
      final avatars = await _avatarService.searchAvatars(query: query, limit: 10);
      final avatarIds = avatars.map((a) => a.id).toList();

      if (avatarIds.isEmpty) return [];

      final sessionsResponse = await _supabase
          .from('chat_sessions')
          .select('''
            *,
            latest_message:chat_messages(
              id,
              message_text,
              is_ai_generated,
              created_at,
              sender_user_id,
              sender_avatar_id
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .inFilter('avatar_id', avatarIds)
          .order('last_message_at', ascending: false);

      final conversations = <Conversation>[];

      for (final sessionData in sessionsResponse) {
        try {
          final avatarId = sessionData['avatar_id'] as String;
          final avatar = avatars.firstWhere((a) => a.id == avatarId);

          ChatMessage? lastMessage;
          if (sessionData['latest_message'] != null && 
              sessionData['latest_message'].isNotEmpty) {
            final msgData = sessionData['latest_message'][0];
            lastMessage = ChatMessage(
              id: msgData['id'] as String,
              text: msgData['message_text'] as String,
              isMe: msgData['sender_user_id'] == userId,
              time: DateTime.parse(msgData['created_at'] as String),
              isAiGenerated: msgData['is_ai_generated'] as bool? ?? false,
            );
          }

          final unreadCount = await _getUnreadCount(sessionData['id'] as String);

          conversations.add(Conversation(
            id: sessionData['id'] as String,
            sessionId: sessionData['id'] as String,
            avatar: avatar,
            lastMessage: lastMessage,
            unreadCount: unreadCount,
            lastActivity: DateTime.parse(sessionData['last_message_at'] as String),
            isActive: sessionData['is_active'] as bool? ?? true,
            metadata: sessionData['metadata'] as Map<String, dynamic>?,
          ));
        } catch (e) {
          debugPrint('Error processing search result ${sessionData['id']}: $e');
          continue;
        }
      }

      return conversations;
    } catch (e) {
      debugPrint('Error searching conversations: $e');
      return [];
    }
  }

  /// Mark specific message as read
  Future<void> markMessageAsRead(String sessionId, String messageId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('user_read_messages')
          .upsert({
            'user_id': userId,
            'session_id': sessionId,
            'message_id': messageId,
            'read_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id,message_id');
    } catch (e) {
      debugPrint('Error marking message as read: $e');
      rethrow;
    }
  }

  /// Get user's read status for messages in a session
  Future<Map<String, DateTime>> getReadStatusForSession(String sessionId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return {};

      final response = await _supabase
          .from('user_read_messages')
          .select('message_id, read_at')
          .eq('user_id', userId)
          .eq('session_id', sessionId);

      final readStatus = <String, DateTime>{};
      for (final record in response) {
        readStatus[record['message_id'] as String] =
            DateTime.parse(record['read_at'] as String);
      }

      return readStatus;
    } catch (e) {
      debugPrint('Error getting read status: $e');
      return {};
    }
  }


  /// Get conversations with pagination support
  Future<ConversationPage> getConversationsPaginated({
    int limit = 20,
    String? cursor,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Build query with cursor-based pagination
      var query = _supabase
          .from('chat_sessions')
          .select('''
            *,
            latest_message:chat_messages(
              id,
              message_text,
              is_ai_generated,
              created_at,
              sender_user_id,
              sender_avatar_id
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_message_at', ascending: false);

      // Apply cursor pagination
      // TODO: Fix lt() method for cursor pagination
      // if (cursor != null) {
      //   query = query.lt('last_message_at', cursor);
      // }

      final sessionsResponse = await query.limit(limit + 1); // +1 to check if there's more

      final conversations = <Conversation>[];
      bool hasMore = sessionsResponse.length > limit;
      
      // Process only the requested amount
      final dataToProcess = hasMore 
          ? sessionsResponse.take(limit).toList() 
          : sessionsResponse;

      for (final sessionData in dataToProcess) {
        try {
          final avatarId = sessionData['avatar_id'] as String;
          final avatar = await _avatarService.getAvatarById(avatarId);

          if (avatar != null) {
            ChatMessage? lastMessage;
            if (sessionData['latest_message'] != null && 
                sessionData['latest_message'].isNotEmpty) {
              final msgData = sessionData['latest_message'][0];
              lastMessage = ChatMessage(
                id: msgData['id'] as String,
                text: msgData['message_text'] as String,
                isMe: msgData['sender_user_id'] == userId,
                time: DateTime.parse(msgData['created_at'] as String),
                isAiGenerated: msgData['is_ai_generated'] as bool? ?? false,
              );
            }

            final unreadCount = await _getUnreadCount(sessionData['id'] as String);

            conversations.add(Conversation(
              id: sessionData['id'] as String,
              sessionId: sessionData['id'] as String,
              avatar: avatar,
              lastMessage: lastMessage,
              unreadCount: unreadCount,
              lastActivity: DateTime.parse(sessionData['last_message_at'] as String),
              isActive: sessionData['is_active'] as bool? ?? true,
              metadata: sessionData['metadata'] as Map<String, dynamic>?,
            ));
          }
        } catch (e) {
          debugPrint('Error processing conversation ${sessionData['id']}: $e');
          continue;
        }
      }

      String? nextCursor;
      if (hasMore && conversations.isNotEmpty) {
        nextCursor = conversations.last.lastActivity.toIso8601String();
      }

      return ConversationPage(
        conversations: conversations,
        hasMore: hasMore,
        nextCursor: nextCursor,
      );
    } catch (e) {
      debugPrint('Error getting paginated conversations: $e');
      return ConversationPage(conversations: [], hasMore: false, nextCursor: null);
    }
  }

  /// Get conversation statistics
  Future<Map<String, dynamic>> getConversationStats() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final stats = await _supabase
          .from('chat_sessions')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .count();

      final totalConversations = stats.count ?? 0;

      // Get total messages sent
      final messageStats = await _supabase
          .from('chat_messages')
          .select('id')
          .eq('sender_user_id', userId)
          .count();

      final totalMessages = messageStats.count ?? 0;

      // Compute total unread across sessions
      final sessionsResponse = await _supabase
          .from('chat_sessions')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true);

      int totalUnread = 0;
      for (final s in sessionsResponse) {
        totalUnread += await _getUnreadCount(s['id'] as String);
      }

      return {
        'totalConversations': totalConversations,
        'totalMessages': totalMessages,
        'averageMessagesPerConversation': totalConversations > 0 
            ? (totalMessages / totalConversations).round() 
            : 0,
        'totalUnreadMessages': totalUnread,
      };
    } catch (e) {
      debugPrint('Error getting conversation stats: $e');
      return {
        'totalConversations': 0,
        'totalMessages': 0,
        'averageMessagesPerConversation': 0,
        'totalUnreadMessages': 0,
      };
    }
  }
}
