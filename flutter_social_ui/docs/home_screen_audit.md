## Home Screen Audit and Development Plan

### Scope
- Home entry: `AppShell` → `PostDetailScreen` as the default landing screen.
- Widgets and modals audited: `PostDetailScreen`, `PostItem`, post options bottom sheet, avatar action sheet, `comments_modal.dart`, `ShareService`, and supporting services (`EnhancedFeedsService`, `CommentService`, `InteractionService`, `UserSafetyService`).
- Goal: confirm real database wiring (Supabase), identify any mock data, placeholders, or incomplete flows, and align with the PRD. Provide a granular development plan.

### Architecture overview
- `AppShell` sets up a 5-tab scaffold, with `PostDetailScreen` as Home.
  - Source: `lib/screens/app_shell.dart`.
- `PostDetailScreen` implements a TikTok-style vertical feed with overlays and action buttons, leveraging `EnhancedFeedsService` for data.
  - Source: `lib/screens/post_detail_screen.dart`.
- `PostItem` renders media, caption cluster, and the interaction row (like/comment/share/save) with callbacks passed from the screen.
  - Source: `lib/widgets/post_item.dart`.
- Comment flow uses `widgets/comments_modal.dart` which calls `CommentService` for fetch/add and comment-like.
- Engagement and social interactions (likes, follows, bookmarks, shares, view events, notifications) are largely implemented in `EnhancedFeedsService` (Supabase-backed).

### Data integrations mapping
- Feed posts: Supabase table `posts` via `EnhancedFeedsService.getVideoFeed` with pagination and trending ordering.
- Avatar info per post: Supabase table `avatars` via `EnhancedFeedsService.getAvatarForPost`.
- Likes:
  - Toggle, batch status, and counters: implemented against `post_likes` and RPCs `increment_likes_count` / `decrement_likes_count` in `EnhancedFeedsService`.
- Follows:
  - Toggle and batch status: implemented against `follows`; creates notifications for avatar owners.
- Bookmarks/Saves:
  - Toggle and batch status: implemented against `saved_posts`.
- Comments:
  - Fetch/add: `CommentService` uses Supabase `post_comments`.
  - Like/delete: NOT implemented in `CommentService` (throws).
  - `EnhancedFeedsService` also contains comment helpers and realtime subscription; UI currently wired to `CommentService`.
- Shares:
  - `PostDetailScreen` uses Clipboard fallback. `EnhancedFeedsService.sharePost` writes to `post_shares` but is not used by the UI.
- View counts:
  - `EnhancedFeedsService.incrementViewCount` calls RPC `increment_view_count`.
- Reporting/blocking/muting:
  - `UserSafetyService` stores everything in `SharedPreferences` (local only); not persisted in DB.

### Placeholders, mocks, and gaps
- Comment composer avatar uses a static asset `assets/images/p.jpg` instead of the current user profile image (DB-driven).
- Comment likes: `CommentService.toggleCommentLike` is unimplemented and throws; delete comment also throws.
- Comment replies: UI explicitly shows "coming soon"; no replies list/threading implemented.
- Share action in `PostDetailScreen` copies a text block to clipboard; no integration with `share_plus` nor `EnhancedFeedsService.sharePost` to update DB counters.
- Report action in post options sheet is a stub (no dialog/integration invoked).
- Avatar action sheet → Chat navigates to `ChatScreen`, but chat backend in `EnhancedChatService` is largely unimplemented (beyond the scope of Home, but affects UX).
- Hardcoded progress indicator in `PostItem` is set to value 0.7 (visual placeholder, not tied to playback state).
- Top-left search button (when not in single-post view) is a stub; no action.
- View/like counter updates rely on DB RPCs that may not exist in the DB schema in this repo (e.g., `increment_view_count`, `increment_likes_count`, `decrement_likes_count`).
- Content upload path: `ContentUploadService` returns a mock post and throws for file upload/import (affects feed population end-to-end for creators).
- Security/Config: default Supabase URL and anon key are embedded in `Environment` and `AppConfig` (needs env injection for production).

### Alignment with PRD (docs/Quanta prd.md)
- Core feed (TikTok-style): implemented for scroll, like, comment (basic), share (fallback only). Missing Trending/Following toggles and niche filters.
- Profile pages: present in app, though not covered in this audit.
- Upload workflow: UI exists, but backend upload is mocked; storage + DB record creation not complete.
- Trends & challenges, remix/collab: not present on Home.
- Chat with avatars: entry point present from avatar action sheet, backend incomplete.
- Commenting & AI replies: basic comments exist; AI replies are scaffolded in `CommentService.generateAIComment` but not integrated in Home comments UI.

### Risk notes
- Using local storage for user safety/reporting undermines moderation and violates consistency with PRD’s moderation expectations.
- Missing DB RPCs/tables for counters and comment likes may cause runtime errors or silent failures.
- Sharing and reporting flows do not update DB → analytics/notifications will be incomplete.
- Mocked content upload breaks the creator loop (create → upload → feed) and validation metrics.

---

## Development Plan (phased, small tasks)

### Phase 1: Close critical gaps for a fully live Home feed
1) Comment like/delete and replies
   - DB: add `comment_likes` table, RLS, indexes.
   - Backend: implement `CommentService.toggleCommentLike` and `deleteComment` with authorization checks; add replies list fetching; wire to UI.
   - UI: replace "coming soon" replies and filter buttons with real interactions and basic sorting.

2) Share flow integration
   - Add `share_plus` dependency and hook `PostDetailScreen._onPostShare` to use `ShareService.shareToExternal`.
   - Record shares via `EnhancedFeedsService.sharePost` to `post_shares` and increment share counters.

3) Reporting and safety
   - Replace local `UserSafetyService.reportContent` with server-side insert into `reports` table via `EnhancedFeedsService.reportPost`.
   - Wire the "Report" option in post options sheet to show `ReportContentDialog`, and submit to DB.
   - Plan follow-up to migrate block/mute to DB (Phase 2).

4) View/like counters RPCs
   - Add/verify Postgres functions: `increment_view_count`, `increment_likes_count`, `decrement_likes_count` with RLS-safe security definer.
   - Add integration tests that call these RPCs from the app to prevent regressions.

5) Comment composer avatar
   - Load current user’s `profile_image_url` from `users` and display in composer instead of hardcoded asset.

6) Top-left action
   - When on Home feed, tap should push `SearchScreenNew` (consistent with bottom tab) to avoid a dead control.

7) Progress indicator
   - Remove the hardcoded 0.7; connect to `EnhancedVideoService` playback position and duration for each item.

### Phase 2: Improve parity with PRD and durability
8) Trending/Following filters and niche tags
   - Add a simple segmented control or tabs at the top; query variants in `EnhancedFeedsService` (following = posts from followed avatars; trending = current default; niche = hashtags/niche filter).

9) Safety features to DB
   - Migrate block/mute/report storage from SharedPreferences to Supabase tables (`user_blocks`, `reports`, `user_mutes` if needed), plus RLS. Provide migration helpers to import existing local state on first run.

10) Chat entry validation
   - From avatar action sheet, verify `ChatScreen` can fetch/create a conversation session in DB. If not ready, gate the CTA with a tooltip and do not navigate.

11) AI replies to comments
   - Integrate `CommentService.generateAICommentReplies` to suggest avatar replies; add a small UI affordance for owners to accept/decline.

12) Analytics events
   - Replace debug prints with an analytics service interface and ensure all key events are captured (post_view, like_toggle, comment_add, share_attempt, bookmark_toggle, follow_toggle).

### Phase 3: Creator loop completion
13) Content upload backend
   - Implement Supabase Storage upload for videos/images; create post records in `posts` with derived thumbnails for video; remove mock returns in `ContentUploadService`.
   - Add retry, progress, and validation states.

14) Moderation pipeline
   - Add minimal admin-review queue for `reports`; ensure reported content visibility is managed.

15) Performance polishing
   - Preload videos around current index; cache avatar/user lookups; ensure PageView smoothness on lower-end devices.

---

## Database migration checklist
- Tables:
  - `comment_likes` (post_comment_id, user_id, created_at)
  - Optional `user_mutes` if muting is required server-side
- Policies (RLS):
  - Enforce per-user access for likes, saves, follows, comments, reports
- Indexes:
  - On foreign keys and (post_id, created_at) where applicable
- Functions (RPC):
  - `increment_view_count(post_id uuid)`
  - `increment_likes_count(post_id uuid)`
  - `decrement_likes_count(post_id uuid)`

---

## QA checklist (Home feed)
- Feed fetch paginates and loads more near end-of-list without duplicates.
- Like/follow/bookmark state reflects server state across sessions.
- Comment add/like/delete works with proper auth and error handling.
- Share triggers OS share sheet and records DB share event.
- Report opens dialog, writes to DB, and shows confirmation.
- View counters RPCs succeed; non-existent RPCs throw surfaced errors in snackbar and logs.
- Progress indicator reflects real playback.
- No mock data or hardcoded assets for user or content in feed UI.

## Definition of Done
- No mock/placeholder logic remains on the Home screen pathways.
- All actions (like, comment, share, save, follow, report, view) persist to Supabase and render accurate UI state.
- RPCs and RLS policies are deployed and verified via instrumentation tests.
- Home feed exposes at least Trending and Following filters per PRD.
- Upload flow creates real posts that appear in the Home feed.


