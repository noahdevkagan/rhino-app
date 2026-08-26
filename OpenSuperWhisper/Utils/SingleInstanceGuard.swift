import AppKit
import Foundation

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
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let current = NSRunningApplication.current
        let me = Instance(pid: current.processIdentifier, launchDate: current.launchDate)

        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me.pid }

        for other in others {
            let theirs = Instance(pid: other.processIdentifier, launchDate: other.launchDate)
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
