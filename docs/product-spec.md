# SmallLight Product Specification

## Overview
SmallLight is a resident macOS utility that listens to the user's cursor position and provides keyboard-gated compression and decompression actions for Finder items. The app delivers a light-themed immersive cursor experience while preserving safe and reversible file operations.

## Goals
- Offer frictionless zip compression/decompression of Finder items under the cursor when the user presents a designated modifier key chord.
- Provide immediate, visually rich feedback that communicates when actions are armed, executed, or cancelled.
- Ensure operations are safe, reversible, and auditable for user trust.

## Non-Goals
- General-purpose archive management outside Finder context.
- Support for archive formats other than `.zip` in the initial release.
- Automation of file operations without explicit modifier-key intent.

## Target Environment
- macOS 13 Ventura and later.
- Runs as a menu-bar style background application registered as a LaunchAgent for auto-start.
- Integrates with Finder through accessibility APIs and Core Graphics events.

## Personas & User Stories
- **Creative Professional**: Needs quick packaging of project folders without breaking flow.
  - *Story*: While holding the configured modifier keys, hovering over a project folder compresses it to `<folder>.zip` and confirms success with cursor glow and notification.
- **QA Engineer**: Frequently inspects zip builds; wants immediate extraction.
  - *Story*: Holding the modifier keys over a zip archive triggers decompression into a sibling folder, logging the action for audit.
- **Power User**: Customizes cursor visuals.
  - *Story*: Chooses a custom light asset pack, sees the cursor swap when SmallLight is listening, and the glow animation when an action triggers.

## Functional Requirements
- The app detects Finder item metadata under the current cursor when the modifier chord is pressed.
- Compression: When hovering a folder, create `<folder>.zip` in the same directory, skipping if a file with the same name exists and prompting via notification.
- Decompression: When hovering over a `.zip`, extract to `<zip-name>/` sibling directory, preserving existing files by prompting and staging.
- Cursor Feedback: Replace the cursor with a light asset when the app is active; animate glow when modifier chord is engaged; display action status (armed, executing, completed, cancelled).
- Keyboard Shortcut: Provide a configurable global shortcut with default (e.g., `⌥⇧Space`), requiring user confirmation for activation.
- Safety Gate: No file operations without the modifier chord pressed; show confirmation toast on the first run for each path.
- Undo: Place original artifacts into `~/Library/Application Support/SmallLight/staging` before moving the final output; allow restoration within a time window.
- Audit Log: Append JSON or NDJSON entries to `~/Library/Application Support/SmallLight/logs/actions.log` with timestamp, path, action type, result.
- Preferences UI: Offer settings pane for modifier key selection, cursor asset pack selection, undo window duration, log viewing, and launch at login toggle.
- Localization: Provide base English strings with hooks for Japanese localization.

## Non-Functional Requirements
- File operations must complete within reasonable time (e.g., < 1s for <500MB assets where possible).
- Always perform operations atomically to avoid partial archives.
- Respect macOS sandboxing and privacy prompts; guide the user through required permissions.
- Minimize CPU and memory footprint when idle; only activate watchers when necessary.
- Ensure accessibility compliance: fallback indicators for visually impaired users (e.g., menu icon state).

## UX & Visual Design Considerations
- Provide a macOS menu bar icon indicating idle/listening/error states.
- Cursor visual assets default to a light source motif; allow user-supplied asset packs stored under `~/Library/Application Support/SmallLight/Assets`.
- Toast notifications summarize actions and offer quick undo button.
- First-time setup wizard guides through permissions and explains modifier key usage.

## Security & Privacy
- Request and store only necessary permissions (Accessibility, Full Disk Access if required).
- Persist user preferences with `UserDefaults`, encrypting sensitive data if added later.
- Do not transmit user data off-device; log files remain local.

## Dependencies & Integrations
- SwiftUI + AppKit bridging for UI.
- `Compression` framework for zip handling.
- Core Graphics / Accessibility APIs for cursor position and Finder info.
- Launch Services for registering at login.

## Acceptance Criteria
1. Modifier chord + hover over folder results in `.zip` creation, visual confirmation, undo available, audit entry logged.
2. Modifier chord + hover over `.zip` extracts contents, original archive staged, undo available, audit entry logged.
3. Cursor visuals respond to app states, including active listening and action execution.
4. Preferences pane allows customizing shortcut and asset pack, persisting across restarts.
5. Automated tests exist covering micro, integration, and system layers, all passing under CI.

## Open Questions
- Should we support multi-file selection when Finder selection differs from cursor target?
- How do we reconcile Finder context detection when multiple windows overlap?
- What is the default undo retention window?
