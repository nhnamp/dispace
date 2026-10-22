// SetupWindow.swift
// The only window of Dispace: status, the two profiles, options, and recent activity.

import AppKit

final class SetupWindowController: NSObject, NSWindowDelegate {
    private unowned let app: AppDelegate
    private var window: NSWindow?

    // Views that `refresh()` updates.
    private let setupLabel = SetupWindowController.label("")
    private let permissionLabel = SetupWindowController.label("")
    private let permissionButton = NSButton(title: "Grant Access…", target: nil, action: nil)
    private let spacesLabel = SetupWindowController.label("")
    private var profileTitles: [SetupKind: NSTextField] = [:]
    private var profileDetails: [SetupKind: NSTextField] = [:]
    private var saveButtons: [SetupKind: NSButton] = [:]
    private var applyButtons: [SetupKind: NSButton] = [:]
    private var deleteButtons: [SetupKind: NSButton] = [:]
    private let autoSwitchBox = NSButton(checkboxWithTitle: "Switch profiles automatically when a display is connected or disconnected", target: nil, action: nil)
    private let loginBox = NSButton(checkboxWithTitle: "Open Dispace at login (needed for automatic switching)", target: nil, action: nil)
    private let activityLabel = SetupWindowController.label("", size: 11, color: .secondaryLabelColor)

    init(app: AppDelegate) {
        self.app = app
        super.init()
        NotificationCenter.default.addObserver(forName: Log.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    func show() {
        if window == nil { window = makeWindow() }
        refresh()
        // While the window is open, Dispace is a regular app: Dock icon and Command-Tab entry.
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        // Release the views to keep memory low while Dispace runs in the background.
        window = nil
        // Remove the Dock icon and the Command-Tab entry. Automatic switching continues.
        NSApp.setActivationPolicy(.accessory)
    }

    func windowDidBecomeKey(_ notification: Notification) { refresh() }

    // MARK: Refresh

    func refresh() {
        guard window != nil else { return }
        let setup = DisplaySetup.current()
        if let kind = setup.kind {
            setupLabel.stringValue = "Displays now: \(kind.summary.lowercased()). Active profile: \(kind.rawValue)."
        } else {
            setupLabel.stringValue = "Displays now: the built-in display is off. No profile applies."
        }

        let trusted = WindowAX.isTrusted
        let missing = SkyLight.missingSymbols
        if !missing.isEmpty {
            permissionLabel.stringValue = "⚠️ This macOS version does not have: \(missing.joined(separator: ", ")). Dispace cannot move windows."
        } else {
            permissionLabel.stringValue = trusted
                ? "✅ Accessibility access is granted."
                : "⚠️ Accessibility access is missing. Dispace cannot move windows or add desktops."
        }
        permissionButton.isHidden = trusted

        var spaces = Displays.haveSeparateSpaces
            ? "✅ \"Displays have separate Spaces\" is on."
            : "⚠️ Turn on \"Displays have separate Spaces\" in System Settings › Desktop & Dock, then log out and in."
        if Displays.rearrangeSpacesByRecentUse {
            spaces += "\n⚠️ Turn off \"Automatically rearrange Spaces based on most recent use\" in System Settings › Desktop & Dock. It changes the order of your desktops."
        }
        spacesLabel.stringValue = spaces

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        for kind in SetupKind.allCases {
            let isCurrent = setup.kind == kind
            profileTitles[kind]?.stringValue = "\(kind.rawValue) — \(kind.summary)" + (isCurrent ? "  (now)" : "")
            if let profile = app.profiles[kind] {
                profileDetails[kind]?.stringValue = "Saved \(formatter.string(from: profile.savedAt)) · \(profile.windows.count) windows\n" + profile.describe()
            } else {
                profileDetails[kind]?.stringValue = isCurrent
                    ? "Not saved yet. Arrange your desktops and windows, then click Save."
                    : "Not saved yet. Connect this display setup to save it."
            }
            saveButtons[kind]?.isEnabled = isCurrent && !app.isBusy
            applyButtons[kind]?.isEnabled = isCurrent && !app.isBusy && app.profiles[kind] != nil && trusted && missing.isEmpty
            deleteButtons[kind]?.isEnabled = !app.isBusy && app.profiles[kind] != nil
        }

        autoSwitchBox.state = app.autoSwitch ? .on : .off
        loginBox.state = app.opensAtLogin ? .on : .off
        activityLabel.stringValue = app.isBusy
            ? "Working… (Mission Control can open for a moment.)\n" + Log.recent.suffix(5).joined(separator: "\n")
            : Log.recent.suffix(6).joined(separator: "\n")
    }

    // MARK: Actions

    @objc private func grantAccess() {
        WindowAX.requestTrust()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func save(_ sender: NSButton) {
        guard let kind = kind(for: sender, in: saveButtons) else { return }
        if app.profiles[kind] != nil {
            let alert = NSAlert()
            alert.messageText = "Replace the saved \(kind.rawValue) profile?"
            alert.informativeText = "Dispace saves the desktops and windows that you have now."
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        app.saveCurrentArrangement()
    }

    @objc private func applyProfile(_ sender: NSButton) {
        guard let kind = kind(for: sender, in: applyButtons) else { return }
        app.applyNow(kind)
    }

    @objc private func deleteProfile(_ sender: NSButton) {
        guard let kind = kind(for: sender, in: deleteButtons) else { return }
        let alert = NSAlert()
        alert.messageText = "Delete the saved \(kind.rawValue) profile?"
        alert.informativeText = "Dispace forgets the desktops and windows of this profile. Your windows do not move. You cannot undo this."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        app.deleteProfile(kind)
    }

    @objc private func toggleAutoSwitch(_ sender: NSButton) { app.setAutoSwitch(sender.state == .on) }
    @objc private func toggleLogin(_ sender: NSButton) { app.setOpensAtLogin(sender.state == .on) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func kind(for button: NSButton, in buttons: [SetupKind: NSButton]) -> SetupKind? {
        buttons.first { $0.value === button }?.key
    }

    // MARK: Layout

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Dispace"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: 56).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 56).isActive = true
        let title = Self.label("Dispace", size: 22, weight: .bold)
        let subtitle = Self.label("Saves your desktops (Spaces) for each display setup. Switches them when you connect or disconnect the external display.",
                                  size: 12, color: .secondaryLabelColor)
        let header = NSStackView(views: [icon, Self.column([title, subtitle], spacing: 2)])
        header.alignment = .centerY
        header.spacing = 12

        permissionButton.target = self
        permissionButton.action = #selector(grantAccess)
        let status = Self.section("Status", [setupLabel, permissionLabel, permissionButton, spacesLabel])

        var profileRows: [NSView] = []
        for kind in SetupKind.allCases {
            let rowTitle = Self.label("", size: 13, weight: .semibold)
            let details = Self.label("", size: 11, color: .secondaryLabelColor)
            let save = NSButton(title: "Save Current Arrangement", target: self, action: #selector(save(_:)))
            let apply = NSButton(title: "Apply Now", target: self, action: #selector(applyProfile(_:)))
            let delete = NSButton(title: "Delete Profile…", target: self, action: #selector(deleteProfile(_:)))
            profileTitles[kind] = rowTitle
            profileDetails[kind] = details
            saveButtons[kind] = save
            applyButtons[kind] = apply
            deleteButtons[kind] = delete
            let buttons = NSStackView(views: [save, apply, delete])
            buttons.spacing = 8
            profileRows.append(Self.column([rowTitle, details, buttons], spacing: 6))
        }
        let profilesSection = Self.section("Profiles", profileRows)

        autoSwitchBox.target = self
        autoSwitchBox.action = #selector(toggleAutoSwitch(_:))
        loginBox.target = self
        loginBox.action = #selector(toggleLogin(_:))
        let options = Self.section("Options", [autoSwitchBox, loginBox])

        activityLabel.isSelectable = true
        let activity = Self.section("Recent activity", [activityLabel])

        let hint = Self.label("Close this window to keep Dispace running in the menu bar. Quit (⌘Q) stops automatic switching.",
                              size: 11, color: .secondaryLabelColor)
        hint.preferredMaxLayoutWidth = 400
        let quitButton = NSButton(title: "Quit Dispace", target: self, action: #selector(quit))
        let footer = NSStackView(views: [hint, quitButton])
        footer.spacing = 12

        let content = Self.column([header, status, profilesSection, options, activity, footer], spacing: 18)
        content.edgeInsets = NSEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)
        content.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: 580),
        ])
        window.contentView = container
        window.center()
        return window
    }

    private static func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular,
                              color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.preferredMaxLayoutWidth = 500
        return label
    }

    private static func column(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    private static func section(_ title: String, _ rows: [NSView]) -> NSStackView {
        let heading = label(title.uppercased(), size: 11, weight: .semibold, color: .secondaryLabelColor)
        return column([heading] + rows, spacing: 8)
    }
}
