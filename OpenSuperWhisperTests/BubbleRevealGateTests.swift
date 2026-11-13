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
}
