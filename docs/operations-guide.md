# SmallLight Operations Guide

## First-Run Checklist
- Build the app bundle via `swift build --product SmallLight` or run the `SmallLightAppHost` scheme in Xcode.
- Launch the `.app` bundle once so macOS prompts for Accessibility permissions. Approve `SmallLight` under **System Settings → Privacy & Security → Accessibility**.
- When notifications are required, launch from the app bundle (not `swift run`) and approve the notification prompt.

## Daily Usage
- Hold the configured modifier chord (default: ⌃⌥ L) and hover Finder items:
  - Folders compress to `<name>.zip`.
  - Zip archives decompress into sibling directories.
- Use the menu bar's **Pause/Resume Monitoring** button to temporarily disable or re-enable SmallLight without quitting the app.
- The cursor glow indicates SmallLight is listening. Menu bar status reflects readiness or errors.
- Confirmation notifications appear on first use of a path. Accept them from Notification Center or the SmallLight menu.
- After each action, the notification includes an **Undo** button; the same path is available in the menu UI.

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
- **Compression failed**: inspect `~/Library/Application Support/SmallLight/logs/actions.log` for entries with `compressionFailed` or `decompressionFailed` reasons.
- **Undo not available**: staged files expire after the configured retention period or when manually cleaned.
- **Launch at login does nothing**: verify that the app was run from the `.app` bundle so the LaunchAgent path resolves correctly.

## Testing & Maintenance
- Run `swift test` before releases; system tests cover orchestrated compression/decompression flows.
- Use the undo retention slider to verify cleanup (see `FileUndoStagingManagerTests`).
- Cursor asset overrides are cached at startup—restart SmallLight after changing the custom asset folder.
