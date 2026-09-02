import XCTest

@testable import OpenSuperWhisper

/// A hands-free tap burst restarts the recording per tap; the start chime must play once per
/// burst, not once per restart (replaying cuts off the in-flight sound — heard as a stutter).
final class ChimeDebounceTests: XCTestCase {

    private let epoch = Date(timeIntervalSinceReferenceDate: 1_000)

    func testFirstChimeAlwaysPlays() {
        XCTAssertTrue(AudioRecorder.chimeShouldPlay(at: epoch, lastPlayedAt: nil))
    }

    /// A double or triple tap lands within the 0.35s-per-tap window — no repeat chime.
    func testTapBurstIsDebounced() {
        XCTAssertFalse(AudioRecorder.chimeShouldPlay(
            at: epoch.addingTimeInterval(0.3), lastPlayedAt: epoch))
        XCTAssertFalse(AudioRecorder.chimeShouldPlay(
            at: epoch.addingTimeInterval(0.7), lastPlayedAt: epoch))
    }

    func testNextDictationChimesAgain() {
        XCTAssertTrue(AudioRecorder.chimeShouldPlay(
            at: epoch.addingTimeInterval(2.0), lastPlayedAt: epoch))
    }

    /// The debounce window must outlast a triple tap (two 0.35s double-tap windows).
    func testWindowCoversTripleTap() {
        XCTAssertGreaterThan(AudioRecorder.chimeDebounceInterval, 0.7)
    }
}
