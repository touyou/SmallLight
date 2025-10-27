# AGENTS

## Mission
- Deliver a resident macOS utility (code name: SmallLight) that reacts to the user's cursor position.
- Provide keyboard-gated compress/decompress actions targeting Finder items under the cursor.
- Offer an immersive light-themed cursor experience with customizable assets.

## North Star Use Cases
- When the app is active and the user holds the designated modifier keys, pointing at a Finder folder triggers zip compression.
- Hovering over a zip archive with the same modifier keys reverses the action via decompression.
- Visual feedback (cursor swap, glow animation) communicates when the app listens for actions.

## Technical Direction
- **Language & UI:** Swift with SwiftUI for configuration UI and AppKit bridging for system integration.
- **Runtime Footprint:** Menu-bar style agent or background app bundled as a LaunchAgent for autorun.
- **Cursor Effects:** Leverage Core Graphics + Core Animation; allow asset overrides via user preferences.
- **File Operations:** Use `Compression` framework and `FileManager`; ensure idempotent operations and safe error handling.
- **Hotkeys:** Implement a configurable global shortcut using `Carbon` Event Hot Keys or `MASShortcut`-style abstraction.
- **Settings:** Persist preferences with `UserDefaults` or `AppStorage`; offer an opt-in icon pack folder.

## Safeguards & UX Expectations
- No file operation occurs unless the modifier sequence is pressed.
- Dry-run preview and confirmation toast for first-time use on a path.
- Maintain an audit log (path, timestamp, action) under `~/Library/Application Support/SmallLight/logs` for traceability.
- Provide undo by moving original artifacts into a temporary staging directory before committing changes.

## Development Workflow
1. Slice work via user stories anchored in the use cases above.
2. Describe the scenario as executable acceptance criteria (XCTest UI test or integration test) before coding.
3. Iterate with tight outside-in TDD loops: red → green → refactor.
4. Document decisions in `docs/` (architecture notes, cursor asset specs, keyboard defaults).

## Testing Principles (t_wada-aligned)
- Treat tests as first-class design artifacts; write them before production code to drive architecture.
- Keep test cycles fast and deterministic; isolate filesystem side effects with temporary directories and fakes.
- Avoid over-mocking—prefer state verification and meaningful domain language in test names.
- Cover three layers: micro tests (pure logic), integration tests (Finder interaction abstractions), and system smoke (end-to-end automation via `xcodebuild test`).
- Enforce "One expectation per concept"; make failure messages actionable.
- Make tests readable: arrange-act-assert structure, fixture builders, and clear Japanese/English hybrid naming when valuable.

## Tooling & Automation
- Bootstrap with Swift Package Manager; add an Xcode project only if GUI tooling requires it.
- Use `swift test` / `xcodebuild test -scheme SmallLight` in CI; gate merges on green builds.
- Configure `swift-format` and `swiftlint` (or equivalent) to maintain consistent style.

## Definition of Done
- Scenario specs and micro tests are green locally and on CI.
- User-facing behavior recorded as a short Loom/GIF for documentation.
- Updated `IDEA.md` or dedicated design doc when introducing new capabilities.
- All new assets include licensing + usage notes.

## Collaboration Norms
- Work in topic branches named `feature/<story>` or `chore/<task>`.
- Submit small, reviewable PRs with test evidence and manual validation notes.
- Tag follow-up work as TODOs with owner + link to tracking issue; avoid silent scope creep.
