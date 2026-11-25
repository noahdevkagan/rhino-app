import AppKit
import KeyboardShortcuts
import XCTest

@testable import OpenSuperWhisper

/// An extra mouse button (middle or side/thumb) as a dictate trigger, alongside the keyboard
/// ones. Left and right click must never be accepted: a trigger on either fires on every click.
final class MouseButtonTests: XCTestCase {

    func testLeftAndRightClickAreRejected() {
        XCTAssertNil(MouseButton(number: 0), "left click can never be a trigger")
        XCTAssertNil(MouseButton(number: 1), "right click can never be a trigger")
        XCTAssertNil(MouseButton(number: -1))
        XCTAssertNil(MouseButton(number: 32))
    }

    func testMiddleAndExtraButtonsAreAccepted() {
        XCTAssertEqual(MouseButton(number: 2), .middle)
        XCTAssertNotNil(MouseButton(number: 3))
        XCTAssertNotNil(MouseButton(number: 4))
        XCTAssertNotNil(MouseButton(number: 31))
    }

    /// Labels follow the one-based numbering a mouse's own software prints.
    func testLabels() {
        XCTAssertEqual(MouseButton.middle.displayName, "Middle button")
        XCTAssertEqual(MouseButton(number: 3)?.displayName, "Mouse 4")
        XCTAssertEqual(MouseButton(number: 4)?.displayName, "Mouse 5")
        XCTAssertEqual(MouseButton(number: 7)?.displayName, "Mouse 8")
    }

    func testStorageKeysRoundTrip() {
        XCTAssertEqual(MouseButton.middle.storageKey, "middle")
        XCTAssertEqual(MouseButton(number: 3)?.storageKey, "button4")
        for number in 2...MouseButton.maxNumber {
            let button = MouseButton(number: number)!
            XCTAssertEqual(MouseButton(storageKey: button.storageKey), button)
        }
    }

    func testStorageKeysForLeftRightOrJunkAreRejected() {
        XCTAssertNil(MouseButton(storageKey: "button1"))
        XCTAssertNil(MouseButton(storageKey: "button2"))
        XCTAssertNil(MouseButton(storageKey: "button"))
        XCTAssertNil(MouseButton(storageKey: "buttonX"))
        XCTAssertNil(MouseButton(storageKey: "none"))
        XCTAssertNil(MouseButton(storageKey: ""))
    }
}

final class MouseRecordingTriggerTests: XCTestCase {

    @MainActor
    private func combo() -> KeyboardShortcuts.Shortcut {
        KeyboardShortcuts.Shortcut(.d, modifiers: [.command, .option])
    }

    private let mouse4 = MouseButton(number: 3)!

    @MainActor
    func testCapsAndCompactDescription() {
        XCTAssertEqual(RecordingTrigger.mouse(mouse4).caps, ["Mouse 4"])
        XCTAssertEqual(RecordingTrigger.mouse(.middle).caps, ["Middle button"])
        XCTAssertEqual(RecordingTrigger.mouse(mouse4).compactDescription, "Mouse 4")
    }

    func testMouseIsItsOwnKind() {
        XCTAssertEqual(RecordingTrigger.mouse(mouse4).kind, .mouse)
        XCTAssertNotEqual(RecordingTrigger.mouse(mouse4).kind, RecordingTrigger.modifier(.fn).kind)
    }

    /// A mouse button is an additional trigger: the keyboard ones stay live next to it.
    @MainActor
    func testMouseButtonCoexistsWithKeyboardTriggers() {
        var set = RecordingTriggerSet(triggers: [.modifier(.fn)])
        set.add(.keyCombo(combo()))
        set.add(.mouse(mouse4))
        set.add(.mouse(.middle))
        set.add(.mouse(mouse4)) // duplicate is a no-op
        XCTAssertEqual(set.triggers.count, 4)
        XCTAssertEqual(set.modifiers, [.fn])
        XCTAssertEqual(set.keyCombos.count, 1)
        XCTAssertEqual(set.mouseButtons, [mouse4, .middle])
        XCTAssertEqual(set.primaryDescription, "fn", "the first trigger stays the one hints show")
    }

    @MainActor
    func testPrimaryDescriptionForAMouseOnlySet() {
        XCTAssertEqual(RecordingTriggerSet(triggers: [.mouse(mouse4)]).primaryDescription, "Mouse 4")
    }

    func testMouseTriggerRequiresGlobalEventListening() {
        XCTAssertTrue(RecordingTriggerSet(triggers: [.mouse(mouse4)]).requiresGlobalEventListening)
    }

    @MainActor
    func testRoundTripsThroughJSON() {
        var set = RecordingTriggerSet(triggers: [.modifier(.fn)])
        set.add(.keyCombo(combo()))
        set.add(.mouse(mouse4))
        set.add(.mouse(.middle))
        XCTAssertEqual(RecordingTriggerSet.load(from: set.json), set)
    }

    /// The stored shape of today's triggers must not change: an existing install's list has to
    /// read back exactly as before.
    func testExistingStoredTriggersStillDecode() {
        let stored = #"{"triggers":[{"modifier":{"_0":"fn"}}]}"#
        XCTAssertEqual(RecordingTriggerSet.load(from: stored).triggers, [.modifier(.fn)])
        XCTAssertEqual(RecordingTriggerSet(triggers: [.modifier(.fn)]).json, stored)
    }

    func testMouseTriggerStoredShape() {
        XCTAssertEqual(RecordingTriggerSet(triggers: [.mouse(mouse4)]).json,
                       #"{"triggers":[{"mouse":{"_0":"button4"}}]}"#)
    }

    /// One unreadable entry (a newer kind, a left-click button that slipped in) is skipped, not
    /// a reason to drop every trigger the user has.
    func testUnreadableEntryIsSkippedNotFatal() {
        let stored = #"{"triggers":[{"modifier":{"_0":"fn"}},{"mouse":{"_0":"button1"}},{"pedal":{"_0":3}},{"mouse":{"_0":"button5"}}]}"#
        XCTAssertEqual(RecordingTriggerSet.load(from: stored).triggers,
                       [.modifier(.fn), .mouse(MouseButton(number: 4)!)])
    }
}

/// The tap's press/release rule and what it swallows.
final class MouseTriggerTrackerTests: XCTestCase {

    private let mouse4 = MouseButton(number: 3)!

    func testHoldAndReleaseReportEdgesAndSwallow() {
        var tracker = MouseTriggerTracker(watched: [mouse4])
        XCTAssertEqual(tracker.handle(.down, buttonNumber: 3), .init(edge: .down(mouse4), consume: true))
        XCTAssertEqual(tracker.handle(.dragged, buttonNumber: 3), .init(edge: nil, consume: true))
        XCTAssertEqual(tracker.handle(.up, buttonNumber: 3), .init(edge: .up(mouse4), consume: true))
    }

    func testUnwatchedButtonsPassThrough() {
        var tracker = MouseTriggerTracker(watched: [mouse4])
        XCTAssertEqual(tracker.handle(.down, buttonNumber: 4), .passThrough)
        XCTAssertEqual(tracker.handle(.down, buttonNumber: 2), .passThrough)
        XCTAssertEqual(tracker.handle(.down, buttonNumber: 0), .passThrough, "left click is never touched")
        XCTAssertEqual(tracker.handle(.down, buttonNumber: 1), .passThrough, "right click is never touched")
    }

    /// The first button owns the take; a second watched button meanwhile is swallowed but
    /// ignored, and its release doesn't end the first button's take.
    func testSecondButtonDuringATakeIsIgnored() {
        var tracker = MouseTriggerTracker(watched: [mouse4, .middle])
        _ = tracker.handle(.down, buttonNumber: 3)
        XCTAssertEqual(tracker.handle(.down, buttonNumber: 2), .init(edge: nil, consume: true))
        XCTAssertEqual(tracker.handle(.up, buttonNumber: 2), .init(edge: nil, consume: true))
        XCTAssertEqual(tracker.handle(.up, buttonNumber: 3), .init(edge: .up(mouse4), consume: true))
    }

    /// A release without its press (the tap came up mid-hold) is not an edge.
    func testStrayReleaseIsNotAnEdge() {
        var tracker = MouseTriggerTracker(watched: [mouse4])
        XCTAssertEqual(tracker.handle(.up, buttonNumber: 3), .init(edge: nil, consume: true))
    }

    func testResetForgetsAHeldButton() {
        var tracker = MouseTriggerTracker(watched: [mouse4])
        _ = tracker.handle(.down, buttonNumber: 3)
        tracker.reset()
        XCTAssertEqual(tracker.handle(.down, buttonNumber: 3), .init(edge: .down(mouse4), consume: true))
    }
}
