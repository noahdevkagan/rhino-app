import AppKit
import ApplicationServices
import Foundation

/// Watches the extra mouse buttons (middle, side 4/5) chosen as recording triggers, with the
/// same down/up callbacks as ModifierKeyMonitor so ShortcutManager gives them identical
/// hold-to-talk / tap / double-tap-lock semantics.
///
/// The tap exists only while at least one mouse-button trigger is configured, and it only ever
/// swallows the configured buttons (`MouseButtonTrigger.shouldConsume`). Every other button,
/// including the middle button when it isn't a trigger, passes straight through.
///
/// Swallowing the trigger button needs an active (filtering) tap, which macOS allows with
/// Accessibility, the grant Rhino already holds to insert text. With only an older Input
/// Monitoring grant the tap falls back to listen-only: the trigger still works, but the
/// button's normal action (paste in a terminal, browser Back) also happens.
final class MouseButtonMonitor {
    static let shared = MouseButtonMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    /// Read on the tap callback, which runs on the main run loop like every other access.
    private var watched: Set<Int> = []
    private var tracker = MouseButtonPressTracker()
    private var consumes = false

    var onButtonDown: ((Int) -> Void)?
    var onButtonUp: ((Int) -> Void)?

    private init() {}

    func start(buttons: [Int]) {
        stop()
        let valid = Set(buttons.filter(MouseButtonTrigger.isValid))
        guard !valid.isEmpty else { return }

        guard GlobalEventListeningAccess.current else {
            print("MouseButtonMonitor: Accessibility is required for mouse-button triggers")
            return
        }

        watched = valid
        tracker.reset()

        let eventMask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)

        // Prefer an active tap so the trigger button doesn't also paste / navigate back; fall
        // back to listen-only when only Input Monitoring is granted.
        let wantsActive = AXIsProcessTrusted()
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<MouseButtonMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }

        var tap = wantsActive ? CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                                  options: .defaultTap, eventsOfInterest: eventMask,
                                                  callback: callback, userInfo: userInfo) : nil
        consumes = tap != nil
        if tap == nil {
            tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                    options: .listenOnly, eventsOfInterest: eventMask,
                                    callback: callback, userInfo: userInfo)
        }
        guard let tap else {
            print("MouseButtonMonitor: Failed to create event tap. Check Accessibility permission.")
            watched = []
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("MouseButtonMonitor: Watching buttons \(valid.sorted()) (consumes: \(consumes))")
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            print("MouseButtonMonitor: Stopped")
        }
        eventTap = nil
        runLoopSource = nil
        watched = []
        tracker.reset()
        consumes = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        // Unwatched buttons are never touched: this is what keeps normal middle-clicks alive.
        guard MouseButtonTrigger.shouldConsume(buttonNumber: button, watched: watched) else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .otherMouseDown:
            if case .down(let number) = tracker.handle(buttonNumber: button, isDown: true, watched: watched) {
                DispatchQueue.main.async { self.onButtonDown?(number) }
            }
        case .otherMouseUp:
            if case .up(let number) = tracker.handle(buttonNumber: button, isDown: false, watched: watched) {
                DispatchQueue.main.async { self.onButtonUp?(number) }
            }
        default:
            break // drags of the held trigger button: swallowed with the rest of the press
        }
        return consumes ? nil : Unmanaged.passUnretained(event)
    }

    deinit {
        stop()
    }
}
