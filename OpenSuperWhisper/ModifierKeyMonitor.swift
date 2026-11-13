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
    
    /// The device-dependent bit for this side of the modifier (IOKit's NX_DEVICE*KEYMASK).
    /// The generic flag (`cgEventFlag`) is set by either side. Nil for Fn, which has one key.
    var deviceFlagBit: UInt64? {
        switch self {
        case .none, .fn: return nil
        case .leftControl: return 0x0000_0001
        case .leftShift: return 0x0000_0002
        case .rightShift: return 0x0000_0004
        case .leftCommand: return 0x0000_0008
        case .rightCommand: return 0x0000_0010
        case .leftOption: return 0x0000_0020
        case .rightOption: return 0x0000_0040
        case .rightControl: return 0x0000_2000
        }
    }

    /// Both sides' device bits for this modifier's class (e.g. left and right ⌘).
    private var deviceClassBits: UInt64 {
        switch self {
        case .none, .fn: return 0
        case .leftCommand, .rightCommand: return 0x08 | 0x10
        case .leftOption, .rightOption: return 0x20 | 0x40
        case .leftShift, .rightShift: return 0x02 | 0x04
        case .leftControl, .rightControl: return 0x01 | 0x2000
        }
    }

    /// Whether these flags say this exact key is down. Uses the side-specific device bit, so
    /// holding left ⌘ doesn't look like a held right-⌘ trigger. Events that carry no device bits
    /// for the class at all (some synthetic posters) fall back to the generic flag.
    func isHeld(in flags: CGEventFlags) -> Bool {
        guard flags.contains(cgEventFlag) else { return false }
        guard let bit = deviceFlagBit else { return true }
        let raw = flags.rawValue
        if raw & deviceClassBits == 0 { return true }
        return raw & bit != 0
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
    /// When the current press went down (`CGEvent.timestamp`); 0 between presses.
    private var pressTimestamp: CGEventTimestamp = 0
    /// Recent trigger edges as event timestamps, from both taps (deduplicated). The two taps
    /// are separate ports serviced on main, and after a main-thread stall their events come
    /// out of order relative to each other; the key tap also sees flagsChanged so its own
    /// port is in order. Key-downs are matched to presses by timestamp, not by arrival.
    private var edges: [UInt16: TriggerEdges] = [:]
    /// A press the key tap already saw chorded before the flags tap handled that press.
    private var pendingChordPress: CGEventTimestamp?

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
            // flagsChanged too: it shares this port with the key-downs, so a trigger release
            // is always seen before a key-down that came after it.
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue)
                | CGEventMask(1 << CGEventType.flagsChanged.rawValue),
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
                } else if type == .flagsChanged {
                    monitor.recordEdge(event: event)
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
        pressTimestamp = 0
        edges = [:]
        pendingChordPress = nil
        print("ModifierKeyMonitor: Stopped")
    }
    
    fileprivate func reenableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            print("ModifierKeyMonitor: Re-enabled tap after timeout")
        }
    }
    
    /// A trigger edge seen by either tap. Returns the watched key and whether it is now down.
    @discardableResult
    private func recordEdge(event: CGEvent) -> (key: ModifierKey, isPressed: Bool)? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard let key = watched[keyCode] else { return nil }
        let isPressed = key.isHeld(in: event.flags)
        edges[keyCode, default: TriggerEdges()].record(isPressed: isPressed, at: event.timestamp)
        return (key, isPressed)
    }

    private func handleFlagsChanged(event: CGEvent) {
        guard let (key, isPressed) = recordEdge(event: event) else { return }

        if isPressed, pressedKey == nil {
            // A second modifier pressed mid-recording is ignored: the first owns this take.
            pressedKey = key
            pressTimestamp = event.timestamp
            // The key tap may already have seen this press chorded (it ran first after a stall).
            pressChorded = pendingChordPress == event.timestamp
            pendingChordPress = nil
            setKeyTap(enabled: true)
            let chorded = pressChorded
            DispatchQueue.main.async {
                self.onKeyDown?(key)
                if chorded { self.onChord?() }
            }
        } else if !isPressed, pressedKey == key {
            pressedKey = nil
            pressTimestamp = 0
            setKeyTap(enabled: false)
            DispatchQueue.main.async {
                self.onKeyUp?(key)
            }
        }
    }

    /// A key went down while a trigger is held. Privacy: keys are only counted here, never
    /// recorded — the key code is compared to the cancel shortcut's and never stored or logged.
    private func handleKeyDown(event: CGEvent) {
        guard let held = pressedKey else { return }
        guard Self.keyDownCountsAsChord(
            isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            cancelKeyCode: KeyboardShortcuts.getShortcut(for: .escape).map { Int64($0.carbonKeyCode) },
            sourcePID: event.getIntegerValueField(.eventSourceUnixProcessID),
            ownPID: Int64(getpid()),
            triggerHeldInEvent: held.isHeld(in: event.flags)) else { return }
        // Which press was held when this key went down, by timestamp.
        guard let owner = edges[held.keyCode]?.pressHolding(at: event.timestamp) else { return }
        switch Self.chordTarget(owner: owner, currentPress: pressTimestamp) {
        case .current:
            guard !pressChorded else { return }
            pressChorded = true
            DispatchQueue.main.async {
                self.onChord?()
            }
        case .upcoming:
            // The flags tap hasn't handled this press yet; charge it there, after its onKeyDown.
            pendingChordPress = owner
        case .stale:
            return
        }
    }

    enum ChordTarget: Equatable { case current, upcoming, stale }

    /// Where a chord for the press that went down at `owner` goes, given the press the flags
    /// tap is on (`currentPress`, 0 if none). A key-down from a quick second tap must not
    /// discard the first tap's take, and must still mark the second press.
    static func chordTarget(owner: CGEventTimestamp, currentPress: CGEventTimestamp) -> ChordTarget {
        if owner == currentPress { return .current }
        return owner > currentPress ? .upcoming : .stale
    }

    /// The Globe (fn) key's own key code. Some keyboards send it as a keyDown alongside the
    /// Fn press; that is part of pressing the trigger, not a shortcut.
    static let globeKeyCode: Int64 = 179

    /// Whether a key-down during a trigger press counts as a chord. Which press it belongs to,
    /// if any, is decided separately by timestamp (`TriggerEdges.pressHolding`).
    /// - Rhino's own synthetic keys (typed text, ⌘V, Return) are skipped: they land after a
    ///   release, possibly while the next take's trigger is already held.
    /// - Other apps' synthetic keys (text expanders, automation) can still count: nothing in a
    ///   CGEvent reliably tells them from a keyboard. They count only if their flags show the
    ///   trigger down, as a real key typed during the hold would.
    /// - Autorepeat of a key held before the trigger is not a new press.
    /// - The cancel shortcut's key (Esc by default) is left to that flow, with its long-take
    ///   confirmation, rather than discarding first and racing it.
    /// - `triggerHeldInEvent`: the key-down's flags show this side of the trigger down (device
    ///   bits, so left ⌘+C doesn't chord a right-⌘ take). This is a cheap filter, not the
    ///   ordering guarantee: with Fn as the trigger, macOS sets the Fn flag on arrows,
    ///   Home/End/Page keys, forward delete and F-keys even when Fn is up. The timestamp
    ///   match in `TriggerEdges` is what keeps a key-down from after a release off that press.
    /// - The Globe key is never a chord. (Modifier keys arrive as flagsChanged, never keyDown,
    ///   so the trigger's own key code needs no check.)
    static func keyDownCountsAsChord(isAutorepeat: Bool, keyCode: Int64, cancelKeyCode: Int64?,
                                     sourcePID: Int64, ownPID: Int64,
                                     triggerHeldInEvent: Bool) -> Bool {
        guard sourcePID != ownPID, triggerHeldInEvent, keyCode != globeKeyCode else { return false }
        return !isAutorepeat && keyCode != cancelKeyCode
    }
    
    deinit {
        stop()
    }
}

/// The trigger's recent presses and releases by event timestamp, so a key-down can be matched
/// to the press that was held when it happened, whatever order the two taps deliver in.
struct TriggerEdges {
    private(set) var presses: [CGEventTimestamp] = []
    private(set) var releases: [CGEventTimestamp] = []
    private static let keep = 8

    mutating func record(isPressed: Bool, at time: CGEventTimestamp) {
        if isPressed { Self.insert(time, into: &presses) } else { Self.insert(time, into: &releases) }
    }

    private static func insert(_ time: CGEventTimestamp, into list: inout [CGEventTimestamp]) {
        guard !list.contains(time) else { return } // both taps report the same event
        list.append(time)
        list.sort()
        if list.count > keep { list.removeFirst(list.count - keep) }
    }

    /// The press held at `time`: the latest press at or before it with no release between.
    /// Nil if the trigger was up then (or the press is too old to know).
    func pressHolding(at time: CGEventTimestamp) -> CGEventTimestamp? {
        guard let press = presses.last(where: { $0 <= time }) else { return nil }
        if releases.contains(where: { $0 > press && $0 <= time }) { return nil }
        return press
    }
}
