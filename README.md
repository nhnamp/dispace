<p align="center">
  <img src="Icon/logo-1024.png" width="128" alt="Dispace logo">
</p>

<h1 align="center">Dispace</h1>

<p align="center">Keeps a separate desktop (Spaces) arrangement for each display setup on macOS, and switches it when you connect or disconnect the external display.</p>

---

## The problem

With "Displays have separate Spaces" on, each display has its own desktops. When you unplug the external display, macOS merges its desktops into the built-in display and shuffles the windows. When you plug it in again, the windows do not go back. With the setting off, all displays share one Space, so you lose separate desktops.

No existing app restores the Space of each window per display setup with System Integrity Protection (SIP) on. [`docs/01_research_and_feasibility.md`](docs/01_research_and_feasibility.md) has the comparison.

## What Dispace does

Dispace keeps two profiles:

| Profile | Display setup |
|---------|---------------|
| `1-monitor` | Built-in display only |
| `2-monitor` | Built-in display and one external display |

A profile records:

- the number of desktops on each display,
- the desktop of each window,
- the frame of each window.

When the display setup changes, Dispace applies the profile for the new setup:

1. It adds missing desktops.
2. It moves each window to its saved desktop and frame.
3. It removes extra empty desktops.

Mission Control can open for about a second while desktops are added or removed.

## Requirements

- An Apple silicon Mac. The build targets `arm64`.
- macOS 27. Dispace was developed and tested on macOS 27.0.1 with SIP on. Other versions are not tested.
- Xcode or the Xcode Command Line Tools (`swiftc`, `codesign`).
- Accessibility permission for Dispace.
- System Settings › Desktop & Dock:
  - "Displays have separate Spaces" must be on.
  - "Automatically rearrange Spaces based on most recent use" must be off. Profiles store desktops by position, and this setting changes their order.

## Build and install

```bash
git clone https://github.com/nhnamp/dispace.git
cd dispace
./build.sh
```

`build.sh` compiles the app, draws the icon, signs the app, and copies it to `/Applications/Dispace.app`. You can then open it from Raycast, Spotlight, or Finder.

- Use `./build.sh --no-install` to build only. The output is `build/Dispace.app`.
- If you have an "Apple Development" signing identity, the script uses it. A stable signature keeps the Accessibility permission across rebuilds. Without one, the script signs ad-hoc, and macOS asks for the permission again after each build.

## First setup

1. Open Dispace. On the first launch it adds itself as a login item. You can turn this off in its window.
2. Click **Grant Access…** and turn on Dispace in System Settings › Privacy & Security › Accessibility.
3. With only the built-in display, arrange your desktops and windows. Click **Save Current Arrangement** in the `1-monitor` row.
4. Connect the external display, arrange both displays, and save the `2-monitor` profile.
5. Close the window. Dispace keeps running in the menu bar.

## Daily use

- **Menu bar icon:** shows the active profile and when it was saved. **Save Current Arrangement** saves the active profile in one click. The icon shows a check mark when the save is done. **Open Dispace** opens the window.
- **Window:** click **Open Dispace** in the menu bar menu, or open Dispace from Raycast, Spotlight, or Finder. It shows the status, both profiles, **Apply Now**, **Delete Profile…**, the options, and recent activity. While the window is open, Dispace has a Dock icon and a Command-Tab entry. Close the window to hide them.
- **Quit:** **Quit Dispace** (or ⌘Q) stops automatic switching.

Profiles are stored in `~/Library/Application Support/Dispace/profiles.json`. The log is `~/Library/Logs/Dispace.log`.

## How it works

macOS has no public API that moves a window to another Space or adds a Space. Dispace uses private interfaces:

| Task | Interface |
|------|-----------|
| Read the Spaces of each display and the Space of each window | SkyLight: `SLSCopyManagedDisplaySpaces`, `SLSCopySpacesForWindows` |
| List windows on hidden Spaces | SkyLight: `SLSCopyWindowsWithOptionsAndTags` and the window query iterator |
| Move another app's window to a Space | SkyLight: `SLSBridgedMoveWindowsToManagedSpaceOperation`, sent with a non-exported function that Dispace finds in the SkyLight symbol table at runtime |
| Add and remove desktops | Mission Control, driven through Accessibility |
| Set window frames, also on hidden Spaces | Accessibility (`AXPosition`, `AXSize`) |
| Detect display changes | `CGDisplayRegisterReconfigurationCallback`, with a 2.5 second settle delay |

The old call `SLSMoveWindowsToManagedSpace` fails silently since macOS 14.5. The window move method comes from [yabai](https://github.com/koekeishiya/yabai) 7.1.25, which works with SIP on.

[`docs/02_dispace_app.md`](docs/02_dispace_app.md) describes the design in more detail.

## Resource use

Dispace uses no timers and no polling. It wakes only for display changes and for clicks in its window or menu. Measured with the window closed: 0.0 % CPU, no idle wakeups, about 30 MB of memory. The app bundle is about 1.2 MB.

## Known limits

- A macOS update can remove the private functions. Dispace then shows a warning and does not move windows.
- Dispace does not move full-screen app Spaces, minimized windows, hidden apps, or windows that show on all desktops.
- Dispace does not open closed apps. New windows that are not in the profile stay where macOS puts them.
- If you close a saved window and open a new window of the same app, Dispace does not move the new window. It treats the new window as a saved window only after the app restarts (logout, restart, or app restart). Then it pairs windows by title, and after that by order of creation. Save the profile again to include new windows.
- Dispace does not apply a profile at login. It applies a profile at the next display change, or when you click **Apply Now**.
- Dispace uses only the first external display.
- With the lid closed (external display only), no profile applies.
- The tests during development used the built-in display only. The automatic switch on connect and disconnect, and moves to the external display, were not tested during development.

## Uninstall

1. Click **Quit Dispace** in its window.
2. Delete `/Applications/Dispace.app`.
3. Remove Dispace from System Settings › General › Login Items and from Privacy & Security › Accessibility.
4. Delete `~/Library/Application Support/Dispace`.

## Documentation

- [`docs/01_research_and_feasibility.md`](docs/01_research_and_feasibility.md): existing apps and private API tests
- [`docs/02_dispace_app.md`](docs/02_dispace_app.md): app design and how a switch works
- [`docs/03_build_and_install.md`](docs/03_build_and_install.md): build, setup, and test steps
- [`docs/04_github_repository.md`](docs/04_github_repository.md): the repository and this README

## Credits

The window move method comes from [yabai](https://github.com/koekeishiya/yabai) by [@koekeishiya](https://github.com/koekeishiya).
