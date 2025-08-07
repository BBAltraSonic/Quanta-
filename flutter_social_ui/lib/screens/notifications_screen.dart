import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Import for SVG assets
import 'chat_screen.dart';

enum TabKind { notifications, chats }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Local style tokens (scoped to this screen)
  // Black base with a stronger but still subtle deep red tint
  static const _bgStart = Color(0xFF000000); // black
  static const _bgEnd = Color(
    0xFF3A0006,
  ); // deeper red to make tint more visible
  static const _surface = Color(0xFFF7F7F7);
  static const _accent = Color(0xFF25D366);
  static const _pagePad = 16.0;
  static const _cardRadius = 24.0;
  static const _segmentRadius = 18.0;

  TabKind _tab = TabKind.notifications; // Default to notifications tab

  // Mock data for Notifications
  final List<_ChatItem> _notificationList = [
    _ChatItem(
      'Jason',
      'assets/images/We.jpg',
      'User ${1} liked your post • ${15}m',
      '9:41 PM',
      isOnline: false,
      unread: true,
    ),
    _ChatItem(
      'John',
      'assets/images/p.jpg',
      'User ${2} commented on your photo • ${20}m',
      '5:07 PM',
      isOnline: false,
    ),
    _ChatItem(
      'Matt L',
      'assets/images/We.jpg',
      'User ${3} started following you • ${30}m',
      '2:23 PM',
      isOnline: false,
    ),
    _ChatItem(
      'Nicolas',
      'assets/images/p.jpg',
      'User ${4} mentioned you in a comment • ${45}m',
      '10:02 AM',
      isOnline: false,
      unread: true,
    ),
    _ChatItem(
      'Katie',
      'assets/images/We.jpg',
      'User ${5} sent you a message • ${60}m',
      '7:46 AM',
      isOnline: false,
    ),
  ];

  // Mock data for Chats
  final List<_ChatItem> _chatList = [
    _ChatItem(
      'Jason',
      'assets/images/We.jpg',
      'Hey! Are you free to call tonight?',
      '9:41 PM',
      isOnline: true,
      unread: true,
    ),
    _ChatItem(
      'John',
      'assets/images/p.jpg',
      'Did you see this? 😅',
      '5:07 PM',
      isOnline: true,
    ),
    _ChatItem(
      'Matt L',
      'assets/images/We.jpg',
      'Looks nice there! Wish I was in Ha...',
      '2:23 PM',
    ),
    _ChatItem(
      'Nicolas',
      'assets/images/p.jpg',
      'Hey bro! How are you?',
      '10:02 AM',
      unread: true,
    ),
    _ChatItem('Katie', 'assets/images/We.jpg', 'Sent an image', '7:46 AM'),
    _ChatItem(
      'Flutter Devs',
      'assets/images/We.jpg',
      'Ben: push your branch when ready',
      '8:30 PM',
      isGroup: true,
    ),
    _ChatItem(
      'Weekend Hikers',
      'assets/images/p.jpg',
      'Sam: Meet 7 AM at the gate',
      'Yesterday',
      isGroup: true,
      unread: true,
    ),
  ];

  List<_ChatItem> get _items =>
      _tab == TabKind.notifications ? _notificationList : _chatList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = _items;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgStart, _bgEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _pagePad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _Header(
                      onSearch: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Search tapped')),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _StoriesRow(accent: _accent),
                    const SizedBox(height: 16),
                    // White surface stretches to the bottom by expanding this card
                    Expanded(
                      child: _SegmentCard(
                        surface: _surface,
                        radius: _cardRadius,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Column(
                            children: [
                              _SegmentedControl(
                                activeColor: _accent,
                                radius: _segmentRadius,
                                value: _tab,
                                onChanged: (v) => setState(() => _tab = v),
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 4),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: list.length,
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 12,
                                  ),
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, i) =>
                                      _ConversationTile(
                                        item: list[i],
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                name: list[i].name,
                                                avatar: list[i].avatar,
                                                isGroup: list[i].isGroup,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          'Notifications', // Changed title to Notifications
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onSearch,
          icon: SvgPicture.asset(
            // Replaced with SVG asset
            'assets/icons/search.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          tooltip: 'Search',
        ),
        IconButton(
          onPressed: () {},
          icon: SvgPicture.asset(
            // Replaced with SVG asset
            'assets/icons/menu-dots-svgrepo-com.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          tooltip: 'More',
        ),
      ],
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final names = ['Add', 'Jason', 'Sam', 'Matt L', 'Jane'];
    final avatars = [
      null,
      'assets/images/We.jpg',
      'assets/images/p.jpg',
      'assets/images/We.jpg',
      'assets/images/p.jpg',
    ];
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: names.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _AddStory(accent: accent);
          }
          return _StoryAvatar(
            name: names[i],
            avatar: avatars[i]!,
            accent: accent,
          );
        },
      ),
    );
  }
}

class _AddStory extends StatelessWidget {
  const _AddStory({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withOpacity(0.6),
              width: 2,
              style: BorderStyle.solid,
            ),
            color: Colors.white.withOpacity(0.06),
          ),
          child: const Center(child: Icon(Icons.add, color: Colors.white)),
        ),
        const SizedBox(height: 6),
        const SizedBox(
          width: 64,
          child: Text(
            'Add',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.name,
    required this.avatar,
    required this.accent,
  });
  final String name;
  final String avatar;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [accent, accent.withOpacity(0.6)]),
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.black,
            child: CircleAvatar(
              radius: 28,
              backgroundImage: AssetImage(avatar),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 64,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({
    required this.surface,
    required this.radius,
    required this.child,
  });
  final Color surface;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 520,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.radius,
  });
  final TabKind value;
  final ValueChanged<TabKind> onChanged;
  final Color activeColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isNotifications = value == TabKind.notifications;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: isNotifications
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Container(
              width:
                  (MediaQuery.of(context).size.width - 2 * 16 - 24) /
                  2, // approximate within constraints
              height: 34,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(radius - 2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius),
                  onTap: () => onChanged(TabKind.notifications),
                  child: Center(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isNotifications ? Colors.black : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius),
                  onTap: () => onChanged(TabKind.chats),
                  child: Center(
                    child: Text(
                      'Chats', // Changed from 'Groups' to 'Chats'
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isNotifications ? Colors.black54 : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.item, required this.onTap});
  final _ChatItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: AssetImage(item.avatar),
                ),
                if (item.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: item.unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.time,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.lastMessage,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatItem {
  _ChatItem(
    this.name,
    this.avatar,
    this.lastMessage,
    this.time, {
    this.unread = false,
    this.isOnline = false,
    this.isGroup = false,
  });

  final String name;
  final String avatar;
  final String lastMessage;
  final String time;
  final bool unread;
  final bool isOnline;
  final bool isGroup;
}
