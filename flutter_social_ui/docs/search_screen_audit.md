## Search Screen Audit and Implementation Plan

### Scope
- Screen: `lib/screens/search_screen_new.dart`
- Services: `lib/services/search_service.dart`, `lib/services/enhanced_feeds_service.dart`, `lib/services/avatar_service.dart`
- Models: `lib/models/avatar_model.dart`, `lib/models/post_model.dart`, `lib/models/user_model.dart`
- Schema: `supabase_schema.sql`
- PRD: `docs/Quanta prd.md`

### Executive Summary
- Avatars and posts search are wired to Supabase and functional, contingent on schema parity.
- Hashtag search relies on a missing RPC (`search_hashtags`) and falls back to in-app aggregation; Trending hashtags on the screen use a hardcoded placeholder list.
- Popular searches are hardcoded; no live suggestions or recent-search persistence.
- Post tap action is a placeholder (snackbar); no navigation to post detail.
- Schema mismatches: the code expects `posts.type`, `posts.status`, `posts.thumbnail_url`, `posts.shares_count`, `posts.engagement_rate` which are absent in `supabase_schema.sql`.
- No modals exist on the search screen; only navigation to `ChatScreen` is implemented.

Overall: Replace placeholders with DB-backed data, align schema with code, add missing RPCs/materialized views, and integrate a proper post detail flow and typeahead.

---

### UI and Interaction Review

1) Search header
- Components: `TextField` with prefix search icon, dynamic clear suffix icon, Cancel button.
- Issue: `suffixIcon` visibility depends on `_searchController.text` but `onChanged` does not call `setState`; visibility may not refresh immediately.
- Action: Trigger rebuild on text change (e.g., `setState` in `_onSearchChanged` or a `ValueListenableBuilder` around the controller).

2) Tabs and results
- Tabs: Avatars, Posts, Hashtags; counts reflect list sizes.
- Avatar results: List items with avatar image/name/bio/niche and a Chat button → navigates to `ChatScreen` with `avatarId`.
- Chat navigation image bug: `SearchScreenNew._navigateToChat` passes `avatar.imageUrl ?? 'assets/images/p.jpg'` into `ChatScreen.avatar`, but `ChatScreen` uses `AssetImage(widget.avatar)` in the AppBar. If `avatar.imageUrl` is a network URL, this will break. Action: Update `ChatScreen` to detect network vs asset paths and use `NetworkImage` when appropriate.
- Post results: Grid of posts with media thumbnail and counts; onTap is a placeholder: shows a snackbar via `_viewPost`.
- Video rendering bug: Post grid uses `Image.network(post.mediaUrl)` regardless of `PostType`. If `PostType.video`, `mediaUrl` points to a video URL and will fail. Action: render `thumbnail_url` for videos or a video thumbnail widget with overlay.
- Hashtag results: List of hashtag strings; subtitle says “Trending hashtag” regardless of actual trendiness.

3) Discover content (when not searching)
- Trending Hashtags: hardcoded list set by `_loadTrendingContent()`; comment notes a missing service implementation.
- Popular Searches: hardcoded static list.

4) Modals
- None used by the search screen (no filters/sort/bottom sheets). Navigation to chat is a full-screen route.

5) Icon buttons
- Search prefix icon (static), Clear icon (dynamic), Arrow icons in lists. No additional action icons (e.g., filter/sort) provided.

---

### Service and Data Flow Review

SearchService (`lib/services/search_service.dart`)
- Avatars: Supabase query with `ilike` filters and ordering on `followers_count` and `engagement_rate`.
- Posts:
  - Supabase query with filters: `is_active = true`, `status = 'published'` and `or(caption.ilike, hashtags.cs)`; sorts by `engagement_rate`, `created_at`.
  - Expects fields `type`, `thumbnail_url`, `status`, `engagement_rate` (used in model or query).
- Users: `username` and `display_name` `ilike`.
- Hashtags:
  - Primary: RPC `search_hashtags(search_query, limit_count, offset_count)` (MISSING in schema).
  - Fallback: in-app aggregation from `posts.hashtags`.
- Trending Hashtags:
  - Primary: RPC `get_trending_hashtags(limit_count)` (MISSING in schema).
  - Fallback: count hashtags from recent posts in-app; cached for 15 minutes.
- Suggestions & recents:
  - `getSearchSuggestions` combines in-memory recent searches, trending hashtags, and avatar name lookups.
  - Recent searches are not persisted; in-memory only.

EnhancedFeedsService (`lib/services/enhanced_feeds_service.dart`)
- Not used by the search UI, but referenced by comment in `_loadTrendingContent()`; contains no `getTrendingHashtags` method.

AvatarService (`lib/services/avatar_service.dart`)
- Used by `ChatScreen` fallback to find avatar by name. Supabase-backed search present.

---

### Schema Alignment Check

Code expects on `posts`:
- Present in schema: `id`, `avatar_id`, `image_url`, `video_url`, `caption`, `hashtags`, `views_count`, `likes_count`, `comments_count`, `is_active`, timestamps.
- Missing but referenced by code:
  - `type` (image|video) → required by `PostModel.type` and UI display heuristics.
  - `status` (draft|published|archived|flagged) → used in queries and default filters.
  - `thumbnail_url` → used for video previews.
  - `shares_count` → referenced in model/utilities.
  - `engagement_rate` → used for ordering and relevance scoring.

RPC functions missing (referenced by code):
- `search_hashtags(search_query text, limit_count int, offset_count int)`
- `get_trending_hashtags(limit_count int)`

Other functions referenced elsewhere (not critical to search but present in services):
- `increment_view_count`, `increment_likes_count`, `decrement_likes_count`, `increment_comments_count` (not present in schema file).

Indexes and extensions:
- For `ilike` performance on large tables, consider `pg_trgm` and GIN indexes on `avatars.name`, `avatars.bio`, `posts.caption`, `posts.hashtags`.

RLS:
- Present for base tables. Ensure RPCs are SECURITY DEFINER where appropriate and respect RLS in underlying queries.

---

### Gaps, Placeholders, and Risks
- Trending Hashtags on UI: hardcoded list; not DB-backed.
- Hashtag search: depends on missing `search_hashtags` RPC; fallback is in-app aggregation; not scalable and may be inconsistent.
- Popular searches: hardcoded; no dynamic suggestions while typing; recent searches are not persisted.
- Post tap: no navigation; `_viewPost` shows snackbar only.
- Suffix clear icon: may not render visibility changes immediately due to missing `setState` on text change.
- Hashtag result subtitle: always “Trending hashtag” regardless of actual counts; misleading.
- Fallback mock in service: `SearchService.searchHashtags` returns a hardcoded fallback list of tags if RPC fails. This should be removed in favor of DB-backed results or explicit error UI.
- Schema mismatches: missing columns may break queries (`status`, `type`, `thumbnail_url`, `engagement_rate`, `shares_count`).
- Service import mismatch: screen references `EnhancedFeedsService` for trending comment, but should use `SearchService.getTrendingHashtags` or implement in the feeds service.
- Integration gap: In `enhanced_post_detail_screen.dart`, the top overlay search icon handler is a placeholder; it should navigate to `SearchScreenNew` to unify entry points.

---

### Alignment With PRD (`docs/Quanta prd.md`)
- PRD emphasizes Trends & Challenges and a TikTok-style discovery surface.
- Current search UI surfaces hashtags and posts but lacks a true “Trending” section backed by real data and challenges.
- Chat integration entry (Chat button) aligns with “Chat with Avatars.”
- Missing: robust trend discovery, challenges integration, and a polished post detail flow from search results.

Overall, the search feature partially aligns with PRD but needs DB-backed trends, suggestions, and a proper navigation to content detail to fully support discovery.

---

### Development Plan (Small, Manageable Subtasks)

Phase 0: Stabilize Schema and RPCs
1. Posts table parity
   - Add columns: `type text check (type in ('image','video')) not null default 'image'`, `status text check (status in ('draft','published','archived','flagged')) not null default 'published'`, `thumbnail_url text`, `shares_count int default 0`, `engagement_rate real default 0.0`.
   - Backfill `type` heuristically from `video_url`/`image_url`.
2. RPCs for hashtags
   - Implement `search_hashtags(search_query text, limit_count int, offset_count int)` to aggregate from `posts.hashtags` (case-insensitive), return `[{hashtag, count}]` sorted by count desc.
   - Implement `get_trending_hashtags(limit_count int)` to aggregate counts over recent window (e.g., 7 days) from `posts.created_at` and `posts.hashtags`.
   - Add tests and ensure policies allow reads.
3. Performance
   - Enable `pg_trgm`.
   - Add GIN index on `posts.hashtags` and trigram indexes on `avatars.name`, `avatars.bio`, `posts.caption`.

Phase 1: Replace Placeholders and Wire UI to DB
4. Trending hashtags on UI
   - Replace `_loadTrendingContent()` with a call to `SearchService.getTrendingHashtags(limit: 20)`; map to display strings.
   - Remove hardcoded lists.
5. Popular searches & suggestions
   - Add typeahead suggestions: use `SearchService.getSearchSuggestions(query)` to show a dropdown overlay while typing.
   - Persist recent searches (e.g., `SharedPreferences` or Supabase `recent_searches` per user) and load on init.
6. Hashtag results subtitle
   - Switch hashtag tab to use `SearchResult` variant with counts when available; render accurate counts.

Phase 2: UX Polish and Navigation
7. Post detail navigation
   - Implement `_viewPost(post)` to navigate to `EnhancedPostDetailScreen` or `PostDetailScreen` with `postId`.
   - Preload post/author data as needed.
8. Clear icon visibility
   - Ensure `setState` on text changes to correctly toggle the clear icon; or use `ValueListenableBuilder` around `TextEditingController`.
9. Empty and error states
   - Standardize empty/error UI across tabs; include retry for transient failures.
10. Correct video grid rendering
   - Use `thumbnail_url` for videos or generate a thumbnail; add a play overlay icon.

Phase 3: Consistency and Maintainability
10. Service usage cleanup
   - Remove unused `EnhancedFeedsService` import from the search screen; or implement `getTrendingHashtags` in that service and route calls consistently through a single source.
11. Unify search flows
   - Consider using `SearchService.search` returning `SearchResult` to support a consolidated, relevance-sorted “All” tab; optionally add an “All” tab and keep type-specific tabs.
12. Telemetry
   - Log search queries (anonymized), result clicks, and conversion to post views/chats for analytics.
13. Wire global search entry
   - From the top overlay search icon in `enhanced_post_detail_screen.dart`, navigate to `SearchScreenNew`.

Phase 4: Optional PRD Enhancements
13. Challenges integration
   - Add a “This Week’s Challenges” strip to Discover, backed by a `challenges` table.
14. Advanced filters
   - Add filter modal (niche, type, date range, engagement) and wire to queries.

---

### Acceptance Criteria
- No hardcoded trending or popular search content on the screen; all discovery content is DB-backed.
- Hashtag search and trending use RPC-backed aggregation with accurate counts.
- Post tap navigates to a detail screen; no snackbar placeholder remains.
- Schema parity ensures queries for posts no longer error on missing columns.
- Suggestions appear as the user types; recent searches persist across app restarts.

---

### Test Plan
- Unit tests
  - `SearchService`: avatar/post/user/hashtag queries, RPC fallbacks, suggestions, trending cache.
- Widget tests
  - Search screen: typing shows suggestions, clear button visibility, tabs render counts and empty states, tapping entries triggers correct navigation.
- Integration tests
  - End-to-end search flows with a seeded DB: avatar search → chat, hashtag search → post list, post tap → detail.

---

### Risks and Mitigations
- Missing RPCs or RLS blocks: Provide SECURITY DEFINER where safe and validate RLS with tests.
- Performance on large datasets: Add indexes and consider materialized views for trending hashtags.
- Schema migration coordination: Protect with `IF NOT EXISTS` and backfills; version migrations.

---

### Quick Fix Checklist (Short-Term)
- Add `setState` on text change for clear icon.
- Replace `_loadTrendingContent()` hardcoded list with `SearchService.getTrendingHashtags()`.
- Implement `_viewPost()` navigation to a detail screen.
- Remove misleading “Trending hashtag” subtitle or derive from counts.

---

### References
- Screen: `lib/screens/search_screen_new.dart`
- Services: `lib/services/search_service.dart`, `lib/services/enhanced_feeds_service.dart`, `lib/services/avatar_service.dart`
- Schema: `supabase_schema.sql`
- PRD: `docs/Quanta prd.md`


