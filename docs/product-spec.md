# FinderOverlayDebugger Product Specification

## Overview
FinderOverlayDebugger (開発コード: SmallLight) is a resident macOS 13+ utility that brings debugger-style insight to Finder interactions. A lightweight indicator tracks the cursor at all times; while a modifier key is held, the app switches to listening mode, resolves the underlying Finder item, and presents a HUD showing the resolved path with quick-copy affordances. When the hovered target is a `.zip`, FinderOverlayDebugger optionally unarchives it automatically and logs the outcome.

## Goals
- Provide an always-on transparent overlay that does not interfere with normal interaction (click-through, all Spaces) and surfaces idle vs listening cursor states.
- Detect Finder items under the cursor without clicks, using dwell detection gated by a configurable held key.
- Resolve absolute file paths reliably and surface them in a toggleable HUD (default top-left) with copy and history controls.
- Offer optional automatic unzip behaviour for ZIP files with user-configurable behaviour.
- Deliver debugging feedback quickly while preventing duplicate triggers through short-term deduplication.

## Non-Goals
- Managing archives beyond `.zip` format.
- Performing path resolution outside Finder UI surfaces.
- Running inside a sandbox or App Store-compliant environment.

## Target Environment
- macOS Ventura (13) or later.
- Runs as a background utility with transparent overlay windows per display.
- Requires Accessibility permission; does not require Screen Recording or Input Monitoring.

## Personas & Key Scenarios
- **Build Engineer** – Needs to quickly inspect generated artifacts. *Scenario:* Hold Option, hover a build output inside Finder, see the full path HUD, copy it instantly.
- **QA Specialist** – Frequently verifies zipped deliverables. *Scenario:* Hover a ZIP for 200 ms; the app auto-unpacks next to the archive and notes completion in the HUD.
- **Support Analyst** – Captures Finder item paths for bug reports. *Scenario:* Trigger manual resolve hotkey (`Ctrl+Option+P`) to re-run detection even after dedup filters.

## Functional Requirements
### Overlay Window
- Maintain one transparent NSWindow per NSScreen.
- `isOpaque = false`, `backgroundColor = clear`, `ignoresMouseEvents = true`, `level = .screenSaver`.
- `collectionBehavior` includes `.canJoinAllSpaces`, `.fullScreenAuxiliary`.
- Hosts a cursor indicator view (16pt circle, system label colour).

### Cursor Tracking & Hover Trigger
- Install a listen-only CGEventTap for mouse moved / flags changed events.
- Track current cursor location and modifier flags, updating the indicator in idle (modifier up) and listening (modifier down) states.
- Dwell processing is activated only when the configured held key (`Option` default; configurable) is down.
- Dwell detection parameters: `dwell_ms = 200`, `debounce_ms = 80`.
- Only trigger when the hovered element belongs to Finder UI (`filter = only_on_finder_ui`).

### Path Resolution
- Perform AX hit-testing at the cursor location to obtain the Finder UI element.
- Extract filename via `kAXFilenameAttribute`. When base directory cannot be deduced, fall back to AppleScript to retrieve the front Finder window’s target (`useFrontWindowTarget`).
- Combine directory and filename into an absolute POSIX path.

### Debug HUD
- Present a SwiftUI HUD anchored top-left by default and hidden until toggled via menu or hotkey.
- Shows latest resolved path as monospaced text, includes Copy button and keyboard shortcut (`⌘C`).
- Maintain history of the last five entries.
- Configurable automatic copy-to-clipboard.
- When additional context is available (e.g. zip extraction result), surface a secondary message line alongside the stored path.

### Global Hotkeys
- `Ctrl+Option+Space`: bring app to front and focus HUD.
- `Ctrl+Option+P`: manual resolve override (ignores dedup TTL and re-runs Finder resolution at the current cursor position).
- `Command+Option+H`: toggle HUD visibility.
- Register via Carbon Event Hot Keys; display accessibility prompt if permissions missing.

### Accessibility Prompt
- On launch, if `AXIsProcessTrusted` is false, present an instructional sheet: “システム設定 > プライバシーとセキュリティ > アクセシビリティ で本アプリを許可してください。” Provide quick-link button opening System Settings.

### Deduplication Log
- Maintain in-memory ring buffer (size 256) keyed by `hash(path + action)`.
- TTL per entry: 3000 ms. Dwell triggers for the same key within TTL are ignored.
- Manual override hotkey bypasses dedup check (but still re-enqueues fresh TTL entry).
- Remove dedup key on action error (e.g., unzip failure) so the user can retry immediately.

### ZIP Handler
- When hovered path ends with `.zip`:
  - Determine extraction destination in the same directory.
  - If conflicting folder exists, append `_unpacked`.
  - Execute `/usr/bin/ditto -x -k {zipPath} {destinationDir}`.
  - Behaviour modes: `auto` (default) vs `prompt` (future preferences).
  - On success, append HUD history entry “解凍完了: {destinationPath}”.
  - On failure, HUD: “解凍に失敗しました: {error}”; dedup key removed to allow retry.

## Settings Defaults
- Trigger: held key Option; dwell 200 ms; debounce 80 ms.
- Hotkeys: focus app `Ctrl+Option+Space`, manual resolve `Ctrl+Option+P`, toggle HUD `Cmd+Option+H`.
- HUD: auto copy disabled by default; history size 5.
- Dedup TTL: 3000 ms.
- ZIP behaviour: auto; destination same directory.

## Security & Permissions
- Requires Accessibility permission for hit testing.
- No Screen Recording or Input Monitoring usage.
- Operates outside the App Sandbox; App Store distribution not supported.

## Performance & Reliability
- Keep CGEventTap in listen-only mode to minimise latency.
- Overlay & HUD updates must stay below 16 ms to maintain responsiveness.
- Zip decompression executed asynchronously to avoid UI blocking.

## Success Metrics / Acceptance Criteria
1. Holding the configured key and dwelling over Finder items presents the overlay indicator and resolves to the correct absolute path, shown in HUD and copyable.
2. Hovering over `.zip` auto-unpacks to the correct destination and notifies the HUD.
3. Dedup prevents repeated HUD/log updates when hovering repeatedly over the same item within TTL, but manual override re-triggers successfully.
4. HUD history stores the latest five entries and allows copy via button or `⌘C`.
5. Application prompts for accessibility permission when unavailable and recovers once granted.
