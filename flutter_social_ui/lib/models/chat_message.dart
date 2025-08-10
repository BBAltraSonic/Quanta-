enum MessageGroupPosition { single, first, middle, last }

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;
  final String? avatarUrl;
  final bool showAvatar;
  final bool showTime;
  final MessageGroupPosition groupPosition;
  final bool isAiGenerated;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.avatarUrl,
    this.showAvatar = false,
    this.showTime = false,
    this.groupPosition = MessageGroupPosition.single,
    this.isAiGenerated = false,
  });
}
