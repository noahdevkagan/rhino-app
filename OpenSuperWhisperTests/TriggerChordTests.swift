import XCTest

@testable import OpenSuperWhisper

/// Fn+↑ (Page Up), Fn+Delete, Fn+F-keys… are shortcuts, not dictation. A key pressed soon
/// after a modifier trigger goes down quietly cancels the take that press started, and that
/// press's release does nothing.
final class TriggerChordTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    /// Hold Fn (starts a take), press ↑: the take is discarded and the release is a no-op.
    func testChordDuringUnlockedTakeCancelsIt() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan(at: t0)
        state.takeStarted(by: press)

        XCTAssertEqual(state.chord(at: at(0.05)), press)
        XCTAssertTrue(ShortcutManager.chordDiscardsTake(
            startedByThisPress: state.startedTake(press), takeLive: true, lockedOn: false))
        XCTAssertTrue(state.isChorded(press), "its release is a no-op")
    }

    /// The chord can land before the press's start ran: the press then never starts, and its
    /// release is still a no-op.
    func testChordBeforeStartIsSeen() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan(at: t0)
        XCTAssertEqual(state.chord(at: at(0.01)), press)
        XCTAssertTrue(state.isChorded(press))
        XCTAssertFalse(state.startedTake(press))
    }

    /// A stray key during a long hold-to-talk take isn't a chord: the take keeps recording and
    /// the release stops it as usual.
    func testLateKeyIsNotAChord() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan(at: t0)
        state.takeStarted(by: press)
        XCTAssertNil(state.chord(at: at(ShortcutManager.chordCancelWindow)))
        XCTAssertNil(state.chord(at: at(5)))
        XCTAssertFalse(state.isChorded(press))
    }

    func testChordWindowEdge() {
        XCTAssertTrue(ShortcutManager.keyIsChord(sincePress: ShortcutManager.chordCancelWindow - 0.01))
        XCTAssertFalse(ShortcutManager.keyIsChord(sincePress: ShortcutManager.chordCancelWindow))
    }

    /// Fn+↑ while a take is locked on (hands-free): the Fn press itself stops and transcribes
    /// the take, as before chords existed, so the chord finds nothing live to cancel.
    func testChordWhileLockedFindsTakeAlreadyStopped() {
        var state = ShortcutManager.ChordState()
        let first = state.pressBegan(at: t0)
        state.takeStarted(by: first)       // first tap; a second tap locks it (no new owner)
        let stop = state.pressBegan(at: at(10))   // the Fn of Fn+↑ stops the locked take
        state.takeEnded()

        XCTAssertEqual(state.chord(at: at(10.05)), stop)
        XCTAssertFalse(ShortcutManager.chordDiscardsTake(
            startedByThisPress: state.startedTake(stop), takeLive: false, lockedOn: false))
    }

    /// A chord on the double-tap's locking press doesn't own the take, so it can't cancel it.
    func testChordOnLockingPressKeepsTake() {
        var state = ShortcutManager.ChordState()
        let first = state.pressBegan(at: t0)
        state.takeStarted(by: first)
        let lockPress = state.pressBegan(at: at(0.3))
        XCTAssertEqual(state.chord(at: at(0.35)), lockPress)
        XCTAssertFalse(ShortcutManager.chordDiscardsTake(
            startedByThisPress: state.startedTake(lockPress), takeLive: true, lockedOn: true))
        XCTAssertFalse(ShortcutManager.chordDiscardsTake(
            startedByThisPress: true, takeLive: true, lockedOn: true))
    }

    /// Plain hold and release: no chord, so the release behaves as before (stop, defer, lock).
    func testPlainHoldUnchanged() {
        var state = ShortcutManager.ChordState()
        let press = state.pressBegan(at: t0)
        state.takeStarted(by: press)
        XCTAssertFalse(state.isChorded(press))
    }

    /// A chord only marks its own press: the next plain press dictates normally.
    func testNextPressAfterChordIsPlain() {
        var state = ShortcutManager.ChordState()
        let chorded = state.pressBegan(at: t0)
        state.takeStarted(by: chorded)
        _ = state.chord(at: at(0.05))
        state.takeEnded()

        let next = state.pressBegan(at: at(2))
        state.takeStarted(by: next)
        XCTAssertFalse(state.isChorded(next))
        XCTAssertTrue(state.startedTake(next))
    }

    /// No press yet: a stray chord callback is ignored.
    func testChordWithoutPressIgnored() {
        var state = ShortcutManager.ChordState()
        XCTAssertNil(state.chord(at: t0))
    }

    // MARK: - Which key-downs count (ModifierKeyMonitor)

    private let me: Int64 = 4242
    private let escape: Int64 = 53
    private let upArrow: Int64 = 126

    private func counts(key: Int64 = 126, autorepeat: Bool = false,
                        cancelKey: Int64? = 53, pid: Int64 = 99,
                        triggerHeld: Bool = true, afterPress: Bool = true) -> Bool {
        ModifierKeyMonitor.keyDownCountsAsChord(
            isAutorepeat: autorepeat, keyCode: key, cancelKeyCode: cancelKey,
            sourcePID: pid, ownPID: me, triggerKeyCode: 63,
            triggerHeldInEvent: triggerHeld, afterPress: afterPress)
    }

    func testTypedKeyCounts() {
        XCTAssertTrue(counts())
        XCTAssertTrue(counts(pid: 0))
    }

    /// Rhino's own typed text, ⌘V and Return can land while the next take's Fn is held.
    func testRhinosOwnSyntheticKeysDontCount() {
        XCTAssertFalse(counts(pid: me))
    }

    func testAutorepeatDoesntCount() {
        XCTAssertFalse(counts(autorepeat: true))
    }

    /// The cancel shortcut's key is left to the cancel flow, whatever it is bound to.
    func testCancelShortcutKeyDoesntCount() {
        XCTAssertFalse(counts(key: escape, cancelKey: escape))
        XCTAssertFalse(counts(key: upArrow, cancelKey: upArrow))
        XCTAssertTrue(counts(key: escape, cancelKey: upArrow))
        XCTAssertTrue(counts(key: escape, cancelKey: nil))
    }

    /// 0.1.48 glitch: a key-down handled late, after a main-thread stall, but typed while Fn
    /// was up (between two quick taps) discarded the take. It must carry the trigger flag.
    func testKeyDownWithTriggerUpDoesntCount() {
        XCTAssertFalse(counts(triggerHeld: false))
    }

    func testKeyDownFromBeforeThePressDoesntCount() {
        XCTAssertFalse(counts(afterPress: false))
    }

    /// The Fn/Globe key's own events are part of pressing the trigger, not a chord.
    func testTriggerAndGlobeKeysDontCount() {
        XCTAssertFalse(counts(key: 63))
        XCTAssertFalse(counts(key: ModifierKeyMonitor.globeKeyCode))
    }
}
