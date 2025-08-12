# Analytics Implementation Documentation

## Overview

This document describes the comprehensive analytics system implemented for the Flutter Social UI app, completing item #12 from the home screen audit. The implementation replaces debug prints with a professional analytics service that tracks all key user interactions.

## 🎯 Key Features

- **Comprehensive Event Tracking**: All major user interactions are tracked
- **Batch Processing**: Events are batched for optimal performance
- **Database Integration**: Events stored in Supabase with proper RLS
- **Session Tracking**: User sessions are tracked for flow analysis
- **Type Safety**: Strongly typed event constants and properties
- **Performance Optimized**: Minimal impact on app performance

## 📊 Tracked Events

### Core User Interactions
- **post_view**: When users view posts (with duration and watch percentage)
- **like_toggle**: Like/unlike actions with post metadata
- **comment_add**: Comment creation with length tracking
- **share_attempt**: Share actions with success/failure status
- **bookmark_toggle**: Save/unsave post actions
- **follow_toggle**: Follow/unfollow avatar actions

### UI Interactions
- **comment_modal_open**: When comment modal is opened
- **tab_switch**: Navigation between app tabs
- **screen_view**: Screen navigation tracking

### Video Analytics
- **video_play**: Video playback started
- **video_pause**: Video playback paused
- **video_seek**: Video position changed
- **video_complete**: Video watched to completion

### System Events
- **app_start**: Application launched
- **app_background**: Application backgrounded
- **error**: Error tracking

## 🏗️ Architecture

### AnalyticsService (`lib/services/analytics_service.dart`)

The central analytics service is a singleton that handles all event tracking:

```dart
// Track a like event
AnalyticsService().trackLikeToggle(
  postId,
  liked,
  postType: 'video',
  authorId: 'avatar-123',
  likesCount: 42,
);

// Track a custom event
AnalyticsService().trackEvent('custom_event', {
  'property1': 'value1',
  'property2': 123,
});
```

### Event Batching

Events are automatically batched for performance:
- **Batch Size**: 10 events
- **Flush Interval**: 5 seconds
- **Auto-flush**: On app background/dispose

### Database Schema

Events are stored in the `analytics_events` table:

```sql
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY,
  event_type TEXT NOT NULL,
  user_id UUID REFERENCES users(id),
  properties JSONB,
  timestamp TIMESTAMPTZ NOT NULL,
  session_id TEXT,
  platform TEXT DEFAULT 'flutter',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 🚀 Deployment

### 1. Database Setup

Run the deployment script to create the necessary database objects:

```bash
# Apply the analytics migration
psql -h your-supabase-host -d postgres -f deploy_analytics_complete.sql
```

Or use the Supabase dashboard to run `deploy_analytics_complete.sql`.

### 2. App Integration

The analytics service is automatically initialized in `main.dart`:

```dart
await Future.wait([
  // ... other services
  AnalyticsService().initialize(),
]);
```

### 3. Verification

Run the test suite to verify everything works:

```bash
flutter test test/services/analytics_service_test.dart
```

## 📈 Usage Examples

### Tracking User Interactions

```dart
// In PostDetailScreen
void _onPostLike(PostModel post) async {
  final liked = await _feedsService.toggleLike(post.id);
  
  // Analytics automatically tracked in EnhancedFeedsService
  // No additional code needed!
}
```

### Custom Event Tracking

```dart
// Track a custom business event
AnalyticsService().trackEvent('premium_upgrade_clicked', {
  'user_tier': 'free',
  'upgrade_source': 'profile_banner',
  'timestamp': DateTime.now().toIso8601String(),
});
```

### Screen Navigation

```dart
// Automatically tracked in AppShell
void _onTabChanged(int index) {
  // Analytics automatically captures tab switches
}
```

## 📊 Analytics Views

The deployment creates several useful views for reporting:

### `analytics_summary`
Hourly event summaries for the last 24 hours:
```sql
SELECT * FROM analytics_summary;
```

### `user_engagement_summary`
Daily user engagement metrics:
```sql
SELECT * FROM user_engagement_summary WHERE user_id = 'specific-user-id';
```

### `popular_content`
Most engaging content based on interactions:
```sql
SELECT * FROM popular_content ORDER BY event_count DESC LIMIT 10;
```

## 🔧 Helper Functions

### Get User Stats
```sql
SELECT * FROM get_user_analytics_stats('user-id');
```

### Get Event Counts by Time Period
```sql
-- Get hourly counts for last 24 hours
SELECT * FROM get_event_counts_by_period('hour', 24);

-- Get daily counts for last week
SELECT * FROM get_event_counts_by_period('day', 168);
```

## 🔒 Security

- **Row Level Security**: Users can only access their own analytics data
- **Service Role Access**: Admin functions available to service role
- **Data Privacy**: No sensitive data stored in event properties
- **Secure Defaults**: All policies follow principle of least privilege

## 🧪 Testing

### Unit Tests
```bash
flutter test test/services/analytics_service_test.dart
```

### Integration Testing
The analytics service integrates with:
- ✅ Authentication service
- ✅ Database service (Supabase)
- ✅ All user interaction flows
- ✅ Video playback system
- ✅ Navigation system

## 📋 Event Properties

### Standard Properties
All events include:
- `user_id`: Authenticated user ID
- `timestamp`: Client-side event timestamp
- `session_id`: Session identifier
- `platform`: Always 'flutter'

### Event-Specific Properties

**post_view**:
```json
{
  "post_id": "uuid",
  "duration_seconds": 15,
  "watch_percentage": 0.75,
  "post_type": "video",
  "author_id": "uuid"
}
```

**like_toggle**:
```json
{
  "post_id": "uuid",
  "liked": true,
  "post_type": "video", 
  "author_id": "uuid",
  "likes_count": 42
}
```

**comment_add**:
```json
{
  "post_id": "uuid",
  "comment_id": "uuid",
  "post_type": "video",
  "author_id": "uuid", 
  "comment_length": 25
}
```

## 🔄 Migration from Debug Prints

The implementation systematically replaced debug prints across:

- ✅ `PostDetailScreen` - All user interactions
- ✅ `EnhancedFeedsService` - Social interactions (likes, follows, etc.)
- ✅ `EnhancedVideoService` - Video playback events
- ✅ `InteractionService` - Core interaction flows
- ✅ `AppShell` - Navigation tracking

## 🎉 Success Metrics

With this implementation, you can now track:

1. **User Engagement**: Daily/weekly active users, session duration
2. **Content Performance**: Most liked/shared/viewed posts
3. **Feature Usage**: Which features are used most/least
4. **User Flows**: How users navigate through the app
5. **Video Analytics**: Watch time, completion rates, engagement
6. **Social Metrics**: Follow rates, comment engagement, share success

## 🔮 Future Enhancements

The analytics foundation supports easy addition of:

- Real-time dashboards
- A/B testing framework
- Push notification analytics
- Revenue tracking
- Advanced cohort analysis
- Machine learning insights

## 📞 Support

For questions about the analytics implementation:

1. Check the test files for usage examples
2. Review the database views for available data
3. Use the helper functions for common queries
4. Refer to the AnalyticsEvents constants for event types

The analytics system is now production-ready and will provide valuable insights into user behavior and app performance! 🚀
