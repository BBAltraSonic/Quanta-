# Flutter Social App — Pixel‑Perfect UI Build Plan

Target: Create a pixel‑perfect replica of the provided screens using Flutter, focusing on UI/UX only. Backend will be integrated after UI completion. Feed behavior should be TikTok‑style vertical PageView. Bottom navigation is locked to the bottom, transparent, with a true floating circular center action that overlaps. Use custom SVG icons. Progress bar reflects media progress.

## Acceptance Criteria

- [ ] UI matches reference pixel‑for‑pixel (spacing, sizes, colors, radii, typography, opacity/blur, layering).
- [ ] Vertical PageView feed with edge‑to‑edge media and overlay controls.
- [ ] Transparent, bottom‑locked nav bar; elevated red center FAB overlapping.
- [ ] Top overlay circular icons (search, volume, menu).
- [ ] Bottom overlay with avatar, display name, caption, interaction bar (like, comment, share, save) matching the reference layout.
- [ ] Bottom red progress indicator reflects media progress (mocked initially, then wired to controller later).
- [ ] Uses custom SVG icons (flutter_svg) with correct sizes and colors.
- [ ] Supports common device DPIs/aspect ratios (Pixel 4/5/6, iPhone 13–15) without layout breaks.
- [ ] Dark theme consistent across screens.

---

## Project Setup

- [ ] Ensure Flutter stable channel and min SDK constraints are satisfied.
- [ ] Dependencies:
  - [ ] flutter_svg (installed)
- [ ] Assets:
  - [ ] images placed under assets/images/
  - [ ] SVGs placed under assets/icons/
  - [ ] pubspec.yaml: include assets paths
- [ ] Theming:
  - [ ] Define theme constants (colors, spacing, text styles) in constants.dart
  - [ ] Use Material typography (as requested) tuned to match the reference sizes/weights.

---

## Color, Spacing, Typography

- [ ] Colors
  - [ ] Background: #0E0E0E–#111111 (verify exact tone to match)
  - [ ] Card overlay: #000000 at 35% opacity (top icons background)
  - [ ] Primary Red: reference red (approx #FF2E2E) tuned by eye
  - [ ] Text: White at 100%, secondary text ~70% opacity
  - [ ] Divider/progress background: white at ~15%
- [ ] Spacing
  - [ ] Horizontal gutters: 16 px
  - [ ] Top overlay Y padding: 10–12 px
  - [ ] Overlay bottom block padding: 16 px with interior spacing 8 px
- [ ] Typography (Material)
  - [ ] Display name: weight 700, ~14–16 sp
  - [ ] Caption: bodyMedium ~13–14 sp, 1.2–1.3 line height, 70–85% white
  - [ ] Counters (likes/comments): caption ~12–13 sp, 70% white

---

## Iconography (SVG)

- [ ] Provide SVGs (names and expected usage):
  - [ ] assets/icons/search.svg
  - [ ] assets/icons/volume.svg
  - [ ] assets/icons/menu.svg
  - [ ] assets/icons/like.svg
  - [ ] assets/icons/comment.svg
  - [ ] assets/icons/share.svg
  - [ ] assets/icons/save.svg
  - [ ] assets/icons/home.svg
  - [ ] assets/icons/profile.svg
- [ ] Guidelines:
  - [ ] ViewBox normalized (e.g., 24x24)
  - [ ] Fill set to currentColor, or remove inline fills to allow color control via color prop
  - [ ] No strokes that ignore color prop unless intended

---

## Component Inventory

- [ ] PostItem (Widget)
  - [ ] Props: imageUrl, author, caption, likes, comments, onCommentTap, onLikeTap, controller (optional)
  - [ ] Layers:
    - [ ] Background media (Image/Video)
    - [ ] Top overlay row: circular buttons (search, volume, menu)
    - [ ] Bottom caption cluster: avatar, author, caption (multi‑line, ellipsized after N lines)
    - [ ] Interaction row: like, comment, share, save (with counters)
    - [ ] Bottom progress line (reflects media progress)
- [ ] BottomNav (Widget)
  - [ ] Transparent background, rounded container shadowless
  - [ ] Left: home.svg, Right: profile.svg (white)
  - [ ] Center: floating circular red FAB (glow) overlapping nav
- [ ] OverlayIcon (Widget)
  - [ ] Circular container with semi‑transparent black background and centered SvgPicture
- [ ] Avatar (Widget)
  - [ ] Circular avatar with 28–32 px radius, shadow optional

---

## Screen Structure

- [ ] PostDetailScreen (Home)
  - [ ] PageView.builder (Axis.vertical)
  - [ ] Each page renders PostItem
  - [ ] Locked bottom navigation using Stack + Positioned
  - [ ] Top SafeArea overlay (icons), bottom overlays anchored
- [ ] ProfileScreen
  - [ ] Keep existing, update later for pixel perfection (not the current priority)
- [ ] CommentsScreen
  - [ ] Keep structure; overhaul to pixel‑match reference after Post feed is complete

---

## Development Tasks (Step‑by‑Step with Checkboxes)

### 1) Assets and Theme

- [ ] Create assets/icons/ directory
- [ ] Add SVG assets into assets/icons/ (names above)
- [ ] Update pubspec.yaml `flutter: assets:` with:
  - [ ] `- assets/images/`
  - [ ] `- assets/icons/`
- [ ] Run `flutter pub get`
- [ ] Verify SvgPicture loads sample icon in a test container

### 2) Overlay Icon Button

- [ ] Create OverlayIcon widget:
  - [ ] Size 40x40
  - [ ] Background: black with 35% opacity
  - [ ] Shape: circle
  - [ ] Child: SvgPicture.asset(iconPath, color: Colors.white, width: 20, height: 20)
- [ ] Spacing between top icons: 12 px
- [ ] Layout: Row { search (left), Spacer, volume, 12 px, menu (right) }

### 3) Bottom Caption Cluster

- [ ] Layout:
  - [ ] Row: Avatar (28–32 px) + 8 px + Column { Author (bold), Caption (wrap up to 2–3 lines) }
- [ ] Caption:
  - [ ] White 70–85% opacity
  - [ ] Line clamp to 2–3 lines, ellipsis
  - [ ] Height & spacing matching reference
- [ ] Author:
  - [ ] Bold, white 100%

### 4) Interaction Row

- [ ] Icons: like.svg, comment.svg, share.svg, save.svg via SvgPicture.asset
- [ ] Size ~18–20 px icons, white 70%
- [ ] Counters next to like and comment in 70% white
- [ ] Spacing: evenly distributed; ensure alignment with caption block

### 5) Bottom Progress Bar

- [ ] LinearProgressIndicator replacement:
  - [ ] SizedBox(height: 3), rounded corners (ClipRRect radius 999)
  - [ ] Background: white at 15%
  - [ ] ValueColor: primary red
  - [ ] Positioned above nav (approx bottom: 92)
- [ ] Wire to controller (mock with AnimationController now)
  - [ ] [Option] If using video later, map VideoPlayerController position to value

### 6) Bottom Navigation (Transparent, Locked)

- [ ] Base container:
  - [ ] Height: 56 px, margin horizontal: 16, radius 28, color rgba(17, 17, 17, 0.0) (transparent)
- [ ] Left icon: home.svg (white)
- [ ] Right icon: profile.svg (white)
- [ ] Center FAB:
  - [ ] Positioned absolute top: -18
  - [ ] Outer size 64x64 (transparent, for hit target)
  - [ ] Inner circle 56x56, color = primary red
  - [ ] Glow shadow (black 54% blur 20, y offset 8)
  - [ ] Child: plus (Material add icon or custom SVG)
- [ ] Ensure overlay layers with Stack; the PageView does not overlap nav

### 7) PageView Behavior

- [ ] Vertical scroll, full‑screen pages, snap physics (PageScrollPhysics)
- [ ] Keep‑alive mechanism (AutomaticKeepAliveClientMixin) if needed to maintain controller states
- [ ] Dismiss keyboard on drag
- [ ] Gesture areas: tap on right toggles mute (if later video), tap on left shows/masks caption (optional)

### 8) Pixel Tuning

- [ ] Adjust paddings, radii, and icon sizes until screenshots closely match reference:
  - [ ] Top icon diameter/spacing
  - [ ] Caption font sizes/line height
  - [ ] Interaction icon sizes and spacing
  - [ ] Bottom progress bar thickness/width
  - [ ] FAB alignment relative to nav and progress bar
- [ ] Use device screenshot overlay comparison (manual) to fine‑tune

---

## SVG Integration Tasks

- [ ] Replace all Icon() usages with SvgPicture.asset() once assets are available:
  - [ ] Top overlay: search.svg, volume.svg, menu.svg
  - [ ] Interaction row: like.svg, comment.svg, share.svg, save.svg
  - [ ] Bottom nav: home.svg, profile.svg, center plus (svg or Icon to start)
- [ ] Ensure color overrides work; remove hardcoded fills if needed
- [ ] Size passes: 18–24 px per icon matching reference

---

## QA Checklist

- [ ] No overflow or clipping on small devices
- [ ] SafeArea tested (notch, status bar, gesture nav)
- [ ] Scrolling performance: 60 fps on emulator/device
- [ ] Tap targets >= 40x40
- [ ] Text truncation correct for long captions/usernames
- [ ] Bottom nav remains locked and transparent across all pages
- [ ] Accessibility pass: contrast, scalable text (min 12 sp), semantics placeholders

---

## Handover to Backend

- [ ] Extract models: Post { id, mediaUrl, author, caption, likesCount, commentsCount, isLiked, ... }
- [ ] Events: onLike, onComment, onShare, onSave, onMute
- [ ] Controllers: feed paging, media progress, mute state, FAB action
- [ ] Replace dummy data with repository layer
- [ ] Wire progress bar to real media controller

---

## Implementation Order (for Coding Agent)

1. [ ] Add assets/icons to repo; update pubspec; flutter pub get
2. [ ] Implement OverlayIcon widget (SVG)
3. [ ] Refine PostItem to exact overlay structure (top row, caption cluster, interaction row, progress)
4. [ ] Replace all Icons with SvgPicture.asset
5. [ ] Adjust BottomNav to fully transparent and ensure FAB overlaps
6. [ ] Integrate PageView physics and keep‑alive
7. [ ] Pixel tune: paddings, sizes, opacity, colors; compare screenshots
8. [ ] QA and device matrix test
9. [ ] Prepare for media progress wiring (scaffold controller)

---

## Notes

- All sizing should use logical pixels and be tested on at least two DPIs.
- Use const constructors and const widgets where possible for performance.
- Keep business logic out of UI for easy backend integration later.
