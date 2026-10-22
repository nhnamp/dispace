// AppDelegate.swift
// App life cycle, display change detection, and the actions of the setup window.

import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var profiles = ProfileStore.load()
    private(set) var isBusy = false
    /// The setup that the last automatic switch handled. Wake events with the same setup do nothing.
    private var lastKind: SetupKind?
    private var settleWork: DispatchWorkItem?
    private let workQueue = DispatchQueue(label: "Dispace.work")
    private var launchedAsLoginItem = false
    private lazy var setupWindow = SetupWindowController(app: self)
    private var menuBar: MenuBarController?

    var autoSwitch: Bool {
        get { UserDefaults.standard.object(forKey: "autoSwitch") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoSwitch") }
    }

    var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    // MARK: Life cycle

    /// Dispace launches as a regular app, so macOS activates it and the window comes to the front.
    /// At login it changes to a background app before the Dock icon appears.
    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAsLoginItem = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if launchedAsLoginItem { NSApp.setActivationPolicy(.accessory) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        menuBar = MenuBarController(app: self)
        lastKind = DisplaySetup.current().kind

        // Event driven: no timers and no polling while nothing changes.
        CGDisplayRegisterReconfigurationCallback({ _, flags, userInfo in
            guard !flags.contains(.beginConfigurationFlag), let userInfo else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { delegate.displaysChanged() }
        }, Unmanaged.passUnretained(self).toOpaque())

        // macOS posts this when the Accessibility list changes.
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.apple.accessibility.api"),
                                                            object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.setupWindow.refresh() }
        }

        if !UserDefaults.standard.bool(forKey: "didSetUpLoginItem") {
            UserDefaults.standard.set(true, forKey: "didSetUpLoginItem")
            setOpensAtLogin(true)
        }

        let missing = SkyLight.missingSymbols
        Log.write(missing.isEmpty ? "Dispace started." : "Dispace started. Missing private symbols: \(missing.joined(separator: ", ")).")
        if !launchedAsLoginItem { showSetupWindow() }
    }

    /// Raycast, Spotlight, and Finder send "reopen" when the app is already running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetupWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func showSetupWindow() {
        setupWindow.show()
    }

    // MARK: Display changes

    /// The callback fires several times for one change. Wait until the displays are stable.
    private func displaysChanged() {
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.displaysSettled(attempt: 0) }
        settleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    private func displaysSettled(attempt: Int) {
        setupWindow.refresh()
        // A switch is still running (for example, the display was reconnected during it).
        // Check again when it ends, so the newest setup is not skipped.
        if isBusy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.displaysSettled(attempt: attempt) }
            return
        }
        let setup = DisplaySetup.current()
        guard setup.kind != lastKind else { return }

        // WindowServer can need a moment before it gives Spaces to a new display.
        let layout = SkyLight.displaySpaces()
        let allManaged = setup.roles.allSatisfy { role in setup.displayID(for: role).map { layout[$0] != nil } ?? false }
        if !allManaged && attempt < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.displaysSettled(attempt: attempt + 1) }
            return
        }

        lastKind = setup.kind
        guard let kind = setup.kind else {
            Log.write("The built-in display is off. No profile applies.")
            return
        }
        Log.write("Display setup changed to \(kind.rawValue).")
        guard autoSwitch else { Log.write("Automatic switching is off."); return }
        guard let profile = profiles[kind] else { Log.write("No \(kind.rawValue) profile is saved yet."); return }
        apply(profile, kind: kind, setup: setup)
    }

    // MARK: Actions

    /// Saves the arrangement of the current setup. `completion` gets true when the file is written.
    func saveCurrentArrangement(completion: ((Bool) -> Void)? = nil) {
        let setup = DisplaySetup.current()
        guard let kind = setup.kind, !isBusy else { completion?(false); return }
        guard Displays.haveSeparateSpaces else {
            Log.write("Not saved: turn on \"Displays have separate Spaces\" first.")
            completion?(false)
            return
        }
        isBusy = true
        setupWindow.refresh()
        workQueue.async { [weak self] in
            let profile = Snapshot.capture(setup: setup)
            DispatchQueue.main.async {
                guard let self else { return }
                self.profiles[kind] = profile
                var saved = false
                do {
                    try ProfileStore.save(self.profiles)
                    saved = true
                    Log.write("Saved \(kind.rawValue): \(profile.windows.count) windows on \(profile.displays.map(\.spaceCount).reduce(0, +)) desktops.")
                } catch {
                    Log.write("Could not write the profile file: \(error.localizedDescription)")
                }
                self.lastKind = kind
                self.isBusy = false
                self.setupWindow.refresh()
                completion?(saved)
            }
        }
    }

    /// Deletes a saved profile. If the file cannot be written, the profile stays.
    func deleteProfile(_ kind: SetupKind) {
        guard !isBusy, let old = profiles[kind] else { return }
        profiles[kind] = nil
        do {
            try ProfileStore.save(profiles)
            Log.write("Deleted the \(kind.rawValue) profile.")
        } catch {
            profiles[kind] = old
            Log.write("Could not delete the \(kind.rawValue) profile: \(error.localizedDescription)")
        }
        setupWindow.refresh()
    }

    func applyNow(_ kind: SetupKind) {
        let setup = DisplaySetup.current()
        guard setup.kind == kind, let profile = profiles[kind] else { return }
        apply(profile, kind: kind, setup: setup)
    }

    private func apply(_ profile: Profile, kind: SetupKind, setup: DisplaySetup) {
        guard !isBusy else { return }
        isBusy = true
        setupWindow.refresh()
        workQueue.async { [weak self] in
            let summary = Switcher.apply(profile, kind: kind, setup: setup) { Log.write($0) }
            Log.write(summary)
            DispatchQueue.main.async {
                self?.isBusy = false
                self?.setupWindow.refresh()
            }
        }
    }

    func setAutoSwitch(_ on: Bool) {
        autoSwitch = on
        Log.write(on ? "Automatic switching is on." : "Automatic switching is off.")
    }

    func setOpensAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Log.write("Could not change the login item: \(error.localizedDescription)")
        }
        setupWindow.refresh()
    }

    // MARK: Menu

    /// The app menu shows only while the window is open: Command-W closes the window, Command-Q quits.
    private func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit Dispace", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let mainMenu = NSMenu()
        for submenu in [appMenu, editMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
    }
}
