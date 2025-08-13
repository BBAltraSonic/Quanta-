import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import 'package:flutter_social_ui/models/chat_message.dart';
import 'package:flutter_social_ui/services/enhanced_feeds_service.dart';
import 'package:flutter_social_ui/services/avatar_service.dart';
import 'package:flutter_social_ui/services/auth_service_wrapper.dart';
import 'package:flutter_social_ui/services/notification_service.dart' as notification_service;
import 'package:flutter_social_ui/services/enhanced_chat_service.dart';
import 'package:flutter_social_ui/screens/chat_screen.dart';
import 'package:flutter_social_ui/screens/post_detail_screen.dart';
import 'package:flutter_social_ui/screens/profile_screen.dart';
import 'package:flutter_social_ui/widgets/skeleton_widgets.dart';
import 'package:flutter/services.dart';
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

  // Note: fromJson method removed as it was unused
  // All data conversion is done directly from NotificationModel in the service
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
  final EnhancedChatService _chatService = EnhancedChatService();
  late TabController _tabController;

  List<NotificationItem> _allNotifications = [];
  List<NotificationItem> _unreadNotifications = [];
  List<ChatMessage> _messages = [];
  final Map<String, AvatarModel> _avatarCache = {};

  bool _isLoading = true;
  bool _isRefreshing = false;
  
  // Real-time subscription
  Stream<List<notification_service.NotificationModel>>? _notificationStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _notificationService.initialize();
      await _loadNotifications();
      await _loadMessages();
      _setupRealtimeSubscription();
    } catch (e) {
      debugPrint('Error initializing services: $e');
      _loadNotifications();
      _loadMessages();
    }
  }
  
  void _setupRealtimeSubscription() {
    try {
      _notificationStream = _notificationService.getNotificationStream();
      
      if (_notificationStream != null) {
        _notificationStream!.listen(
          (notifications) {
            if (mounted) {
              _updateNotificationsFromStream(notifications);
            }
          },
          onError: (error) {
            debugPrint('Real-time notification error: $error');
          },
        );
      }
    } catch (e) {
      debugPrint('Error setting up real-time notifications: $e');
    }
  }
  
  void _updateNotificationsFromStream(List<notification_service.NotificationModel> notifications) {
    final notificationItems = notifications.map((n) => NotificationItem(
      id: n.id,
      type: _mapNotificationType(n.type),
      title: n.title,
      message: n.message,
      isRead: n.isRead,
      timestamp: n.createdAt,
      avatarId: n.relatedAvatarId,
      postId: n.relatedPostId,
      userId: n.relatedUserId,
    )).toList();
    
    setState(() {
      _allNotifications = notificationItems;
    });
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
                  if (_allNotifications.any((n) => !n.isRead))
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
                  Tab(text: 'Messages (${_messages.length})'),
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
                          _buildMessagesList(_messages),
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

              // Unread indicator and action menu
              Column(
                children: [
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  SizedBox(height: 4),
                  // Action menu button
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: kLightTextColor,
                      size: 20,
                    ),
                    color: kCardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      if (notification.isRead)
                        PopupMenuItem<String>(
                          value: 'mark_unread',
                          child: Row(
                            children: [
                              Icon(Icons.mark_email_unread_outlined, color: kLightTextColor, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Mark as unread',
                                style: TextStyle(color: kLightTextColor),
                              ),
                            ],
                          ),
                        ),
                      PopupMenuItem<String>(
                        value: 'mute_type',
                        child: Row(
                          children: [
                            Icon(Icons.notifications_off_outlined, color: kLightTextColor, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Mute this type',
                              style: TextStyle(color: kLightTextColor),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'copy_link',
                        child: Row(
                          children: [
                            Icon(Icons.copy, color: kLightTextColor, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Copy link',
                              style: TextStyle(color: kLightTextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) => _handleNotificationAction(notification, value),
                  ),
                ],
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
        userId: n.relatedUserId, // Fix: Add missing relatedUserId mapping
      )).toList();

      setState(() {
        _allNotifications = notificationItems;
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
        return NotificationType.systemUpdate; // Correct system mapping
    }
  }



  Future<void> _refreshNotifications() async {
    setState(() => _isRefreshing = true);
    await _loadNotifications();
    await _loadMessages();
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
        // Navigate to post detail with real navigation
        if (notification.postId != null) {
          _navigateToPostDetail(notification.postId!);
        } else {
          _showErrorMessage('Post not found');
        }
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
        // Navigate to profile with real navigation
        if (notification.userId != null) {
          _navigateToProfile(notification.userId!);
        } else {
          _showErrorMessage('User profile not found');
        }
        break;

      case NotificationType.systemUpdate:
        // Show system update details or navigate to settings
        _showNotificationDetails(notification);
        break;
    }
  }

  void _markAsRead(NotificationItem notification) async {
    // Optimistically update UI first
    setState(() {
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
      _unreadNotifications = _allNotifications.where((n) => !n.isRead).toList();
    });

    // Persist to database
    try {
      await _notificationService.markAsRead(notification.id);
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
      // Revert optimistic update on error
      setState(() {
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
            isRead: false,
            metadata: notification.metadata,
          );
        }
        _unreadNotifications = _allNotifications.where((n) => !n.isRead).toList();
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark notification as read')),
        );
      }
    }
  }

  void _markAllAsRead() async {
    // Store original state for rollback
    final originalNotifications = List<NotificationItem>.from(_allNotifications);
    final originalUnreadNotifications = List<NotificationItem>.from(_unreadNotifications);
    
    // Optimistically update UI first
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

    // Persist to database
    try {
      await _notificationService.markAllAsRead();
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
      
      // Revert optimistic update on error
      setState(() {
        _allNotifications = originalNotifications;
        _unreadNotifications = originalUnreadNotifications;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all notifications as read')),
        );
      }
    }
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

  // Navigate to PostDetailScreen with postId
  void _navigateToPostDetail(String postId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: kCardColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: kPrimaryColor),
              SizedBox(height: 16),
              Text(
                'Loading post...',
                style: kBodyTextStyle,
              ),
            ],
          ),
        ),
      );

      // Try to fetch the post first to validate it exists
      final post = await _feedsService.getPostById(postId);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (post != null) {
        // Navigate with the post data
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(initialPost: post),
          ),
        );
      } else {
        // Post not found, try navigating with just the ID
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: postId),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      debugPrint('Error navigating to post detail: $e');
      _showErrorMessage('Unable to open post. Please try again.');
    }
  }

  // Navigate to ProfileScreen with userId
  void _navigateToProfile(String userId) async {
    try {
      // Navigate directly to profile screen with userId
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: userId),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
      _showErrorMessage('Unable to open profile. Please try again.');
    }
  }

  // Show error message with retry option
  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () {
            // Refresh notifications to retry
            _refreshNotifications();
          },
        ),
      ),
    );
  }

  // Handle notification action menu selections
  void _handleNotificationAction(NotificationItem notification, String action) {
    switch (action) {
      case 'delete':
        _deleteNotification(notification);
        break;
      case 'mark_unread':
        _markAsUnread(notification);
        break;
      case 'mute_type':
        _muteNotificationType(notification.type);
        break;
      case 'copy_link':
        _copyNotificationLink(notification);
        break;
    }
  }

  // Delete notification with confirmation
  void _deleteNotification(NotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(
          'Delete Notification',
          style: kHeadingTextStyle.copyWith(fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete this notification?',
          style: kBodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: kLightTextColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performDeleteNotification(notification);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Perform actual notification deletion
  Future<void> _performDeleteNotification(NotificationItem notification) async {
    // Optimistically remove from UI
    final originalAllNotifications = List<NotificationItem>.from(_allNotifications);
    final originalUnreadNotifications = List<NotificationItem>.from(_unreadNotifications);
    
    setState(() {
      _allNotifications.removeWhere((n) => n.id == notification.id);
      _unreadNotifications.removeWhere((n) => n.id == notification.id);
    });

    try {
      await _notificationService.deleteNotification(notification.id);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Notification deleted',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to delete notification: $e');
      
      // Revert optimistic update
      setState(() {
        _allNotifications = originalAllNotifications;
        _unreadNotifications = originalUnreadNotifications;
      });
      
      _showErrorMessage('Failed to delete notification. Please try again.');
    }
  }

  // Mark notification as unread
  void _markAsUnread(NotificationItem notification) async {
    // Optimistically update UI first
    setState(() {
      final index = _allNotifications.indexWhere((n) => n.id == notification.id);
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
          isRead: false,
          metadata: notification.metadata,
        );
        _unreadNotifications.add(_allNotifications[index]);
      }
    });

    // Note: There's no markAsUnread method in the notification service
    // For now, we'll show a message that this feature is coming soon
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Marked as unread (feature coming soon)',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Mute notification type
  void _muteNotificationType(NotificationType type) {
    final typeDisplayName = _getNotificationTypeDisplayName(type);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(
          'Mute ${typeDisplayName} Notifications',
          style: kHeadingTextStyle.copyWith(fontSize: 18),
        ),
        content: Text(
          'You won\'t receive ${typeDisplayName.toLowerCase()} notifications anymore. You can change this in settings.',
          style: kBodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: kLightTextColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performMuteNotificationType(type, typeDisplayName);
            },
            child: Text(
              'Mute',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  // Perform actual muting (placeholder implementation)
  void _performMuteNotificationType(NotificationType type, String displayName) {
    // For now, just show a success message
    // In a real implementation, this would update user preferences
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications_off, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '${displayName} notifications muted',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${displayName} notifications unmuted'),
                backgroundColor: Colors.green[700],
              ),
            );
          },
        ),
      ),
    );
  }

  // Copy notification link to clipboard
  void _copyNotificationLink(NotificationItem notification) async {
    String linkText = '';
    
    // Generate appropriate link based on notification type
    switch (notification.type) {
      case NotificationType.like:
      case NotificationType.comment:
      case NotificationType.postFeatured:
        if (notification.postId != null) {
          linkText = 'quanta.app/post/${notification.postId}';
        }
        break;
      case NotificationType.follow:
      case NotificationType.mention:
        if (notification.userId != null) {
          linkText = 'quanta.app/profile/${notification.userId}';
        }
        break;
      case NotificationType.chatMessage:
      case NotificationType.avatarReply:
        if (notification.avatarId != null) {
          linkText = 'quanta.app/chat/${notification.avatarId}';
        }
        break;
      default:
        linkText = 'quanta.app/notifications';
    }

    if (linkText.isNotEmpty) {
      try {
        await Clipboard.setData(ClipboardData(text: linkText));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.copy, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Link copied to clipboard',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue[700],
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Failed to copy to clipboard: $e');
        _showErrorMessage('Failed to copy link');
      }
    } else {
      _showErrorMessage('No link available for this notification');
    }
  }

  // Get display name for notification type
  String _getNotificationTypeDisplayName(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return 'Like';
      case NotificationType.comment:
        return 'Comment';
      case NotificationType.follow:
        return 'Follow';
      case NotificationType.mention:
        return 'Mention';
      case NotificationType.chatMessage:
        return 'Chat Message';
      case NotificationType.avatarReply:
        return 'Avatar Reply';
      case NotificationType.postFeatured:
        return 'Post Featured';
      case NotificationType.systemUpdate:
        return 'System Update';
    }
  }

  // ===== MESSAGE FUNCTIONALITY =====
  
  Widget _buildMessagesList(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return _buildMessagesEmptyState();
    }

    // Group messages by avatar/sender
    final groupedMessages = <String, List<ChatMessage>>{};
    for (final message in messages) {
      final key = message.isMe ? 'me' : (message.avatarUrl ?? 'unknown');
      groupedMessages[key] = groupedMessages[key] ?? [];
      groupedMessages[key]!.add(message);
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: groupedMessages.length,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = groupedMessages.entries.elementAt(index);
        final senderKey = entry.key;
        final senderMessages = entry.value;
        final latestMessage = senderMessages.last;
        
        return _buildMessageCard(senderKey, latestMessage, senderMessages.length);
      },
    );
  }

  Widget _buildMessageCard(String senderKey, ChatMessage latestMessage, int messageCount) {
    final isFromMe = senderKey == 'me';
    final avatarUrl = isFromMe ? 'assets/images/We.jpg' : latestMessage.avatarUrl;
    final senderName = isFromMe ? 'You' : _getSenderNameFromMessage(latestMessage);
    
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () => _handleMessageTap(latestMessage),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: avatarUrl != null && avatarUrl.startsWith('assets/')
                      ? Image.asset(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              isFromMe ? Icons.person : Icons.smart_toy,
                              color: kPrimaryColor,
                              size: 24,
                            );
                          },
                        )
                      : Icon(
                          isFromMe ? Icons.person : Icons.smart_toy,
                          color: kPrimaryColor,
                          size: 24,
                        ),
                ),
              ),

              SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          senderName,
                          style: kBodyTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeago.format(latestMessage.time),
                          style: kCaptionTextStyle.copyWith(
                            color: kLightTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      latestMessage.text,
                      style: kCaptionTextStyle.copyWith(
                        color: kLightTextColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (messageCount > 1)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '$messageCount messages',
                          style: kCaptionTextStyle.copyWith(
                            color: kPrimaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Message indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: kLightTextColor),
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: kHeadingTextStyle.copyWith(fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Start chatting with your avatars\nto see messages here.',
            style: kBodyTextStyle.copyWith(color: kLightTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getSenderNameFromMessage(ChatMessage message) {
    // Try to get avatar name from cache or return default
    // In a real implementation, you might extract this from message metadata
    return 'Avatar'; // Placeholder - could be enhanced to get actual avatar names
  }

  void _handleMessageTap(ChatMessage message) {
    // Navigate to the chat screen
    // For messages from avatars, we can try to navigate to that specific chat
    if (!message.isMe) {
      // Try to determine avatar ID from message or navigate to general chat
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            name: _getSenderNameFromMessage(message),
            avatar: message.avatarUrl ?? 'assets/images/p.jpg',
          ),
        ),
      );
    }
  }

  Future<void> _loadMessages() async {
    try {
      // Load recent messages from chat service
      // This is a placeholder implementation
      final recentMessages = await _chatService.getRecentMessages();
      setState(() {
        _messages = recentMessages;
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');
      // For now, create some sample messages for demo purposes
      setState(() {
        _messages = _createSampleMessages();
      });
    }
  }

  List<ChatMessage> _createSampleMessages() {
    // Sample messages for demo purposes
    return [
      ChatMessage(
        id: 'sample_1',
        text: 'Hello! How are you doing today?',
        isMe: false,
        time: DateTime.now().subtract(Duration(hours: 2)),
        avatarUrl: 'assets/images/p.jpg',
      ),
      ChatMessage(
        id: 'sample_2',
        text: 'I\'m working on some new features for the app',
        isMe: true,
        time: DateTime.now().subtract(Duration(hours: 1)),
        avatarUrl: 'assets/images/We.jpg',
      ),
      ChatMessage(
        id: 'sample_3',
        text: 'That sounds exciting! Let me know if you need any help.',
        isMe: false,
        time: DateTime.now().subtract(Duration(minutes: 30)),
        avatarUrl: 'assets/images/p.jpg',
      ),
    ];
  }
}
