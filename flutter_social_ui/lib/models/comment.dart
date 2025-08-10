class Comment {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String text;
  final DateTime createdAt;
  int likes;
  bool hasLiked;
  final int repliesCount;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.text,
    required this.createdAt,
    this.likes = 0,
    this.hasLiked = false,
    this.repliesCount = 0,
  });
}


