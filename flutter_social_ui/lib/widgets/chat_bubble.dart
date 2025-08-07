import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({Key? key, required this.message}) : super(key: key);

  BorderRadius _getBorderRadius() {
    const double radius = kChatBubbleRadius;
    switch (message.groupPosition) {
      case MessageGroupPosition.single:
        return BorderRadius.circular(radius);
      case MessageGroupPosition.first:
        return message.isMe
            ? BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(
                  radius * 0.2,
                ), // Slightly less rounded for continuity
              )
            : BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(
                  radius * 0.2,
                ), // Slightly less rounded for continuity
              );
      case MessageGroupPosition.middle:
        return message.isMe
            ? BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
                topRight: Radius.circular(radius * 0.2),
                bottomRight: Radius.circular(radius * 0.2),
              )
            : BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
                topLeft: Radius.circular(radius * 0.2),
                bottomLeft: Radius.circular(radius * 0.2),
              );
      case MessageGroupPosition.last:
        return message.isMe
            ? BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
                topRight: Radius.circular(radius * 0.2),
                bottomRight: Radius.circular(radius),
              )
            : BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
                topLeft: Radius.circular(radius * 0.2),
                bottomLeft: Radius.circular(radius),
              );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double maxWidth = size.width * kChatBubbleMaxWidthRatio;

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 2.0,
          horizontal: kDefaultPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.isMe && message.showAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: message.avatarUrl != null
                      ? AssetImage(message.avatarUrl!)
                      : null,
                  backgroundColor: Theme.of(context).primaryColorLight,
                  child: message.avatarUrl == null
                      ? Icon(Icons.person, size: 20, color: kTextColor)
                      : null,
                ),
              ),
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                decoration: BoxDecoration(
                  color: message.isMe
                      ? kChatOutgoingBubbleColor
                      : kChatIncomingBubbleColor,
                  borderRadius: _getBorderRadius(),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 0,
                      blurRadius: 4,
                      offset: Offset(0, 2), // changes position of shadow
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isMe ? kTextColor : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    if (message.showTime)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          '${message.time.hour}:${message.time.minute.toString().padLeft(2, '0')} ${message.time.hour >= 12 ? 'PM' : 'AM'}',
                          style: TextStyle(
                            color: kChatTimeTextColor,
                            fontSize: 10,
                            height: 1.1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (message.isMe && message.showAvatar)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: message.avatarUrl != null
                      ? AssetImage(message.avatarUrl!)
                      : null,
                  backgroundColor: Theme.of(context).primaryColorLight,
                  child: message.avatarUrl == null
                      ? Icon(Icons.person, size: 20, color: kTextColor)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
