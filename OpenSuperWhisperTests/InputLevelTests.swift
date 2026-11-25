import XCTest

@testable import OpenSuperWhisper

/// InputLevel decides what reaches the recognizer: quiet speech must be kept and lifted, while
/// silence, flat noise and clicks must never be turned into "speech" (a dead mic typing words is
/// worse than a missed word). Signals here are synthetic stand-ins with the property that
/// matters: speech = voiced syllable-length bursts well above the floor.
final class InputLevelTests: XCTestCase {
    private let sr = InputLevel.sampleRate

    private func db(_ x: Float) -> Float { pow(10, x / 20) }

    /// Deterministic noise in [-1, 1].
    private func noise(_ n: Int, seed: UInt64) -> [Float] {
        var state = seed &* 6364136223846793005 &+ 1442695040888963407
        return (0..<n).map { _ in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int64(bitPattern: state >> 1) % 2_000_001 - 1_000_000) / 1_000_000
        }
    }

    /// "Syllables": 250 ms of a 150 Hz voiced tone (with harmonics), 150 ms pause, repeated,
    /// over faint hiss. `peakDb` sets the loudness.
    private func syllables(seconds: Double, peakDb: Float, hissDb: Float = -90) -> [Float] {
        let n = Int(seconds * Double(sr))
        let hiss = noise(n, seed: 3)
        let a = db(peakDb) / 1.6
        return (0..<n).map { i in
            let t = Float(i) / Float(sr)
            let inSyllable = (i % (sr * 4 / 10)) < sr / 4
            let voice = inSyllable
                ? a * (sin(2 * .pi * 150 * t) + 0.4 * sin(2 * .pi * 300 * t) + 0.2 * sin(2 * .pi * 450 * t))
                : 0
            return voice + db(hissDb) * hiss[i]
        }
    }

    // MARK: - Silence and noise stay silent / untouched

    func testDigitalSilenceIsSilent() {
        let a = InputLevel.analyze([Float](repeating: 0, count: sr * 3))
        XCTAssertTrue(a.isSilent)
        XCTAssertFalse(a.isSpeechLike)
        XCTAssertEqual(a.gain, 1)
    }

    func testDitherIsSilent() {
        let x = noise(sr * 3, seed: 1).map { $0 / 32767 }
        XCTAssertTrue(InputLevel.analyze(x).isSilent)
    }

    func testQuietFlatNoiseIsSilent() {
        // Room tone / hiss at about -60 dBFS: below the old bail and flat, so silent.
        let x = noise(sr * 3, seed: 2).map { $0 * self.db(-55) }
        let a = InputLevel.analyze(x)
        XCTAssertFalse(a.isSpeechLike)
        XCTAssertTrue(a.isSilent)
    }

    func testLoudFlatNoiseReachesTheEngineUntouched() {
        // Above the old bail: behaviour unchanged (the engine's own guards handle it), no gain.
        let x = noise(sr * 3, seed: 4).map { $0 * self.db(-30) }
        let a = InputLevel.analyze(x)
        XCTAssertFalse(a.isSilent)
        XCTAssertFalse(a.isSpeechLike)
        XCTAssertEqual(a.gain, 1)
        XCTAssertEqual(InputLevel.prepare(x).samples, x)
    }

    func testKeystrokesAreNotSpeech() {
        // Ten 25 ms broadband bursts a second: lots of contrast, but no syllable-length voiced run.
        let burst = noise(sr / 40, seed: 5)
        var x = [Float](repeating: 0, count: sr * 3)
        var at = 0
        while at + burst.count < x.count {
            for i in 0..<burst.count { x[at + i] = burst[i] * db(-30) * exp(-Float(i) / 100) }
            at += sr / 10
        }
        let a = InputLevel.analyze(x)
        XCTAssertGreaterThan(a.activeMs, InputLevel.minActiveMs, "keystrokes do stand out")
        XCTAssertFalse(a.isSpeechLike)
        XCTAssertEqual(a.gain, 1)
    }

    func testLoudClickInSilenceIsSilent() {
        // Peaks far above the old bail, but it is one pop in a quiet room: Parakeet typed
        // "Really" for this. Nothing to transcribe.
        var x = noise(sr * 2, seed: 6).map { $0 * self.db(-90) }
        for i in 0..<40 { x[sr + i] += exp(-Float(i) / 6) * (i % 2 == 0 ? 0.5 : -0.5) }
        let a = InputLevel.analyze(x)
        XCTAssertFalse(a.isSpeechLike)
        XCTAssertTrue(a.isIsolatedBlip)
        XCTAssertTrue(a.isSilent)
        XCTAssertEqual(a.gain, 1)
    }

    func testShortThumpInRoomToneIsSilent() {
        // 60 ms broadband thump over -75 dBFS room tone.
        var x = noise(sr * 3, seed: 7).map { $0 * self.db(-75) }
        let thump = noise(sr * 6 / 100, seed: 8)
        for i in 0..<thump.count { x[sr + i] += thump[i] * db(-25) * sin(.pi * Float(i) / Float(thump.count)) }
        XCTAssertTrue(InputLevel.analyze(x).isSilent)
    }

    func testABlipIsNeverInferredOverABusyBackground() {
        // Loud steady noise (floor above -60 dBFS) is not "a quiet room": the blip rule must
        // not fire, so the clip reaches the engine exactly as before.
        var x = noise(sr * 2, seed: 9).map { $0 * self.db(-35) }
        x[sr] = 0.9
        let a = InputLevel.analyze(x)
        XCTAssertFalse(a.isIsolatedBlip)
        XCTAssertFalse(a.isSilent)
    }

    func testFaintWhisperOfSoundUnderTheHardFloorIsSilentWhateverItsShape() {
        // Speech-shaped but peaking below -80 dBFS: nothing a mic picked up.
        let a = InputLevel.analyze(syllables(seconds: 2, peakDb: -84, hissDb: -120))
        XCTAssertTrue(a.isSilent)
        XCTAssertFalse(a.isSpeechLike)
    }

    // MARK: - Quiet speech is kept and lifted

    func testQuietSpeechBelowTheOldBailIsKept() {
        // Peak -55 dBFS: the old peak test (< 0.004, about -48 dBFS) returned nothing for this.
        let x = syllables(seconds: 2, peakDb: -55)
        XCTAssertLessThan(x.map(abs).max()!, InputLevel.legacyPeak)
        let a = InputLevel.analyze(x)
        XCTAssertTrue(a.isSpeechLike)
        XCTAssertFalse(a.isSilent)
        XCTAssertGreaterThan(a.gain, 1)
    }

    func testQuietSpeechIsLiftedWithoutClipping() {
        let x = syllables(seconds: 2, peakDb: -40)
        let (out, a) = InputLevel.prepare(x)
        XCTAssertTrue(a.isSpeechLike)
        let outPeak = out.map(abs).max()!
        XCTAssertLessThanOrEqual(outPeak, InputLevel.peakCeiling + 1e-4)
        XCTAssertGreaterThan(InputLevel.dbfs(outPeak), -20, "brought up near a normal level")
        XCTAssertGreaterThan(InputLevel.dbfs(outPeak) - InputLevel.dbfs(x.map(abs).max()!), 20)
    }

    func testQuietSpeechInRoomToneIsKept() {
        // Soft talker over -75 dBFS room tone: about 25 dB of contrast.
        let a = InputLevel.analyze(syllables(seconds: 3, peakDb: -50, hissDb: -75))
        XCTAssertTrue(a.isSpeechLike)
        XCTAssertFalse(a.isSilent)
    }

    func testNormalLevelSpeechIsLeftBitForBit() {
        let x = syllables(seconds: 2, peakDb: -6)
        let (out, a) = InputLevel.prepare(x)
        XCTAssertTrue(a.isSpeechLike)
        XCTAssertEqual(a.gain, 1)
        XCTAssertEqual(out, x)
    }

    func testOneShortWordIsEnough() {
        // A 250 ms "yes" in a 2 s clip at -55 dBFS peak.
        var x = [Float](repeating: 0, count: sr * 2)
        let word = syllables(seconds: 0.25, peakDb: -55, hissDb: -120)
        for i in 0..<word.count { x[sr / 2 + i] = word[i] }
        let a = InputLevel.analyze(x)
        XCTAssertTrue(a.isSpeechLike)
        XCTAssertFalse(a.isSilent)
    }

    // MARK: - Gain rule

    func testGainNeverAttenuates() {
        XCTAssertEqual(InputLevel.gain(levelDb: -5, peak: 0.9), 1)
    }

    func testSmallBoostsAreSkipped() {
        // 4 dB under target: leave it alone rather than touch normal speech.
        XCTAssertEqual(InputLevel.gain(levelDb: InputLevel.targetLevelDb - 4, peak: 0.1), 1)
    }

    func testGainIsCapped() {
        let g = InputLevel.gain(levelDb: -100, peak: 0.00001)
        XCTAssertEqual(InputLevel.dbfs(g), InputLevel.maxGainDb, accuracy: 0.01)
    }

    func testGainNeverPushesPeakPastTheCeiling() {
        // Level wants +30 dB but the peak only has room for +20.
        let peak = InputLevel.peakCeiling / 10
        let g = InputLevel.gain(levelDb: InputLevel.targetLevelDb - 30, peak: peak)
        XCTAssertEqual(peak * g, InputLevel.peakCeiling, accuracy: 1e-4)
    }

    func testEmptyAndTinyClips() {
        XCTAssertTrue(InputLevel.analyze([]).isSilent)
        XCTAssertTrue(InputLevel.analyze([0.5, -0.5]).isSilent == false)
        XCTAssertFalse(InputLevel.analyze([0.5, -0.5]).isSpeechLike)
    }
}
