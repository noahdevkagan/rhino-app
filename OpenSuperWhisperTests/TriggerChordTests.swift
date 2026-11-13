import CoreGraphics
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
                        triggerHeld: Bool = true) -> Bool {
        ModifierKeyMonitor.keyDownCountsAsChord(
            isAutorepeat: autorepeat, keyCode: key, cancelKeyCode: cancelKey,
            sourcePID: pid, ownPID: me, triggerHeldInEvent: triggerHeld)
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

    func testKeyDownWithTriggerUpDoesntCount() {
        XCTAssertFalse(counts(triggerHeld: false))
    }

    /// The Globe key's own keyDown is part of pressing Fn, not a chord.
    func testGlobeKeyDoesntCount() {
        XCTAssertFalse(counts(key: ModifierKeyMonitor.globeKeyCode))
    }

    // MARK: - Matching key-downs to presses by timestamp (0.1.48 glitch)

    /// Two quick Fn taps: A down 100, up 200, B down 300, key at 350 (a Fn-flagged arrow or a
    /// phantom key from tap B). Delivered late after a stall, it must belong to B, not A.
    func testKeyAfterReleaseBelongsToNextPress() {
        var edges = TriggerEdges()
        edges.record(isPressed: true, at: 100)
        edges.record(isPressed: false, at: 200)
        edges.record(isPressed: true, at: 300)
        XCTAssertEqual(edges.pressHolding(at: 350), 300)
        XCTAssertEqual(edges.pressHolding(at: 150), 100)
        XCTAssertNil(edges.pressHolding(at: 250), "trigger was up")
        XCTAssertNil(edges.pressHolding(at: 50), "before any press")
    }

    /// The key tap sees A's release before a later key-down (one port, FIFO), even when the
    /// flags tap hasn't handled it yet: only A's press is known there, the release came via
    /// the key tap.
    func testReleaseSeenBeforeKeyDownMeansNoChordOnThatPress() {
        var edges = TriggerEdges()
        edges.record(isPressed: true, at: 100)   // flags tap: A down
        edges.record(isPressed: false, at: 200)  // key tap: A up
        XCTAssertNil(edges.pressHolding(at: 220))
        edges.record(isPressed: true, at: 300)   // key tap: B down
        edges.record(isPressed: true, at: 300)   // flags tap reports the same event later
        XCTAssertEqual(edges.presses, [100, 300])
        XCTAssertEqual(edges.pressHolding(at: 320), 300)
    }

    func testChordTargetsTheRightPress() {
        // Flags tap is still on A (100); the key belongs to B (300): charge B when it lands.
        XCTAssertEqual(ModifierKeyMonitor.chordTarget(owner: 300, currentPress: 100), .upcoming)
        XCTAssertEqual(ModifierKeyMonitor.chordTarget(owner: 300, currentPress: 300), .current)
        // Flags tap already moved on to B; a late key from A must not chord B.
        XCTAssertEqual(ModifierKeyMonitor.chordTarget(owner: 100, currentPress: 300), .stale)
    }

    // MARK: - Device-dependent modifier bits

    private func flags(_ generic: CGEventFlags, device: UInt64) -> CGEventFlags {
        CGEventFlags(rawValue: generic.rawValue | device)
    }

    /// Right-⌘ trigger: left ⌘ held alone is not the trigger, and left ⌘+C is not a chord.
    func testRightCommandTriggerIgnoresLeftCommand() {
        let right = ModifierKey.rightCommand
        XCTAssertTrue(right.isHeld(in: flags(.maskCommand, device: 0x10)))
        XCTAssertFalse(right.isHeld(in: flags(.maskCommand, device: 0x08)))
        XCTAssertTrue(right.isHeld(in: flags(.maskCommand, device: 0x18)))
        XCTAssertFalse(right.isHeld(in: []))
        XCTAssertFalse(counts(key: 8, triggerHeld: right.isHeld(in: flags(.maskCommand, device: 0x08))))
        XCTAssertTrue(counts(key: 8, triggerHeld: right.isHeld(in: flags(.maskCommand, device: 0x10))))
    }

    func testOtherSidesUseTheirOwnBits() {
        XCTAssertTrue(ModifierKey.leftOption.isHeld(in: flags(.maskAlternate, device: 0x20)))
        XCTAssertFalse(ModifierKey.leftOption.isHeld(in: flags(.maskAlternate, device: 0x40)))
        XCTAssertTrue(ModifierKey.rightControl.isHeld(in: flags(.maskControl, device: 0x2000)))
        XCTAssertFalse(ModifierKey.rightControl.isHeld(in: flags(.maskControl, device: 0x01)))
        XCTAssertTrue(ModifierKey.rightShift.isHeld(in: flags(.maskShift, device: 0x04)))
    }

    /// Synthetic events with only the generic flag still read as held.
    func testGenericFlagWithoutDeviceBitsCountsAsHeld() {
        XCTAssertTrue(ModifierKey.rightCommand.isHeld(in: .maskCommand))
        XCTAssertTrue(ModifierKey.fn.isHeld(in: .maskSecondaryFn))
        XCTAssertFalse(ModifierKey.fn.isHeld(in: .maskCommand))
    }
}
