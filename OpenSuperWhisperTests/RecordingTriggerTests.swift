import AppKit
import KeyboardShortcuts
import XCTest

@testable import OpenSuperWhisper

/// The unified trigger field records whatever the user does: a combination or a lone modifier.
/// The lone-modifier rule is the delicate one — recording ⌥ when the user was reaching for ⌥⇧K
/// would hand them a trigger that fires constantly.
final class SingleModifierDetectorTests: XCTestCase {

    private let rightOption = ModifierKey.rightOption
    private let leftShift = ModifierKey.leftShift

    func testCleanPressIsRecognised() {
        var detector = SingleModifierDetector()
        XCTAssertNil(detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: [.option]))
        XCTAssertEqual(detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: []),
                       rightOption)
    }

    /// Two modifiers means a combination is being typed, not a lone press.
    func testSecondModifierDisqualifies() {
        var detector = SingleModifierDetector()
        _ = detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: [.option])
        _ = detector.handleFlagsChanged(keyCode: leftShift.keyCode, flags: [.option, .shift])
        XCTAssertNil(detector.handleFlagsChanged(keyCode: leftShift.keyCode, flags: [.option]))
        XCTAssertNil(detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: []),
                     "⌥⇧ is the start of a combination, not a single-modifier trigger")
    }

    /// ⌥ then K: the key press has to cancel the pending modifier, or releasing ⌥ afterwards
    /// would record it.
    func testKeyPressDisqualifies() {
        var detector = SingleModifierDetector()
        _ = detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: [.option])
        detector.contaminate()
        XCTAssertNil(detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: []))
    }

    /// After a disqualified press, the next clean one still works.
    func testDetectorRecoversAfterContamination() {
        var detector = SingleModifierDetector()
        _ = detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: [.option])
        detector.contaminate()
        _ = detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: [])

        _ = detector.handleFlagsChanged(keyCode: leftShift.keyCode, flags: [.shift])
        XCTAssertEqual(detector.handleFlagsChanged(keyCode: leftShift.keyCode, flags: []),
                       leftShift)
    }

    func testResetClearsAPendingPress() {
        var detector = SingleModifierDetector()
        _ = detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: [.option])
        detector.reset()
        XCTAssertNil(detector.handleFlagsChanged(keyCode: rightOption.keyCode, flags: []))
    }

    /// Left and right of the same modifier are distinct triggers, so releasing the other side
    /// must not record the pending one.
    func testSidesAreNotInterchangeable() {
        var detector = SingleModifierDetector()
        _ = detector.handleFlagsChanged(keyCode: ModifierKey.leftCommand.keyCode, flags: [.command])
        XCTAssertNil(detector.handleFlagsChanged(keyCode: ModifierKey.rightCommand.keyCode, flags: []))
    }
}

/// Stored preferences resolve to exactly one trigger, and the precedence has to match what
/// ShortcutManager has always done, or an upgrade would silently change someone's trigger.
final class RecordingTriggerResolveTests: XCTestCase {

    func testModifierWinsOverCombo() {
        let trigger = RecordingTrigger.resolve(modifierRaw: "fn", shortcut: nil)
        XCTAssertEqual(trigger, .modifier(.fn))
    }

    func testNothingStoredIsNoTrigger() {
        XCTAssertEqual(RecordingTrigger.resolve(modifierRaw: "none", shortcut: nil), .none)
    }

    /// An unknown stored value (downgrade, hand-edited defaults) must not resolve to a trigger
    /// the app can't act on.
    func testUnknownStoredValuesAreIgnored() {
        XCTAssertEqual(RecordingTrigger.resolve(modifierRaw: "hyper", shortcut: nil), .none)
    }
}

/// Several triggers coexist: a shortcut and a lone modifier, without a trip through Settings
/// between them (#48).
final class MultipleRecordingTriggersTests: XCTestCase {

    @MainActor
    private func combo() -> KeyboardShortcuts.Shortcut {
        KeyboardShortcuts.Shortcut(.d, modifiers: [.command, .option])
    }

    @MainActor
    func testAllConfiguredTriggersAreReturned() {
        let triggers = RecordingTrigger.resolveAll(modifierRaw: "rightOption",
                                                   shortcut: combo())
        XCTAssertEqual(triggers.count, 2)
        XCTAssertTrue(triggers.contains(.modifier(.rightOption)))
        XCTAssertTrue(triggers.contains(.keyCombo(combo())))
    }

    @MainActor
    func testNothingConfiguredYieldsNoTriggers() {
        XCTAssertTrue(RecordingTrigger.resolveAll(modifierRaw: "none", shortcut: nil).isEmpty)
    }

    @MainActor
    func testPartialConfigurationReturnsOnlyWhatIsSet() {
        let triggers = RecordingTrigger.resolveAll(modifierRaw: "fn", shortcut: nil)
        XCTAssertEqual(triggers, [.modifier(.fn)])
    }

    /// Two triggers of the same kind can't coexist — there is one slot per kind — so recording a
    /// second modifier has to replace the first rather than accumulate.
    @MainActor
    func testKindsAreDistinct() {
        XCTAssertEqual(RecordingTrigger.modifier(.fn).kind, RecordingTrigger.modifier(.rightOption).kind)
        XCTAssertNotEqual(RecordingTrigger.modifier(.fn).kind, RecordingTrigger.keyCombo(combo()).kind)
    }

    /// An unknown stored value must not become a phantom trigger the app can't act on.
    @MainActor
    func testUnknownStoredValuesAreSkipped() {
        let triggers = RecordingTrigger.resolveAll(modifierRaw: "hyper", shortcut: nil)
        XCTAssertTrue(triggers.isEmpty)
    }
}

/// The trigger list holds any number of each kind. The previous shape had one slot per kind —
/// one shortcut, one modifier — so the ceiling was fixed however the UI was drawn (#48).
final class RecordingTriggerSetTests: XCTestCase {

    @MainActor
    private func combo(_ key: KeyboardShortcuts.Key) -> KeyboardShortcuts.Shortcut {
        KeyboardShortcuts.Shortcut(key, modifiers: [.command, .option])
    }

    @MainActor
    func testHoldsSeveralOfTheSameKind() {
        var set = RecordingTriggerSet.empty
        set.add(.keyCombo(combo(.d)))
        set.add(.keyCombo(combo(.k)))
        set.add(.modifier(.rightOption))
        set.add(.modifier(.fn))

        XCTAssertEqual(set.keyCombos.count, 2)
        XCTAssertEqual(set.modifiers, [.rightOption, .fn])
    }

    /// Recording the same key twice should change nothing, not add a row that fires once.
    @MainActor
    func testDuplicatesAreIgnored() {
        var set = RecordingTriggerSet.empty
        set.add(.modifier(.fn))
        set.add(.modifier(.fn))
        XCTAssertEqual(set.triggers.count, 1)
    }

    func testEmptyTriggerIsNeverStored() {
        var set = RecordingTriggerSet.empty
        set.add(.none)
        XCTAssertTrue(set.triggers.isEmpty)
    }

    @MainActor
    func testRemoveTakesOnlyTheOneAskedFor() {
        var set = RecordingTriggerSet.empty
        set.add(.modifier(.fn))
        set.add(.keyCombo(combo(.d)))

        set.remove(.modifier(.fn))

        XCTAssertEqual(set.triggers, [.keyCombo(combo(.d))])
    }

    @MainActor
    func testRoundTripsThroughJSON() {
        var set = RecordingTriggerSet.empty
        set.add(.keyCombo(combo(.d)))
        set.add(.modifier(.rightCommand))
        XCTAssertEqual(RecordingTriggerSet.load(from: set.json), set)
    }

    func testUnreadableStoredValueYieldsNoTriggers() {
        XCTAssertEqual(RecordingTriggerSet.load(from: "not json"), .empty)
        XCTAssertEqual(RecordingTriggerSet.load(from: ""), .empty)
    }

    @MainActor
    func testModifierTriggerRequiresGlobalEventListening() {
        let set = RecordingTriggerSet(triggers: [.modifier(.fn)])
        XCTAssertTrue(set.requiresGlobalEventListening)
    }

    @MainActor
    func testRegisteredKeyCombinationDoesNotRequireGlobalEventListening() {
        let set = RecordingTriggerSet(triggers: [.keyCombo(combo(.d))])
        XCTAssertFalse(set.requiresGlobalEventListening)
    }

    @MainActor
    func testPrimaryDescriptionShowsDefaultFnTrigger() {
        let set = RecordingTriggerSet(triggers: [.modifier(.fn)])
        XCTAssertEqual(set.primaryDescription, "fn")
    }

    @MainActor
    func testPrimaryDescriptionShowsRecordedKeyCombination() {
        let set = RecordingTriggerSet(triggers: [.keyCombo(combo(.d))])
        XCTAssertEqual(set.primaryDescription, combo(.d).description)
    }

    @MainActor
    func testPrimaryDescriptionUsesDashOnlyWhenNoTriggerExists() {
        XCTAssertEqual(RecordingTriggerSet.empty.primaryDescription, "—")
    }

    /// Upgrading must keep whatever was configured before the list existed.
    @MainActor
    func testMigrationCarriesTheOldSlots() {
        let set = RecordingTriggerSet.migrated(modifierRaw: "rightOption", shortcut: combo(.d))
        XCTAssertEqual(set.triggers.count, 2)
        XCTAssertTrue(set.modifiers.contains(.rightOption))
        XCTAssertEqual(set.keyCombos.count, 1)
    }

    func testMigrationOfAnUnconfiguredInstallIsEmpty() {
        XCTAssertEqual(RecordingTriggerSet.migrated(modifierRaw: "none", shortcut: nil), .empty)
    }
}

/// Rhino already needs Accessibility for insertion. It must count as authorization for the
/// listen-only modifier tap instead of forcing users through a redundant Input Monitoring gate.
final class GlobalEventListeningAccessTests: XCTestCase {
    func testAccessibilityGrantAuthorizesListening() {
        XCTAssertTrue(GlobalEventListeningAccess.isGranted(accessibility: true,
                                                           inputMonitoring: false))
    }

    func testExistingInputMonitoringGrantAuthorizesListening() {
        XCTAssertTrue(GlobalEventListeningAccess.isGranted(accessibility: false,
                                                           inputMonitoring: true))
    }

    func testListeningIsDeniedWithoutEitherGrant() {
        XCTAssertFalse(GlobalEventListeningAccess.isGranted(accessibility: false,
                                                            inputMonitoring: false))
    }
}

/// Mouse-button triggers (middle, side 4/5). Two users asked for a middle-button trigger; the
/// rules that matter are that left/right click can never become one, and that a button which
/// is not a trigger is never swallowed.
final class MouseButtonTriggerTests: XCTestCase {

    func testOnlyOtherMouseButtonsAreValid() {
        XCTAssertFalse(MouseButtonTrigger.isValid(0), "left click must never be a trigger")
        XCTAssertFalse(MouseButtonTrigger.isValid(1), "right click must never be a trigger")
        XCTAssertTrue(MouseButtonTrigger.isValid(2))
        XCTAssertTrue(MouseButtonTrigger.isValid(3))
        XCTAssertTrue(MouseButtonTrigger.isValid(4))
        XCTAssertFalse(MouseButtonTrigger.isValid(-1))
    }

    func testUnwatchedMiddleClickIsNeverConsumed() {
        XCTAssertFalse(MouseButtonTrigger.shouldConsume(buttonNumber: 2, watched: []))
        XCTAssertFalse(MouseButtonTrigger.shouldConsume(buttonNumber: 2, watched: [3]))
        XCTAssertTrue(MouseButtonTrigger.shouldConsume(buttonNumber: 2, watched: [2]))
    }

    func testLeftAndRightClickAreNeverConsumedEvenIfStored() {
        XCTAssertFalse(MouseButtonTrigger.shouldConsume(buttonNumber: 0, watched: [0, 1, 2]))
        XCTAssertFalse(MouseButtonTrigger.shouldConsume(buttonNumber: 1, watched: [0, 1, 2]))
    }

    func testDisplayNamesMatchMouseLabels() {
        XCTAssertEqual(MouseButtonTrigger.displayName(for: 2), "Middle Mouse Button")
        XCTAssertEqual(MouseButtonTrigger.displayName(for: 3), "Mouse Button 4")
        XCTAssertEqual(MouseButtonTrigger.displayName(for: 4), "Mouse Button 5")
    }

    @MainActor
    func testCompactDescriptionAndCaps() {
        XCTAssertEqual(RecordingTrigger.mouseButton(2).compactDescription, "Middle click")
        XCTAssertEqual(RecordingTrigger.mouseButton(3).caps, ["Mouse Button 4"])
    }

    func testInvalidButtonIsNeverStored() {
        var set = RecordingTriggerSet.empty
        set.add(.mouseButton(0))
        set.add(.mouseButton(1))
        XCTAssertTrue(set.triggers.isEmpty)
    }

    func testMouseButtonsCoexistWithOtherKinds() {
        var set = RecordingTriggerSet.empty
        set.add(.modifier(.fn))
        set.add(.mouseButton(2))
        set.add(.mouseButton(4))
        set.add(.mouseButton(2))
        XCTAssertEqual(set.mouseButtons, [2, 4])
        XCTAssertEqual(set.modifiers, [.fn])
        XCTAssertNotEqual(RecordingTrigger.mouseButton(2).kind, RecordingTrigger.modifier(.fn).kind)
    }

    func testHandEditedLeftClickIsFilteredFromWatchedButtons() {
        let set = RecordingTriggerSet(triggers: [.mouseButton(0), .mouseButton(3)])
        XCTAssertEqual(set.mouseButtons, [3])
    }

    func testMouseTriggerRequiresGlobalEventListening() {
        XCTAssertTrue(RecordingTriggerSet(triggers: [.mouseButton(2)]).requiresGlobalEventListening)
    }

    func testRoundTripsThroughJSON() {
        var set = RecordingTriggerSet.empty
        set.add(.modifier(.rightOption))
        set.add(.mouseButton(3))
        XCTAssertEqual(RecordingTriggerSet.load(from: set.json), set)
    }

    /// A list written by this version (or a newer one) must still load the triggers an older
    /// shape understands, instead of collapsing to "no trigger at all".
    func testUnknownTriggerIsSkippedNotFatal() {
        let json = #"{"triggers":[{"modifier":{"_0":"fn"}},{"futureKind":{"_0":7}}]}"#
        XCTAssertEqual(RecordingTriggerSet.load(from: json).triggers, [.modifier(.fn)])
    }

    /// The encoded shape must stay what earlier builds wrote and read.
    func testExistingStoredShapeStillDecodes() {
        let json = RecordingTriggerSet(triggers: [.modifier(.fn)]).json
        XCTAssertTrue(json.contains(#""triggers""#))
        XCTAssertEqual(RecordingTriggerSet.load(from: json).triggers, [.modifier(.fn)])
    }
}

/// Hold-to-talk bookkeeping for the mouse tap: same rules as the modifier monitor.
final class MouseButtonPressTrackerTests: XCTestCase {

    func testPressAndReleaseOfWatchedButton() {
        var tracker = MouseButtonPressTracker()
        XCTAssertEqual(tracker.handle(buttonNumber: 2, isDown: true, watched: [2]), .down(2))
        XCTAssertEqual(tracker.handle(buttonNumber: 2, isDown: false, watched: [2]), .up(2))
        XCTAssertNil(tracker.pressed)
    }

    func testUnwatchedButtonIsIgnored() {
        var tracker = MouseButtonPressTracker()
        XCTAssertNil(tracker.handle(buttonNumber: 2, isDown: true, watched: [3]))
        XCTAssertNil(tracker.handle(buttonNumber: 2, isDown: false, watched: [3]))
    }

    func testSecondButtonMidTakeIsIgnored() {
        var tracker = MouseButtonPressTracker()
        _ = tracker.handle(buttonNumber: 2, isDown: true, watched: [2, 3])
        XCTAssertNil(tracker.handle(buttonNumber: 3, isDown: true, watched: [2, 3]))
        XCTAssertNil(tracker.handle(buttonNumber: 3, isDown: false, watched: [2, 3]),
                     "only the owning button's release ends the take")
        XCTAssertEqual(tracker.handle(buttonNumber: 2, isDown: false, watched: [2, 3]), .up(2))
    }

    func testStrayReleaseIsIgnored() {
        var tracker = MouseButtonPressTracker()
        XCTAssertNil(tracker.handle(buttonNumber: 2, isDown: false, watched: [2]))
    }

    func testResetForgetsAHeldButton() {
        var tracker = MouseButtonPressTracker()
        _ = tracker.handle(buttonNumber: 2, isDown: true, watched: [2])
        tracker.reset()
        XCTAssertEqual(tracker.handle(buttonNumber: 2, isDown: true, watched: [2]), .down(2))
    }
}
