import XCTest

@testable import OpenSuperWhisper

/// A double-tap must lock the same take on, never stop it and start a new one: that read as the
/// bubble popping up, vanishing and popping back.
final class DoubleTapLockTests: XCTestCase {

    private func lock(age: TimeInterval, awaiting: Bool = false,
                      locked: Bool = false, enabled: Bool = true) -> Bool {
        ShortcutManager.shouldLock(takeAge: age, awaitingSecondTap: awaiting,
                                   lockedOn: locked, doubleTapLock: enabled)
    }

    /// A quick second tap locks, as before.
    func testFastSecondTapLocks() {
        XCTAssertTrue(lock(age: 0.2))
    }

    /// A loose double-tap (slower than the old 0.35s window) used to stop the take.
    func testSlowSecondTapStillLocks() {
        XCTAssertTrue(lock(age: 0.5))
        XCTAssertTrue(lock(age: 0.9))
    }

    /// Once the take is long enough to keep, a press is a deliberate stop.
    func testPressOnKeepableTakeStops() {
        XCTAssertFalse(lock(age: AudioRecorder.minimumKeptDuration))
        XCTAssertFalse(lock(age: 8))
    }

    /// The second tap after a too-short hold locks whatever the take's age.
    func testPressDuringHoldGraceLocks() {
        XCTAssertTrue(lock(age: 1.2, awaiting: true))
    }

    func testPressWhileLockedStops() {
        XCTAssertFalse(lock(age: 0.2, locked: true))
        XCTAssertFalse(lock(age: 0.2, awaiting: true, locked: true))
    }

    func testHandsFreeOffNeverLocks() {
        XCTAssertFalse(lock(age: 0.2, enabled: false))
        XCTAssertFalse(lock(age: 0.2, awaiting: true, enabled: false))
    }

    /// A first tap held just past the hold threshold waits for the second tap instead of
    /// stopping and hiding the bubble.
    func testShortHoldReleaseDefersStop() {
        XCTAssertTrue(ShortcutManager.shouldDeferHoldStop(takeAge: 0.4, doubleTapLock: true))
    }

    /// Real push-to-talk stops on release, immediately.
    func testKeepableHoldReleaseStopsNow() {
        XCTAssertFalse(ShortcutManager.shouldDeferHoldStop(takeAge: 1.5, doubleTapLock: true))
        XCTAssertFalse(ShortcutManager.shouldDeferHoldStop(takeAge: 0.4, doubleTapLock: false))
    }

    /// No live take (start time unknown) never counts as young.
    func testUnknownAgeStops() {
        XCTAssertFalse(lock(age: .infinity))
        XCTAssertFalse(ShortcutManager.shouldDeferHoldStop(takeAge: .infinity, doubleTapLock: true))
    }
}
