# FinderOverlayDebugger Implementation Plan

## Overview
Delivery follows outside-in, test-guided iterations. Each phase concludes with runnable demos and updated specification artefacts. The plan emphasises decomposition into independently testable services (overlay, detection, HUD, automation).

## Phase 0 – Reboot & Documentation
- Replace existing spec with FinderOverlayDebugger requirements (done).
- Create this implementation plan and align with collaboration norms.
- Audit permissions needed (Accessibility) and document prompts.

## Phase 1 – Architecture & Scaffolding
1. **Domain & Settings**
   - Define immutable `AppSettings` (trigger thresholds, hotkeys, dedup TTL, HUD defaults).
   - Introduce `DeduplicationStore` with ring buffer + TTL.
   - Unit tests for dedup behaviour and settings decoding.
2. **Overlay Infrastructure**
   - Build `OverlayWindowManager` creating transparent windows per screen.
   - Add `CursorIndicatorLayer` (CALayer-backed circle).
   - Smoke tests via dependency-injected screen abstractions.

## Phase 2 – Event & Hover Detection
1. **CGEventTap Integration**
   - Implement `HoverMonitor` capturing mouse moved / flags changed events.
   - Detect held-key matches, manage dwell & debounce timers.
   - Add tests simulating event sequences (using synthetic monitors or test doubles).
2. **Global Hotkeys**
   - Build `HotKeyCenter` registering `Ctrl+Option+Space`, `Ctrl+Option+P`, `⌘⌥H`.
   - Verify callbacks fire in unit environment (Carbon stubs).

## Phase 3 – Finder Resolution & Dedup
1. **Accessibility Resolution Pipeline**
   - Implement `FinderItemResolver` using `AXUIElementCopyElementAtPosition`.
   - Fallback AppleScript to retrieve base directory when needed.
   - Unit tests for script builder and path composition logic.
2. **Trigger Orchestration**
   - Wire `HoverMonitor` → `FinderItemResolver` → `DeduplicationStore`.
   - Provide manual override path that bypasses dedup TTL.
   - Add integration tests with fake resolver/deduper.

## Phase 4 – HUD & Feedback Loop
1. **HUD Presentation**
   - Create SwiftUI HUD view & view model with history (5 entries) and copy support.
   - Auto-copy controlled via settings flag.
   - Snapshot/unit tests ensuring history management.
2. **Status & Overlay Sync**
   - Update overlay indicator position on mouse move.
   - Tie HUD visibility to toggle hotkey and focus behaviour.

## Phase 5 – ZIP Automation & Notifications
1. **ZipHandler**
   - Execute `/usr/bin/ditto` for `.zip` paths, applying suffix if conflicts exist.
   - Post results to HUD; on error, remove dedup key.
   - Integration tests using temporary directories.
2. **HUD/Notification Messaging**
   - Localise completion/error messages (English/Japanese).
   - Ensure global focus hotkey brings HUD forward.

## Phase 6 – Polishing, UX & Docs
- Accessibility prompt flow with quick link (AppKit sheet).
- HUD/hotkey instructions in operations guide; update troubleshooting.
- Performance check: ensure event tap and overlay idle CPU usage is minimal.
- final localisation review & comment documentation on critical classes.

## Testing Strategy
- **Unit**: Dedup store, settings parsing, AppleScript builder, history view model.
- **Integration**: Hover orchestration with fake resolver, ZipHandler with temp directories, hotkey invocations via Carbon stubs.
- **Manual**: Accessibility prompt, overlay alignment on multiple displays, Finder path resolution accuracy.
- Continuous `swift test` and (future) UI screenshot evaluations.

## Tooling / Automation
- Maintain `swift-format` & `swiftlint`.
- Extend `mise` tasks (`test`, `lint`, `package`) to cover new modules.
- Prepare manual QA checklist (permissions, multi-display, zip handling).

## Deliverables Checklist
- [ ] Overlay manager renders indicator on every display.
- [ ] Hover dwell detection triggers HUD updates with accurate paths.
- [ ] Hotkeys operational (`focus`, `manual resolve`, `toggle HUD`).
- [ ] ZIP auto-extraction works with dedup/notifications.
- [ ] Documentation (product spec, operations guide) reflects new workflow.
