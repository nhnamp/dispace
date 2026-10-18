# Build and install

## What was done
We wrote `build.sh`. It compiles the Swift sources with `swiftc`, draws the icon, signs the app with the Apple Development identity, and copies `Dispace.app` to `/Applications`. Raycast can open apps in `/Applications`. Raycast finds "Dispace" and shows its logo, also with Spotlight indexing off on this Mac. On the first launch, Dispace adds itself as a login item.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `build.sh` | Created | Builds, signs, and installs the app |
| `/Applications/Dispace.app` | Created | The installed app |

## Why it matters
The Accessibility permission belongs to the signature of the app. A stable signature (Apple Development certificate) keeps the permission after a rebuild. With ad-hoc signing, macOS asks for the permission again after each build.

## Build and install
Run this command in the project folder:

```bash
./build.sh
```

Use `./build.sh --no-install` to build only. The result is `build/Dispace.app`.

## First setup
1. Open Raycast, type "Dispace", and press Return.
2. Click "Grant Access…". In System Settings › Privacy & Security › Accessibility, turn on Dispace.
3. Make sure that "Displays have separate Spaces" is on (System Settings › Desktop & Dock).
4. With only the built-in display, arrange your desktops and windows. Click "Save Current Arrangement" in the "1-monitor" row.
5. Connect the external display. Arrange the desktops on both displays. Click "Save Current Arrangement" in the "2-monitor" row.
6. Close the window. The Dock icon goes away, and Dispace keeps running in the menu bar. Do not quit Dispace (⌘Q): quit stops the automatic switch.
7. To save a profile again, click the Dispace icon in the menu bar, then click "Save Current Arrangement". The icon shows a check mark for 1.5 seconds when the save is complete.

## How to test the automatic switch
1. Disconnect the external display. Wait 5–8 seconds.
2. Make sure that each window is on its "1-monitor" desktop. Mission Control can open for one second if desktops must be added or removed.
3. Connect the external display again. Wait 5–8 seconds. Make sure that the "2-monitor" arrangement is back.
4. Open Dispace from Raycast. "Recent activity" shows the result, for example "Applied 2-monitor: 6 windows moved, 2 resized, 1 desktops added."
5. If a result is wrong, read `~/Library/Logs/Dispace.log`.

## Remove Dispace
1. Open Dispace and click "Quit Dispace".
2. Delete `/Applications/Dispace.app`.
3. Remove Dispace from System Settings › General › Login Items and from Privacy & Security › Accessibility.
4. Delete `~/Library/Application Support/Dispace`.
