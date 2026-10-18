// WindowAX.swift
// Accessibility helpers: find the AXUIElement of a window, read its title, set its frame.

import AppKit
import ApplicationServices

enum WindowAX {
    // Private but exported Accessibility functions.
    private typealias GetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> AXError
    private typealias CreateWithRemoteTokenFn = @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    private static let getWindow: GetWindowFn? = {
        guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(pointer, to: GetWindowFn.self)
    }()
    private static let createWithRemoteToken: CreateWithRemoteTokenFn? = {
        guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementCreateWithRemoteToken") else { return nil }
        return unsafeBitCast(pointer, to: CreateWithRemoteTokenFn.self)
    }()

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that adds this app to the Accessibility list.
    static func requestTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    static func windowID(of element: AXUIElement) -> UInt32? {
        var windowID: UInt32 = 0
        guard let getWindow, getWindow(element, &windowID) == .success, windowID != 0 else { return nil }
        return windowID
    }

    /// Returns the AXUIElements of the wanted windows of one app, keyed by window ID.
    /// Many apps list only the windows of the visible Space in `AXWindows`. For windows on
    /// other Spaces, we try the element IDs one by one with a remote token (same method as
    /// AltTab). A time limit of 0.2 s per app keeps this fast.
    static func elements(forWindows wanted: Set<UInt32>, pid: pid_t) -> [UInt32: AXUIElement] {
        var found: [UInt32: AXUIElement] = [:]
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        for window in attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? [] {
            if let id = windowID(of: window), wanted.contains(id) { found[id] = window }
        }
        guard found.count < wanted.count, let createWithRemoteToken else { return found }

        // Token layout: pid (4 bytes), 0 (4 bytes), "coco" (4 bytes), element ID (8 bytes).
        var token = Data(count: 20)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: pid) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: UInt32(0x636f636f)) { Data($0) })
        let deadline = Date().addingTimeInterval(0.2)
        for elementID: UInt64 in 0..<2000 where found.count < wanted.count && Date() < deadline {
            token.replaceSubrange(12..<20, with: withUnsafeBytes(of: elementID) { Data($0) })
            guard let element = createWithRemoteToken(token as CFData)?.takeRetainedValue(),
                  let id = windowID(of: element), wanted.contains(id), found[id] == nil,
                  attribute(element, kAXRoleAttribute) as? String == kAXWindowRole else { continue }
            found[id] = element
        }
        return found
    }

    /// Returns the AXUIElements of windows of several apps, keyed by window ID.
    static func elements(for windows: [LiveWindow]) -> [UInt32: AXUIElement] {
        var result: [UInt32: AXUIElement] = [:]
        for (pid, group) in Dictionary(grouping: windows, by: \.pid) {
            result.merge(elements(forWindows: Set(group.map(\.windowID)), pid: pid)) { first, _ in first }
        }
        return result
    }

    static func title(of element: AXUIElement) -> String {
        attribute(element, kAXTitleAttribute) as? String ?? ""
    }

    /// Sets the window frame (top-left global coordinates).
    /// The position is set before and after the size, because apps clamp the size to the
    /// display that contains the window at that moment.
    @discardableResult
    static func setFrame(_ element: AXUIElement, _ frame: CGRect) -> Bool {
        var origin = frame.origin
        var size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin), let sizeValue = AXValueCreate(.cgSize, &size) else { return false }
        let first = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, position)
        let second = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        let third = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, position)
        return first == .success || second == .success || third == .success
    }
}
