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

// Mock data generator
List<Comment> generateMockComments() {
  return [
    Comment(
      id: '1',
      userId: 'u1',
      userName: 'Kurt Bates',
      userAvatar: 'assets/images/p.jpg',
      text: "That's the dopest hyperlapse video I've ever seen mate",
      createdAt: DateTime.now().subtract(const Duration(minutes: 14)),
      likes: 4,
      repliesCount: 8,
    ),
    Comment(
      id: '2',
      userId: 'u2',
      userName: 'Bradley Lawlor',
      userAvatar: 'assets/images/We.jpg',
      text: "Love the sunsets in Dubai!",
      createdAt: DateTime.now().subtract(const Duration(minutes: 56)),
      likes: 12,
      repliesCount: 0,
    ),
    Comment(
      id: '3',
      userId: 'u3',
      userName: 'Paula Mora',
      userAvatar: 'assets/images/p.jpg',
      text: "Your style is top notch 😍",
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      likes: 334,
      repliesCount: 8,
    ),
    Comment(
      id: '4',
      userId: 'u4',
      userName: 'Stephanie Sharkey',
      userAvatar: 'assets/images/We.jpg',
      text: "This guy is underrated.",
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      likes: 334,
      repliesCount: 0,
    ),
  ];
}
