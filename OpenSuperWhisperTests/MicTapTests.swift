import AVFoundation
import XCTest
@testable import OpenSuperWhisper

/// Covers the two halves of the 2026-09-05 AirPods "Connecting…" hang fix: a stale engine
/// format must never reach installTap, and an NSException raised there must become a
/// Swift error instead of unwinding through the main queue.
final class MicTapTests: XCTestCase {

    private func format(_ rate: Double, channels: AVAudioChannelCount = 1) -> AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
    }

    func testHardwareFormatWinsOverStaleOutputFormat() {
        // The exact 2026-09-05 shapes: hardware 48 kHz, cached node output 24 kHz.
        let resolved = MicTap.resolveFormat(hardware: format(48_000), output: format(24_000))
        XCTAssertEqual(resolved?.format.sampleRate, 48_000)
        XCTAssertEqual(resolved?.stale, true)
    }

    func testMatchingFormatsAreNotFlaggedStale() {
        let resolved = MicTap.resolveFormat(hardware: format(48_000), output: format(48_000))
        XCTAssertEqual(resolved?.format.sampleRate, 48_000)
        XCTAssertEqual(resolved?.stale, false)
    }

    func testLiveFormatIsUsable() {
        XCTAssertTrue(MicTap.isUsable(format(16_000)))
    }

    func testObjCExceptionBecomesSwiftError() {
        XCTAssertThrowsError(try ObjCExceptionCatcher.run {
            NSException(name: .invalidArgumentException,
                        reason: "Input HW format and tap format not matching",
                        userInfo: nil).raise()
        }) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "RhinoObjCExceptionErrorDomain")
            XCTAssertTrue(nsError.localizedDescription.contains("tap format not matching"),
                          nsError.localizedDescription)
        }
    }

    func testNoExceptionIsNoError() {
        var ran = false
        XCTAssertNoThrow(try ObjCExceptionCatcher.run { ran = true })
        XCTAssertTrue(ran)
    }
}
