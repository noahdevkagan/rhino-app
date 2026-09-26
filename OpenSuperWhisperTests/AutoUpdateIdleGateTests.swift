import XCTest
@testable import OpenSuperWhisper

/// The silent-install gate: a downloaded update may relaunch Rhino only when
/// nothing dictation-related is in flight and the user has stepped away.
final class AutoUpdateIdleGateTests: XCTestCase {
    private let away = SparkleUpdater.idleInstallThreshold
    private let active: TimeInterval = 5

    private func gate(recording: Bool = false, transcribing: Bool = false,
                      indicator: Bool = false, quiet: TimeInterval) -> Bool {
        SparkleUpdater.shouldInstallNow(isRecording: recording,
                                        isTranscribing: transcribing,
                                        indicatorVisible: indicator,
                                        secondsSinceUserInput: quiet)
    }

    func testInstallsWhenIdleAndAway() {
        XCTAssertTrue(gate(quiet: away))
        XCTAssertTrue(gate(quiet: away * 10))
    }

    func testWaitsWhileUserIsActive() {
        XCTAssertFalse(gate(quiet: active))
        XCTAssertFalse(gate(quiet: away - 1))
    }

    func testNeverInstallsMidDictation() {
        // A long hold-to-talk take produces no key/mouse events, so "away" alone
        // must not be enough while recording.
        XCTAssertFalse(gate(recording: true, quiet: away * 2))
    }

    func testNeverInstallsWhileATakeIsStillTranscribingOrPasting() {
        XCTAssertFalse(gate(transcribing: true, quiet: away * 2))
        XCTAssertFalse(gate(indicator: true, quiet: away * 2))
    }

    func testThresholdIsMinutesNotSeconds() {
        XCTAssertGreaterThanOrEqual(SparkleUpdater.idleInstallThreshold, 120)
    }
}
