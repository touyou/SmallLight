# SmallLight Implementation Plan

## Overview
This plan outlines the phased delivery of SmallLight, ensuring compliance with the product specification and t_wada-aligned testing principles. Work proceeds outside-in, starting with executable acceptance criteria and iterating through red → green → refactor loops.

## Phase 0: Project Bootstrap
- Initialize Swift Package Manager project `SmallLight` with app target and test targets (`SmallLightTests`, `SmallLightUITests`).
- Configure `swift-format` and `swiftlint` in the repository; add baseline configurations.
- Set up CI workflow (GitHub Actions or Azure DevOps) running `swift test` and `xcodebuild test -scheme SmallLight`.
- Create initial documentation structure in `docs/` (already in place), verify contribution guidelines from `AGENTS.md`.

## Phase 1: Domain Modeling & Core Services
1. **Acceptance Criteria Definition**
   - Write system-level XCTest describing the compression flow triggered by synthetic cursor positioning and modifier simulation.
   - Draft integration test stubs for Finder metadata retrieval using fakes.
2. **Domain Modules**
   - `FinderTargetingService`: determines Finder item under cursor via Accessibility API; expose pure protocol for mocking.
   - `CompressionService`: handles zip compress/decompress using `Compression` framework; ensure idempotency and staging logic.
   - `ActionOrchestrator`: coordinates modifier chord detection, target evaluation, operation execution, logging, undo staging.
3. **Testing**
   - Micro tests for staging path calculations, naming conflict resolution, undo restoration.
   - Integration tests using temporary directories for compression/decompression (isolated via `FileManager` mocks or temporary URLs).

## Phase 2: Input Handling & Safety Gates
1. **Global Shortcut Implementation**
   - Introduce `HotKeyManager` built on Carbon Event Hot Keys; provide wrapper for configurability and testing.
   - Acceptance test covering modifier chord activation gating operations.
2. **Safety Mechanisms**
   - Implement dry-run preview prompting via `NSUserNotification` or `UserNotifications` framework for first-time path actions.
   - Add undo staging manager storing originals to `~/Library/Application Support/SmallLight/staging` with TTL configuration.
   - Write integration tests to confirm staging contents and cleanup policy.

## Phase 3: UI & Feedback Loop
1. **Menu Bar App Skeleton**
   - Build SwiftUI-based status bar interface showing state (idle/listening/error) and shortcuts to preferences/logs.
   - Micro tests verifying view model state transitions.
2. **Cursor Visualization**
   - Implement cursor asset loader supporting default and custom packs; rely on Core Graphics to swap cursor image.
   - Animate glow (Core Animation) when modifier chord engaged.
   - Add snapshot/UI tests (where feasible) or instrumentation tests verifying state flags driving visuals.
3. **Notifications & Toasts**
   - Provide action result notifications with undo button invoking staging restore.
   - Test via integration tests ensuring undo reinstates original artifacts and logs entry.

## Phase 4: Preferences & Persistence
1. **Preferences Window**
   - Build SwiftUI settings panes: shortcut picker, asset pack selector, undo retention slider, launch-at-login toggle, log viewer.
   - Persist settings with `UserDefaults` / `AppStorage`; supply protocols for testing.
2. **LaunchAgent Integration**
   - Add helper for registering/unregistering LaunchAgent plist; include manual verification checklist.
   - Provide integration tests (where possible) or scripted validation for development environment.

## Phase 5: Polishing & Hardening
- Audit logging refinement: ensure NDJSON format with schema validation tests.
- Localization: add base English strings and scaffolding for Japanese.
- Performance profiling: measure idle CPU/memory, add regression tests if possible.
- Accessibility review: verify menu labels, notifications, and fallback states.

## Testing Strategy (Per Phase)
- **Micro Tests**: Pure Swift logic (naming, staging, asset selection) executed via `swift test`.
- **Integration Tests**: File-system interactions in temporary directories, hotkey manager with dependency injection, cursor manager using mocked Core Graphics wrappers.
- **System Tests**: UIAutomator-style tests using `xcodebuild test` verifying end-to-end compression and decompression flows under simulated input.
- Maintain red → green → refactor discipline; track test evidence in PR descriptions.

## Tooling & Automation Tasks
- Add Makefile or `mise` tasks for `bootstrap`, `lint`, `test` ensuring consistent developer workflow.
- Configure pre-commit hooks invoking `swift-format` and `swiftlint`.
- Integrate artifacts (logs, staging) cleanup script executed post-tests.

## Risk Mitigation
- Accessibility permission hurdles: document setup script prompting required permissions; include troubleshooting guide in `docs/`.
- Finder target ambiguity: implement fallback to Finder selection when cursor target undefined; add tests for both paths.
- Undo staging growth: schedule cleanup based on retention window; add tests ensuring size constraints enforced.

## Deliverables Checklist
- [ ] All acceptance tests documented and automated.
- [ ] Menu bar app delivers compression/decompression per spec.
- [ ] Cursor visuals and notifications validated.
- [ ] Preferences persistent and LaunchAgent optional.
- [ ] Documentation updated with operation guide, troubleshooting, and testing strategy.
