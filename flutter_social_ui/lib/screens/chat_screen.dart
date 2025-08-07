import 'package:flutter/material.dart';
import 'package:flutter_social_ui/models/chat_message.dart';
import 'package:flutter_social_ui/widgets/chat_bubble.dart';
import 'package:flutter_social_ui/widgets/day_separator.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class ChatScreen extends StatefulWidget {
  final String name;
  final String avatar;
  final bool isGroup;

  const ChatScreen({
    Key? key,
    required this.name,
    required this.avatar,
    this.isGroup = false,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      text: 'off at your place, hope you like it!!!',
      isMe: false,
      time: DateTime(2025, 8, 6, 21, 45),
      avatarUrl: 'assets/images/p.jpg',
    ),
    ChatMessage(
      id: '2',
      text: 'Thanks so much man! 🙏',
      isMe: true,
      time: DateTime(2025, 8, 6, 21, 45),
      avatarUrl: 'assets/images/We.jpg',
    ),
    ChatMessage(
      id: '3',
      text:
          'Do you think you will be able to make it to the presentation tomorrow? I think it would be helpfull for the team if you are there to support them. 😊',
      isMe: false,
      time: DateTime(2025, 8, 7, 11, 46),
      avatarUrl: 'assets/images/p.jpg',
    ),
    ChatMessage(
      id: '4',
      text: 'Yes I should be able to make it!',
      isMe: true,
      time: DateTime(2025, 8, 7, 11, 46),
      avatarUrl: 'assets/images/We.jpg',
    ),
    ChatMessage(
      id: '5',
      text: 'What time is it at again?',
      isMe: true,
      time: DateTime(2025, 8, 7, 11, 46),
      avatarUrl: 'assets/images/We.jpg',
    ),
    ChatMessage(
      id: '6',
      text: '2:30, but I don\'t think it\'ll start then',
      isMe: false,
      time: DateTime(2025, 8, 7, 12, 5),
      avatarUrl: 'assets/images/p.jpg',
    ),
    ChatMessage(
      id: '7',
      text: 'Probably more like 3pm',
      isMe: false,
      time: DateTime(2025, 8, 7, 12, 5),
      avatarUrl: 'assets/images/p.jpg',
    ),
    ChatMessage(
      id: '8',
      text: 'Thanks again for coming 😉',
      isMe: false,
      time: DateTime(2025, 8, 7, 12, 5),
      avatarUrl: 'assets/images/p.jpg',
    ),
    ChatMessage(
      id: '9',
      text: 'Hey! Are you free to call tonight?',
      isMe: true,
      time: DateTime(2025, 8, 7, 21, 41),
      avatarUrl: 'assets/images/We.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _messages.sort((a, b) => a.time.compareTo(b.time));
  }

  void _handleSend() {
    if (_textController.text.trim().isEmpty) return;

    final newMessage = ChatMessage(
      id: DateTime.now().toIso8601String(),
      text: _textController.text.trim(),
      isMe: true,
      time: DateTime.now(),
      avatarUrl: 'assets/images/We.jpg',
    );

    setState(() {
      _messages.add(newMessage);
      _textController.clear();
    });

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  List<Widget> _buildMessageList() {
    List<Widget> widgets = [];
    DateTime? lastMessageTime;
    String? lastSenderId;

    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      final bool isNewDay =
          lastMessageTime == null || !isSameDay(message.time, lastMessageTime!);

      if (isNewDay) {
        widgets.add(DaySeparator(date: message.time));
      }

      final bool isSameSender =
          message.id ==
          lastSenderId; // Placeholder logic, actual sender ID needed
      final bool isCloseInTime =
          lastMessageTime != null &&
          message.time.difference(lastMessageTime!).inMinutes < 5;

      MessageGroupPosition groupPosition = MessageGroupPosition.single;
      bool showAvatar = true;
      bool showTime = true;

      // Determine group position
      if (i > 0 && _messages[i - 1].isMe == message.isMe && isCloseInTime) {
        // Part of a group
        if (i < _messages.length - 1 &&
            _messages[i + 1].isMe == message.isMe &&
            _messages[i + 1].time.difference(message.time).inMinutes < 5) {
          groupPosition = MessageGroupPosition.middle;
        } else {
          groupPosition = MessageGroupPosition.last;
        }
        showAvatar = false; // Hide avatar for grouped messages
        showTime = false; // Hide time for grouped messages
      } else if (i < _messages.length - 1 &&
          _messages[i + 1].isMe == message.isMe &&
          _messages[i + 1].time.difference(message.time).inMinutes < 5) {
        groupPosition = MessageGroupPosition.first;
      }

      widgets.add(
        ChatBubble(
          message: ChatMessage(
            id: message.id,
            text: message.text,
            isMe: message.isMe,
            time: message.time,
            avatarUrl: message.avatarUrl,
            showAvatar: showAvatar,
            showTime: showTime,
            groupPosition: groupPosition,
          ),
        ),
      );

      lastMessageTime = message.time;
      lastSenderId = message.id; // Placeholder, use actual sender ID
    }
    return widgets;
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Changed to black
      appBar: AppBar(
        backgroundColor: Colors.black, // Changed to black
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Icon(
            Icons.arrow_back,
            color: kTextColor,
          ), // Changed to arrow_back
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(widget.avatar),
            ),
            const SizedBox(width: 8),
            Text(
              widget.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16, // slightly smaller for better fit
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        // Remove call/video actions; keep only overflow with tighter padding
        actions: const [
          SizedBox(width: 4),
          Icon(Icons.more_vert, color: Colors.white),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              reverse: false,
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: _buildMessageList(),
            ),
          ),
          // Bottom input bar styled like the reference
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    // "+" button at far left
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // TextField with grey hint
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Red circular send button
                    GestureDetector(
                      onTap: _handleSend,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF2E2E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
