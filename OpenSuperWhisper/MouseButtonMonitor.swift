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

    enum Phase { case down, up }

    /// Fixed for the tracker's life: the monitor builds a new tracker (and tap) when the trigger
    /// list changes, so the tap thread can read this without a lock.
    let watched: Set<MouseButton>
    /// The button that owns the current take. A second watched button pressed meanwhile is
    /// swallowed but ignored: switching intent halfway would be ambiguous.
    private(set) var pressed: MouseButton?

    init(watched: Set<MouseButton> = [], pressed: MouseButton? = nil) {
        self.watched = watched
        self.pressed = pressed.flatMap { watched.contains($0) ? $0 : nil }
    }

    /// Cheap pre-check the tap callback runs before taking any lock: an event for any button that
    /// isn't a configured trigger goes straight back to the system.
    func watches(buttonNumber: Int) -> Bool {
        guard let button = MouseButton(number: buttonNumber) else { return false }
        return watched.contains(button)
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
        case .up:
            guard pressed == button else { return Outcome(edge: nil, consume: true) }
            pressed = nil
            return Outcome(edge: .up(button), consume: true)
        }
    }

    /// After a gap in which events may have been missed (macOS disabled the tap for a moment):
    /// if the held button is no longer physically down, its release was lost, so report it now.
    /// If it is still down, keep the take; its real release will arrive as usual.
    mutating func reconcile(isDown: (MouseButton) -> Bool) -> Edge? {
        guard let held = pressed, !isDown(held) else { return nil }
        pressed = nil
        return .up(held)
    }

    /// A tap rebuild (settings change, trust change) with `held` down on the old tap: keep the
    /// take on the new tap when the button is still a trigger and still physically down, else
    /// return its release. `watched` empty (or no tap could be built) means the trigger is gone.
    static func carryOver(held: MouseButton?, into watched: Set<MouseButton>,
                          isDown: (MouseButton) -> Bool) -> (pressed: MouseButton?, release: Edge?) {
        guard let held else { return (nil, nil) }
        if watched.contains(held), isDown(held) { return (held, nil) }
        return (nil, .up(held))
    }

    /// The tap is going away. Hands back the release of a held button so the caller can end the
    /// take (or carry it into the next tap) instead of stranding it.
    mutating func release() -> Edge? {
        guard let held = pressed else { return nil }
        pressed = nil
        return .up(held)
    }
}

/// Watches the configured extra mouse buttons system-wide with a CGEvent tap and reports
/// presses and releases on main.
///
/// Permissions: no new one. With Accessibility (which Rhino already needs to insert text) the
/// tap is active and swallows the trigger button so it doesn't also fire Back/Forward or a
/// middle-click paste in the app under the pointer. With only an Input Monitoring grant, the tap
/// is listen-only: the trigger still works, but the button's normal action happens too. Trust is
/// re-checked every few seconds and on tap-disabled events, so a grant or revoke mid-run rebuilds
/// the tap without a relaunch.
///
/// Latency: the tap asks only for other-button down and up (no drags, no left/right clicks, no
/// movement) and runs on its own thread with its own run loop, never main. The callback decides
/// from the tap's own state under a lock and hops to main only to report an edge, so a busy main
/// thread never delays a middle click or makes macOS time the tap out.
final class MouseButtonMonitor {
    static let shared = MouseButtonMonitor()

    /// How often a live monitor compares Accessibility trust with the tap it built.
    static let trustCheckInterval: TimeInterval = 3

    private var tap: TapContext?
    private var trustTimer: Timer?
    private var currentButtons: [MouseButton] = []

    /// Whether the live tap can swallow events (active) or only observe them.
    var swallows: Bool { tap?.swallows ?? false }

    var onButtonDown: ((MouseButton) -> Void)?
    var onButtonUp: ((MouseButton) -> Void)?

    /// Physical button state. The tracker takes it as a closure, so tests inject their own.
    /// `.hidSystemState` is the hardware state, read before any event tap: the session state
    /// may not count a press our own active tap swallowed, which would end a take mid-hold.
    static func isPhysicallyDown(_ button: MouseButton) -> Bool {
        guard let cgButton = CGMouseButton(rawValue: UInt32(button.number)) else { return false }
        return CGEventSource.buttonState(.hidSystemState, button: cgButton)
    }

    private init() {}

    /// Builds (or rebuilds) the tap for `mouseButtons`. A button held across the rebuild keeps its
    /// take when it is still a trigger and still down; otherwise its release is delivered, so
    /// changing settings mid-hold never leaves a take recording after the button is let go.
    func start(mouseButtons: [MouseButton]) {
        precondition(Thread.isMainThread)
        let held = teardown()
        currentButtons = mouseButtons
        let canSwallow = AXIsProcessTrusted()
        let canTap = !mouseButtons.isEmpty && (canSwallow || CGPreflightListenEventAccess())
        let carry = MouseTriggerTracker.carryOver(held: held,
                                                  into: canTap ? Set(mouseButtons) : [],
                                                  isDown: Self.isPhysicallyDown)
        if let release = carry.release { deliver(release) }
        guard !mouseButtons.isEmpty else { return }
        guard canTap else {
            print("MouseButtonMonitor: Accessibility is required for a mouse-button trigger")
            startTrustTimer()
            return
        }

        let context = TapContext(tracker: MouseTriggerTracker(watched: Set(mouseButtons), pressed: carry.pressed),
                                 swallows: canSwallow,
                                 monitor: self)
        guard context.open() else {
            print("MouseButtonMonitor: Failed to create event tap")
            if let carried = carry.pressed { deliver(.up(carried)) }
            // Keep checking: recheckTrust() retries the build while no tap exists.
            startTrustTimer()
            return
        }
        tap = context
        // A release in the gap between the old tap closing and this one going live was seen by
        // neither; settle it now so the carried take can't be stranded.
        context.settle()
        startTrustTimer()
        print("MouseButtonMonitor: Started (\(mouseButtons.map(\.displayName).joined(separator: ", ")), swallow: \(canSwallow))")
    }

    /// Removes the tap. A held trigger button's release is delivered so no take is stranded.
    func stop() {
        precondition(Thread.isMainThread)
        currentButtons = []
        if let held = teardown() { deliver(.up(held)) }
    }

    /// Closes the tap and stops the trust timer; returns the button that was held, if any.
    @discardableResult
    private func teardown() -> MouseButton? {
        trustTimer?.invalidate()
        trustTimer = nil
        guard let context = tap else { return nil }
        tap = nil
        let held = context.close()
        print("MouseButtonMonitor: Stopped")
        return held
    }

    fileprivate func deliver(_ edge: MouseTriggerTracker.Edge) {
        // Always async, even from main: the handler then runs after anything already queued
        // (FIFO with edges from the tap thread) and never re-enters a settings rebuild.
        DispatchQueue.main.async { [weak self] in
            switch edge {
            case .down(let button): self?.onButtonDown?(button)
            case .up(let button): self?.onButtonUp?(button)
            }
        }
    }

    /// Rebuilds the tap when Accessibility trust no longer matches it: granted later (the tap
    /// should start swallowing, so the button stops also going Back) or revoked (an active tap
    /// must not linger; fall back to listen-only or none). Waits while a take's button is held so
    /// the rebuild can't split one press across two taps. Never prompts.
    fileprivate func recheckTrust() {
        precondition(Thread.isMainThread)
        guard !currentButtons.isEmpty else { return }
        // Settle first: a take whose release was lost (tap died mid-hold) must not block the
        // rebuild forever. Only a button that is really still down defers it.
        if let tap {
            tap.settle()
            if tap.tracker.pressed != nil { return }
        }
        let trusted = AXIsProcessTrusted()
        let wantsTap = trusted || CGPreflightListenEventAccess()
        let mismatch = tap.map { $0.swallows != trusted } ?? wantsTap
        if mismatch {
            print("MouseButtonMonitor: Accessibility trust changed (trusted: \(trusted)); rebuilding tap")
            start(mouseButtons: currentButtons)
        }
    }

    private func startTrustTimer() {
        trustTimer?.invalidate()
        let timer = Timer(timeInterval: Self.trustCheckInterval, repeats: true) { [weak self] _ in
            self?.recheckTrust()
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        trustTimer = timer
    }
}

/// One tap and its thread. Everything the callback touches lives here, so a rebuild never races
/// a callback still running on the old tap's thread.
private final class TapContext {
    let swallows: Bool
    private weak var monitor: MouseButtonMonitor?
    private let lock = NSLock()
    private var _tracker: MouseTriggerTracker
    private var alive = true
    /// Unlocked pre-check: the watched set never changes for this tap.
    private let watchedNumbers: Set<Int>

    /// Set once in `open()` before the run loop source is added, never cleared, so the tap
    /// thread can read them without the lock.
    private var machPort: CFMachPort?
    private var runLoop: CFRunLoop?

    init(tracker: MouseTriggerTracker, swallows: Bool, monitor: MouseButtonMonitor) {
        _tracker = tracker
        watchedNumbers = Set(tracker.watched.map(\.number))
        self.swallows = swallows
        self.monitor = monitor
    }

    var tracker: MouseTriggerTracker {
        lock.lock(); defer { lock.unlock() }
        return _tracker
    }

    /// Creates the tap and starts its thread; returns once the tap is live.
    func open() -> Bool {
        let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: swallows ? .defaultTap : .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let context = Unmanaged<TapContext>.fromOpaque(refcon).takeUnretainedValue()
                return context.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        machPort = port

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            machPort = nil
            return false
        }
        let ready = DispatchSemaphore(value: 0)
        // The thread holds the context strongly until its run loop stops, so the callback's
        // unretained refcon stays valid for as long as it can fire.
        let thread = Thread { [self] in
            let loop = CFRunLoopGetCurrent()
            self.runLoop = loop
            CFRunLoopAddSource(loop, source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            ready.signal()
            CFRunLoopRun()
            CFRunLoopRemoveSource(loop, source, .commonModes)
        }
        thread.name = "Rhino mouse trigger tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return true
    }

    /// Delivers the release of a held button that is no longer physically down.
    func settle() {
        lock.lock()
        defer { lock.unlock() }
        guard alive else { return }
        if let edge = _tracker.reconcile(isDown: MouseButtonMonitor.isPhysicallyDown) {
            monitor?.deliver(edge)
        }
    }

    /// Stops the tap and its thread; returns the button that was held, if any. After this the
    /// callback passes every event through and reports nothing.
    func close() -> MouseButton? {
        lock.lock()
        alive = false
        let held: MouseButton?
        if case .up(let button)? = _tracker.release() { held = button } else { held = nil }
        lock.unlock()

        if let machPort {
            CGEvent.tapEnable(tap: machPort, enable: false)
            CFMachPortInvalidate(machPort)
        }
        if let runLoop { CFRunLoopStop(runLoop) }
        return held
    }

    /// Runs on the tap thread. Keep it short: every middle/side click system-wide waits on it.
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let phase: MouseTriggerTracker.Phase
        switch type {
        case .otherMouseDown: phase = .down
        case .otherMouseUp: phase = .up
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            recoverFromDisable()
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }

        let number = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        guard watchedNumbers.contains(number) else { return Unmanaged.passUnretained(event) }

        lock.lock()
        guard alive else {
            lock.unlock()
            return Unmanaged.passUnretained(event)
        }
        let outcome = _tracker.handle(phase, buttonNumber: number)
        // Queued inside the lock so a concurrent close() can't also hand back this release.
        if let edge = outcome.edge { monitor?.deliver(edge) }
        lock.unlock()
        return outcome.consume && swallows ? nil : Unmanaged.passUnretained(event)
    }

    /// macOS turned the tap off (slow callback, or secure input). Turn it back on, then settle a
    /// release that may have happened while it was off, and let main re-check trust: a revoked
    /// Accessibility grant also shows up here.
    private func recoverFromDisable() {
        lock.lock()
        defer { lock.unlock() }
        guard alive, let machPort else { return }
        CGEvent.tapEnable(tap: machPort, enable: true)
        if let edge = _tracker.reconcile(isDown: MouseButtonMonitor.isPhysicallyDown) {
            monitor?.deliver(edge)
        }
        DispatchQueue.main.async { [weak monitor] in monitor?.recheckTrust() }
    }
}
