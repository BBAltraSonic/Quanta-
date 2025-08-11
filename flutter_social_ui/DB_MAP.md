# Database Mapping - Quanta Post Detail Implementation

This document maps the app's domain concepts to actual Supabase table and column names based on the existing database schema.

## Table Mappings

### Videos/Posts
- **Domain**: videos, posts
- **Actual Table**: `posts`
- **Key Columns**:
  - `id` (UUID) - Primary key
  - `avatar_id` (UUID) - Reference to avatars table
  - `video_url` (TEXT) - URL for video content
  - `image_url` (TEXT) - URL for image content  
  - `caption` (TEXT) - Post description/caption
  - `hashtags` (TEXT[]) - Array of hashtags
  - `views_count` (INTEGER) - View count
  - `likes_count` (INTEGER) - Like count
  - `comments_count` (INTEGER) - Comment count
  - `shares_count` (INTEGER) - Share count
  - `engagement_rate` (REAL) - Engagement rate
  - `status` (TEXT) - Post status (draft, published, archived, deleted)
  - `is_active` (BOOLEAN) - Active status
  - `created_at` (TIMESTAMPTZ) - Creation timestamp
  - `updated_at` (TIMESTAMPTZ) - Update timestamp
  - `metadata` (JSONB) - Additional metadata

### Users
- **Domain**: users
- **Actual Table**: `users`
- **Key Columns**:
  - `id` (UUID) - Primary key (references auth.users)
  - `username` (TEXT) - Unique username
  - `email` (TEXT) - User email
  - `display_name` (TEXT) - Display name
  - `profile_image_url` (TEXT) - Profile image URL
  - `role` (TEXT) - User role (creator, viewer, admin, user, moderator)
  - `followers_count` (INTEGER) - Follower count
  - `following_count` (INTEGER) - Following count
  - `posts_count` (INTEGER) - Post count
  - `created_at` (TIMESTAMPTZ) - Creation timestamp
  - `updated_at` (TIMESTAMPTZ) - Update timestamp
  - `metadata` (JSONB) - Additional metadata

### Avatars
- **Domain**: avatars, creators
- **Actual Table**: `avatars`
- **Key Columns**:
  - `id` (UUID) - Primary key
  - `owner_user_id` (UUID) - Reference to users table
  - `name` (TEXT) - Avatar name
  - `bio` (TEXT) - Avatar bio
  - `backstory` (TEXT) - Avatar backstory
  - `niche` (TEXT) - Avatar niche (fashion, fitness, comedy, tech, etc.)
  - `personality_traits` (TEXT[]) - Array of personality traits
  - `avatar_image_url` (TEXT) - Avatar image URL
  - `voice_style` (TEXT) - Voice style
  - `personality_prompt` (TEXT) - AI personality prompt
  - `followers_count` (INTEGER) - Follower count
  - `likes_count` (INTEGER) - Total likes received
  - `posts_count` (INTEGER) - Post count
  - `engagement_rate` (REAL) - Engagement rate
  - `is_active` (BOOLEAN) - Active status
  - `allow_autonomous_posting` (BOOLEAN) - Allow autonomous posting
  - `created_at` (TIMESTAMPTZ) - Creation timestamp
  - `updated_at` (TIMESTAMPTZ) - Update timestamp
  - `metadata` (JSONB) - Additional metadata

### Likes
- **Domain**: likes, reactions
- **Actual Tables**: `post_likes` (primary), `likes` (legacy)
- **Primary Table**: `post_likes`
- **Key Columns**:
  - `id` (UUID) - Primary key
  - `user_id` (UUID) - Reference to users table
  - `post_id` (UUID) - Reference to posts table
  - `created_at` (TIMESTAMPTZ) - Creation timestamp

### Comments
- **Domain**: comments
- **Actual Table**: `post_comments`
- **Key Columns**:
  - `id` (UUID) - Primary key
  - `post_id` (UUID) - Reference to posts table
  - `user_id` (UUID) - Reference to users table (nullable)
  - `avatar_id` (UUID) - Reference to avatars table (nullable)
  - `text` (TEXT) - Comment text
  - `is_ai_generated` (BOOLEAN) - Whether comment is AI-generated
  - `parent_comment_id` (UUID) - Reference to parent comment (for replies)
  - `likes_count` (INTEGER) - Comment like count
  - `created_at` (TIMESTAMPTZ) - Creation timestamp
  - `updated_at` (TIMESTAMPTZ) - Update timestamp

### Follows
- **Domain**: follows, subscriptions
- **Actual Table**: `follows`
- **Key Columns**:
  - `id` (UUID) - Primary key
  - `user_id` (UUID) - Reference to users table (follower)
  - `avatar_id` (UUID) - Reference to avatars table (being followed)
  - `created_at` (TIMESTAMPTZ) - Creation timestamp

### Bookmarks/Saved Posts
- **Domain**: bookmarks, saved_posts
- **Actual Table**: `saved_posts`
- **Key Columns**:
  - `id` (UUID) - Primary key
  - `user_id` (UUID) - Reference to users table
  - `post_id` (UUID) - Reference to posts table
  - `created_at` (TIMESTAMPTZ) - Creation timestamp

### Shares
- **Domain**: shares
- **Actual Table**: `post_shares`
- **Key Columns**:
  - `id` (UUID) - Primary key
  - `user_id` (UUID) - Reference to users table
  - `post_id` (UUID) - Reference to posts table
  - `message` (TEXT) - Optional share message
  - `created_at` (TIMESTAMPTZ) - Creation timestamp

### Views/Analytics
- **Domain**: views, analytics
- **Implementation**: Views are tracked in the `posts.views_count` column
- **Additional Analytics**: Can be stored in `posts.metadata` JSONB field

### Reports
- **Domain**: reports
- **Implementation**: Will use `notifications` table with type='report' or create custom report handling
- **Alternative**: Store in `posts.metadata` or create dedicated reports table if needed

### Notifications
- **Domain**: notifications
- **Actual Table**: `notifications`
- **Key Columns**:
  - `id` (UUID) - Primary key
  - `user_id` (UUID) - Reference to users table
  - `type` (TEXT) - Notification type (like, comment, follow, avatar_mention, system)
  - `title` (TEXT) - Notification title
  - `message` (TEXT) - Notification message
  - `is_read` (BOOLEAN) - Read status
  - `related_avatar_id` (UUID) - Related avatar reference
  - `related_post_id` (UUID) - Related post reference
  - `related_user_id` (UUID) - Related user reference
  - `created_at` (TIMESTAMPTZ) - Creation timestamp
  - `updated_at` (TIMESTAMPTZ) - Update timestamp
  - `metadata` (JSONB) - Additional metadata

## Configuration Object

```dart
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
  
  // Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String postsBucket = 'posts';
}
```

## Notes

1. **Video Content**: Posts with `video_url` are considered video posts. Posts with only `image_url` are image posts.
2. **Comments**: Support both user comments (`user_id` set) and AI-generated comments (`avatar_id` set).
3. **Likes**: Using `post_likes` table as primary, with `likes` table as legacy.
4. **RLS**: All tables have Row Level Security enabled with appropriate policies.
5. **Triggers**: Database has triggers for updating counters automatically.
6. **Views**: Tracked directly in `posts.views_count` column.
7. **Analytics**: Additional analytics data can be stored in the `metadata` JSONB fields.

## Missing Tables (To Be Created If Needed)

- **View Events**: For detailed view analytics (optional)
- **Reports**: For content reporting (can use notifications table)
- **Blocks**: For user blocking functionality
- **Download Logs**: For tracking downloads
