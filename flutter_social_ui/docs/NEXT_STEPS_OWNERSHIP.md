# Ownership System: Next Steps Report

This report outlines the prioritized actions to fully enforce and operationalize the new ownership-based UI and logic system across the app.

Last updated: 2025-08-15

---

## Priority 1 — Enforce ownership in all services
Purpose: Ensure no unauthorized backend calls can slip through.

Actions:
- Wire OwnershipGuardService into service methods that mutate or expose owner-only data.
  - lib/services/enhanced_feeds_service.dart
    - Guard before allowing: delete/edit post, add/delete comment, pin/unpin, upload media, view private analytics, toggle follow (prevent self-follow), report (prevent self-report).
    - Call guard methods first, then proceed with Supabase/RPC actions.
  - lib/services/profile_service.dart
    - Guard profile edits, settings updates, private analytics pulls.
  - lib/services/follow_service.dart and lib/services/comment_service.dart (or equivalent)
    - Guard follow/unfollow (no self-follow); guard comment edits/deletes to owner only.

Checklist:
- [ ] All owner-only mutations call OwnershipGuardService first
- [ ] Self-actions (self-follow, self-report, self-block) are rejected
- [ ] Private analytics endpoints are owner-gated

---

## Priority 2 — Replace ad-hoc checks in UI with ownership-aware widgets
Purpose: Consistent UX across app and prevent drift.

Actions:
- Replace manual “is my profile/post” logic with:
  - OwnershipAwareWidget
  - OwnershipActionButtons
  - OwnershipVisibility

Targets:
- lib/screens/profile_screen.dart
  - Remove _isOwnProfile and follow-state duplication; use OwnershipActionButtons and OwnershipVisibility.
- lib/screens/post_detail_screen.dart (or equivalent)
  - Show edit/delete for owner, follow/report for others; restrict comment controls accordingly.
- lib/screens/feeds_screen.dart and any list/grid item widgets
  - Replace action bars with OwnershipActionButtons.
- lib/screens/comments_screen.dart or comment widgets
  - Use OwnershipVisibility for edit/delete on own comments.
- lib/screens/avatar_management_screen.dart
  - Owner-only controls guarded/displayed via OwnershipVisibility.
- Settings/analytics screens
  - Use OwnershipGuardService to protect entry and OwnershipVisibility to control access.

Checklist:
- [ ] No direct id == currentUserId checks in widgets
- [ ] All action bars use OwnershipActionButtons
- [ ] Owner-only UI hidden/disabled for non-owners

---

## Priority 3 — Centralize navigation and action menus
Purpose: Eliminate duplicate logic in menus and app bars.

Actions:
- Update common PopupMenuButton menus to build items via ownership state:
  - Use stateAdapter.canEdit/canDelete/canFollow/canReport
  - Ensure report/block entries never show for self

Checklist:
- [ ] All three-dot menus use ownership-aware predicates
- [ ] No self-report/block options surface

---

## Priority 4 — Test, lint, and fix
Purpose: Reach 95%+ confidence.

Commands:
- flutter analyze
- flutter test test/ownership_integration_test.dart
- flutter test

Fix policy:
- Any failing tests indicate missing guard or UI not swapped to ownership-aware components—fix and re-run.

Checklist:
- [ ] All tests passing locally
- [ ] flutter analyze shows no new issues
- [ ] Optional: CI runs tests on PRs

---

## Priority 5 — Documentation and consistency
Purpose: Team reliability and future-proofing.

Actions:
- Link docs/OWNERSHIP_SYSTEM_GUIDE.md from README or docs index
- Extend docs/DATA_CONSISTENCY_RULES.md with a mandatory review checklist:
  - “All sensitive actions must call OwnershipGuardService before backend calls.”
  - “UI must use OwnershipActionButtons/OwnershipVisibility; ad-hoc ‘is mine’ checks are forbidden.”

Checklist:
- [ ] Documentation linked and reviewed
- [ ] Review checklist enforced in code reviews

---

## Optional performance polish

- Cache warming on login:
  - Call OwnershipManager.warmOwnershipCache()
  - Prefetch current user’s avatars/posts into the state cache via StateServiceAdapter.warmCacheFromService()

---

## Ready-made files to reference

- Ownership utilities: lib/utils/ownership_manager.dart
- State adapter ownership API: lib/store/state_service_adapter.dart
- Ownership-aware widgets: lib/widgets/ownership_aware_widgets.dart
- Guard service (security layer): lib/services/ownership_guard_service.dart
- Example profile screen: lib/examples/ownership_aware_profile_screen.dart
- Integration tests: test/ownership_integration_test.dart
- Guide: docs/OWNERSHIP_SYSTEM_GUIDE.md

---

## Suggested Implementation Order (per file)

1) Services (security first)
- enhanced_feeds_service.dart
- profile_service.dart
- follow_service.dart, comment_service.dart (or equivalents)

2) High-traffic UI
- feeds_screen.dart (cards/list items)
- post_detail_screen.dart

3) Profile-related UI
- profile_screen.dart
- avatar_management_screen.dart

4) Comments UI
- comment widgets / comments screen

5) Settings/analytics
- settings and analytics screens

---

## Done Definition

- [ ] All owner-only paths guarded in services (OwnershipGuardService)
- [ ] UI uses ownership-aware widgets exclusively
- [ ] No self-action exploits (self-follow, self-report, self-block)
- [ ] Tests green and analysis clean
- [ ] Docs updated; code review checklist enforced

