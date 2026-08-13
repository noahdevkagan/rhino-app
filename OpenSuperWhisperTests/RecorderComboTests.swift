import AppKit
import Carbon.HIToolbox
import XCTest

@testable import OpenSuperWhisper

final class RecorderComboTests: XCTestCase {
    func testRequiresCommandOptionOrControl() {
        XCTAssertTrue(RecorderCombo.isValid(modifiers: [.command], keyCode: kVK_ANSI_A))
        XCTAssertTrue(RecorderCombo.isValid(modifiers: [.option, .shift], keyCode: kVK_ANSI_A))
        XCTAssertTrue(RecorderCombo.isValid(modifiers: [.control], keyCode: kVK_Space))
        XCTAssertFalse(RecorderCombo.isValid(modifiers: [], keyCode: kVK_ANSI_A))
    }

    func testShiftAloneIsRejected() {
        XCTAssertFalse(RecorderCombo.isValid(modifiers: [.shift], keyCode: kVK_ANSI_A))
    }

    func testBareFunctionKeysAllowed() {
        XCTAssertTrue(RecorderCombo.isValid(modifiers: [], keyCode: kVK_F5))
        XCTAssertTrue(RecorderCombo.isValid(modifiers: [.shift], keyCode: kVK_F13))
        XCTAssertFalse(RecorderCombo.isValid(modifiers: [], keyCode: kVK_Escape))
    }
}

final class AudioRecorderDurationTests: XCTestCase {
    func testDiscardsZeroAndOtherSubSecondDurations() {
        XCTAssertTrue(AudioRecorder.shouldDiscardRecording(duration: 0))
        XCTAssertTrue(AudioRecorder.shouldDiscardRecording(duration: 0.999))
    }

    func testKeepsRecordingsAtLeastOneSecondLong() {
        XCTAssertFalse(AudioRecorder.shouldDiscardRecording(duration: 1.0))
        XCTAssertFalse(AudioRecorder.shouldDiscardRecording(duration: 12.5))
    }

    func testDiscardsMissingOrInvalidDuration() {
        XCTAssertTrue(AudioRecorder.shouldDiscardRecording(duration: nil))
        XCTAssertTrue(AudioRecorder.shouldDiscardRecording(duration: .nan))
        XCTAssertTrue(AudioRecorder.shouldDiscardRecording(duration: .infinity))
    }
}
