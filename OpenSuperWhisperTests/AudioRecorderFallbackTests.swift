import CoreAudio
import XCTest

@testable import OpenSuperWhisper

/// Covers the recovery decision made when a recording input delivers no audio (the
/// AirPods-disconnected-between-dictations hang): which device to re-record from, and
/// whether the system default input has to be repointed first.
final class AudioRecorderFallbackTests: XCTestCase {
    private let airPods: AudioDeviceID = 71
    private let builtIn: AudioDeviceID = 42
    private let usbMic: AudioDeviceID = 99

    func testSystemDefaultAlreadyMovedOn() {
        // macOS already re-picked a default (e.g. built-in) after the AirPods vanished:
        // record from it as-is, no need to touch the user's setting.
        let fallback = AudioRecorder.fallbackInput(systemDefault: builtIn, builtIn: builtIn, failed: airPods)
        XCTAssertEqual(fallback?.deviceID, builtIn)
        XCTAssertEqual(fallback?.mustSetSystemDefault, false)
    }

    func testSystemDefaultStillPointsAtDeadDevice() {
        // The app itself pinned the system default input to the now-dead AirPods; the
        // recorder must repoint it at the built-in mic before retrying.
        let fallback = AudioRecorder.fallbackInput(systemDefault: airPods, builtIn: builtIn, failed: airPods)
        XCTAssertEqual(fallback?.deviceID, builtIn)
        XCTAssertEqual(fallback?.mustSetSystemDefault, true)
    }

    func testNoSystemDefaultFallsBackToBuiltIn() {
        let fallback = AudioRecorder.fallbackInput(systemDefault: nil, builtIn: builtIn, failed: airPods)
        XCTAssertEqual(fallback?.deviceID, builtIn)
        XCTAssertEqual(fallback?.mustSetSystemDefault, true)
    }

    func testNothingLiveToFallBackTo() {
        XCTAssertNil(AudioRecorder.fallbackInput(systemDefault: nil, builtIn: nil, failed: airPods))
        XCTAssertNil(AudioRecorder.fallbackInput(systemDefault: airPods, builtIn: airPods, failed: airPods))
    }

    func testFailedDeviceUnknown() {
        // recordingDeviceID was never resolved: any live default is acceptable.
        let fallback = AudioRecorder.fallbackInput(systemDefault: usbMic, builtIn: builtIn, failed: nil)
        XCTAssertEqual(fallback?.deviceID, usbMic)
        XCTAssertEqual(fallback?.mustSetSystemDefault, false)
    }

    func testRecordingFilenamesAreUnique() {
        let a = AudioRecorder.makeRecordingFilename()
        let b = AudioRecorder.makeRecordingFilename()
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(a.hasPrefix("rec-"))
        XCTAssertTrue(a.hasSuffix(".wav"))
    }
}
