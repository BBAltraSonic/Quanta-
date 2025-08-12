## Create/Upload Post Flow Audit and Implementation Plan

### Scope
- Screen: `lib/screens/create_post_screen.dart` → `ContentUploadScreen`
- Services: `lib/services/content_upload_service.dart`, `lib/services/avatar_service.dart`, `lib/services/auth_service.dart`
- Models: `lib/models/post_model.dart`, `lib/models/avatar_model.dart`
- DB config/schema: `lib/config/db_config.dart`, `supabase_schema.sql`, `database_feeds_functions.sql`, `database_migration_fix.sql`
- Related widgets/modals: local `_MediaTypeButton`, `_MediaPickerOption` in `ContentUploadScreen`

This review was done to be exhaustive and to propose changes only when highly confident, per your preference [[memory:5857922]].

---

### High-level UX Flow
1. User lands on `CreatePostScreen`, which directly renders `ContentUploadScreen`.
2. `ContentUploadScreen` loads user avatars via `AvatarService.getUserAvatars()` (Supabase-backed) and allows selecting one.
3. User picks media (gallery/camera, image/video) via bottom sheets; a preview is shown (image or `VideoPlayer`).
4. User writes caption; hashtags are extracted live and previewed.
5. Share action (AppBar or bottom button) triggers `_uploadContent()` using `ContentUploadService.createPost()`.
6. On success, the screen pops and returns the created `PostModel`.

---

### Detailed Findings

#### UI and Modals
- Avatar selector, caption field, and media picker are implemented with modern UI and UX.
- Two bottom sheets are present:
  - Media source picker (Gallery, Video, Camera)
  - Camera options (Photo, Video)
- The Share button is correctly disabled until: avatar selected, media present, caption non-empty, not uploading.

Key code references:

```66:418:lib/screens/content_upload_screen.dart
// ...
actions: [
  TextButton(
    onPressed: _canUpload() ? _uploadContent : null,
// ...
],
// ...
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: _canUpload() ? _uploadContent : null,
// ... existing code ...
```

```467:553:lib/screens/content_upload_screen.dart
Future<void> _pickMedia({ImageSource? source, bool? isVideo}) async {
  // Shows bottom sheet when source == null, then picks image or video
}
```

```555:597:lib/screens/content_upload_screen.dart
void _showCameraOptions() {
  // Bottom sheet with Photo/Video options
}
```

Observations/gaps:
- No UI for external content import (e.g., Hugging Face/Runway URL), which the PRD calls for under Upload Workflow (link-outs and import option).
- No moderation warning UI in the upload flow (moderation service exists but is not integrated in this screen).
- No video length enforcement in UI; `Environment.maxVideoLengthSeconds` exists but isn’t used here.
- No compression or thumbnail generation UI feedback.

#### Service Layer (Critical)
- `ContentUploadService` currently returns a mock post and does not write to Supabase Storage nor insert into the `posts` table.

```234:264:lib/services/content_upload_service.dart
Future<PostModel> _uploadContentSupabase({
  // ...
}) async {
  // For now, create a mock post for testing purposes
  // In production, this would upload to Supabase storage and create database record
  // ... returns PostModel with local file path in imageUrl/videoUrl
}
```

- Media upload and external import are not implemented and explicitly throw:

```266:271:lib/services/content_upload_service.dart
Future<String> _uploadMediaFileSupabase(File file, PostType type) async {
  throw Exception('Media file upload service is not yet fully implemented.');
}
```

```273:285:lib/services/content_upload_service.dart
Future<PostModel> _importExternalContentSupabase(...) async {
  throw Exception('External content import service is not yet fully implemented.');
}
```

Consequences:
- The Share action yields a local-only `PostModel` object; no content appears in feed for other users, and app restarts will lose the content.
- Feeds and details that rely on network URLs will break because the returned `imageUrl`/`videoUrl` are file paths.

#### Data Model vs Schema Mismatches

- `PostModel` expects fields not present in `supabase_schema.sql`:
  - Missing in schema but used in code/model: `type`, `status`, `shares_count`, `engagement_rate`, `thumbnail_url`.
  - Schema has `posts` with: `video_url`, `image_url`, `caption`, `hashtags`, `views_count`, `likes_count`, `comments_count`, `is_active`, timestamps, `metadata`.

- Table name constants vs schema:
  - `DbConfig.likesTable` = `'post_likes'`; schema defines `'likes'` (and some services use `DbConfig.likesTable`).
  - `DbConfig.commentsTable` = `'post_comments'`; schema defines `'comments'`.
  - This will cause runtime errors where services query non-existent tables.

References:

```1:82:lib/config/db_config.dart
static const String likesTable = 'post_likes';
static const String commentsTable = 'post_comments';
```

```1:148:supabase_schema.sql
-- Likes policies
-- Table is named public.likes
```

#### Moderation
- `ContentModerationService` provides local keyword-based moderation and stubs for external APIs.
- Not invoked anywhere in the upload flow; no blocking/flagging/warning step prior to publishing.

#### Other Observations
- `AvatarService.getUserAvatars()` is fully Supabase-backed and works with storage for avatar images.
- `AuthService` initializes Supabase correctly and listens for auth changes.
- No offline upload queue; no retry strategy for failed uploads.
- No analytics event emitted on post creation (PRD calls for growth/metrics eventually; optional for MVP, but nice to have basic logging).

---

### Alignment with PRD

- Matches:
  - Upload workflow basics: select avatar, upload image/video, add caption/hashtags.
  - TikTok-style ecosystem and models exist for feeds/interactions.

- Gaps vs PRD MVP:
  - Storage/DB write missing for uploads → core MVP blocker.
  - Max video length (90s) not enforced in UI or service.
  - No optional voiceover selection in upload step.
  - No “external tool import” UI (Hugging Face, Runway, Pika) though service stub exists.
  - No moderation step before publishing.
  - Schema mismatches for fields used by models and services (e.g., `type`, `status`, `shares_count`).

---

### What Still Needs Implementation (Exhaustive)

1. Supabase Storage upload for media to `posts` bucket.
2. Create `posts` row insert with correct fields; return canonical `PostModel` with public URLs.
3. Schema alignment: add missing columns (`type`, `status`, `thumbnail_url`, `shares_count`, `engagement_rate`) or refactor code to existing schema.
4. Fix `DbConfig` table names to match schema (`likes`, `comments`).
5. Enforce validations:
   - File size/type (already in service helper, but not used in UI)
   - Video max length 90s
6. Thumbnail generation for videos and use in feeds.
7. Optional: compress video before upload.
8. Integrate moderation check in `_uploadContent()` before commit.
9. Add external import UI (URL + platform picker) and implement `_importExternalContentSupabase`.
10. Robust progress UI and error handling; cancel/retry uploads.
11. Update related counts (avatar `posts_count`) and analytics (optional).
12. Tests: unit (service), widget (screen), and integration (upload + feed appearance).

---

### Development Plan (Small, Manageable Tasks)

#### Phase A — Schema and Config Corrections
1. Posts table columns:
   - Add `type TEXT CHECK (type IN ('image','video'))`.
   - Add `status TEXT DEFAULT 'published' CHECK (status IN ('draft','published','archived','flagged'))`.
   - Add `thumbnail_url TEXT`.
   - Add `shares_count INTEGER DEFAULT 0`.
   - Add `engagement_rate REAL DEFAULT 0.0`.
2. Ensure indexes match new columns if needed (created_at ordering exists).
3. Align table names in `DbConfig`:
   - `likesTable = 'likes'`
   - `commentsTable = 'comments'`
4. Verify RLS policies for posts insert (already present) and storage policies for `posts` bucket.

#### Phase B — Media Upload Service (Supabase)
1. Implement `ContentUploadService.uploadMediaFile()`:
   - Path: `posts/<avatarId>/<uuid>.<ext>`
   - Use `_authService.supabase.storage.from('posts').upload(...)`.
   - Return public URL via `.getPublicUrl(...)`.
2. For videos:
   - Generate and upload a thumbnail (first frame or placeholder image) → return `thumbnail_url`.
3. Add compression step (using a plugin like `video_compress`).

#### Phase C — Create Post (DB Insert)
1. Implement `_uploadContentSupabase` to:
   - Validate content (call `validateContent`) and video duration (<= 90s).
   - Upload media to storage and get public URLs.
   - Insert into `public.posts` with fields aligned to `PostModel`.
   - Return `PostModel.fromJson(response)`.
2. Increment `avatars.posts_count` via trigger or service-side update.

#### Phase D — UI Integration and UX Polish
1. Wire `ContentUploadScreen._uploadContent()` to show granular progress (select, upload, publish).
2. Invoke `ContentModerationService.moderatePost()` pre-insert; if `block` → show `ModerationWarning` with options; if `flag`/`warn` → proceed with badge/metadata.
3. Enforce video length in UI; show message if > 90s.
4. Replace local file path preview with network URL post-publish if the user stays on screen.
5. Add external import entry point:
   - Button “Import from external tool” → modal: URL + platform (list from `getSupportedPlatforms()`).

#### Phase E — External Import
1. Implement `_importExternalContentSupabase`:
   - Validate URL and supported platform.
   - Insert post with `image_url`/`video_url` pointing to the external resource (or fetch & rehost if desired).
   - Mark metadata with `source_platform`.

#### Phase F — Testing
1. Unit tests for `ContentUploadService`:
   - Media upload happy/failed paths.
   - DB insert returns `PostModel` with proper fields.
   - Validation and moderation branches.
2. Widget tests for `ContentUploadScreen`:
   - Share button enable/disable logic.
   - Bottom sheets open and callbacks fire.
3. Integration test:
   - Full upload → feed fetch shows the new post.

#### Phase G — Analytics and Telemetry (Optional for MVP)
1. Emit events on upload start/success/failure with durations and sizes.
2. Track moderation outcomes.

#### Phase H — Documentation
1. Update README or a `docs/upload_workflow.md` with environment requirements, permissions, and expected storage paths.

---

### Acceptance Criteria
- Share action creates a post in Supabase:
  - Media is uploaded to `posts` bucket; public URLs are set.
  - Row exists in `public.posts` with accurate `type`, `status`, `caption`, `hashtags`, `thumbnail_url` (for video), counters at 0.
  - Avatar `posts_count` increments (immediate or eventually via trigger/job).
- UI enforces max 90s video length and basic validation; shows user-friendly errors.
- Optional: moderation step is executed and respected.
- Feeds screens load and display the newly posted content using network URLs.

---

### Risks and Mitigations
- Schema drift between code and DB: lock via migration scripts; run in CI.
- Large video uploads: add compression and upload progress + cancellation.
- RLS/storage policy errors: include a setup script and validation checks during app init.
- External URLs may break over time: prefer rehosting or background fetch-and-store.

---

### Quick Win Checklist (Day 1-2)
- Fix `DbConfig` table names to match schema.
- Add missing `posts` columns (type, status, thumbnail_url, shares_count, engagement_rate).
- Implement storage upload + DB insert in `ContentUploadService`.
- Call `validateContent` in `_uploadContent()` before upload; enforce 90s video rule.
- Minimal progress UI and robust error toasts.

---

### Longer-term Enhancements (Post-MVP)
- Transcoding, adaptive streaming, and thumbnail sprites for scrubbing.
- Offline upload queue with retries and backoff.
- Scheduled/agentic posting per PRD “Autonomous Posting Mode”.
- External import deep-links and templated helpers.

---

### Appendix: Key Code Excerpts

Mock post creation (must be replaced by real storage + DB insert):
```243:264:lib/services/content_upload_service.dart
// For now, create a mock post for testing purposes
// In production, this would upload to Supabase storage and create database record
return PostModel(
  id: postId,
  avatarId: avatarId,
  type: type,
  caption: caption,
  videoUrl: type == PostType.video ? (mediaFile?.path ?? externalMediaUrl) : null,
  imageUrl: type == PostType.image ? (mediaFile?.path ?? externalMediaUrl) : null,
  // ...
);
```

Schema tables missing fields expected by `PostModel`:
```43:58:supabase_schema.sql
CREATE TABLE public.posts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  avatar_id UUID REFERENCES public.avatars(id) ON DELETE CASCADE NOT NULL,
  video_url TEXT,
  image_url TEXT,
  caption TEXT,
  hashtags TEXT[] DEFAULT '{}',
  views_count INTEGER DEFAULT 0,
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  metadata JSONB DEFAULT '{}'
);
```

DbConfig table name mismatches:
```1:82:lib/config/db_config.dart
static const String likesTable = 'post_likes';
static const String commentsTable = 'post_comments';
```


