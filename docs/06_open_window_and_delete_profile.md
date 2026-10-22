# Open the window from the menu bar, and delete a profile

## What was done
The menu bar menu has a new item, **Open Dispace**. It opens the Dispace window. The item shows in every state, also when the built-in display is off. Each profile row in the window has a new button, **Delete Profile…**. The button asks for confirmation, then removes the profile from memory and from `profiles.json`. Windows and desktops do not move.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `Sources/MenuBar.swift` | Modified | Adds the **Open Dispace** item at the end of the menu |
| `Sources/SetupWindow.swift` | Modified | Adds the **Delete Profile…** button, its state, and the confirmation alert |
| `Sources/AppDelegate.swift` | Modified | New `deleteProfile(_:)`: removes the profile and writes the file |
| `README.md` | Modified | Daily use: the new menu item and button |
| `docs/06_open_window_and_delete_profile.md` | Created | This file |

## Behavior
- **Open Dispace** calls the same function as a reopen from Raycast or Spotlight. While the window is open, Dispace has a Dock icon and a Command-Tab entry.
- **Delete Profile…** is enabled when the profile is saved and no save or switch runs. The profile does not need to be the active profile.
- The alert has two buttons: **Delete** and **Cancel**. **Delete** is marked as a destructive action.
- If Dispace cannot write `profiles.json`, the profile stays in memory and in the file. The activity log shows the error.
- After a delete, the next display change to that setup does nothing. The log shows "No … profile is saved yet."

## Tests
A test harness compiled the app sources with a different `main.swift`. It ran the real `AppDelegate`, `MenuBarController`, and window. The installed Dispace was stopped during the test. The profile file was copied before the test and restored after it.

| Check | Result |
|---|---|
| The menu ends with an enabled **Open Dispace** item | PASS |
| No Dispace window before the click. The window is visible after the click. | PASS |
| The Dock icon shows while the window is open | PASS |
| Two **Delete Profile…** buttons. Both are enabled when both profiles are saved. | PASS |
| A delete of `1-monitor` removes it from memory and from the file. `2-monitor` stays. | PASS |
| The **Delete Profile…** button of `1-monitor` is disabled after the delete | PASS |
| The log shows "Deleted the 1-monitor profile." | PASS |
| A second delete of the same profile does nothing | PASS |
| With a read-only profile folder, a delete keeps the profile in memory and in the file, and logs the error | PASS |

The harness called `deleteProfile(_:)` directly. The confirmation alert was not clicked in the test.

## Why it matters
Before this change, you opened the window from Raycast or Spotlight only. Now the menu bar icon, which is always visible, opens it in two clicks.

A deleted profile lets you start a display setup again from nothing, for example after you change your desktops a lot. Before this change, the only way was to edit or remove `profiles.json` by hand.
