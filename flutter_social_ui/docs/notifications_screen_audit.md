## Notifications Screen Audit and Development Plan

This document provides a thorough audit of the notifications feature covering UI, modals, icon buttons, widgets, data flow, database connectivity, and alignment with the project PRD. It also includes a comprehensive, incremental development plan.

### Scope and Files Reviewed

- UI screen: `lib/screens/notifications_screen_new.dart`
- Notification service: `lib/services/notification_service.dart`
- Feed interactions that create notifications: `lib/services/enhanced_feeds_service.dart`
- DB config constants: `lib/config/db_config.dart`
- Supabase schema and migration: `supabase_schema.sql`, `database_migration_fix.sql`
- App shell (nav/tab): `lib/screens/app_shell.dart`
- Skeletons: `lib/widgets/skeleton_widgets.dart`
- PRD: `docs/Quanta prd.md`

### High-level Overview

- The notifications screen fetches user notifications from Supabase via a dedicated service and displays them in All/Unread tabs with a loading state and a simple empty state.
- Feed and follow/comment interactions write notifications to the `notifications` table.
- Real-time subscription support exists in the service but is not used by the screen.
- Local-only state updates are used for mark-as-read and mark-all-read. No writes are issued to the database from the screen.
- Some type-name mismatches and mapping issues are present between UI, service, and schema.
- Navigation from notifications to actual destination screens is stubbed via SnackBars for several cases.

### UI, Widgets, Icon Buttons, and Modals

- Screen header shows “Notifications” and a conditional “Mark all read” TextButton.
- Tabs: All and Unread with counts.
- List items show an icon, title, message, timestamp, and unread dot indicator.
- Loading state shows a progress indicator; not using the skeleton notification widget.
- Modal: an `AlertDialog` for system update details.
- No per-item overflow menu (e.g., delete/mark read/unread) exists.

Key excerpts:

```startLine:119:endLine:151:lib/screens/notifications_screen_new.dart
// Header with conditional 'Mark all read' button and tabs
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: Row(
    children: [
      Text('Notifications', ...),
      Spacer(),
      if (_unreadNotifications.isNotEmpty)
        TextButton(
          onPressed: _markAllAsRead,
          child: Text('Mark all read', ...),
        ),
    ],
  ),
)
...
TabBar(
  controller: _tabController,
  tabs: [
    Tab(text: 'All (${_allNotifications.length})'),
    Tab(text: 'Unread (${_unreadNotifications.length})'),
  ],
)
```

```startLine:529:endLine:546:lib/screens/notifications_screen_new.dart
// Simple details modal for system updates
void _showNotificationDetails(NotificationItem notification) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: kCardColor,
      title: Text(notification.title, ...),
      content: Text(notification.message, ...),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close', ...)),
      ],
    ),
  );
}
```

### Data Flow and Database Connectivity

- Data source: Supabase `notifications` table.
- Fetch: `NotificationService.getUserNotifications()` is called by the screen.
- Create: Likes, comments, and follows from `EnhancedFeedsService` insert rows into `notifications`.
- Real-time: `NotificationService` exposes a stream using Supabase `.stream(...)` filtered by `user_id` but the screen does not subscribe.
- Update/Read flags: Service exposes `markAsRead` and `markAllAsRead`, but the screen only updates local state.

Fetch path:

```startLine:361:endLine:379:lib/screens/notifications_screen_new.dart
Future<void> _loadNotifications() async {
  setState(() => _isLoading = true);
  try {
    final notifications = await _notificationService.getUserNotifications();
    final notificationItems = notifications.map((n) => NotificationItem(
      id: n.id,
      type: _mapNotificationType(n.type),
      title: n.title,
      message: n.message,
      isRead: n.isRead,
      timestamp: n.createdAt,
      avatarId: n.relatedAvatarId,
      postId: n.relatedPostId,
    )).toList();
    ...
```

Service fetch implementation:

```startLine:131:endLine:156:lib/services/notification_service.dart
Future<List<NotificationModel>> getUserNotifications({int limit = 50, int offset = 0, bool unreadOnly = false}) async {
  final userId = _authService.currentUserId;
  var query = _supabase.from('notifications').select().eq('user_id', userId);
  if (unreadOnly) { query = query.eq('is_read', false); }
  final response = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
  return response.map<NotificationModel>((json) => NotificationModel.fromJson(json)).toList();
}
```

Creation path in feeds service:

```startLine:727:endLine:755:lib/services/enhanced_feeds_service.dart
// Like → notification
await _supabase.from(DbConfig.notificationsTable).insert({
  'user_id': avatar['owner_user_id'],
  'type': DbConfig.likeNotification,
  'title': 'New Like',
  'message': 'Someone liked your ${avatar['name']} post',
  'related_post_id': postId,
  'related_user_id': likerId,
  'created_at': DateTime.now().toIso8601String(),
});
```

Real-time support in service (unused by UI):

```startLine:380:endLine:399:lib/services/notification_service.dart
_notificationStream = _supabase
  .from('notifications')
  .stream(primaryKey: ['id'])
  .eq('user_id', userId)
  .order('created_at', ascending: false)
  .map((data) => data.map<NotificationModel>((json) => NotificationModel.fromJson(json)).toList());
```

### Gaps, Mismatches, and Risks

- Database writes for read-state are not triggered by the UI.
  - `_markAsRead` and `_markAllAsRead` only mutate local lists; they do not call service methods that update Supabase.
  - Evidence:
    ```startLine:461:endLine:485:lib/screens/notifications_screen_new.dart
    void _markAsRead(NotificationItem notification) {
      setState(() {
        final index = _allNotifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) { _allNotifications[index] = NotificationItem(... isRead: true ...); }
        _unreadNotifications = _allNotifications.where((n) => !n.isRead).toList();
      });
    }
    ```
    ```startLine:487:endLine:506:lib/screens/notifications_screen_new.dart
    void _markAllAsRead() {
      setState(() {
        _allNotifications = _allNotifications.map((n) => NotificationItem(... isRead: true ...)).toList();
        _unreadNotifications.clear();
      });
    }
    ```

- Type-name mismatch between schema and service for mentions:
  - Migration enforces `type IN ('like','comment','follow','avatar_mention','system')`.
    ```startLine:8:endLine:22:database_migration_fix.sql
    CREATE TABLE IF NOT EXISTS public.notifications (... type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow', 'avatar_mention', 'system')), ...);
    ```
  - Service uses `NotificationType.mention` with string value `'mention'` (not allowed by the CHECK constraint), likely causing insert failures if called.
    ```startLine:5:endLine:25:lib/services/notification_service.dart
    enum NotificationType { like, comment, follow, mention, system }
    extension NotificationTypeExtension on NotificationType { String get value => toString().split('.').last; }
    ```

- Incorrect UI type mapping for system notifications:
  - System is mapped to `postFeatured` in the UI, which is misleading.
    ```startLine:395:endLine:408:lib/screens/notifications_screen_new.dart
    // serviceType.system → NotificationType.postFeatured // Default mapping (likely wrong)
    ```

- Incomplete navigation handlers:
  - For like/comment/postFeatured, navigation is a `SnackBar` with postId; not actual deep link to a post detail screen.
  - For follow/mention, navigation is also a `SnackBar` (profile).
  - Chat/avatarReply attempts real navigation via `ChatScreen` when `avatarId` is present.

- Real-time updates not used in UI:
  - The screen does not subscribe to the notification stream; users must pull-to-refresh.

- Missing UX affordances:
  - No per-notification options (Delete, Mark unread, Copy link, Mute this type, etc.).
  - No unread count badge on the bottom navigation bar icon in `AppShell`.
  - Loading uses a spinner; the codebase includes a `SkeletonNotificationItem` not used here.

- Data model/UI drift:
  - `NotificationItem` in UI has fields (`chatMessage`, `avatarReply`, `postFeatured`) not currently created by services.
  - `NotificationItem.fromJson` exists but is not used by the screen’s fetch path.
  - `_avatarCache` is declared but unused.

- Table name consistency risks:
  - `DbConfig` uses `post_likes` and `post_comments`, while `supabase_schema.sql` defines `likes` and `comments`. The app currently uses `DbConfig` tables; ensure actual DB has the expected tables and RLS.

### Alignment with PRD (docs/Quanta prd.md)

- The PRD emphasizes engagement loops (likes, comments, chat). Notifications are a natural complement, though not explicitly detailed in MVP lists.
- Current state supports essential notification delivery for likes, comments, and follows. Mentions and system updates are partially supported but inconsistent with schema.
- To align better with the PRD goals (engagement and return visits), real-time updates, proper deep-links, and badges should be implemented.

### What Still Needs Implementation

- Persist read state:
  - Call `NotificationService.markAsRead(id)` on item tap.
  - Call `NotificationService.markAllAsRead()` for “Mark all read”.

- Fix type mismatches:
  - Either change schema `avatar_mention` → `mention`, or update service to emit `avatar_mention` consistently, and update UI mapping accordingly.

- Correct UI type mapping:
  - Map `serviceType.system` → `NotificationType.systemUpdate`.

- Navigation:
  - Implement real navigation to Post Detail and Profile screens using `postId` and `userId`.
  - Ensure routes exist and accept IDs.

- Real-time updates in UI:
  - Subscribe to `NotificationService.getNotificationStream()` and merge updates into local lists.

- UX improvements:
  - Add item overflow menu: Delete, Mark unread, Mute type.
  - Show unread count badge on nav bar.
  - Use skeletons during initial loads.

- Data model cleanup:
  - Remove unused `NotificationItem.fromJson` or adopt a single model mapping path.
  - Remove or use `_avatarCache`.

- Table names/RLS verification:
  - Confirm production DB uses `DbConfig`-referenced table names, or reconcile app constants with actual schema.

### Detailed Development Plan (Small, Manageable Tasks)

1) Persist read states
- Implement per-item read persistence:
  - Wire `await _notificationService.markAsRead(notification.id)` inside `_markAsRead`, handle errors, and optimistically update UI.
- Implement bulk read persistence:
  - Wire `await _notificationService.markAllAsRead()` inside `_markAllAsRead` with loading guard.

2) Type naming consistency
- Option A (recommended): Update DB migration to allow `'mention'` in CHECK constraint and keep service as-is.
- Option B: Keep DB as `'avatar_mention'` and change `NotificationService.NotificationType.mention` string to `'avatar_mention'` and adjust mapping in UI.
- Add regression test to verify insert success for mention notifications.

3) Correct system type mapping in UI
- Change `serviceType.system` → `NotificationType.systemUpdate` in `_mapNotificationType`.

4) Real navigation
- Implement navigation for post notifications:
  - Resolve post by `notification.postId` and push the detail screen.
- Implement navigation for profile notifications:
  - Resolve profile by `notification.userId` or `avatarId` and push the appropriate screen.
- Add guards and toasts for missing IDs.

5) Real-time updates in UI
- On `initState`, subscribe to notification stream:
  - Debounce and merge into `_allNotifications` and `_unreadNotifications`.
  - Provide a dispose handler.

6) UX enhancements
- Add trailing overflow icon per item with a menu: Mark unread, Delete, Mute this type.
- Replace spinner with skeleton list during initial loading.
- Add unread badge to the nav notifications icon in `AppShell` by querying `getUnreadCount()` and subscribing to the service stream.

7) Data model and cleanup
- Consolidate to a single model adapter from `NotificationModel` → `NotificationItem` or use `NotificationModel` directly in UI.
- Remove unused `_avatarCache` unless used for avatar thumbnails.

8) Table names and RLS alignment
- Verify production Supabase tables match `DbConfig`.
- If not, either update `DbConfig` to match existing tables (`likes`, `comments`) or migrate DB to expected names.
- Ensure RLS and indexes exist for `notifications` (already present in `database_migration_fix.sql`).

9) Tests
- Unit tests for `NotificationService` methods: fetch, stream, mark read, mark all read, delete, create.
- Widget tests for notifications list, unread badge, and tap navigation.
- Integration test: like/comment/follow flows create notifications visible to the recipient.

10) Telemetry and errors
- Add error toasts/logging for failed DB updates when marking read/deleting.
- Consider retry logic for temporary failures.

### Acceptance Criteria

- Tapping a notification marks it read both locally and in the database.
- “Mark all read” updates both local state and the database.
- Mentions insert without DB CHECK errors and display correctly.
- System notifications render as system, not post featured.
- Post/profile notifications navigate to the correct screens.
- Real-time updates reflect immediately without manual refresh.
- Unread count badge appears on the nav bar and updates in real time.
- No mock data or placeholders drive the notifications list; only Supabase.

### Observed Placeholders/Fallbacks

- Navigation for some types uses `SnackBar` placeholders instead of actual navigation.
- `ChatScreen` navigation uses a default asset image when avatar image is null.
- Loading uses a spinner; consider the existing skeleton widget for consistency with other parts of the app.

### Conclusion

The notifications backend connectivity is implemented and functional for core types (like, comment, follow). The screen needs to persist read states to the database, fix type and mapping inconsistencies, implement real navigation and real-time updates, and add UX affordances like menus and badges. Addressing the listed gaps will bring the feature in line with the PRD’s engagement goals and ensure a production-quality experience without mock data.


