import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

enum NotificationType { like, comment, follow, mention, system }

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.like:
        return 'Like';
      case NotificationType.comment:
        return 'Comment';
      case NotificationType.follow:
        return 'Follow';
      case NotificationType.mention:
        return 'Mention';
      case NotificationType.system:
        return 'System';
    }
  }

  String get value {
    switch (this) {
      case NotificationType.mention:
        return 'avatar_mention'; // Match database constraint
      default:
        return toString().split('.').last;
    }
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? relatedPostId;
  final String? relatedAvatarId;
  final String? relatedUserId;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.relatedPostId,
    this.relatedAvatarId,
    this.relatedUserId,
    this.isRead = false,
    required this.createdAt,
    this.metadata,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.value == json['type'],
        orElse: () => NotificationType.system,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      relatedPostId: json['related_post_id'] as String?,
      relatedAvatarId: json['related_avatar_id'] as String?,
      relatedUserId: json['related_user_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.value,
      'title': title,
      'message': message,
      'related_post_id': relatedPostId,
      'related_avatar_id': relatedAvatarId,
      'related_user_id': relatedUserId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  NotificationModel copyWith({bool? isRead, Map<String, dynamic>? metadata}) {
    return NotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      relatedPostId: relatedPostId,
      relatedAvatarId: relatedAvatarId,
      relatedUserId: relatedUserId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final AuthService _authService = AuthService();
  SupabaseClient get _supabase => _authService.supabase;

  // Stream for real-time notifications
  Stream<List<NotificationModel>>? _notificationStream;

  // Initialize notification service
  Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing Notification Service');
      // Setup real-time subscription if user is authenticated
      if (_authService.isAuthenticated) {
        _setupRealtimeSubscription();
      }
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
    }
  }

  // Get user notifications with pagination
  Future<List<NotificationModel>> getUserNotifications({
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<NotificationModel>((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching notifications: $e');
      return [];
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return 0;

      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count();

      return response.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);

      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', userId);

      debugPrint('✅ Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      rethrow;
    }
  }

  // Create notification (internal use by other services)
  Future<NotificationModel?> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? relatedPostId,
    String? relatedAvatarId,
    String? relatedUserId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notificationData = {
        'user_id': userId,
        'type': type.value,
        'title': title,
        'message': message,
        'related_post_id': relatedPostId,
        'related_avatar_id': relatedAvatarId,
        'related_user_id': relatedUserId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': metadata,
      };

      final response = await _supabase
          .from('notifications')
          .insert(notificationData)
          .select()
          .single();

      final notification = NotificationModel.fromJson(response);
      debugPrint('✅ Notification created: ${notification.id}');
      return notification;
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
      return null;
    }
  }

  // Helper methods for common notification types

  // Create like notification
  Future<void> createLikeNotification({
    required String postOwnerId,
    required String likerUserId,
    required String postId,
    required String avatarName,
  }) async {
    if (postOwnerId == likerUserId) return; // Don't notify self

    await createNotification(
      userId: postOwnerId,
      type: NotificationType.like,
      title: 'New Like',
      message: 'Someone liked your avatar $avatarName\'s post',
      relatedPostId: postId,
      relatedUserId: likerUserId,
    );
  }

  // Create comment notification
  Future<void> createCommentNotification({
    required String postOwnerId,
    required String commenterId,
    required String postId,
    required String avatarName,
    required String commentText,
  }) async {
    if (postOwnerId == commenterId) return; // Don't notify self

    final truncatedComment = commentText.length > 50
        ? '${commentText.substring(0, 50)}...'
        : commentText;

    await createNotification(
      userId: postOwnerId,
      type: NotificationType.comment,
      title: 'New Comment',
      message:
          'Someone commented on your avatar $avatarName\'s post: "$truncatedComment"',
      relatedPostId: postId,
      relatedUserId: commenterId,
    );
  }

  // Create follow notification
  Future<void> createFollowNotification({
    required String avatarOwnerId,
    required String followerId,
    required String avatarId,
    required String avatarName,
  }) async {
    if (avatarOwnerId == followerId) return; // Don't notify self

    await createNotification(
      userId: avatarOwnerId,
      type: NotificationType.follow,
      title: 'New Follower',
      message: 'Someone started following your avatar $avatarName',
      relatedAvatarId: avatarId,
      relatedUserId: followerId,
    );
  }

  // Create mention notification
  Future<void> createMentionNotification({
    required String mentionedUserId,
    required String mentionerUserId,
    required String postId,
    required String context,
  }) async {
    if (mentionedUserId == mentionerUserId) return; // Don't notify self

    await createNotification(
      userId: mentionedUserId,
      type: NotificationType.mention,
      title: 'You were mentioned',
      message: 'You were mentioned in a post: "$context"',
      relatedPostId: postId,
      relatedUserId: mentionerUserId,
    );
  }

  // Create system notification
  Future<void> createSystemNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.system,
      title: title,
      message: message,
      metadata: metadata,
    );
  }

  // Setup real-time subscription for notifications
  void _setupRealtimeSubscription() {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      _notificationStream = _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map(
            (data) => data
                .map<NotificationModel>(
                  (json) => NotificationModel.fromJson(json),
                )
                .toList(),
          );

      debugPrint('✅ Real-time notification subscription setup');
    } catch (e) {
      debugPrint('❌ Error setting up real-time notifications: $e');
    }
  }

  // Get real-time notification stream
  Stream<List<NotificationModel>>? getNotificationStream() {
    if (_notificationStream == null && _authService.isAuthenticated) {
      _setupRealtimeSubscription();
    }
    return _notificationStream;
  }

  // Clean up old notifications (run periodically)
  Future<void> cleanupOldNotifications({int daysToKeep = 30}) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId)
          .lt('created_at', cutoffDate.toIso8601String());

      debugPrint('✅ Old notifications cleaned up');
    } catch (e) {
      debugPrint('❌ Error cleaning up notifications: $e');
    }
  }

  // Get notification preferences
  Future<Map<String, bool>> getNotificationPreferences() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return _defaultPreferences();

      // For now, return default preferences
      // In the future, this could be stored in user metadata or separate table
      return _defaultPreferences();
    } catch (e) {
      debugPrint('❌ Error getting notification preferences: $e');
      return _defaultPreferences();
    }
  }

  // Update notification preferences
  Future<void> updateNotificationPreferences(
    Map<String, bool> preferences,
  ) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // For now, just log the preferences
      // In the future, this could be stored in user metadata or separate table
      debugPrint('📝 Notification preferences updated: $preferences');
    } catch (e) {
      debugPrint('❌ Error updating notification preferences: $e');
      rethrow;
    }
  }

  Map<String, bool> _defaultPreferences() {
    return {
      'likes': true,
      'comments': true,
      'follows': true,
      'mentions': true,
      'system': true,
      'push_notifications': true,
      'email_notifications': false,
    };
  }

  // Dispose resources
  void dispose() {
    _notificationStream = null;
    debugPrint('🔔 Notification Service disposed');
  }
}
