import CoreGraphics
import XCTest

@testable import OpenSuperWhisper

/// Fn+↑ (Page Up), Fn+Delete, Fn+F-keys… are shortcuts, not dictation. A non-modifier key
/// pressed while a modifier trigger is held quietly cancels the take that press started, and
/// that press's release does nothing. Only young takes; locked (hands-free) takes are untouched.
final class TriggerChordTests: XCTestCase {

    /// Hold Fn (starts a take), press ↑: the take is discarded and the release is a no-op.
    func testChordDuringUnlockedTakeCancelsIt() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan()
        state.takeStarted(by: press)

        XCTAssertEqual(state.chord(), press)
        XCTAssertTrue(state.chordDiscardsTake(press: press, takeLive: true, lockedOn: false, takeAge: 0.1))
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

    /// Fn+↑ while a take is locked on (hands-free): the Fn press itself stops and transcribes
    /// the take, as before chords existed, so the chord finds nothing live to cancel and the
    /// press's release behaves normally.
    func testChordWhileLockedFindsTakeAlreadyStopped() {
        var state = ShortcutManager.ChordState()
        let first = state.pressBegan()
        state.takeStarted(by: first)       // first tap; second tap locks it (not a new owner)
        let stop = state.pressBegan()      // the Fn of Fn+↑ stops the locked take
        state.takeEnded()

        XCTAssertEqual(state.chord(), stop)
        XCTAssertFalse(state.chordDiscardsTake(press: stop, takeLive: false, lockedOn: false,
                                               takeAge: .infinity))
        state.chordIgnored(stop)
        XCTAssertFalse(state.releaseIgnored(stop))
    }

    /// A chord on the double-tap's locking press doesn't own the take, so it can't cancel it.
    func testChordOnLockingPressKeepsTake() {
        var state = ShortcutManager.ChordState()
        let first = state.pressBegan()
        state.takeStarted(by: first)
        let lockPress = state.pressBegan()
        XCTAssertEqual(state.chord(), lockPress)
        XCTAssertFalse(state.chordDiscardsTake(press: lockPress, takeLive: true, lockedOn: true,
                                               takeAge: 0.4))
        XCTAssertFalse(ShortcutManager.chordDiscardsTake(
            startedByThisPress: true, takeLive: true, lockedOn: true, takeAge: 0.1))
    }

    /// A stray key during a long hold-to-talk take keeps recording; the release then stops
    /// and transcribes it as usual.
    func testLateChordKeepsLongTake() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan()
        state.takeStarted(by: press)
        XCTAssertEqual(state.chord(), press)
        XCTAssertFalse(state.chordDiscardsTake(
            press: press, takeLive: true, lockedOn: false,
            takeAge: ShortcutManager.chordCancelWindow))
        XCTAssertFalse(state.chordDiscardsTake(press: press, takeLive: true, lockedOn: false,
                                               takeAge: 5))
        state.chordIgnored(press)
        XCTAssertFalse(state.releaseIgnored(press))
        XCTAssertNil(state.chord(), "still one chord per press")
    }

    func testChordInsideWindowCancels() {
        XCTAssertTrue(ShortcutManager.chordDiscardsTake(
            startedByThisPress: true, takeLive: true, lockedOn: false,
            takeAge: ShortcutManager.chordCancelWindow - 0.01))
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

    // MARK: - Which key-downs count (ModifierKeyMonitor)

    private let me: Int64 = 4242
    private let hid = Int64(CGEventSourceStateID.hidSystemState.rawValue)

    private func counts(autorepeat: Bool = false, escape: Bool = false,
                        pid: Int64 = 0, state: Int64? = nil) -> Bool {
        ModifierKeyMonitor.keyDownCountsAsChord(
            isAutorepeat: autorepeat, isEscape: escape, sourcePID: pid,
            sourceStateID: state ?? hid, ownPID: me)
    }

    func testTypedKeyCounts() {
        XCTAssertTrue(counts())
        XCTAssertTrue(counts(pid: 99))
    }

    /// Rhino's own typed text, ⌘V and Return can land while the next take's Fn is held.
    func testRhinosOwnSyntheticKeysDontCount() {
        XCTAssertFalse(counts(pid: me))
    }

    /// Text expanders and automation post from a non-HID source state.
    func testOtherAppsSyntheticKeysDontCount() {
        XCTAssertFalse(counts(pid: 99, state: Int64(CGEventSourceStateID.combinedSessionState.rawValue)))
        XCTAssertFalse(counts(pid: 99, state: Int64(CGEventSourceStateID.privateState.rawValue)))
    }

    func testAutorepeatAndEscapeDontCount() {
        XCTAssertFalse(counts(autorepeat: true))
        XCTAssertFalse(counts(escape: true))
    }
}
