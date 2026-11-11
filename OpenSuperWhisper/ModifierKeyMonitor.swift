import AppKit
import Carbon
import Foundation

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
    /// Modifiers being watched, by key code. More than one so a second modifier can mean
    /// "dictate and submit" alongside the plain record trigger (#50).
    private var watched: [UInt16: ModifierKey] = [:]
    private var pressedKey: ModifierKey?
    /// Whether a non-modifier key went down during the current press (see `handleKeyDown`).
    private var pressChorded = false

    var onKeyDown: ((ModifierKey) -> Void)?
    var onKeyUp: ((ModifierKey) -> Void)?
    /// A non-modifier key went down while the trigger was held: the press is a shortcut such as
    /// Fn+↑ (Page Up), Fn+Delete or Fn+F5, not dictation. Fires at most once per press, on main,
    /// after that press's `onKeyDown` and before its `onKeyUp`.
    var onChord: ((ModifierKey) -> Void)?
    
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
        
        // keyDown is only there to spot chords while a trigger is held. Still listen-only:
        // nothing is ever swallowed or delayed.
        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
        
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
                
                if type == .keyDown {
                    monitor.handleKeyDown(event: event)
                } else {
                    monitor.handleFlagsChanged(event: event)
                }
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
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
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
            DispatchQueue.main.async {
                self.onKeyDown?(key)
            }
        } else if !isPressed, pressedKey == key {
            pressedKey = nil
            DispatchQueue.main.async {
                self.onKeyUp?(key)
            }
        }
    }

    /// A key went down somewhere. Privacy: keys are only counted here, never recorded — the
    /// key code is read solely to leave Esc to the cancel shortcut, and is never stored or logged.
    private func handleKeyDown(event: CGEvent) {
        guard let key = pressedKey, !pressChorded else { return }
        guard Self.keyDownCountsAsChord(
            isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            isEscape: event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Escape),
            sourcePID: event.getIntegerValueField(.eventSourceUnixProcessID),
            sourceStateID: event.getIntegerValueField(.eventSourceStateID),
            ownPID: Int64(getpid())) else { return }
        pressChorded = true
        DispatchQueue.main.async {
            self.onChord?(key)
        }
    }
    
    /// Whether a key-down during a trigger press is a person's chord. Only a key physically
    /// typed counts:
    /// - Rhino's own synthetic keys (typed text, ⌘V, Return) land after a release, possibly
    ///   while the next take's trigger is already held; they must not cancel that take.
    /// - Other apps' synthetic keys (text expanders, automation) don't come from the HID
    ///   system state; real keyboards, including virtual HID devices like Karabiner's, do.
    /// - Autorepeat of a key held before the trigger is not a new press.
    /// - Esc while recording is the cancel shortcut, with its own long-take confirmation:
    ///   leave it to that flow rather than discarding first and racing it.
    static func keyDownCountsAsChord(isAutorepeat: Bool, isEscape: Bool, sourcePID: Int64,
                                     sourceStateID: Int64, ownPID: Int64) -> Bool {
        guard sourcePID != ownPID else { return false }
        guard sourceStateID == Int64(CGEventSourceStateID.hidSystemState.rawValue) else { return false }
        return !isAutorepeat && !isEscape
    }

    deinit {
        stop()
    }
}
