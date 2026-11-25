import AppKit
import ApplicationServices
import Foundation

/// An extra mouse button used as a dictate trigger: the middle button (wheel click) or a side /
/// thumb button. Left and right click can never be one: a trigger on either would start a
/// dictation on every ordinary click, so `init?(number:)` refuses them.
///
/// `number` is the button number macOS reports (`CGEvent`'s `.mouseEventButtonNumber`,
/// `NSEvent.buttonNumber`): zero-based, so 0 = left, 1 = right, 2 = middle, 3+ = extra buttons.
/// Labels use the common one-based convention a mouse's own software prints ("Mouse 4").
struct MouseButton: Hashable {
    let number: Int

    /// Highest button number the event APIs report (32 buttons, 0–31).
    static let maxNumber = 31
    static let middle = MouseButton(uncheckedNumber: 2)

    init?(number: Int) {
        guard Self.isAllowed(number: number) else { return nil }
        self.number = number
    }

    private init(uncheckedNumber: Int) { number = uncheckedNumber }

    /// Left (0) and right (1) are never triggers; neither is anything out of range.
    static func isAllowed(number: Int) -> Bool {
        (2...maxNumber).contains(number)
    }

    /// Cap label in Settings and the inline hint ("Hold Mouse 4 to talk").
    var displayName: String {
        number == 2 ? "Middle button" : "Mouse \(number + 1)"
    }

    // MARK: - Storage

    /// The stored spelling: "middle", "button4", "button5", … — the format the pre-cut
    /// implementation used, so it reads the same way if one ever turns up.
    var storageKey: String {
        number == 2 ? "middle" : "button\(number + 1)"
    }

    init?(storageKey: String) {
        if storageKey == "middle" {
            self.init(number: 2)
            return
        }
        guard storageKey.hasPrefix("button"),
              let oneBased = Int(storageKey.dropFirst("button".count)) else { return nil }
        self.init(number: oneBased - 1)
    }
}

extension MouseButton: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let button = MouseButton(storageKey: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Not a trigger button: \(raw)"))
        }
        self = button
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageKey)
    }
}

/// Press/release bookkeeping for the mouse tap, kept pure so it is testable: which events are
/// trigger edges, and which the tap should swallow.
struct MouseTriggerTracker {
    enum Edge: Equatable { case down(MouseButton), up(MouseButton) }

    struct Outcome: Equatable {
        /// Report this edge to the trigger handler, if any.
        var edge: Edge?
        /// Whether the event belongs to a watched button and should not reach the app under the
        /// pointer (so Mouse 4 doesn't also go Back in a browser). Only honoured by an active tap.
        var consume: Bool

        static let passThrough = Outcome(edge: nil, consume: false)
    }

    enum Phase { case down, dragged, up }

    var watched: Set<MouseButton> = []
    /// The button that owns the current take. A second watched button pressed meanwhile is
    /// swallowed but ignored: switching intent halfway would be ambiguous.
    private(set) var pressed: MouseButton?

    init(watched: Set<MouseButton> = []) {
        self.watched = watched
    }

    mutating func handle(_ phase: Phase, buttonNumber: Int) -> Outcome {
        guard let button = MouseButton(number: buttonNumber), watched.contains(button) else {
            return .passThrough
        }
        switch phase {
        case .down:
            guard pressed == nil else { return Outcome(edge: nil, consume: true) }
            pressed = button
            return Outcome(edge: .down(button), consume: true)
        case .dragged:
            // A drag with no down would confuse the app under the pointer, so it goes too.
            return Outcome(edge: nil, consume: true)
        case .up:
            guard pressed == button else { return Outcome(edge: nil, consume: true) }
            pressed = nil
            return Outcome(edge: .up(button), consume: true)
        }
    }

    mutating func reset() {
        pressed = nil
    }
}

/// Watches the configured extra mouse buttons system-wide with a CGEvent tap and reports
/// presses and releases on main.
///
/// Permissions: no new one. With Accessibility (which Rhino already needs to insert text) the
/// tap is active, like `UserPasteWatcher`'s, and swallows the trigger button so it doesn't also
/// fire Back/Forward or a middle-click paste in the app under the pointer. With only an Input
/// Monitoring grant, the tap is listen-only: the trigger still works, but the button's normal
/// action happens too. The tap only asks for other-button events, so ordinary left/right clicks
/// and pointer movement never pass through Rhino.
final class MouseButtonMonitor {
    static let shared = MouseButtonMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tracker = MouseTriggerTracker()
    /// Whether the live tap can swallow events (active) or only observe them.
    private(set) var swallows = false

    var onButtonDown: ((MouseButton) -> Void)?
    var onButtonUp: ((MouseButton) -> Void)?

    private init() {}

    func start(mouseButtons: [MouseButton]) {
        stop()
        guard !mouseButtons.isEmpty else { return }

        let canSwallow = AXIsProcessTrusted()
        guard canSwallow || CGPreflightListenEventAccess() else {
            print("MouseButtonMonitor: Accessibility is required for a mouse-button trigger")
            return
        }
        tracker = MouseTriggerTracker(watched: Set(mouseButtons))

        let eventMask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: canSwallow ? .defaultTap : .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<MouseButtonMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("MouseButtonMonitor: Failed to create event tap")
            return
        }

        eventTap = tap
        swallows = canSwallow
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("MouseButtonMonitor: Started (\(mouseButtons.map(\.displayName).joined(separator: ", ")), swallow: \(canSwallow))")
        }
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            print("MouseButtonMonitor: Stopped")
        }
        eventTap = nil
        runLoopSource = nil
        swallows = false
        tracker = MouseTriggerTracker()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let phase: MouseTriggerTracker.Phase
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS turns off a tap it thinks is slow; a release may have been missed meanwhile.
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            tracker.reset()
            return Unmanaged.passUnretained(event)
        case .otherMouseDown: phase = .down
        case .otherMouseDragged: phase = .dragged
        case .otherMouseUp: phase = .up
        default: return Unmanaged.passUnretained(event)
        }

        let outcome = tracker.handle(phase,
                                     buttonNumber: Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        switch outcome.edge {
        case .down(let button):
            DispatchQueue.main.async { self.onButtonDown?(button) }
        case .up(let button):
            DispatchQueue.main.async { self.onButtonUp?(button) }
        case nil:
            break
        }
        return outcome.consume && swallows ? nil : Unmanaged.passUnretained(event)
    }

    deinit {
        stop()
    }
}
