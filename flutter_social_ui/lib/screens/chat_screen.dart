import 'package:flutter/material.dart';
import 'package:flutter_social_ui/models/chat_message.dart';
import 'package:flutter_social_ui/widgets/chat_bubble.dart';
import 'package:flutter_social_ui/widgets/day_separator.dart';
import 'package:flutter_social_ui/services/chat_service.dart';
import 'package:flutter_social_ui/services/avatar_service.dart';
import 'package:flutter_social_ui/services/auth_service_wrapper.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import '../constants.dart';

class ChatScreen extends StatefulWidget {
  final String name;
  final String avatar;
  final bool isGroup;
  final String? avatarId; // Added for backend integration

  const ChatScreen({
    super.key,
    required this.name,
    required this.avatar,
    this.isGroup = false,
    this.avatarId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final AvatarService _avatarService = AvatarService();
  final AuthServiceWrapper _authService = AuthServiceWrapper();

  List<ChatMessage> _messages = [];
  AvatarModel? _avatar;
  String? _chatSessionId;
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasError = false;
  final String _errorMessage = '';
  String? _actualAvatarId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Find avatar by name if ID not provided
      if (widget.avatarId != null) {
        _actualAvatarId = widget.avatarId;
      } else {
        // Search for avatar by name (fallback for existing UI)
        _actualAvatarId = await _findAvatarByName(widget.name);
      }

      if (_actualAvatarId != null) {
        // Load avatar details
        _avatar = await _avatarService.getAvatar(_actualAvatarId!);

        // Create or get existing chat session
        await _loadOrCreateChatSession();

        // Load existing messages
        await _loadChatHistory();
      } else {
        // Use demo mode if avatar not found
        _loadDemoMessages();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      _loadDemoMessages();
      setState(() {
        _isLoading = false;
        _hasError = false; // Don't show error for demo mode
      });
    }
  }

  Future<String?> _findAvatarByName(String name) async {
    try {
      final avatars = await _avatarService.searchAvatars(query: name, limit: 1);
      return avatars.isNotEmpty ? avatars.first.id : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadOrCreateChatSession() async {
    if (_actualAvatarId == null) return;

    try {
      final session = await _chatService.getOrCreateChatSession(
        _actualAvatarId!,
      );
      _chatSessionId = session.id;
    } catch (e) {
      debugPrint('Error loading chat session: $e');
    }
  }

  Future<void> _loadChatHistory() async {
    if (_chatSessionId == null) return;

    try {
      final messages = await _chatService.getChatMessages(
        sessionId: _chatSessionId!,
        limit: 50,
      );

      setState(() {
        _messages = messages.reversed
            .toList(); // Reverse to show newest at bottom
      });
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  void _loadDemoMessages() {
    // Demo messages when backend is not available
    final demoMessages = [
      ChatMessage(
        id: '1',
        text: 'Hey there! I\'m ${widget.name}, nice to meet you! 😊',
        isMe: false,
        time: DateTime.now().subtract(Duration(hours: 2)),
        avatarUrl: widget.avatar,
      ),
      ChatMessage(
        id: '2',
        text: 'What would you like to chat about today?',
        isMe: false,
        time: DateTime.now().subtract(Duration(hours: 1)),
        avatarUrl: widget.avatar,
      ),
    ];

    setState(() {
      _messages = demoMessages;
      _isLoading = false;
    });
  }

  Future<void> _handleSend() async {
    if (_textController.text.trim().isEmpty) return;
    if (_isSending) return;

    final messageText = _textController.text.trim();
    _textController.clear();

    // Add user message immediately
    final userMessage = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      text: messageText,
      isMe: true,
      time: DateTime.now(),
      avatarUrl: 'assets/images/We.jpg',
    );

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });

    _scrollToBottom();

    try {
      if (_actualAvatarId != null && _authService.isAuthenticated) {
        // Send message through real chat service
        final aiResponse = await _chatService.sendMessageToAvatar(
          avatarId: _actualAvatarId!,
          messageText: messageText,
        );

        // Add AI response
        setState(() {
          _messages.add(
            ChatMessage(
              id: aiResponse.id,
              text: aiResponse.text,
              isMe: false,
              time: aiResponse.time,
              avatarUrl: widget.avatar,
            ),
          );
        });
      } else {
        // Demo mode - generate simple response
        await Future.delayed(Duration(seconds: 1));
        final demoResponse = _generateDemoResponse(messageText);

        setState(() {
          _messages.add(
            ChatMessage(
              id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
              text: demoResponse,
              isMe: false,
              time: DateTime.now(),
              avatarUrl: widget.avatar,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Show error or add fallback response
      setState(() {
        _messages.add(
          ChatMessage(
            id: 'error_${DateTime.now().millisecondsSinceEpoch}',
            text:
                'Sorry, I had trouble understanding that. Could you try again?',
            isMe: false,
            time: DateTime.now(),
            avatarUrl: widget.avatar,
          ),
        );
      });
    } finally {
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  String _generateDemoResponse(String userMessage) {
    final responses = [
      'That\'s interesting! Tell me more about that.',
      'I understand what you mean. What do you think about it?',
      'Thanks for sharing that with me! 😊',
      'That\'s a great point! I hadn\'t thought of it that way.',
      'I\'d love to hear your thoughts on this topic.',
      'What\'s your favorite part about that?',
      'That sounds really cool! How did you get into that?',
    ];

    responses.shuffle();
    return responses.first;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Widget> _buildMessageList() {
    List<Widget> widgets = [];
    DateTime? lastMessageTime;
    String? lastSenderId;

    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      final bool isNewDay =
          lastMessageTime == null || !isSameDay(message.time, lastMessageTime);

      if (isNewDay) {
        widgets.add(DaySeparator(date: message.time));
      }

      final bool isSameSender =
          message.id ==
          lastSenderId; // Placeholder logic, actual sender ID needed
      final bool isCloseInTime =
          lastMessageTime != null &&
          message.time.difference(lastMessageTime).inMinutes < 5;

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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back, color: kTextColor),
          ),
          title: Text(
            widget.name,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: kPrimaryColor),
              SizedBox(height: 16),
              Text(
                'Connecting to ${widget.name}...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

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
              children: [
                ..._buildMessageList(),
                // Typing indicator when AI is responding
                if (_isSending)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: AssetImage(widget.avatar),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TypingIndicator(),
                              SizedBox(width: 8),
                              Text(
                                '${widget.name} is typing...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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

// Typing indicator widget
class _TypingIndicator extends StatefulWidget {
  @override
  __TypingIndicatorState createState() => __TypingIndicatorState();
}

class __TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Opacity(
              opacity: (_animation.value + index * 0.3) % 1.0,
              child: Container(
                width: 4,
                height: 4,
                margin: EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
