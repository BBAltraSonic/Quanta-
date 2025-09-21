import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quanta/screens/post_detail_screen.dart';
import 'package:quanta/constants.dart';
import 'package:quanta/screens/create_post_screen.dart';
import 'package:quanta/screens/profile_screen.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:quanta/screens/search_screen_new.dart';
import 'package:quanta/screens/notifications_screen_new.dart';
import 'package:quanta/services/analytics_service.dart';
import 'package:quanta/services/notification_service.dart'
    as notification_service;
import 'package:quanta/services/avatar_navigation_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  int _unreadCount = 0;
  final notification_service.NotificationService _notificationService =
      notification_service.NotificationService();
  final AvatarNavigationService _avatarNavigationService =
      AvatarNavigationService();
  Stream<List<notification_service.NotificationModel>>? _notificationStream;

  // Navigation tabs with enhanced PostDetailScreen as home:
  // [PostDetail (Home), Search (left of center), Create (center), Notifications (right of center), Profile]
  static final List<Widget> _widgetOptions = <Widget>[
    const PostDetailScreen(), // Home / Enhanced TikTok-style video feed
    const SearchScreenNew(), // Left of center
    const CreatePostScreen(), // Center FAB highlight
    const NotificationsScreenNew(), // Right of center
    const ProfileScreen(), // Far right
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _initializeNotifications() async {
    try {
      // Initialize notification service
      await _notificationService.initialize();

      // Get initial unread count
      final count = await _notificationService.getUnreadCount();
      setState(() {
        _unreadCount = count;
      });

      // Set up real-time subscription for badge updates
      _notificationStream = _notificationService.getNotificationStream();
      if (_notificationStream != null) {
        _notificationStream!.listen(
          (notifications) {
            if (mounted) {
              final unreadCount = notifications.where((n) => !n.isRead).length;
              setState(() {
                _unreadCount = unreadCount;
              });
            }
          },
          onError: (error) {
            debugPrint('Notification stream error in AppShell: $error');
          },
        );
      }
    } catch (e) {
      debugPrint('Error initializing notifications in AppShell: $e');
    }
  }

  void _onItemTapped(int index) {
    // Handle avatar-centric navigation for profile tab
    if (index == 4) {
      // Profile tab - use avatar navigation service
      _avatarNavigationService.navigateToProfile(context);

      // Track profile navigation
      AnalyticsService().trackEvent(AnalyticsEvents.tabSwitch, {
        'from_tab': _getScreenName(_selectedIndex),
        'to_tab': 'Profile',
        'tab_index': index,
        'navigation_type': 'avatar_centric',
      });
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    // Track tab navigation
    AnalyticsService().trackEvent(AnalyticsEvents.tabSwitch, {
      'from_tab': _getScreenName(_selectedIndex),
      'to_tab': _getScreenName(index),
      'tab_index': index,
    });
  }

  String _getScreenName(int index) {
    const screenNames = [
      'Home',
      'Search',
      'Create',
      'Notifications',
      'Profile',
    ];
    return index < screenNames.length ? screenNames[index] : 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // prevents visual gap under curved bar
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: _curvedBottomNavigationBar(),
    );
  }

  // Curved Bottom Navigation Bar styled like the original PostDetail design
  Widget _curvedBottomNavigationBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0), // fill bottom; no extra gap
      child: CurvedNavigationBar(
        height: 62,
        backgroundColor: Colors.transparent,
        color: Color(0xFF002B36),
        buttonBackgroundColor: kPrimaryColor, // red accent bubble
        animationDuration: const Duration(milliseconds: 280),
        index: _selectedIndex,
        items: <Widget>[
          // Home/Post (house icon)
          _shadowedSvg('assets/icons/home-svgrepo-com.svg', size: 26),
          // Left of center: Search (magnifier)
          _shadowedSvg('assets/icons/magnifer-svgrepo-com.svg', size: 26),
          // Center: Create (unchanged)
          _shadowedSvg('assets/icons/add-square-svgrepo-com.svg', size: 30),
          // Right of center: Notifications (heart) with badge
          _buildNotificationIconWithBadge(),
          // Far right: Profile (existing)
          _shadowedSvg('assets/icons/user-rounded-svgrepo-com.svg', size: 26),
        ],
        onTap: _onItemTapped,
      ),
    );
  }

  // Notification icon with unread count badge
  Widget _buildNotificationIconWithBadge() {
    return Stack(
      children: [
        _shadowedSvg('assets/icons/heart-svgrepo-com.svg', size: 26),
        if (_unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // Reusable icon with subtle drop shadow to improve readability
  Widget _shadowedSvg(String path, {double size = 24}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 1.5),
          child: Opacity(
            opacity: 0.45,
            child: SvgPicture.asset(
              path,
              width: size + 2,
              height: size + 2,
              colorFilter: const ColorFilter.mode(
                Color(0xFF002B36),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        SvgPicture.asset(
          path,
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ],
    );
  }
}
