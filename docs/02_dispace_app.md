# Dispace app

## What was done
We built Dispace, a small AppKit app in Swift. It keeps two profiles: "1-monitor" (built-in display only) and "2-monitor" (built-in display and one external display). A profile records the number of desktops on each display, the desktop of each window, and the window frame. When the display setup changes, Dispace applies the profile of the new setup. You open its window from Raycast, and the window comes to the front. While the window is open, Dispace shows a Dock icon and a Command-Tab entry. When you close the window, they go away and Dispace continues in the background. A menu bar icon is always visible. Its menu shows the active profile and a "Save Current Arrangement" item.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `Sources/main.swift` | Created | Entry point |
| `Sources/AppDelegate.swift` | Created | Life cycle, display change detection, login item, window actions |
| `Sources/SetupWindow.swift` | Created | The setup window: status, profiles, options, recent activity |
| `Sources/MenuBar.swift` | Created | Menu bar icon. Its menu shows the active profile and a Save item |
| `Sources/SkyLight.swift` | Created | Private SkyLight calls: read Spaces, list windows on a Space, move windows |
| `Sources/MissionControl.swift` | Created | Adds and removes desktops through Mission Control and Accessibility |
| `Sources/WindowAX.swift` | Created | Accessibility helpers: find a window element, read its title, set its frame |
| `Sources/Profiles.swift` | Created | Data model, capture of the current arrangement, window matching, JSON storage |
| `Sources/Switcher.swift` | Created | Applies a profile in three steps |
| `Sources/Log.swift` | Created | Recent activity for the window and `~/Library/Logs/Dispace.log` |
| `Resources/Info.plist` | Created | Bundle settings. Dispace launches as a regular app, so macOS brings its window to the front |
| `Icon/make_icon.swift` | Created | Draws the logo at all icon sizes |
| `Icon/logo-1024.png` | Created | The logo at 1024 × 1024 pixels |

## Why it matters
With "Displays have separate Spaces" on, macOS merges the desktops of a disconnected display into the built-in display and shuffles windows. Dispace puts each window back on its desktop for the new setup, so each display keeps separate desktops for work and for entertainment.

## How a switch works
1. The display callback (`CGDisplayRegisterReconfigurationCallback`) fires several times. Dispace waits until the displays are stable for 2.5 seconds.
2. Dispace selects the profile from the display types: built-in only gives "1-monitor", built-in and external gives "2-monitor". With the lid closed, no profile applies. A wake from sleep with the same setup does nothing.
3. If a display has fewer desktops than the profile, Dispace adds desktops in Mission Control.
4. Dispace matches saved windows to open windows. The rules depend on whether the app restarted after the save ([`05_window_matching.md`](05_window_matching.md)). It moves each window to its desktop and sets its frame. It reads the result back and tries once more. A second pass after 2 seconds corrects windows that macOS moved late.
5. Dispace removes extra desktops at the end of each display if they are empty and not visible.

Profiles are in `~/Library/Application Support/Dispace/profiles.json`. Desktops are stored by position (1, 2, 3 …), not by Space ID, because macOS creates new Space IDs when a display reconnects.

## Resource use
Dispace uses no timers and no polling. It wakes only for display changes and for clicks in its window or its menu. The menu reads the state when it opens. Measured on this Mac with the window closed: 0.0 % CPU, no idle wakeups in 25 seconds, about 30 MB memory footprint. The app bundle is 1.2 MB.

## Login launch
At login, Dispace changes to a background app before it finishes launching. It shows only the menu bar icon. Dispace detects the login launch from the "launched as login item" flag of the launch event. This detection was not tested with a real login. If it fails, the window and the Dock icon appear at login. Close the window to hide them.

## Known limits
- Dispace does not move full-screen app Spaces, minimized windows, hidden apps, or windows on all desktops.
- Dispace does not open apps that are closed. It leaves new windows (not in the profile) where macOS puts them.
- Turn off "Automatically rearrange Spaces based on most recent use". This setting changes the order of desktops, and profiles store desktops by position.
- Tests ran on the built-in display only. "Save Current Arrangement" and "Apply Now" in the installed app put two TextEdit windows back on their desktop and frame. A test harness also checked the addition and removal of desktops.
- A move to a desktop of another display was not tested, because no external display was connected during the build. Dispace sets the frame after the move to put the window on the correct display.
- Dispace uses only the first external display. With two external displays, the second one is ignored.
- A macOS update can remove the private functions. Dispace then shows a warning in its window and does not move windows.
