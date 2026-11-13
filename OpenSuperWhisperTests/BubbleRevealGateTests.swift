import XCTest

@testable import OpenSuperWhisper

/// With a modifier trigger (Fn), the mic starts on the press but the bubble stays hidden for
/// `chordSettleDelay`, so Fn+↑ (Page Up) and friends discard the take without the bubble ever
/// appearing. Normal dictation reveals it once the settle (and any caret lookup) is over.
final class BubbleRevealGateTests: XCTestCase {

    /// Only a modifier trigger can be the start of a chord; key combos show at once.
    func testOnlyModifierTriggersSettle() {
        XCTAssertEqual(ShortcutManager.bubbleSettle(triggerCanChord: true),
                       ShortcutManager.chordSettleDelay)
        XCTAssertEqual(ShortcutManager.bubbleSettle(triggerCanChord: false), 0)
    }

    /// Covers the 20–120 ms chords seen in Noah's logs, and stays short enough not to feel
    /// laggy; it must also stay well inside the window in which a key counts as a chord.
    func testSettleWindowIsShortButCoversRealChords() {
        XCTAssertGreaterThanOrEqual(ShortcutManager.chordSettleDelay, 0.15)
        XCTAssertLessThanOrEqual(ShortcutManager.chordSettleDelay, 0.25)
        XCTAssertTrue(ShortcutManager.keyIsChord(sincePress: ShortcutManager.chordSettleDelay))
    }

    /// Key-combo trigger, no caret lookup: revealed immediately, as before.
    func testNoWaitRevealsAtOnce() {
        var gate = BubbleRevealGate()
        XCTAssertTrue(gate.begin(waitForCaret: false, settle: false))
    }

    /// Plain Fn hold: hidden during the settle, revealed when it ends.
    func testFnHoldRevealsAfterSettle() {
        var gate = BubbleRevealGate()
        XCTAssertFalse(gate.begin(waitForCaret: false, settle: true))
        XCTAssertTrue(gate.settled())
    }

    /// Fn+↑: the chord discards the take inside the settle, so the reveal never happens.
    func testChordInsideSettleNeverReveals() {
        var gate = BubbleRevealGate()
        XCTAssertFalse(gate.begin(waitForCaret: false, settle: true))
        XCTAssertTrue(gate.cancel(), "a reveal was pending")
        XCTAssertFalse(gate.settled(), "a late settle timer must not reveal a discarded take")
        XCTAssertFalse(gate.caretResolved())
        XCTAssertFalse(gate.isReady)
    }

    /// Cursor placement: the caret wait and the settle overlap; both must finish, in any order.
    func testCaretAndSettleBothRequired() {
        var gate = BubbleRevealGate()
        XCTAssertFalse(gate.begin(waitForCaret: true, settle: true))
        XCTAssertFalse(gate.caretResolved(), "still settling")
        XCTAssertTrue(gate.settled())

        var other = BubbleRevealGate()
        XCTAssertFalse(other.begin(waitForCaret: true, settle: true))
        XCTAssertFalse(other.settled(), "still waiting for the caret")
        XCTAssertTrue(other.caretResolved())
    }

    /// Once revealed, nothing reveals it again and a later cancel isn't a skipped reveal.
    func testRevealIsOneShot() {
        var gate = BubbleRevealGate()
        XCTAssertFalse(gate.begin(waitForCaret: false, settle: true))
        XCTAssertTrue(gate.settled())
        gate.revealed()
        XCTAssertFalse(gate.settled())
        XCTAssertFalse(gate.cancel())
    }

    /// A new take's show() replaces a still-hidden bubble: the old reveal is dropped and the
    /// new one starts its own settle.
    func testNewTakeRestartsTheSettle() {
        var gate = BubbleRevealGate()
        XCTAssertFalse(gate.begin(waitForCaret: false, settle: true))
        gate.cancel()
        XCTAssertFalse(gate.begin(waitForCaret: false, settle: true))
        XCTAssertTrue(gate.awaitingSettle)
        XCTAssertTrue(gate.settled())
    }

    // MARK: - Main-thread stall: a chord still queued in the tap's port

    /// ↑ at 60 ms, main stalled until 400 ms: the window server saw the key-down after the
    /// press, so the reveal waits for the chord to be delivered instead of flashing first.
    func testKeyDownSincePressWaitsForChord() {
        XCTAssertTrue(BubbleRevealGate.shouldAwaitChord(
            secondsSinceLastKeyDown: 0.34, secondsSincePress: 0.40, catchUpsSoFar: 0))
    }

    /// Plain Fn hold, the last key typed before the press: reveal on time, no extra wait.
    func testKeyBeforePressDoesNotDelay() {
        XCTAssertFalse(BubbleRevealGate.shouldAwaitChord(
            secondsSinceLastKeyDown: 1.5, secondsSincePress: 0.20, catchUpsSoFar: 0))
    }

    /// A key-down that never turns into a chord (Esc, autorepeat, Globe) only delays the
    /// bubble by a few short hops; it can't hold it back.
    func testCatchUpIsCapped() {
        let cap = BubbleRevealGate.maxChordCatchUps
        XCTAssertTrue(BubbleRevealGate.shouldAwaitChord(
            secondsSinceLastKeyDown: 0.1, secondsSincePress: 0.2, catchUpsSoFar: cap - 1))
        XCTAssertFalse(BubbleRevealGate.shouldAwaitChord(
            secondsSinceLastKeyDown: 0.1, secondsSincePress: 0.2, catchUpsSoFar: cap))
        XCTAssertLessThanOrEqual(Double(cap) * BubbleRevealGate.chordCatchUpDelay, 0.1)
    }

    /// The press time is backdated by the window server's "last modifier change" age, so a
    /// late handler still counts keys pressed during its stall; never more than the chord window.
    func testPhysicalPressTimeBackdatesTheHandler() {
        let handled = Date(timeIntervalSinceReferenceDate: 1_000)
        XCTAssertEqual(ShortcutManager.physicalPressTime(
            handledAt: handled, secondsSinceLastFlagsChange: 0.35), handled.addingTimeInterval(-0.35))
        XCTAssertEqual(ShortcutManager.physicalPressTime(
            handledAt: handled, secondsSinceLastFlagsChange: 1e9),
                       handled.addingTimeInterval(-ShortcutManager.chordCancelWindow))
        XCTAssertEqual(ShortcutManager.physicalPressTime(
            handledAt: handled, secondsSinceLastFlagsChange: -1), handled)
    }
}
