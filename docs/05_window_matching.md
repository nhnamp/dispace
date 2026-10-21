# Window matching after logout and restart

## What was done
The matcher now selects its rules for each app from the launch date of the app. If the app runs since the save, a saved window pairs only with the live window that has the same window ID. If the app started after the save, the matcher ignores window IDs. It pairs by title first, then by order of creation. This change removes two wrong moves. A new window no longer takes the place of a closed window. An old window ID that WindowServer gives to a different window no longer causes a wrong pair.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `Sources/Profiles.swift` | Modified | `Matcher.match` takes `savedAt` and selects the rules for each app. New `Matcher.startedAfter` reads `NSRunningApplication.launchDate`, or the process start time from `sysctl` when macOS gives no launch date. |
| `Sources/Switcher.swift` | Modified | Gives `profile.savedAt` to `Matcher.match` |
| `README.md` | Modified | Known limits: closed windows and login |
| `docs/02_dispace_app.md` | Modified | Step 4 of a switch refers to this file |
| `docs/05_window_matching.md` | Created | This file |

## The rules
A profile stores each window with its window ID, app, title, desktop, and frame. A window ID is valid only while the app runs. When the app quits, macOS destroys all its windows. When the app starts again, its windows get new IDs.

| App state at the display change | Window IDs | Rules |
|---|---|---|
| Runs since the save (`launchDate <= savedAt`) | Valid | Same window ID only. A saved window without a pair was closed, minimized, or put in full screen. Dispace does not give its place to another window. |
| Started after the save (`launchDate > savedAt`) | Not valid. WindowServer can give an old number to a different window. | 1. Same title. 2. The next free window of the app, in order of creation. |

An app with more than one running instance counts as "started after the save" only if all instances started after the save.

macOS gives no `launchDate` for Finder. On the test Mac, Finder was the only regular app without one. For such an app, Dispace reads the process start time from the kernel (`sysctl` with `KERN_PROC_PID`). Boot time is not a correct substitute: a logout starts Finder again without a reboot. On the test Mac, the boot was on 5 October and Finder started on 18 October, at the last login. If both values are missing, the app counts as "runs since the save", and Dispace uses window IDs and does not guess.

A live window without a pair does not move.

## Logout, restart, and app restart
All three cases give the same state: each app starts after the save, and each saved window ID is not valid. The matcher does not need to know which case occurred.

- **Logout or restart with "Reopen windows when logging back in" on.** Apps open their windows again. Most windows have the same title as before, so the title rule pairs them.
- **Logout or restart with this option off.** The user opens the apps again. The title rule pairs windows that have the same title, for example Finder folders and documents. The order rule pairs the other windows. Extra windows do not move. Saved windows without a live window stay empty.
- **One app quits and starts again.** Only the windows of that app use the title and order rules. All other apps keep the window ID rule.

The "Reopen windows" checkbox shows in the Log Out, Restart, and Shut Down dialogs. macOS stores one value for all three (`TALLogoutSavesState` in `com.apple.loginwindow`). Thus a restart is not a separate case.

Dispace does not apply a profile at login. It applies a profile at the next display change, or when the user clicks **Apply Now**.

## Tests
A test harness compiled the app sources with a different `main.swift`. It ran `Matcher.match` on three real TextEdit windows (`a.txt`, `b.txt`, `c.txt`). Saved windows were made in the harness. The harness set `savedAt` after or before the launch of TextEdit to select the two rule sets. The same harness also ran the matcher from the previous commit.

| Case | Expected pair | New matcher | Old matcher |
|---|---|---|---|
| S1: app runs since the save. Saved window was closed. A new window has the same title. | none | PASS | FAIL (`a.txt`) |
| S2: app runs since the save. Saved window was closed. New windows have other titles. | none | PASS | FAIL (`a.txt`) |
| S3: app runs since the save. Saved window is still open. | `b.txt` | PASS | PASS |
| S4: app restarted. Window has the same title. | `b.txt` | PASS | PASS |
| S5: app restarted. Title changed. | `a.txt` (oldest) | PASS | PASS |
| S6: app restarted. The old window ID now belongs to a different window. Title is `c.txt`. | `c.txt` | PASS | FAIL (`a.txt`) |

A second test used a real restart of TextEdit. Before the restart, `startedAfter` returned false, and the saved window got no pair. After TextEdit quit and opened the three files again, `startedAfter` returned true, and the title rule paired the saved window with `c.txt`.

A third test checked Finder, which has no `launchDate`. With `savedAt` before the Finder start, `startedAfter` returned true. With `savedAt` set to now, it returned false.

A full switch with a real display change was not tested. The switch code changed in one line only: it gives `profile.savedAt` to the matcher.

## Why it matters
Before this change, a new window could move to another display when you plugged in the external display. This occurred when the new window belonged to an app with a closed saved window. Now Dispace moves a window only when it has good evidence that the window is the saved window: the same ID while the app runs, or the same app after a restart.

There is a cost. Say you close a saved document and open it again while the app keeps running. Dispace does not put the document back. The new window has a new ID, and the app did not restart, so Dispace treats it as a new window. Save the profile again to include it.
