# Research and feasibility

## What was done
We searched for an existing app that saves the Space arrangement for each display setup and switches it automatically when the external display connects or disconnects. No app does all of this with System Integrity Protection (SIP) on. We then tested the private macOS APIs on macOS 27.0.1 (build 26A434, SIP on). Two private mechanisms work, so the app is possible.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `docs/01_research_and_feasibility.md` | Created | Records the market search and the API test results |

## Why it matters
macOS has no public API that moves a window to another Space or adds a Space. Apple confirmed this on the developer forums in 2026. Every tool in this area depends on private behavior. We tested that behavior on this Mac before we wrote any code. A tool that worked on macOS 15 can fail silently on macOS 27.

## Findings: existing apps

| App | Saves windows per display setup | Restores the Space of a window | Automatic on connect or disconnect | Adds or removes Spaces | Result |
|-----|-----|-----|-----|-----|-----|
| Many Displays | Yes | No. Its README says moves between Spaces need SIP off | Yes | No | Positions only |
| Stay | Yes | No | Yes | No | Positions only |
| Display Maid | Yes | No. It cannot touch windows on hidden Spaces | Yes | No | Positions only |
| Workflo, Putback | Yes | No. Workflo restores the visible Space only | Yes | No | Positions only |
| ShiftPlus | Yes | It claims a Space number for each app | No. You press a hotkey | Not stated | Manual |
| Ikuna | Yes | No. "Does not reorder or assign macOS Spaces" | No | No | Manual |
| Display Spaces Manager | Spaces only | Partly | Partly | Yes | Abandoned (2015), users report errors |
| yabai 7.1.25 | No profiles (you write scripts) | Yes, with SIP on since May 2026 | Yes (display signals) | Only with SIP partly off | Closest, but needs scripts and SIP changes |
| Hammerspoon `hs.spaces` | No profiles (you write Lua) | No. `moveWindowToSpace` uses the old blocked call | Yes (screen watcher) | Yes (Mission Control) | Partial |

## Findings: private APIs on macOS 27.0.1 (SIP on)

| Operation | API | Result |
|-----------|-----|--------|
| Read Spaces of each display | `SLSCopyManagedDisplaySpaces` | Works |
| Read the Space of a window | `SLSCopySpacesForWindows` | Works |
| List the windows on a hidden Space | `SLSCopyWindowsWithOptionsAndTags` and the window iterator | Works |
| Move another app's window (old call) | `SLSMoveWindowsToManagedSpace` | Fails silently since macOS 14.5 |
| Move another app's window (new call) | `SLSBridgedMoveWindowsToManagedSpaceOperation` sent with the hidden function `SLSPerformAsynchronousBridgedWindowManagementOperation` | Works. We moved a TextEdit window from Space 1 to Space 4 and back |
| Add a Space | Mission Control "Add Desktop" button through Accessibility | Works. Top-down search of the Mission Control tree gives no children on macOS 27, so a hit test at the top of the display must find the Spaces bar |
| Remove a Space | Mission Control `AXRemoveDesktop` action | Works |
| Set a window frame on a hidden Space | Accessibility `AXPosition` and `AXSize` | Works |

The hidden move function is not exported. We find it in the SkyLight symbol table in memory, as yabai does. A macOS update can remove it. If it is missing, the app reports this and does not move windows.

## Conclusion
The requirement is possible on macOS 27 without changes to SIP. Three limits stay:
- A switch that adds or removes Spaces opens Mission Control for about one second.
- Full-screen app Spaces, minimized windows, and windows on all desktops are not moved.
- After a reboot or an app restart, window IDs change. The app then matches windows by app and title, then by app and creation order. Apps with many similar windows (for example, several browser windows) can be matched incorrectly.

## Sources
- Many Displays README: https://github.com/manydisplays/manydisplays
- yabai changelog 7.1.25 (moves work with SIP on again): https://github.com/asmvik/yabai/blob/master/CHANGELOG.md
- Apple Developer Forums, private Spaces APIs on macOS 27: https://developer.apple.com/forums/thread/830748
- Stay documentation: https://cordlessdog.com/stay/documentation/restoring-windows
- Amethyst discussion on Space moves after macOS 15: https://github.com/ianyh/Amethyst/discussions/1682
- Hammerspoon `hs.spaces`: https://www.hammerspoon.org/docs/hs.spaces.html
- ShiftPlus: https://shiftplus.app/blog/mac-windows-rearrange-external-monitor/
- Workflo: https://getworkflo.app/mac-windows-rearrange-external-monitor
- Ikuna: https://ikuna.app/guides/stop-macos-rearranging-spaces-restore-after-restart
- Display Spaces Manager thread: https://discuss.binaryage.com/t/reboot-causes-number-of-spaces-to-converge-on-monitor-1/1343?page=2
