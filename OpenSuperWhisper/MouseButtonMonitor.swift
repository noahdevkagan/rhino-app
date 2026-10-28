import AppKit
import ApplicationServices
import Foundation

/// Watches the extra mouse buttons (middle, side 4/5) chosen as recording triggers, with the
/// same down/up callbacks as ModifierKeyMonitor so ShortcutManager gives them identical
/// hold-to-talk / tap / double-tap-lock semantics.
///
/// The tap exists only while at least one mouse-button trigger is configured, and it only ever
/// swallows the configured buttons (`MouseButtonPressTracker`). Every other button, including
/// the middle button when it isn't a trigger, passes straight through.
///
/// Swallowing the trigger button needs an active (filtering) tap, which macOS allows with
/// Accessibility, the grant Rhino already holds to insert text. With only an older Input
/// Monitoring grant the tap falls back to listen-only: the trigger still works, but the
/// button's normal action (paste in a terminal, browser Back) also happens.
///
/// The tap runs on its own thread and run loop. An active tap holds every middle/side click
/// and drag system-wide until its callback returns, so it must never wait on a busy main
/// thread. Only the trigger callbacks hop to main.
final class MouseButtonMonitor {
    static let shared = MouseButtonMonitor()

    /// Called on the main thread.
    var onButtonDown: ((Int) -> Void)?
    var onButtonUp: ((Int) -> Void)?

    /// Main-thread only. Events from a session that is no longer current are dropped.
    private var session: MouseButtonTapSession?

    private init() {}

    func start(buttons: [Int]) {
        stop()
        let valid = Set(buttons.filter(MouseButtonTrigger.isValid))
        guard !valid.isEmpty else { return }

        guard GlobalEventListeningAccess.current else {
            print("MouseButtonMonitor: Accessibility is required for mouse-button triggers")
            return
        }

        let newSession = MouseButtonTapSession(watched: valid)
        newSession.onTransition = { [weak self, weak newSession] transition in
            DispatchQueue.main.async {
                guard let self, let newSession, self.session === newSession else { return }
                switch transition {
                case .down(let number): self.onButtonDown?(number)
                case .up(let number): self.onButtonUp?(number)
                }
            }
        }
        guard newSession.start(active: AXIsProcessTrusted()) else {
            print("MouseButtonMonitor: Failed to create event tap. Check Accessibility permission.")
            return
        }
        session = newSession
        print("MouseButtonMonitor: Watching buttons \(valid.sorted()) (consumes: \(newSession.consumes))")
    }

    /// Tears the tap down. If a trigger button is still held, its release is delivered now, so
    /// a hold-to-talk take can't stay on because the tap went away mid-press (settings change,
    /// re-recording the trigger).
    func stop() {
        guard let current = session else { return }
        session = nil
        if let held = current.stop() {
            onButtonUp?(held)
        }
        print("MouseButtonMonitor: Stopped")
    }

    deinit {
        _ = session?.stop()
    }
}

/// One tap on one dedicated thread. Created per `start`, discarded on `stop`.
private final class MouseButtonTapSession {
    let watched: Set<Int>
    var onTransition: ((MouseButtonPressTracker.Transition) -> Void)?
    private(set) var consumes = false

    private let lock = NSLock()
    private var tracker = MouseButtonPressTracker()
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var thread: Thread?
    private var installed = false

    init(watched: Set<Int>) {
        self.watched = watched
    }

    /// Builds the tap on its own thread and waits until it is installed (or failed).
    func start(active: Bool) -> Bool {
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            let ok = self.install(active: active)
            let loop = CFRunLoopGetCurrent()
            self.lock.lock()
            self.runLoop = loop
            self.installed = ok
            self.lock.unlock()
            ready.signal()
            guard ok else { return }
            CFRunLoopRun()
        }
        thread.name = "com.noahkagan.rhino.mouse-trigger-tap"
        thread.qualityOfService = .userInteractive
        self.thread = thread
        thread.start()
        ready.wait()
        lock.lock()
        defer { lock.unlock() }
        return installed
    }

    /// Runs on the tap thread.
    private func install(active: Bool) -> Bool {
        let eventMask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let session = Unmanaged<MouseButtonTapSession>.fromOpaque(refcon).takeUnretainedValue()
            return session.handle(type: type, event: event)
        }

        // Prefer an active tap so the trigger button doesn't also paste / navigate back.
        var created = active ? CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                                 options: .defaultTap, eventsOfInterest: eventMask,
                                                 callback: callback, userInfo: userInfo) : nil
        consumes = created != nil
        if created == nil {
            created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                        options: .listenOnly, eventsOfInterest: eventMask,
                                        callback: callback, userInfo: userInfo)
        }
        guard let created, let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0) else {
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        lock.lock()
        tap = created
        lock.unlock()
        return true
    }

    /// Stops the tap thread's run loop and invalidates the port. Returns the button that was
    /// holding a take, if any.
    func stop() -> Int? {
        lock.lock()
        let tap = self.tap
        let loop = self.runLoop
        self.tap = nil
        self.runLoop = nil
        let held = tracker.reset()
        onTransition = nil
        lock.unlock()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let loop {
            CFRunLoopStop(loop)
        }
        thread = nil
        return held
    }

    /// Runs on the tap thread. Must stay fast: an active tap holds the click until it returns.
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lock.lock()
            let tap = self.tap
            lock.unlock()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let phase: MouseButtonPressTracker.Phase
        switch type {
        case .otherMouseDown: phase = .down
        case .otherMouseUp: phase = .up
        case .otherMouseDragged: phase = .drag
        default: return Unmanaged.passUnretained(event)
        }

        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        lock.lock()
        let live = self.tap != nil
        let outcome = live
            ? tracker.handle(buttonNumber: button, phase: phase, watched: watched)
            : MouseButtonPressTracker.Outcome(transition: nil, swallow: false)
        let deliver = onTransition
        lock.unlock()

        if let transition = outcome.transition {
            deliver?(transition)
        }
        return outcome.swallow && consumes ? nil : Unmanaged.passUnretained(event)
    }
}
