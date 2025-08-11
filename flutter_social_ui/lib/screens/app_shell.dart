import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_social_ui/screens/simple_feeds_screen.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/screens/create_post_screen.dart';
import 'package:flutter_social_ui/screens/profile_screen.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_social_ui/screens/search_screen_new.dart';
import 'package:flutter_social_ui/screens/notifications_screen_new.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // New order (keeping Feeds screen as the main/home tab):
  // [Feeds (Home), Search (left of center), Create (center), Notifications (right of center), Profile]
  static final List<Widget> _widgetOptions = <Widget>[
    const SimpleFeedsScreen(), // Home / Feeds screen with real posts
    const SearchScreenNew(), // Left of center
    const CreatePostScreen(), // Center FAB highlight
    const NotificationsScreenNew(), // Right of center
    const ProfileScreen(), // Far right
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
        height: 60,
        backgroundColor: Colors.transparent,
        color: Colors.black,
        buttonBackgroundColor: kPrimaryColor, // red accent bubble
        animationDuration: const Duration(milliseconds: 280),
        index: _selectedIndex,
        items: <Widget>[
          // Home/Post (house icon)
          _shadowedSvg('assets/icons/home-svgrepo-com.svg', size: 26),
          // Left of center: Search (magnifier)
          _shadowedSvg('assets/icons/magnifer-svgrepo-com.svg', size: 26),
          // Center: Create (unchanged)
          _shadowedSvg('assets/icons/add-square-svgrepo-com.svg', size: 26),
          // Right of center: Notifications (heart)
          _shadowedSvg('assets/icons/heart-svgrepo-com.svg', size: 26),
          // Far right: Profile (existing)
          _shadowedSvg('assets/icons/user-rounded-svgrepo-com.svg', size: 26),
        ],
        onTap: _onItemTapped,
      ),
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
                Colors.black,
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
