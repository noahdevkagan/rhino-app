import Cocoa

/// Watches for the user's own ⌘V while the clipboard is borrowed for a dictation paste, and has
/// `ClipboardUtil` put their contents back before the keystroke reaches the app. Without it, a
/// paste within `ClipboardUtil.borrowRestoreDelay` of a dictation pastes the dictation a second
/// time instead of what the user copied.
///
/// The tap is active (not listen-only) so the restore finishes before the app sees the key, and
/// it is enabled only while a borrow is pending. Needs Accessibility, like text insertion; without
/// it the tap can't be created and the fixed timer is the only restore. Main-thread only.
final class UserPasteWatcher {
    static let shared = UserPasteWatcher()

    /// `eventSourceUserData` on the ⌘V Rhino posts itself ("RHINO"), so it isn't taken for the user's.
    static let syntheticMarker: Int64 = 0x5248_494E_4F

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    /// Whether a borrow is pending right now (watch the user's ⌘V).
    private var wantedPaste = false
    /// Whether Command Mode's late-copy watch is running (watch the user's ⌘C / ⌘X).
    private var wantedCopy = false
    /// The tap should be on.
    private var wanted: Bool { wantedPaste || wantedCopy }

    private init() {}

    /// Whether a key-down is the user pasting. ⌘V with any of ⇧/⌥ counts too (paste and match
    /// style reads the same clipboard). Matches the V key by position or by the character the
    /// layout produces, so Dvorak and non-Latin layouts are covered; a false match only brings
    /// the restore forward.
    static func isUserPaste(keyCode: Int64, flags: CGEventFlags, characters: String?,
                            userData: Int64) -> Bool {
        guard userData != syntheticMarker,
              flags.contains(.maskCommand), !flags.contains(.maskControl) else { return false }
        return keyCode == 0x09 || characters?.lowercased() == "v"
    }

    /// Whether a key-down is the user copying or cutting for themselves (⌘C / ⌘X, by position or
    /// by the layout's character). ⌃ excludes the Command Mode shortcut (⌃⌥⌘C) and its
    /// autorepeat; Rhino's own synthetic ⌘C carries the marker.
    static func isUserCopy(keyCode: Int64, flags: CGEventFlags, characters: String?,
                           userData: Int64) -> Bool {
        guard userData != syntheticMarker,
              flags.contains(.maskCommand), !flags.contains(.maskControl) else { return false }
        let char = characters?.lowercased()
        return keyCode == 0x08 || keyCode == 0x07 || char == "c" || char == "x"
    }

    func setActive(_ active: Bool) {
        wantedPaste = active
        applyWanted()
    }

    /// Command Mode's late-copy watch: a ⌘C / ⌘X of the user's own ends it, so the watch never
    /// puts the old clipboard back over a copy the user just made.
    func setCopyWatchActive(_ active: Bool) {
        wantedCopy = active
        applyWanted()
    }

    private func applyWanted() {
        if wanted, tap == nil { createTap() }
        if let tap { CGEvent.tapEnable(tap: tap, enable: wanted) }
    }

    private func createTap() {
        guard AXIsProcessTrusted() else { return }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, type, event, _ in
                UserPasteWatcher.shared.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else { return }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // macOS turns a slow tap off; turn it back on only while a borrow still needs it,
            // so a late notification after the borrow ended doesn't leave it in the key path.
            if wanted, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .keyDown else { return }
        var length = 0
        var units = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length,
                                       unicodeString: &units)
        let characters = String(utf16CodeUnits: units, count: min(length, units.count))
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let userData = event.getIntegerValueField(.eventSourceUserData)
        if wantedCopy, Self.isUserCopy(keyCode: keyCode, flags: event.flags,
                                       characters: characters, userData: userData) {
            SelectionCapture.clipboardTakenElsewhere()
            return
        }
        guard wantedPaste, Self.isUserPaste(keyCode: keyCode, flags: event.flags,
                                            characters: characters, userData: userData)
        else { return }
        ClipboardUtil.restoreBeforeUserPaste()
    }
}
