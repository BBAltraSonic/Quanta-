## Profile Screen Audit and Development Plan

This document provides a thorough analysis of the current Profile experience (screen, modals, icon buttons, and widgets), assesses database connectivity, identifies placeholders/mock data, and proposes a comprehensive, granular development plan. It also checks alignment with the PRD in `docs/Quanta prd.md`.

### Scope (files reviewed)
- `lib/screens/profile_screen.dart`
- `lib/services/profile_service.dart`
- `lib/services/auth_service.dart`
- `lib/models/user_model.dart`, `lib/models/avatar_model.dart`
- `lib/screens/edit_profile_screen.dart`
- `lib/screens/avatar_management_screen.dart`
- `lib/services/avatar_service.dart`, `lib/services/follow_service.dart`
- `lib/services/enhanced_feeds_service.dart`, `lib/models/post_model.dart`
- `lib/screens/chat_screen.dart`, `lib/services/chat_service.dart`
- `supabase_schema.sql`, `database_migration_fix.sql`
- PRD: `docs/Quanta prd.md`

---

## Findings (High-level)

- Profile loads user, avatars, and basic stats via Supabase. Edit profile and avatar management are wired to DB. Storage uploads work.
- Several UI sections use placeholders or inconsistent keys, resulting in incorrect or zeroed stats and mock visuals.
- Critical DB mismatches exist (e.g., setting active avatar on a non-existent `users.active_avatar_id` column).
- Primary CTAs (“Follow”, “Message/Chat”) are not implemented; posts grid uses asset placeholders (no DB posts).
- PRD expects an avatar-centric profile with “Chat with me”, content grid, engagement metrics; current screen is user-centric and not fully aligned.

---

## Detailed Review

### App bar and navigation
- Leading settings icon navigates to `SettingsScreen` (OK, implemented).
- Trailing edit icon navigates to `EditProfileScreen` (OK). Edit screen updates `users` via `ProfileService.updateUserProfile()` and uploads images to Supabase Storage bucket `avatars` (works, but naming mixes profile and avatar assets).

### Header (photo, name, bio, stats, primary actions)
- Background/profile photo: correctly displays `user.profile_image_url` with error/fallback image.
- Display name: uses `user.display_name ?? user.username` (OK).
- Bio: uses the first avatar’s `bio` when available; otherwise fallback text.
- Stats row uses keys `total_posts`, `total_followers`, `total_following`. However, `ProfileService.getUserProfileData()` returns `posts_count`, `followers_count`, `following_count`. This mismatch will render zeros/incorrect values.
- Primary buttons:
  - “Follow”: onPressed is empty. No logic for self vs. other profiles. Should use `FollowService.toggleFollow` when viewing other avatars.
  - “Message”: onPressed is empty. Should navigate to `ChatScreen` with an `avatarId` (PRD: “Chat with me”).

### Analytics section
- Cards display values from `_stats` using keys like `total_views`, `engagement_rate`, `total_revenue`, `growth_rate`. These fields are not provided by `ProfileService.getUserProfileData()`. Subtitles show static growth strings (“+12% this week”): placeholders.
- “Top Performing Avatar” simply uses `_avatars.first` (comment acknowledges placeholder). Not based on computed performance.

### Avatars section
- “My Avatars” list is loaded from DB via `ProfileService.getUserAvatars()` (OK).
- “View All” navigates to `AvatarManagementScreen` (OK).
- `AvatarManagementScreen` loads avatars from DB and allows setting an active avatar via `ProfileService.setActiveAvatar(userId, avatarId)` which updates `users.active_avatar_id` — this column is NOT present in `supabase_schema.sql` or `database_migration_fix.sql`. This will fail at runtime. Bottom sheet details modal is implemented and informative.

### Posts grid (masonry)
- Entirely uses local assets (`assets/images/We.jpg`, `assets/images/p.jpg`) and hard-coded badges (e.g., “1/3”, “5/7”). No DB fetch. This is mock UI.
- PRD requires the avatar’s public page to show its content grid (shorts feed). Missing.

### Data services and schema
- `ProfileService.getUserProfileData(userId)` aggregates:
  - `users` row
  - `avatars` list for owner
  - `follows` count as following_count
  - Returns a `stats` map with `following_count`, `followers_count`, `posts_count` derived from `users` columns (added by `database_migration_fix.sql`).
- Inconsistent stat keys between service and UI (see above).
- `setActiveAvatar` attempts to update `users.active_avatar_id` which doesn’t exist in schema. Either add it or derive “active” from avatars themselves.
- `EditProfileScreen` updates `users.email` in the `users` table only; it does not update `auth.users.email` in Supabase Auth. Depending on product intent, this may be acceptable or cause confusion.

### Follow and chat integration
- Follow logic exists in `FollowService` and works against `follows` table, but the profile screen does not call it.
- `ChatScreen` and `ChatService` are implemented and integrated with Supabase and AI service, but Profile does not route to it. The profile should launch chat for an active avatar as “Chat with me”.

### PRD alignment check (Profile-related)
From `docs/Quanta prd.md`:
- Avatar Profile Page should include: avatar bio, follower stats, engagement rate, “Chat with me” CTA, collabs/duets tab, content grid.
  - Bio and basic avatar info: partially present (via first avatar). Should be avatar-specific, not user-specific.
  - Follower stats: present in schema and services; UI key mismatch prevents correct rendering.
  - Engagement metrics: not implemented (placeholders). Need real calculations from posts and follows/likes.
  - “Chat with me”: missing; “Message” button is empty.
  - Collabs and Duets tab: not present.
  - Content grid: missing DB-backed posts; uses placeholder assets.

Overall, the current Profile experience is user-centric and partially wired; the PRD expects an avatar-centric, publicly viewable profile with real data and interactive CTAs.

---

## Gaps and Issues (Exhaustive)

1. Stats keys mismatch between UI and service: `_stats['total_*']` vs `*_count`.
2. Analytics cards show placeholder data and growth text; no backend source.
3. “Top Performing Avatar” selection is not data-driven.
4. Posts grid uses local assets; no DB posts for the user’s avatar(s).
5. “Follow” button has no implementation and is inappropriate for self-profile. Needs context-aware behavior or different actions.
6. “Message” button has no implementation. Should launch `ChatScreen` with `avatarId`.
7. Active avatar persistence updates a non-existent column `users.active_avatar_id`.
8. Profile displays the first avatar’s bio as user bio; not selected/active avatar-aware and not consistent if multiple avatars exist.
9. `uploadProfileImage` stores in `avatars` bucket (naming confusion). Consider separate `profiles` bucket or keep but document.
10. Email update in `users` only; not in Supabase Auth. Clarify desired behavior.
11. No pinned post or collabs/duets tab to match PRD.
12. No error UI for failed profile load beyond spinner removal; limited UX for empty/error states on Profile.

---

## Development Plan (Incremental, small tasks)

### Phase 1: Correctness and wiring
- Fix stat keys in `profile_screen.dart` to use `posts_count`, `followers_count`, `following_count` consistently.
- Replace analytics placeholder keys with actual fields or compute-only what exists; temporarily hide cards if data unavailable.
- Implement “Message” button:
  - If there is an active avatar (see Phase 2), navigate to `ChatScreen` with `avatarId` and avatar image.
  - If no avatar, disable with tooltip or guide to create avatar.
- Implement context-aware primary action:
  - If viewing own profile: replace “Follow” with “Share Profile” or “Create Post”.
  - If viewing someone else’s avatar profile: show “Follow” wired to `FollowService.toggleFollow(avatarId)` and reflect state.

### Phase 2: Active avatar and avatar-centric profile
- Schema: add `users.active_avatar_id UUID REFERENCES public.avatars(id)` with RLS update policy; or derive active avatar from avatars table (e.g., `avatars.is_active` + new `is_primary` flag). Recommended: add `active_avatar_id` for clear UX.
- Backend:
  - Update `supabase_schema.sql` and migrations to include `users.active_avatar_id` and policies.
  - Update `ProfileService.setActiveAvatar` only after schema is present.
- UI:
  - In Profile header, use active avatar data (bio, followers, engagement, CTA).
  - Add a small selector to switch active avatar when owner is viewing their own profile.

### Phase 3: Posts grid (DB-backed)
- Service: add a method to fetch posts by avatar(s), e.g., `getPostsForAvatar(avatarId, page, limit)` and optionally `getPostsForUser(userId)` aggregating all owned avatars.
- Replace masonry placeholders with a list/grid fed by Supabase `posts` table.
- Show real thumbnails for images/videos (`thumbnailUrl` or `image_url`), and tap-through to a post detail.
- Add empty-state when no posts exist; CTA to “Create Post”.

### Phase 4: Analytics
- Define minimal analytics available now:
  - Views, likes, comments from the aggregated posts for active avatar.
  - Engagement rate: simple formula like `total_engagement / total_views` or similar MVP metric.
- Compute server-side via SQL views or client-side aggregation. Prefer SQL view for performance and consistency.
- Update `ProfileService.getUserProfileData()` to return the new analytics map with documented keys.
- Update UI cards to display computed values; remove static “+12% this week” placeholders until time-windowed metrics exist.

### Phase 5: PRD UX alignment
- “Chat with Me” CTA: rename “Message” to “Chat with Me” and ensure it launches chat for the active avatar.
- Add optional “Pinned post” section above the grid. Schema: add `avatars.pinned_post_id` or a join table; otherwise pick most recent for MVP.
- Add “Collabs and Duets” tab or a simple horizontally scrollable section filtered by a `collab_with` field or hashtag as MVP.

### Phase 6: Robustness and polish
- Error and empty states for profile loading, avatars, and posts.
- Loading skeletons in place of content; remove redundant custom spinners.
- Unit tests:
  - Key mapping tests for `ProfileService.getUserProfileData()`.
  - UI widget tests for stat rendering and CTA visibility logic.
- Integration tests:
  - Follow/unfollow flow from profile.
  - Chat launch from profile and basic message roundtrip.

---

## Task Breakdown (Actionable subtasks)

1) Stats key fixes
- Update `lib/screens/profile_screen.dart` to use `posts_count`, `followers_count`, `following_count`.
- Add null-safe defaults and ensure formatting via `_formatNumber`.

2) Implement “Message”/Chat CTA
- In profile header, wire onPressed to navigate to `ChatScreen`, passing `avatarId` of the active avatar.
- If no active avatar, disable and show a tooltip or prompt to create/select an avatar.

3) Context-aware primary action
- If `userId == viewingUserId`: show “Share Profile” or “Create Post” instead of “Follow”. Otherwise show Follow.
- Use `FollowService.isFollowing` to set initial state; `toggleFollow` on tap.

4) Active avatar persistence
- Add `active_avatar_id` to `users` (SQL + RLS) or an equivalent approach; migrate.
- Keep `AvatarManagementScreen` as the place to set active avatar; update UI copy and feedback.

5) Posts grid from DB
- Add service method(s): `getPostsForAvatar(avatarId)`, optionally paginated.
- Replace asset tiles with real thumbnails from `posts.image_url`/`thumbnailUrl` or poster frame for video.
- Show counts (likes/comments) overlays if available.

6) Analytics MVP
- Create a SQL view (e.g., `avatar_analytics`) to expose aggregated counts per avatar.
- Update `ProfileService.getUserProfileData()` to pull analytics for the active avatar and return keys: `views_count`, `likes_count`, `comments_count`, `engagement_rate`.
- Update UI to use these keys; hide cards if analytics are unavailable.

7) PRD features
- Rename “Message” to “Chat with me”.
- Add optional “Pinned Post” section; wire to post detail.
- Add “Collabs and Duets” surface (MVP: filter posts by a `collab` tag or simple indicator).

8) Schema and policy updates
- `users.active_avatar_id` column + RLS update policy.
- Optional: triggers to maintain `users.followers_count`, `users.posts_count` (or use views and compute counts on read).

9) Testing and QA
- Unit tests for key mapping, services, and widget logic.
- Integration tests: follow toggling, chat session creation from profile, posts grid loading.

---

## Acceptance Criteria
- Profile shows correct counts for posts/followers/following.
- “Chat with me” launches chat for the active avatar, or gracefully prompts to set one.
- Posts grid loads real posts from Supabase and navigates to details on tap.
- “Follow” button implemented for other users’/avatars’ profiles; not shown for self-profile.
- No placeholders remain in analytics; cards show real values or are hidden when unavailable.
- Active avatar setting persists without errors; no writes to non-existent columns.

---

## Notes and Risks
- Updating `users.email` without syncing `auth.users.email` can confuse authentication flows. Decide whether to allow profile-only email or implement a secure email change flow via Supabase Auth.
- Buckets: storing profile images in the `avatars` bucket works but may complicate lifecycle rules. Consider a `profiles` bucket.
- If multiple avatars per user are part of MVP, ensure UI clearly distinguishes user vs. avatar profiles. PRD suggests the public profile is avatar-centric.

---

## Alignment Summary with PRD
- Avatar-centric public page: partially met; needs active avatar framing and content grid from DB.
- “Chat with me”: missing; implement via `ChatScreen` for active avatar.
- Engagement metrics: missing; implement aggregated analytics.
- Collabs/duets: missing; add MVP surface/tab.
- Overall: after Phases 1–5, Profile will be aligned with PRD expectations for MVP.


