// main.swift
// Entry point. Open Dispace from Raycast, Spotlight, or Finder to show the setup window.
// The Dock icon and the Command-Tab entry are visible only while the window is open.
// The menu bar icon is always visible while Dispace runs.

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
