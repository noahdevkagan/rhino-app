import AppKit
import XCTest

@testable import OpenSuperWhisper

/// The survivor rule for duplicate running instances (#duplicate-paste). Two instances racing
/// through their launch guards must always agree on exactly one winner, or both could quit
/// (no app left) or both stay (the duplicate-paste bug the guard exists to kill).
final class SingleInstanceGuardTests: XCTestCase {

    private func instance(pid: pid_t, launchedAt seconds: TimeInterval?) -> SingleInstanceGuard.Instance {
        SingleInstanceGuard.Instance(
            pid: pid,
            launchDate: seconds.map { Date(timeIntervalSinceReferenceDate: $0) })
    }

    func testNewerLaunchWins() {
        let old = instance(pid: 100, launchedAt: 1000)
        let new = instance(pid: 50, launchedAt: 2000)  // lower pid, later launch — date decides
        XCTAssertTrue(SingleInstanceGuard.currentWins(current: new, other: old))
        XCTAssertFalse(SingleInstanceGuard.currentWins(current: old, other: new))
    }

    func testSameLaunchDateFallsBackToPid() {
        let a = instance(pid: 100, launchedAt: 1000)
        let b = instance(pid: 200, launchedAt: 1000)
        XCTAssertTrue(SingleInstanceGuard.currentWins(current: b, other: a))
        XCTAssertFalse(SingleInstanceGuard.currentWins(current: a, other: b))
    }

    func testUnknownLaunchDateRanksOldest() {
        let dated = instance(pid: 100, launchedAt: 1000)
        let unknown = instance(pid: 200, launchedAt: nil)
        XCTAssertTrue(SingleInstanceGuard.currentWins(current: dated, other: unknown))
        XCTAssertFalse(SingleInstanceGuard.currentWins(current: unknown, other: dated))
    }

    func testBothUnknownFallBackToPid() {
        let a = instance(pid: 100, launchedAt: nil)
        let b = instance(pid: 200, launchedAt: nil)
        XCTAssertTrue(SingleInstanceGuard.currentWins(current: b, other: a))
        XCTAssertFalse(SingleInstanceGuard.currentWins(current: a, other: b))
    }

    /// The property that makes the guard race-safe: for ANY pair there is exactly one winner.
    func testOrderingIsTotalAndAntisymmetric() {
        let candidates: [SingleInstanceGuard.Instance] = [
            instance(pid: 1, launchedAt: nil),
            instance(pid: 2, launchedAt: nil),
            instance(pid: 3, launchedAt: 1000),
            instance(pid: 4, launchedAt: 1000),
            instance(pid: 5, launchedAt: 2000),
        ]
        for current in candidates {
            for other in candidates where current != other {
                let forward = SingleInstanceGuard.currentWins(current: current, other: other)
                let backward = SingleInstanceGuard.currentWins(current: other, other: current)
                XCTAssertNotEqual(forward, backward,
                                  "pids \(current.pid)/\(other.pid) must have exactly one winner")
            }
        }
    }

    /// A directly exec'd bundle (`./run.sh`) has no LaunchServices launchDate; the kernel start
    /// time must fill in so a dev build is ranked by when it actually started, not as "oldest".
    func testProcessStartTimeIsKnownForThisProcess() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let start = SingleInstanceGuard.processStartTime(pid: pid)
        XCTAssertNotNil(start)
        let uptime = ProcessInfo.processInfo.systemUptime
        XCTAssertLessThanOrEqual(start!, Date())
        XCTAssertGreaterThan(start!, Date(timeIntervalSinceNow: -uptime - 60),
                             "start time must be after boot")
    }

    func testProcessStartTimeIsNilForDeadPid() {
        XCTAssertNil(SingleInstanceGuard.processStartTime(pid: pid_t.max))
    }

    func testInstanceFromRunningApplicationFallsBackToKernelStartTime() {
        // The test host itself: launched by xcodebuild, launchDate may or may not be known —
        // either way the Instance must carry a date.
        let me = SingleInstanceGuard.Instance(NSRunningApplication.current)
        XCTAssertEqual(me.pid, ProcessInfo.processInfo.processIdentifier)
        XCTAssertNotNil(me.launchDate)
    }
}
