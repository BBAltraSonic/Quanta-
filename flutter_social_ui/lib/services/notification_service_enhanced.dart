import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Enhanced notification service with real-time capabilities
class NotificationServiceEnhanced {
  static final NotificationServiceEnhanced _instance = NotificationServiceEnhanced._internal();
  factory NotificationServiceEnhanced() => _instance;
  NotificationServiceEnhanced._internal();

  final AuthService _authService = AuthService();
  
  // In-memory cache for demo mode
  final Map<String, List<AppNotification>> _userNotifications = {};
  final Map<String, int> _unreadCounts = {};
  
  /// Get notifications for the current user
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return [];
      
      if (false) {
        return _getNotificationsDemo(userId, limit, offset);
      } else {
        return _getNotificationsSupabase(userId, limit, offset);
      }
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return 0;
      
      if (false) {
        return _unreadCounts[userId] ?? 0;
      } else {
        return _getUnreadCountSupabase(userId);
      }
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      if (false) {
        _markAsReadDemo(notificationId);
      } else {
        await _markAsReadSupabase(notificationId);
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;
      
      if (false) {
        _markAllAsReadDemo(userId);
      } else {
        await _markAllAsReadSupabase(userId);
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Send notification (for system/admin use)
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? avatarId,
    String? postId,
    String? commentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (false) {
        _sendNotificationDemo(
          userId: userId,
          type: type,
          title: title,
          message: message,
          avatarId: avatarId,
          postId: postId,
          commentId: commentId,
          metadata: metadata,
        );
      } else {
        await _sendNotificationSupabase(
          userId: userId,
          type: type,
          title: title,
          message: message,
          avatarId: avatarId,
          postId: postId,
          commentId: commentId,
          metadata: metadata,
        );
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Send like notification
  Future<void> sendLikeNotification({
    required String postOwnerId,
    required String likerUserId,
    required String postId,
    required String avatarName,
  }) async {
    await sendNotification(
      userId: postOwnerId,
      type: NotificationType.like,
      title: '❤️ New Like',
      message: 'Someone liked your post from $avatarName!',
      postId: postId,
      metadata: {
        'likerUserId': likerUserId,
        'avatarName': avatarName,
      },
    );
  }

  /// Send comment notification
  Future<void> sendCommentNotification({
    required String postOwnerId,
    required String commenterUserId,
    required String postId,
    required String commentText,
    required String avatarName,
  }) async {
    await sendNotification(
      userId: postOwnerId,
      type: NotificationType.comment,
      title: '💬 New Comment',
      message: 'Someone commented on your post from $avatarName!',
      postId: postId,
      metadata: {
        'commenterUserId': commenterUserId,
        'commentText': commentText,
        'avatarName': avatarName,
      },
    );
  }

  /// Send follow notification
  Future<void> sendFollowNotification({
    required String avatarOwnerId,
    required String followerUserId,
    required String avatarId,
    required String avatarName,
  }) async {
    await sendNotification(
      userId: avatarOwnerId,
      type: NotificationType.follow,
      title: '👥 New Follower',
      message: 'Someone started following $avatarName!',
      avatarId: avatarId,
      metadata: {
        'followerUserId': followerUserId,
        'avatarName': avatarName,
      },
    );
  }

  /// Send AI interaction notification
  Future<void> sendAIInteractionNotification({
    required String userId,
    required String avatarId,
    required String avatarName,
    required String interactionType,
    String? details,
  }) async {
    await sendNotification(
      userId: userId,
      type: NotificationType.aiInteraction,
      title: '🤖 AI Update',
      message: '$avatarName $interactionType',
      avatarId: avatarId,
      metadata: {
        'interactionType': interactionType,
        'details': details,
      },
    );
  }

  /// Send system notification
  Future<void> sendSystemNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    await sendNotification(
      userId: userId,
      type: NotificationType.system,
      title: title,
      message: message,
      metadata: metadata,
    );
  }

  // Demo mode implementations
  List<AppNotification> _getNotificationsDemo(String userId, int limit, int offset) {
    final notifications = _userNotifications[userId] ?? [];
    
    // Sort by timestamp (newest first)
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, notifications.length);
    
    if (startIndex >= notifications.length) return [];
    
    return notifications.sublist(startIndex, endIndex);
  }

  void _markAsReadDemo(String notificationId) {
    for (final notifications in _userNotifications.values) {
      for (final notification in notifications) {
        if (notification.id == notificationId && !notification.isRead) {
          notification.isRead = true;
          final userId = notification.userId;
          _unreadCounts[userId] = (_unreadCounts[userId] ?? 1) - 1;
          if (_unreadCounts[userId]! < 0) _unreadCounts[userId] = 0;
          break;
        }
      }
    }
  }

  void _markAllAsReadDemo(String userId) {
    final notifications = _userNotifications[userId] ?? [];
    for (final notification in notifications) {
      notification.isRead = true;
    }
    _unreadCounts[userId] = 0;
  }

  void _sendNotificationDemo({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? avatarId,
    String? postId,
    String? commentId,
    Map<String, dynamic>? metadata,
  }) {
    final notification = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
      avatarId: avatarId,
      postId: postId,
      commentId: commentId,
      metadata: metadata ?? {},
    );

    _userNotifications[userId] = _userNotifications[userId] ?? [];
    _userNotifications[userId]!.insert(0, notification);
    _unreadCounts[userId] = (_unreadCounts[userId] ?? 0) + 1;
  }

  /// Initialize demo data
  void initializeDemoData() {
    const demoUserId = 'demo-user-1';
    
    final demoNotifications = [
      AppNotification(
        id: 'notif-1',
        userId: demoUserId,
        type: NotificationType.like,
        title: '❤️ New Like',
        message: 'Someone liked your post from TechBot!',
        timestamp: DateTime.now().subtract(Duration(minutes: 5)),
        isRead: false,
        postId: 'post-1',
        metadata: {'avatarName': 'TechBot'},
      ),
      AppNotification(
        id: 'notif-2',
        userId: demoUserId,
        type: NotificationType.comment,
        title: '💬 New Comment',
        message: 'ArtBot commented on your creative post!',
        timestamp: DateTime.now().subtract(Duration(minutes: 15)),
        isRead: false,
        postId: 'post-2',
        metadata: {'avatarName': 'ArtBot', 'commentText': 'This is amazing!'},
      ),
      AppNotification(
        id: 'notif-3',
        userId: demoUserId,
        type: NotificationType.follow,
        title: '👥 New Follower',
        message: 'Someone started following CreativeBot!',
        timestamp: DateTime.now().subtract(Duration(hours: 1)),
        isRead: true,
        avatarId: 'avatar-3',
        metadata: {'avatarName': 'CreativeBot'},
      ),
      AppNotification(
        id: 'notif-4',
        userId: demoUserId,
        type: NotificationType.aiInteraction,
        title: '🤖 AI Update',
        message: 'TechBot generated a new response to a user comment!',
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        isRead: true,
        avatarId: 'avatar-1',
        metadata: {
          'interactionType': 'generated a new response',
          'details': 'Auto-replied to a comment about AI development',
        },
      ),
      AppNotification(
        id: 'notif-5',
        userId: demoUserId,
        type: NotificationType.system,
        title: '🎉 Welcome to Quanta!',
        message: 'Your AI avatar platform is ready! Start creating and sharing.',
        timestamp: DateTime.now().subtract(Duration(days: 1)),
        isRead: true,
        metadata: {'welcomeMessage': true},
      ),
    ];

    _userNotifications[demoUserId] = demoNotifications;
    _unreadCounts[demoUserId] = demoNotifications.where((n) => !n.isRead).length;
  }

  // Supabase implementations (placeholders)
  Future<List<AppNotification>> _getNotificationsSupabase(String userId, int limit, int offset) async {
    // TODO: Implement Supabase notifications
    throw UnimplementedError('Supabase notifications not implemented yet');
  }

  Future<int> _getUnreadCountSupabase(String userId) async {
    // TODO: Implement Supabase unread count
    throw UnimplementedError('Supabase unread count not implemented yet');
  }

  Future<void> _markAsReadSupabase(String notificationId) async {
    // TODO: Implement Supabase mark as read
    throw UnimplementedError('Supabase mark as read not implemented yet');
  }

  Future<void> _markAllAsReadSupabase(String userId) async {
    // TODO: Implement Supabase mark all as read
    throw UnimplementedError('Supabase mark all as read not implemented yet');
  }

  Future<void> _sendNotificationSupabase({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? avatarId,
    String? postId,
    String? commentId,
    Map<String, dynamic>? metadata,
  }) async {
    // TODO: Implement Supabase send notification
    throw UnimplementedError('Supabase send notification not implemented yet');
  }

  /// Clear all cache
  void clearCache() {
    _userNotifications.clear();
    _unreadCounts.clear();
  }
}

/// Notification model
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;
  final String? avatarId;
  final String? postId;
  final String? commentId;
  final Map<String, dynamic> metadata;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    this.avatarId,
    this.postId,
    this.commentId,
    required this.metadata,
  });

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }

  /// Get notification icon
  String get icon {
    switch (type) {
      case NotificationType.like:
        return '❤️';
      case NotificationType.comment:
        return '💬';
      case NotificationType.follow:
        return '👥';
      case NotificationType.aiInteraction:
        return '🤖';
      case NotificationType.system:
        return '🔔';
    }
  }
}

/// Notification types
enum NotificationType {
  like,
  comment,
  follow,
  aiInteraction,
  system,
}
