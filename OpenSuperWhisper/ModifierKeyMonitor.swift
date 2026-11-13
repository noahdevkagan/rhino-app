import AppKit
import Carbon
import Foundation
import KeyboardShortcuts

enum ModifierKey: String, CaseIterable, Identifiable, Codable {
    case none = "none"
    case leftCommand = "leftCommand"
    case rightCommand = "rightCommand"
    case leftOption = "leftOption"
    case rightOption = "rightOption"
    case leftShift = "leftShift"
    case rightShift = "rightShift"
    case leftControl = "leftControl"
    case rightControl = "rightControl"
    case fn = "fn"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .leftCommand: return "Left ⌘ Command"
        case .rightCommand: return "Right ⌘ Command"
        case .leftOption: return "Left ⌥ Option"
        case .rightOption: return "Right ⌥ Option"
        case .leftShift: return "Left ⇧ Shift"
        case .rightShift: return "Right ⇧ Shift"
        case .leftControl: return "Left ⌃ Control"
        case .rightControl: return "Right ⌃ Control"
        case .fn: return "Fn"
        }
    }
    
    var shortSymbol: String {
        switch self {
        case .none: return ""
        case .leftCommand: return "⌘"
        case .rightCommand: return "⌘"
        case .leftOption: return "⌥"
        case .rightOption: return "⌥"
        case .leftShift: return "⇧"
        case .rightShift: return "⇧"
        case .leftControl: return "⌃"
        case .rightControl: return "⌃"
        case .fn: return "fn"
        }
    }
    
    var keyCode: UInt16 {
        switch self {
        case .none: return 0
        case .leftCommand: return 55
        case .rightCommand: return 54
        case .leftOption: return 58
        case .rightOption: return 61
        case .leftShift: return 56
        case .rightShift: return 60
        case .leftControl: return 59
        case .rightControl: return 62
        case .fn: return 63
        }
    }
    
    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .none: return []
        case .leftCommand, .rightCommand: return .command
        case .leftOption, .rightOption: return .option
        case .leftShift, .rightShift: return .shift
        case .leftControl, .rightControl: return .control
        case .fn: return .function
        }
    }
    
    var cgEventFlag: CGEventFlags {
        switch self {
        case .none: return []
        case .leftCommand, .rightCommand: return .maskCommand
        case .leftOption, .rightOption: return .maskAlternate
        case .leftShift, .rightShift: return .maskShift
        case .leftControl, .rightControl: return .maskControl
        case .fn: return .maskSecondaryFn
        }
    }
    
    var isCommandOrOption: Bool {
        switch self {
        case .leftCommand, .rightCommand, .leftOption, .rightOption:
            return true
        default:
            return false
        }
    }
}

class ModifierKeyMonitor {
    static let shared = ModifierKeyMonitor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    /// Listen-only keyDown tap for spotting chords. Enabled only while a trigger is held, so
    /// Rhino is not on every keystroke's path otherwise (the same pattern as UserPasteWatcher).
    private var keyTap: CFMachPort?
    private var keyTapSource: CFRunLoopSource?
    /// Modifiers being watched, by key code. More than one so a second modifier can mean
    /// "dictate and submit" alongside the plain record trigger (#50).
    private var watched: [UInt16: ModifierKey] = [:]
    private var pressedKey: ModifierKey?
    /// Whether a non-modifier key went down during the current press (see `handleKeyDown`).
    private var pressChorded = false
    /// When the current press went down (`CGEvent.timestamp`), to drop key-downs from before it.
    private var pressTimestamp: CGEventTimestamp = 0

    var onKeyDown: ((ModifierKey) -> Void)?
    var onKeyUp: ((ModifierKey) -> Void)?
    /// A non-modifier key went down while the trigger was held: the press may be a shortcut
    /// such as Fn+↑ (Page Up), Fn+Delete or Fn+F5, not dictation. Fires at most once per press,
    /// on main, after that press's `onKeyDown` and before its `onKeyUp`.
    var onChord: (() -> Void)?
    
    private init() {}
    
    func start(modifierKeys: [ModifierKey]) {
        let active = modifierKeys.filter { $0 != .none }
        guard !active.isEmpty else {
            stop()
            return
        }
        start(modifierKey: active[0])
        watched = Dictionary(active.map { ($0.keyCode, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func start(modifierKey: ModifierKey) {
        guard modifierKey != .none else {
            stop()
            return
        }
        
        stop()
        
        watched = [modifierKey.keyCode: modifierKey]
        pressedKey = nil
        pressChorded = false

        // Accessibility already authorizes both posting and listening to events. Rhino needs it
        // to insert text, so requiring Input Monitoring as well creates a redundant TCC prompt
        // whose newly enabled state may not become visible until relaunch. Existing installs
        // with the narrower Input Monitoring grant remain supported.
        guard GlobalEventListeningAccess.current else {
            print("ModifierKeyMonitor: Accessibility is required for global \(modifierKey.displayName)")
            return
        }
        
        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                
                let monitor = Unmanaged<ModifierKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    monitor.reenableTap()
                    return Unmanaged.passUnretained(event)
                }
                
                monitor.handleFlagsChanged(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("ModifierKeyMonitor: Failed to create event tap. Check Accessibility permission.")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("ModifierKeyMonitor: Started monitoring for \(modifierKey.displayName)")
        }

        createKeyTap()
    }

    /// Listen-only: nothing is ever swallowed or delayed. Created disabled; see `setKeyTap`.
    private func createKeyTap() {
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { (_, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<ModifierKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                // Our own tapEnable(false) on every trigger release is delivered back here as
                // tapDisabledByUserInput. Answering it with another disable re-sent it forever and
                // pinned the main thread (Rhino froze after a few Fn presses). Only a timeout
                // needs handling, and only while a trigger is held.
                if type == .tapDisabledByTimeout {
                    if monitor.pressedKey != nil { monitor.setKeyTap(enabled: true) }
                } else if type == .keyDown {
                    monitor.handleKeyDown(event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // Chords just go unnoticed; the trigger itself still works.
            print("ModifierKeyMonitor: Failed to create the chord tap")
            return
        }
        CGEvent.tapEnable(tap: tap, enable: false)
        keyTap = tap
        keyTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let keyTapSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), keyTapSource, .commonModes)
        }
    }

    private func setKeyTap(enabled: Bool) {
        if let keyTap { CGEvent.tapEnable(tap: keyTap, enable: enabled) }
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        if let keyTap {
            CGEvent.tapEnable(tap: keyTap, enable: false)
            if let keyTapSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), keyTapSource, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        keyTap = nil
        keyTapSource = nil
        watched = [:]
        pressedKey = nil
        pressChorded = false
        print("ModifierKeyMonitor: Stopped")
    }
    
    fileprivate func reenableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            print("ModifierKeyMonitor: Re-enabled tap after timeout")
        }
    }
    
    private func handleFlagsChanged(event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        guard let key = watched[keyCode] else { return }

        let isPressed = flags.contains(key.cgEventFlag)

        if isPressed, pressedKey == nil {
            // A second modifier pressed mid-recording is ignored: the first owns this take.
            pressedKey = key
            pressChorded = false
            pressTimestamp = event.timestamp
            setKeyTap(enabled: true)
            DispatchQueue.main.async {
                self.onKeyDown?(key)
            }
        } else if !isPressed, pressedKey == key {
            pressedKey = nil
            setKeyTap(enabled: false)
            DispatchQueue.main.async {
                self.onKeyUp?(key)
            }
        }
    }

    /// A key went down while a trigger is held. Privacy: keys are only counted here, never
    /// recorded — the key code is compared to the cancel shortcut's and never stored or logged.
    private func handleKeyDown(event: CGEvent) {
        guard let held = pressedKey, !pressChorded else { return }
        guard Self.keyDownCountsAsChord(
            isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            cancelKeyCode: KeyboardShortcuts.getShortcut(for: .escape).map { Int64($0.carbonKeyCode) },
            sourcePID: event.getIntegerValueField(.eventSourceUnixProcessID),
            ownPID: Int64(getpid()),
            triggerKeyCode: Int64(held.keyCode),
            triggerHeldInEvent: event.flags.contains(held.cgEventFlag),
            afterPress: event.timestamp >= pressTimestamp) else { return }
        pressChorded = true
        DispatchQueue.main.async {
            self.onChord?()
        }
    }

    /// The Globe (fn) key's own key code. Some keyboards send it as a keyDown with the Fn press.
    static let globeKeyCode: Int64 = 179

    /// Whether a key-down during a trigger press counts as a chord.
    /// - Rhino's own synthetic keys (typed text, ⌘V, Return) are skipped: they land after a
    ///   release, possibly while the next take's trigger is already held.
    /// - Other apps' synthetic keys (text expanders, automation) DO still count. Nothing in a
    ///   CGEvent reliably tells them from a keyboard: a poster using the HID system state
    ///   reports the same source state ID as hardware.
    /// - Autorepeat of a key held before the trigger is not a new press.
    /// - The cancel shortcut's key (Esc by default) is left to that flow, with its long-take
    ///   confirmation, rather than discarding first and racing it.
    /// - The key-down must itself say the trigger was down when it happened, and come after
    ///   the press. Both taps are serviced on the main run loop, from separate ports, so after a
    ///   main-thread stall (take start sets up audio for ~0.4 s) a key-down can be handled
    ///   before the trigger's release that preceded it. Without this, a quick second Fn tap
    ///   was read as a chord on the first: the take was discarded and a new one started
    ///   (0.1.48 "glitchy" bubble that flashes off and on, nothing pasted).
    /// - The trigger's own key code and the Globe key are never chords.
    static func keyDownCountsAsChord(isAutorepeat: Bool, keyCode: Int64, cancelKeyCode: Int64?,
                                     sourcePID: Int64, ownPID: Int64,
                                     triggerKeyCode: Int64, triggerHeldInEvent: Bool,
                                     afterPress: Bool) -> Bool {
        guard sourcePID != ownPID, triggerHeldInEvent, afterPress else { return false }
        guard keyCode != triggerKeyCode, keyCode != globeKeyCode else { return false }
        return !isAutorepeat && keyCode != cancelKeyCode
    }
    
    deinit {
        stop()
    }
}
