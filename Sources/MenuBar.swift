// MenuBar.swift
// The menu bar icon. Its menu shows the active profile, a Save item, and an item that opens the window.
// The icon stays when the window is closed, because the app keeps running.

import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private unowned let app: AppDelegate
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    init(app: AppDelegate) {
        self.app = app
        super.init()
        statusItem.button?.image = Self.icon
        statusItem.button?.toolTip = "Dispace"
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Builds the menu each time it opens, so it shows the current state without polling.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        addProfileItems(to: menu)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open Dispace", action: #selector(openWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
    }

    private func addProfileItems(to menu: NSMenu) {
        guard let kind = DisplaySetup.current().kind else {
            menu.addItem(Self.info("No profile: the built-in display is off"))
            return
        }
        menu.addItem(Self.info("Profile: \(kind.rawValue) — \(kind.summary)"))
        if let profile = app.profiles[kind] {
            let date = DateFormatter.localizedString(from: profile.savedAt, dateStyle: .medium, timeStyle: .short)
            menu.addItem(Self.info("Saved \(date) · \(profile.windows.count) windows"))
        } else {
            menu.addItem(Self.info("Not saved yet"))
        }
        menu.addItem(.separator())
        let save = NSMenuItem(title: app.isBusy ? "Working…" : "Save Current Arrangement",
                              action: #selector(save), keyEquivalent: "")
        save.target = self
        save.isEnabled = !app.isBusy
        menu.addItem(save)
    }

    @objc private func openWindow() { app.showSetupWindow() }

    @objc private func save() {
        app.saveCurrentArrangement { [weak self] saved in
            // Short feedback: a check mark (or a warning sign) replaces the icon for 1.5 s.
            let symbol = saved ? "checkmark.circle" : "exclamationmark.triangle"
            self?.statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: saved ? "Saved" : "Not saved")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.statusItem.button?.image = Self.icon }
        }
    }

    private static func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// A small display with three desktops, drawn as a template image (it follows light and dark mode).
    private static let icon: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { _ in
            NSColor.black.set()
            let screen = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 4.5, width: 15, height: 10.5), xRadius: 2, yRadius: 2)
            screen.lineWidth = 1.5
            screen.stroke()
            NSBezierPath(rect: NSRect(x: 8, y: 2, width: 2, height: 2.5)).fill()
            NSBezierPath(roundedRect: NSRect(x: 5.5, y: 0.5, width: 7, height: 1.75), xRadius: 0.8, yRadius: 0.8).fill()
            for x in [4.0, 7.65, 11.3] {
                NSBezierPath(roundedRect: NSRect(x: x, y: 7.75, width: 2.7, height: 4), xRadius: 0.6, yRadius: 0.6).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
