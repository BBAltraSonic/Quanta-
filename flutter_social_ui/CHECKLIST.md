# Production Readiness Checklist

## Phase 1: Planning and Setup
- [x] 1. Confirm and finalize the specification (SPEC.md created)
- [x] 2. Create and commit living checklist (CHECKLIST.md)
- [ ] 3. Baseline branch and CI prep
- [x] 4. Codebase inventory of mock, fake, and demo artifacts (INVENTORY.md created)
- [ ] 5. Map data flow and dependency injection bindings
- [ ] 6. Lock production configuration defaults and flavors

## Phase 2: Code Cleanup
- [ ] 7. Eliminate repository/data-source level mock implementations from app code
- [ ] 8. Remove HTTP client stubs and fake interceptors
- [ ] 9. Purge seeding and fixture-based local storage
- [ ] 10. Remove UI-level demo fallbacks and placeholder models
- [ ] 11. Define and implement production-grade empty and error states
- [ ] 12. Align models/DTOs with production API schemas

## Phase 3: Feature and Asset Cleanup
- [ ] 13. Remove demo feature flags and remote toggles
- [ ] 14. Sanitize authentication and session flows
- [ ] 15. Realtime features: remove local simulators
- [ ] 16. Assets and pubspec cleanup
- [ ] 17. Logging, debug menus, and overlays

## Phase 4: Testing and Quality Assurance
- [ ] 18. Refactor tests to isolate mocks to test-only
- [ ] 19. Add static guardrails: banned terms scan and lints
- [ ] 20. Manual QA validation matrix
- [ ] 21. Performance and stability check on production endpoints

## Phase 5: Release Preparation
- [ ] 22. Release build, device verification, and store readiness
- [ ] 23. Documentation and traceability delivery

## Progress Tracking
- **Started**: [Date]
- **Current Phase**: Phase 1
- **Estimated Completion**: TBD
- **Issues Found**: 0
- **Blockers**: None

## Links to Work
(Will be updated as PRs and commits are made)

## Notes
- Each completed task should be marked with [x] and include a link to the relevant PR/commit
- Any blockers or issues should be documented in the Progress Tracking section
- This file serves as the single source of truth for project progress
