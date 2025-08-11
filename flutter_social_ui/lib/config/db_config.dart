/// Database configuration constants for Post Detail implementation
class DbConfig {
  // Table names
  static const String postsTable = 'posts';
  static const String usersTable = 'users';
  static const String avatarsTable = 'avatars';
  static const String likesTable = 'post_likes';
  static const String commentsTable = 'post_comments';
  static const String followsTable = 'follows';
  static const String savedPostsTable = 'saved_posts';
  static const String sharesTable = 'post_shares';
  static const String notificationsTable = 'notifications';
  static const String viewEventsTable = 'view_events';
  static const String reportsTable = 'reports';
  static const String userBlocksTable = 'user_blocks';
  
  // Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String postsBucket = 'posts';
  
  // Post types
  static const String videoType = 'video';
  static const String imageType = 'image';
  
  // Post statuses
  static const String publishedStatus = 'published';
  static const String draftStatus = 'draft';
  static const String archivedStatus = 'archived';
  static const String deletedStatus = 'deleted';
  
  // Report types
  static const String spamReport = 'spam';
  static const String inappropriateReport = 'inappropriate';
  static const String harassmentReport = 'harassment';
  static const String copyrightReport = 'copyright';
  static const String otherReport = 'other';
  
  // Report statuses
  static const String pendingReport = 'pending';
  static const String reviewedReport = 'reviewed';
  static const String resolvedReport = 'resolved';
  static const String dismissedReport = 'dismissed';
  
  // Notification types
  static const String likeNotification = 'like';
  static const String commentNotification = 'comment';
  static const String followNotification = 'follow';
  static const String avatarMentionNotification = 'avatar_mention';
  static const String systemNotification = 'system';
  
  // User roles
  static const String creatorRole = 'creator';
  static const String viewerRole = 'viewer';
  static const String adminRole = 'admin';
  static const String userRole = 'user';
  static const String moderatorRole = 'moderator';
  
  // Avatar niches
  static const List<String> avatarNiches = [
    'fashion', 'fitness', 'comedy', 'tech', 'music', 'art', 
    'cooking', 'travel', 'gaming', 'education', 'lifestyle', 'business', 'other'
  ];
  
  // Pagination defaults
  static const int defaultPageSize = 10;
  static const int maxPageSize = 50;
  
  // View thresholds
  static const int viewThresholdSeconds = 2;
  static const double significantWatchPercentage = 0.3;
  
  // Analytics events
  static const String playEvent = 'play';
  static const String pauseEvent = 'pause';
  static const String seekEvent = 'seek';
  static const String likeEvent = 'like';
  static const String commentEvent = 'comment';
  static const String shareEvent = 'share';
  static const String downloadEvent = 'download';
  static const String reportEvent = 'report';
}
