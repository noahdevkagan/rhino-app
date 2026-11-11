import XCTest

@testable import OpenSuperWhisper

/// Fn+↑ (Page Up), Fn+Delete, Fn+F-keys… are shortcuts, not dictation. A non-modifier key
/// pressed while a modifier trigger is held quietly cancels the take that press started, and
/// that press's release does nothing. Locked (hands-free) takes are left alone.
final class TriggerChordTests: XCTestCase {

    /// Hold Fn (starts a take), press ↑: the take is discarded and the release is a no-op.
    func testChordDuringUnlockedTakeCancelsIt() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan()
        state.takeStarted(by: press)

        XCTAssertEqual(state.chord(), press)
        XCTAssertTrue(state.chordDiscardsTake(press: press, takeLive: true, lockedOn: false))
        XCTAssertTrue(state.releaseIgnored(press))
    }

    /// The chord can be seen before the press's start ran: the press then never starts.
    func testChordBeforeStartIsSeen() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan()
        _ = state.chord()
        XCTAssertTrue(state.isChorded(press))
    }

    /// Autorepeat or a second key in the same press fires once.
    func testChordFiresOncePerPress() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan()
        XCTAssertEqual(state.chord(), press)
        XCTAssertNil(state.chord())
    }

    /// Double-tap locked the take on; the next press is Fn+↑ (scrolling while dictating
    /// hands-free). That press didn't start the take, so the take survives.
    func testChordWhileLockedKeepsTake() {
        var state = ShortcutManager.ChordState()
        let first = state.pressBegan()
        state.takeStarted(by: first)
        let second = state.pressBegan()    // the locking press

        XCTAssertEqual(state.chord(), second)
        XCTAssertFalse(state.chordDiscardsTake(press: second, takeLive: true, lockedOn: true))
        XCTAssertFalse(state.chordDiscardsTake(press: second, takeLive: true, lockedOn: false))
        XCTAssertFalse(ShortcutManager.chordDiscardsTake(
            startedByThisPress: true, takeLive: true, lockedOn: true))
    }

    /// The press that stopped a locked take leaves nothing live to cancel.
    func testChordOnStoppingPressDoesNothing() {
        var state = ShortcutManager.ChordState()
        let first = state.pressBegan()
        state.takeStarted(by: first)
        let stop = state.pressBegan()
        state.takeEnded()

        XCTAssertEqual(state.chord(), stop)
        XCTAssertFalse(state.chordDiscardsTake(press: stop, takeLive: false, lockedOn: false))
    }

    /// Plain hold and release: no chord, so the release behaves as before (stop, defer, lock).
    func testPlainHoldUnchanged() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan()
        state.takeStarted(by: press)
        XCTAssertFalse(state.isChorded(press))
        XCTAssertFalse(state.releaseIgnored(press))
    }

    /// A chord only marks its own press: the next plain press dictates normally.
    func testNextPressAfterChordIsPlain() {
        var state = ShortcutManager.ChordState()
        let chorded = state.pressBegan()
        state.takeStarted(by: chorded)
        _ = state.chord()
        state.takeEnded()

        let next = state.pressBegan()
        state.takeStarted(by: next)
        XCTAssertFalse(state.isChorded(next))
        XCTAssertFalse(state.releaseIgnored(next))
        XCTAssertEqual(state.chord(), next)
    }

    /// No press yet: a stray chord callback is ignored.
    func testChordWithoutPressIgnored() {
        var state = ShortcutManager.ChordState()
        XCTAssertNil(state.chord())
    }
}
