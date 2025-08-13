import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import 'package:flutter_social_ui/services/enhanced_feeds_service.dart';
import 'package:flutter_social_ui/services/avatar_service.dart';
import 'package:flutter_social_ui/services/auth_service_wrapper.dart';
import 'package:flutter_social_ui/services/notification_service.dart' as notification_service;
import 'package:flutter_social_ui/screens/chat_screen.dart';
import 'package:flutter_social_ui/widgets/skeleton_widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

enum NotificationType {
  like,
  comment,
  follow,
  mention,
  chatMessage,
  avatarReply,
  postFeatured,
  systemUpdate,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? avatarId;
  final String? postId;
  final String? userId;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.avatarId,
    this.postId,
    this.userId,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => NotificationType.systemUpdate,
      ),
      title: json['title'],
      message: json['message'],
      avatarId: json['avatar_id'],
      postId: json['post_id'],
      userId: json['user_id'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['is_read'] ?? false,
      metadata: json['metadata'],
    );
  }
}

class NotificationsScreenNew extends StatefulWidget {
  const NotificationsScreenNew({super.key});

  @override
  _NotificationsScreenNewState createState() => _NotificationsScreenNewState();
}

class _NotificationsScreenNewState extends State<NotificationsScreenNew>
    with SingleTickerProviderStateMixin {
  final EnhancedFeedsService _feedsService = EnhancedFeedsService();
  final AvatarService _avatarService = AvatarService();
  final AuthService _authService = AuthService();
  final notification_service.NotificationService _notificationService = notification_service.NotificationService();
  late TabController _tabController;

  List<NotificationItem> _allNotifications = [];
  List<NotificationItem> _unreadNotifications = [];
  final Map<String, AvatarModel> _avatarCache = {};

  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize any required services here if needed
      _loadNotifications();
    } catch (e) {
      debugPrint('Error initializing services: $e');
      _loadNotifications();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: kHeadingTextStyle.copyWith(fontSize: 24),
                  ),
                  Spacer(),
                  if (_unreadNotifications.isNotEmpty)
                    TextButton(
                      onPressed: _markAllAsRead,
                      child: Text(
                        'Mark all read',
                        style: TextStyle(color: kPrimaryColor),
                      ),
                    ),
                ],
              ),
            ),

            // Tab bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                controller: _tabController,
                labelColor: kPrimaryColor,
                unselectedLabelColor: kLightTextColor,
                indicatorColor: kPrimaryColor,
                tabs: [
                  Tab(text: 'All (${_allNotifications.length})'),
                  Tab(text: 'Unread (${_unreadNotifications.length})'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : RefreshIndicator(
                      onRefresh: _refreshNotifications,
                      color: kPrimaryColor,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildNotificationsList(_allNotifications),
                          _buildNotificationsList(_unreadNotifications),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SkeletonLoader.notificationList(itemCount: 8);
  }

  Widget _buildNotificationsList(List<NotificationItem> notifications) {
    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return Container(
      decoration: BoxDecoration(
        color: notification.isRead ? kCardColor : kCardColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: notification.isRead
            ? null
            : Border.all(color: kPrimaryColor.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getNotificationColor(
                    notification.type,
                  ).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 24,
                ),
              ),

              SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: kBodyTextStyle.copyWith(
                        fontWeight: notification.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: kCaptionTextStyle.copyWith(
                        color: kLightTextColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      timeago.format(notification.timestamp),
                      style: kCaptionTextStyle.copyWith(
                        color: kLightTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: kLightTextColor),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: kHeadingTextStyle.copyWith(fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'When your avatars get likes, comments, or messages,\nyou\'ll see them here.',
            style: kBodyTextStyle.copyWith(color: kLightTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.comment:
        return Icons.comment;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.chatMessage:
        return Icons.chat_bubble;
      case NotificationType.avatarReply:
        return Icons.smart_toy;
      case NotificationType.postFeatured:
        return Icons.star;
      case NotificationType.systemUpdate:
        return Icons.info;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Colors.red;
      case NotificationType.comment:
        return Colors.blue;
      case NotificationType.follow:
        return Colors.green;
      case NotificationType.mention:
        return Colors.orange;
      case NotificationType.chatMessage:
        return kPrimaryColor;
      case NotificationType.avatarReply:
        return Colors.purple;
      case NotificationType.postFeatured:
        return Colors.amber;
      case NotificationType.systemUpdate:
        return kLightTextColor;
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final notifications = await _notificationService.getUserNotifications();
      
      // Convert NotificationModel to NotificationItem for UI compatibility
      final notificationItems = notifications.map((n) => NotificationItem(
        id: n.id,
        type: _mapNotificationType(n.type),
        title: n.title,
        message: n.message,
        isRead: n.isRead,
        timestamp: n.createdAt,
        avatarId: n.relatedAvatarId,
        postId: n.relatedPostId,
      )).toList();

      setState(() {
        _allNotifications = notificationItems;
        _unreadNotifications = notificationItems.where((n) => !n.isRead).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      // Still show empty state on error
      setState(() {
        _allNotifications = [];
        _unreadNotifications = [];
        _isLoading = false;
      });
    }
  }

  // Map notification service types to UI types
  NotificationType _mapNotificationType(notification_service.NotificationType serviceType) {
    switch (serviceType) {
      case notification_service.NotificationType.like:
        return NotificationType.like;
      case notification_service.NotificationType.comment:
        return NotificationType.comment;
      case notification_service.NotificationType.follow:
        return NotificationType.follow;
      case notification_service.NotificationType.mention:
        return NotificationType.mention;
      case notification_service.NotificationType.system:
        return NotificationType.postFeatured; // Default mapping
    }
  }



  Future<void> _refreshNotifications() async {
    setState(() => _isRefreshing = true);
    await _loadNotifications();
    setState(() => _isRefreshing = false);
  }

  void _handleNotificationTap(NotificationItem notification) {
    // Mark as read if not already
    if (!notification.isRead) {
      _markAsRead(notification);
    }

    // Handle different notification types
    switch (notification.type) {
      case NotificationType.like:
      case NotificationType.comment:
      case NotificationType.postFeatured:
        // Navigate to post detail (would need post ID)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to post: ${notification.postId}')),
        );
        break;

      case NotificationType.chatMessage:
      case NotificationType.avatarReply:
        // Navigate to chat (would need avatar info)
        if (notification.avatarId != null) {
          _navigateToAvatarChat(notification.avatarId!);
        }
        break;

      case NotificationType.follow:
      case NotificationType.mention:
        // Navigate to profile or relevant screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigate to profile: ${notification.userId}'),
          ),
        );
        break;

      case NotificationType.systemUpdate:
        // Show system update details or navigate to settings
        _showNotificationDetails(notification);
        break;
    }
  }

  void _markAsRead(NotificationItem notification) {
    setState(() {
      // Update the notification
      final index = _allNotifications.indexWhere(
        (n) => n.id == notification.id,
      );
      if (index != -1) {
        _allNotifications[index] = NotificationItem(
          id: notification.id,
          type: notification.type,
          title: notification.title,
          message: notification.message,
          avatarId: notification.avatarId,
          postId: notification.postId,
          userId: notification.userId,
          timestamp: notification.timestamp,
          isRead: true,
          metadata: notification.metadata,
        );
      }

      // Update unread list
      _unreadNotifications = _allNotifications.where((n) => !n.isRead).toList();
    });
  }

  void _markAllAsRead() {
    setState(() {
      _allNotifications = _allNotifications.map((notification) {
        return NotificationItem(
          id: notification.id,
          type: notification.type,
          title: notification.title,
          message: notification.message,
          avatarId: notification.avatarId,
          postId: notification.postId,
          userId: notification.userId,
          timestamp: notification.timestamp,
          isRead: true,
          metadata: notification.metadata,
        );
      }).toList();

      _unreadNotifications.clear();
    });
  }

  void _navigateToAvatarChat(String avatarId) async {
    try {
      final avatar = await _avatarService.getAvatar(avatarId);
      if (avatar != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              name: avatar.name,
              avatar: avatar.imageUrl ?? 'assets/images/p.jpg',
              avatarId: avatar.id,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading avatar: $e')));
    }
  }

  void _showNotificationDetails(NotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(
          notification.title,
          style: kHeadingTextStyle.copyWith(fontSize: 18),
        ),
        content: Text(notification.message, style: kBodyTextStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }
}
