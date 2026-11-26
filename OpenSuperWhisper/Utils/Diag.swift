import AppKit
import Foundation
import os

/// Lightweight diagnostic tracing for the record-start / hotkey hot path.
///
/// Why `os.Logger` and not `print`/a file: these lines are written to the
/// unified log immediately, so they **survive a force-quit** of a hung app —
/// exactly the situation we need to diagnose. After a freeze, retrieve them with:
///
///     log show --predicate 'subsystem == "com.noahkagan.rhino"' --last 30m --info --debug
///
/// The key trick for a *hang*: every potentially-blocking call is wrapped so it
/// logs `▶ name` before and `◀ name (Nms)` after. If the app freezes mid-call,
/// you'll find the last `▶` with no matching `◀` — that names the culprit, and
/// it's already on disk.
enum Diag {
    static let log = Logger(subsystem: "com.noahkagan.rhino", category: "hotpath")

    /// On by default in DEBUG (the build used day-to-day). In release, enable with:
    ///   defaults write com.noahkagan.rhino diagnosticLogging -bool YES
    static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return DefaultsStore.current.bool(forKey: "diagnosticLogging")
        #endif
    }

    /// A call that takes longer than this is flagged as a stall risk (`.error`).
    private static let slowThresholdMs: Double = 200

    private static let lock = NSLock()
    private static var inFlight: String?

    static func mark(_ message: String) {
        guard isEnabled else { return }
        log.notice("\(message, privacy: .public)")
    }

    /// Runs `body`, logging entry/exit and elapsed time. Do not nest `measure`
    /// calls — the in-flight name (used by the watchdog) tracks a single level.
    @discardableResult
    static func measure<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
        guard isEnabled else { return try body() }
        setInFlight(name)
        log.notice("▶ \(name, privacy: .public)")
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let ms = Double(DispatchTime.now().uptimeNanoseconds &- start) / 1_000_000
            if ms >= slowThresholdMs {
                log.error("⚠️ \(name, privacy: .public) blocked caller for \(ms, format: .fixed(precision: 0))ms")
            } else {
                log.notice("◀ \(name, privacy: .public) (\(ms, format: .fixed(precision: 0))ms)")
            }
            setInFlight(nil)
        }
        return try body()
    }

    private static func setInFlight(_ name: String?) {
        lock.lock(); inFlight = name; lock.unlock()
    }

    /// The name passed to the innermost active `measure`, or nil. Read by the
    /// watchdog to report what the main thread is stuck on.
    static func currentInFlight() -> String? {
        lock.lock(); defer { lock.unlock() }
        return inFlight
    }
}

/// Detects a frozen main thread. A main-thread timer stamps a heartbeat; a
/// background timer notices when the heartbeat goes stale and logs a `.fault`
/// (with the in-flight operation name) so a freeze is captured even if the
/// begin/end markers around it never get their matching `◀`.
final class MainThreadWatchdog {
    static let shared = MainThreadWatchdog()

    private let stallThresholdNs: UInt64 = 3_000_000_000 // 3s
    private let lock = NSLock()
    private var lastBeatNs = DispatchTime.now().uptimeNanoseconds
    private var reported = false
    private var heartbeatTimer: Timer?
    private var checkTimer: DispatchSourceTimer?

    private init() {}

    func start() {
        guard Diag.isEnabled, checkTimer == nil else { return }

        let beat = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.beat()
        }
        RunLoop.main.add(beat, forMode: .common)
        heartbeatTimer = beat

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "diag.watchdog"))
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.check() }
        checkTimer = timer
        timer.resume()

        Diag.mark("watchdog started")
    }

    /// Runs on the main thread; if it stops running, the main thread is stuck.
    private func beat() {
        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        lastBeatNs = now
        let recovered = reported
        reported = false
        lock.unlock()
        if recovered {
            Diag.log.notice("✅ main thread responsive again")
        }
    }

    private func check() {
        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        let gapNs = now &- lastBeatNs
        let shouldReport = gapNs >= stallThresholdNs && !reported
        if shouldReport { reported = true }
        lock.unlock()

        if shouldReport {
            let op = Diag.currentInFlight() ?? "(unknown)"
            Diag.log.fault("🛑 main thread stalled ≥\(gapNs / 1_000_000_000)s — in-flight: \(op, privacy: .public)")
        }
    }
}

/// Takes thrown away because a key followed the modifier trigger (Fn+↑ and friends; see
/// `ShortcutManager.handleChord`). Counted locally and written to the unified log in every
/// build, so a report of "the bubble turns on, then off" can be checked against it. Only the
/// count, the time of the last one and its delay after the press are kept; never the key.
/// Nothing leaves the Mac unless the user sends the feedback email that quotes the count.
enum ChordDiscards {
    static let countKey = "diag.chordDiscardCount"
    static let lastKey = "diag.chordDiscardLastAt"

    static var count: Int { DefaultsStore.current.integer(forKey: countKey) }

    static func record(msSincePress: Int, at time: Date = Date()) {
        let total = count + 1
        DefaultsStore.current.set(total, forKey: countKey)
        DefaultsStore.current.set(time, forKey: lastKey)
        Diag.log.notice("trigger chord → discard take (\(msSincePress)ms after press, \(total) total)")
    }

    /// One line for the feedback email.
    static var summary: String {
        guard count > 0 else { return "Dictations cancelled as key shortcuts: 0" }
        var line = "Dictations cancelled as key shortcuts: \(count)"
        if let last = DefaultsStore.current.object(forKey: lastKey) as? Date {
            line += " (last \(ISO8601DateFormatter().string(from: last)))"
        }
        return line
    }
}

/// What else on this Mac could be answering the same key press as Rhino: a second Rhino, another
/// dictation app, or Apple Dictation. Each one shows its own indicator and inserts its own copy
/// of the text, which the user reports as "everything is pasted twice" (Mitch, 0.1.56). Read
/// only when the feedback form is sent, and quoted in that email; nothing is stored or sent
/// anywhere else.
enum DictationConflicts {
    /// Dictation apps by the name macOS shows for them (lowercased; a running app matches when
    /// its name contains one).
    static let knownApps = ["wispr flow", "superwhisper", "opensuperwhisper", "macwhisper",
                            "aqua voice", "voiceink", "willow", "monologue", "typeless"]

    /// The names in `running` that are known dictation apps, in order, without repeats.
    static func otherDictationApps(running names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { name in
            let lower = name.lowercased()
            return knownApps.contains(where: lower.contains) && seen.insert(lower).inserted
        }
    }

    /// `enabled`: `AppleDictationAutoEnable` in com.apple.HIToolbox (nil when never set).
    static func appleDictationLine(enabled: Bool?, globeKey: FnGlobeKeySetting.Action) -> String {
        guard let enabled else { return "Apple Dictation: not set up" }
        guard enabled else { return "Apple Dictation: off" }
        return globeKey == .startDictation
            ? "Apple Dictation: on, started by the 🌐 key"
            : "Apple Dictation: on"
    }

    static func lines(rhinoCopies: Int, running names: [String],
                      appleDictation: String) -> [String] {
        let others = otherDictationApps(running: names)
        return [
            "Rhino copies running: \(rhinoCopies)",
            "Other dictation apps running: \(others.isEmpty ? "none" : others.joined(separator: ", "))",
            appleDictation,
        ]
    }

    /// Lines for the feedback email.
    static var summary: [String] {
        let apps = NSWorkspace.shared.runningApplications
        let rhinoIDs = SingleInstanceGuard.competingBundleIDs(for: Bundle.main.bundleIdentifier ?? "")
        let rhinos = apps.filter {
            rhinoIDs.contains($0.bundleIdentifier ?? "") && $0.activationPolicy != .prohibited
        }
        let others = apps.filter { !rhinoIDs.contains($0.bundleIdentifier ?? "") }
            .compactMap(\.localizedName)
        let enabled = CFPreferencesCopyValue("AppleDictationAutoEnable" as CFString,
                                             "com.apple.HIToolbox" as CFString,
                                             kCFPreferencesCurrentUser,
                                             kCFPreferencesAnyHost) as? Bool
        return lines(rhinoCopies: rhinos.count, running: others,
                     appleDictation: appleDictationLine(enabled: enabled,
                                                        globeKey: FnGlobeKeySetting.current))
    }
}
