# SmallLight Operations Guide

## First-Run Checklist
- Build the app bundle via `swift build --product SmallLight` or run the `SmallLightAppHost` scheme in Xcode.
- Launch the `.app` bundle once so macOS prompts for Accessibility permissions. Approve `SmallLight` under **System Settings → Privacy & Security → Accessibility**.
- When notifications are required, launch from the app bundle (not `swift run`) and approve the notification prompt.

## Daily Usage
- Hold the configured modifier chord (default: Option) and hover Finder items to update the HUD with the resolved absolute path. The HUD keeps the latest five entries and offers a one-click copy plus `⌘C` shortcut when focused.
- When the pointer rests on a `.zip`, FinderOverlayDebugger extracts it with `/usr/bin/ditto` into a sibling directory. Existing folders trigger an `_unpacked`, `_unpacked2`, … suffix so nothing is overwritten.
- Extraction outcomes are mirrored in the HUD: success messages reference the destination folder, while failures include the ditto error so you can retry.
- Use the menu bar control or `⌃⌥ Space` to focus the HUD, `⌘⌥ H` to toggle visibility, and `⌃⌥ P` for a manual resolve that bypasses deduplication (helpful when you need to re-run against the same path).
- The hovered cursor indicator confirms the listener is active; pause or resume monitoring from the menu bar when you need to temporarily disable the overlay.

## Preferences
Open **Preferences…** from the menu bar item to configure:

| Setting | Description |
| --- | --- |
| Undo retention | Slider (1–30 days) controlling staged artifact cleanup. |
| Launch at login | Toggles a LaunchAgent under `~/Library/LaunchAgents/io.smalllight.app.plist`. |
| Cursor asset pack | Optional directory to override default cursor images (`cursor-idle.png`, `cursor-active.png`). |
| Global shortcut | Preset chords built on Space + modifier combinations. |
| Reveal Logs | Opens `~/Library/Application Support/SmallLight/logs`. |

### LaunchAgent Notes
- When running from an `.app` bundle, enabling **Launch at login** writes the LaunchAgent.
- While developing via `swift run`, the bundle path is not an `.app`; the toggle persists in preferences but does not create the LaunchAgent until run from a bundle.

## Troubleshooting
- **Cursor never glows**: ensure hotkey permission and accessibility permission are set. Check that Finder is frontmost.
- **Zip extraction failed**: the HUD will show the ditto error; after a failure the dedup cache resets so a manual resolve (`⌃⌥ P`) immediately retries. Check `~/Library/Application Support/SmallLight/logs/actions.log` for persistent issues.
- **Undo not available**: staged files expire after the configured retention period or when manually cleaned.
- **Launch at login does nothing**: verify that the app was run from the `.app` bundle so the LaunchAgent path resolves correctly.

## Testing & Maintenance
- Run `swift test` before releases; system tests cover orchestrated compression/decompression flows.
- Use the undo retention slider to verify cleanup (see `FileUndoStagingManagerTests`).
- Cursor asset overrides are cached at startup—restart SmallLight after changing the custom asset folder.
