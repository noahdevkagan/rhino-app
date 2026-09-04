import AppKit
import Foundation
import Darwin

/// Makes sure only one copy of Rhino is running.
///
/// Two live instances is the "every dictation pastes twice" bug: both hold an event tap on the
/// trigger key, both record the mic (macOS happily shares it), both transcribe, and both insert —
/// so the user sees duplicate output on every dictation until one of them is quit. It happens in
/// the wild more easily than it sounds: an old instance that failed to exit during a Sparkle
/// update relaunch, or a second copy of the app run from Downloads / a mounted DMG / a dev build
/// while the installed one is already up (LaunchServices only dedupes launches of the same bundle
/// *path*, not the same bundle id). (#duplicate-paste)
///
/// The rule is "newest launch wins": the instance the user (or the updater) just started asks the
/// older ones to quit. Deliberately NOT the Info.plist `LSMultipleInstancesProhibited` route —
/// that would stop a fresh copy from launching while a wedged old instance lingers, leaving the
/// user with the broken instance and no way to replace it short of Activity Monitor.
enum SingleInstanceGuard {

    /// One running instance, reduced to what the survivor rule needs. `launchDate` can be nil
    /// (the system couldn't determine it), so the rule has to rank that case too.
    struct Instance: Equatable {
        let pid: pid_t
        let launchDate: Date?

        init(pid: pid_t, launchDate: Date?) {
            self.pid = pid
            self.launchDate = launchDate
        }

        /// `NSRunningApplication.launchDate` is only known for LaunchServices launches. A bundle
        /// exec'd directly — `./run.sh` runs `Rhino.app/Contents/MacOS/Rhino` — reports nil, which
        /// the survivor rule ranks OLDEST: a dev build would yield to the installed copy (whose
        /// guard already ran) and both would stay up. Fall back to the kernel's process start
        /// time, which every process has.
        init(_ app: NSRunningApplication) {
            let pid = app.processIdentifier
            self.init(pid: pid, launchDate: app.launchDate ?? SingleInstanceGuard.processStartTime(pid: pid))
        }
    }

    /// Wall-clock start time of `pid` from `kinfo_proc.kp_proc.p_starttime`; nil if the process
    /// is gone or the sysctl fails.
    static func processStartTime(pid: pid_t) -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0,
              info.kp_proc.p_pid == pid
        else { return nil }
        let start = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000)
    }

    /// True when `current` outranks `other` and should ask it to quit; false means `other` is the
    /// newer launch, whose own guard is responsible for terminating us. The ordering is total
    /// (dates, then pid as the tie-break; an unknown date ranks oldest), so two instances racing
    /// through their launch guards can never both win — or both yield.
    static func currentWins(current: Instance, other: Instance) -> Bool {
        switch (current.launchDate, other.launchDate) {
        case let (mine?, theirs?):
            if mine != theirs { return mine > theirs }
            return current.pid > other.pid
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            return current.pid > other.pid
        }
    }

    /// How long a politely-asked instance gets to exit before it's force-killed. Generous — a
    /// healthy instance quits in well under a second; this only matters for a wedged one.
    static let terminationGrace: TimeInterval = 3.0

    /// Finds every other running instance with our bundle id and asks the ones we outrank to
    /// quit, escalating to a force-kill if one is still alive after `terminationGrace` (the
    /// stuck-old-instance-after-an-update case is exactly the one where polite doesn't work).
    /// Not actor-isolated: it's called from `applicationDidFinishLaunching`, which this project
    /// keeps non-isolated (see AppDelegate's `MainActor.assumeIsolated` bridges).
    static func terminateOtherInstances() {
        // xcodebuild runs the test bundle in parallel workers, each hosting its own Rhino.app with
        // this bundle id — the newest worker would kill the others mid-suite (and the developer's
        // installed Rhino along with them). No test needs the takeover.
        guard !DefaultsStore.isRunningTests else { return }
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let current = NSRunningApplication.current
        let me = Instance(current)

        // Headless CLI runs of this same binary (`Rhino transcribe|bench|cleanup`, including the
        // push gate's suites) register with LaunchServices under our bundle id but never paste —
        // they mark themselves `.prohibited` (CLI.swift) and must not be killed by a GUI launch.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me.pid && $0.activationPolicy != .prohibited }

        for other in others {
            let theirs = Instance(other)
            guard currentWins(current: me, other: theirs) else { continue }

            print("SingleInstanceGuard: another instance is running (pid \(theirs.pid)) — asking it to quit")
            if !other.terminate() {
                other.forceTerminate()
                continue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + terminationGrace) {
                if !other.isTerminated {
                    print("SingleInstanceGuard: pid \(other.processIdentifier) didn't quit — force-terminating")
                    other.forceTerminate()
                }
            }
        }
    }
}
