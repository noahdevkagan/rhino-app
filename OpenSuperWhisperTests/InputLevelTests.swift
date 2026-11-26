import XCTest

@testable import OpenSuperWhisper

/// InputLevel may only RESCUE (decisions.md 2026-11-25): compared with the old peak bail it must
/// never drop a clip the old rule sent to the engine (bar one isolated pop), and it may only lift
/// or rescue a clip with real evidence of a talker loud enough to be the user. Signals here are
/// synthetic stand-ins with the property that matters for each rule.
final class InputLevelTests: XCTestCase {
    private let sr = InputLevel.sampleRate

    private func db(_ x: Float) -> Float { pow(10, x / 20) }

    /// Master's rule, copied verbatim from WhisperEngine.isNearSilence before 2026-11-25.
    private func masterIsNearSilence(_ samples: [Float], threshold: Float = 0.004) -> Bool {
        var peak: Float = 0
        for s in samples {
            peak = max(peak, abs(s))
            if peak >= threshold { return false }
        }
        return true
    }

    /// Deterministic noise in [-1, 1].
    private func noise(_ n: Int, seed: UInt64) -> [Float] {
        var state = seed &* 6364136223846793005 &+ 1442695040888963407
        return (0..<n).map { _ in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int64(bitPattern: state >> 1) % 2_000_001 - 1_000_000) / 1_000_000
        }
    }

    private func rms(_ x: [Float]) -> Float {
        (x.reduce(0) { $0 + $1 * $1 } / Float(max(x.count, 1))).squareRoot()
    }

    /// Talker stand-in: 220 ms voiced syllables (a harmonic tone whose pitch glides, a different
    /// contour each time), 180 ms gaps, over noise at `noiseDb` RMS. `peakDb` sets loudness.
    private func speech(seconds: Double, peakDb: Float, noiseDb: Float = -95) -> [Float] {
        let n = Int(seconds * Double(sr))
        let bg = noise(n, seed: 3)
        let period = sr * 4 / 10, voiced = sr * 22 / 100
        var x = [Float](repeating: 0, count: n)
        var phase: Float = 0
        for i in 0..<n {
            let k = i / period, j = i % period
            guard j < voiced else { continue }
            let t = Float(j) / Float(voiced)
            let start: Float = [120, 150, 135, 170, 110][k % 5]
            let f0 = start * (1 + (k % 2 == 0 ? 0.25 : -0.2) * t)
            phase += 2 * .pi * f0 / Float(sr)
            let env = sin(.pi * t)
            x[i] = env * (sin(phase) + 0.5 * sin(2 * phase) + 0.3 * sin(3 * phase))
        }
        let pk = x.map(abs).max() ?? 1
        return (0..<n).map { x[$0] * db(peakDb) / pk + db(noiseDb) * 1.7 * bg[$0] }
    }

    /// A steady 175 Hz buzz with harmonics (a phone on the desk), `seconds` long.
    private func buzz(seconds: Double, peakDb: Float, gated: Bool = false) -> [Float] {
        let n = Int(seconds * Double(sr))
        var x = (0..<n).map { i -> Float in
            let t = Float(i) / Float(sr)
            return sin(2 * .pi * 175 * t) + 0.6 * sin(2 * .pi * 350 * t) + 0.4 * sin(2 * .pi * 525 * t)
        }
        if gated {  // on 300 ms, off 200 ms, like a vibrating phone
            for i in 0..<n where (i % (sr / 2)) >= sr * 3 / 10 { x[i] = 0 }
        }
        let pk = x.map(abs).max() ?? 1
        return x.map { $0 * db(peakDb) / pk }
    }

    private func pop(in x: [Float], at: Int, peak: Float) -> [Float] {
        var y = x
        for i in 0..<40 { y[at + i] += exp(-Float(i) / 6) * (i % 2 == 0 ? peak : -peak) }
        return y
    }

    // MARK: - Off is master, exactly

    func testOffIsByteIdenticalToMastersPeakRule() {
        var cases: [[Float]] = [
            [], [0.5], [Float](repeating: 0, count: sr * 2),
            noise(sr * 2, seed: 1).map { $0 / 32767 },
            [Float](repeating: 0.0039, count: sr), [Float](repeating: 0.004, count: sr),
            buzz(seconds: 2, peakDb: -50), buzz(seconds: 2, peakDb: -30, gated: true),
            pop(in: [Float](repeating: 0, count: sr * 2), at: sr, peak: 0.5),
        ]
        for peakDb in stride(from: Float(-90), through: -10, by: 4) {
            cases.append(speech(seconds: 1.6, peakDb: peakDb))
            cases.append(speech(seconds: 1.6, peakDb: peakDb, noiseDb: peakDb - 12))
            cases.append(noise(sr, seed: UInt64(-peakDb)).map { $0 * self.db(peakDb) })
        }
        for x in cases {
            let a = InputLevel.analyze(x, enabled: false)
            XCTAssertEqual(a.isSilent, masterIsNearSilence(x))
            XCTAssertEqual(a.gain, 1)
            XCTAssertFalse(a.isIsolatedPop)
            var y = x
            InputLevel.prepare(&y, enabled: false)
            XCTAssertEqual(y, x)
        }
    }

    // MARK: - Never drop what master sent

    func testAnythingAboveTheOldBailStillReachesTheEngine() {
        // Low-SNR speech over pink-ish room tone at about -62 dBFS, short words, flat noise:
        // master passed all of these, and so must the new rule.
        for peakDb in stride(from: Float(-48), through: -6, by: 3) {
            for noiseDb: Float in [-95, -62, peakDb - 15, peakDb - 6] {
                let x = speech(seconds: 1.2, peakDb: peakDb, noiseDb: noiseDb)
                XCTAssertFalse(masterIsNearSilence(x))
                XCTAssertFalse(InputLevel.analyze(x).isSilent, "peak \(peakDb) noise \(noiseDb)")
            }
        }
        let flat = noise(sr * 3, seed: 4).map { $0 * self.db(-30) }
        XCTAssertFalse(InputLevel.analyze(flat).isSilent)
        XCTAssertEqual(InputLevel.analyze(flat).gain, 1)
    }

    func testOnlyAnIsolatedPopIsDroppedAboveTheOldBail() {
        let quiet = noise(sr * 2, seed: 6).map { $0 * self.db(-90) }
        let a = InputLevel.analyze(pop(in: quiet, at: sr, peak: 0.5))
        XCTAssertTrue(a.isIsolatedPop)
        XCTAssertTrue(a.isSilent)
        // Over a busy background it is not "isolated": the engine hears it as before.
        let busy = noise(sr * 2, seed: 9).map { $0 * self.db(-35) }
        XCTAssertFalse(InputLevel.analyze(pop(in: busy, at: sr, peak: 0.9)).isSilent)
        // A short word in a quiet room is not a pop.
        let word = Array(speech(seconds: 0.4, peakDb: -20).prefix(sr * 3 / 10))
        let clip = [Float](repeating: 0, count: sr) + word + [Float](repeating: 0, count: sr)
        XCTAssertFalse(InputLevel.analyze(clip).isIsolatedPop)
        XCTAssertFalse(InputLevel.analyze(clip).isSilent)
    }

    // MARK: - Rescue and boost need a talker

    func testQuietSpeechAboveTheRescueFloorIsKeptAndLifted() {
        // Just above the rescue floor (this synthetic talker's speech level sits ~6 dB under
        // its peak). If that is under the old bail, the clip is rescued; either way it is lifted.
        let x = speech(seconds: 2, peakDb: InputLevel.rescueFloorDb + 8)
        let a = InputLevel.analyze(x)
        XCTAssertTrue(a.hasSpeechEvidence, "\(a)")
        XCTAssertGreaterThanOrEqual(a.speechDb, InputLevel.rescueFloorDb, "\(a)")
        XCTAssertFalse(a.isSilent, "\(a)")
        XCTAssertGreaterThan(InputLevel.dbfs(a.gain), 15)
        var y = x
        InputLevel.prepare(&y, enabled: true)
        XCTAssertLessThanOrEqual(y.map(abs).max()!, InputLevel.peakCeiling + 1e-4)
        XCTAssertGreaterThan(rms(y), rms(x) * 5)
    }

    func testParakeetIsOnlyLiftedWhenRescuedFromUnderTheOldBail() {
        // Above the old bail: Whisper is lifted, Parakeet gets the clip bit-for-bit.
        let above = speech(seconds: 2, peakDb: -40)
        XCTAssertFalse(InputLevel.analyze(above).legacySilent)
        XCTAssertGreaterThan(InputLevel.dbfs(InputLevel.analyze(above).gain), 6)
        let pk = InputLevel.analyze(above, boostAboveLegacyBail: false)
        XCTAssertTrue(pk.hasSpeechEvidence, "\(pk)")
        XCTAssertFalse(pk.isSilent)
        XCTAssertEqual(pk.gain, 1)
        var y = above
        InputLevel.prepare(&y, enabled: true, boostAboveLegacyBail: false)
        XCTAssertEqual(y, above)
        // Under the old bail (master typed nothing): rescued and lifted on Parakeet too.
        let under = speech(seconds: 2, peakDb: InputLevel.rescueFloorDb + 8)
        let pkUnder = InputLevel.analyze(under, boostAboveLegacyBail: false)
        XCTAssertTrue(pkUnder.legacySilent, "\(pkUnder)")
        XCTAssertFalse(pkUnder.isSilent, "\(pkUnder)")
        XCTAssertGreaterThan(InputLevel.dbfs(pkUnder.gain), 15)
    }

    func testATalkerBelowTheRescueFloorIsHandledAsBefore() {
        // A TV in the next room: real speech, but quieter than any user at their own mic.
        let x = speech(seconds: 2, peakDb: -66)
        let a = InputLevel.analyze(x)
        XCTAssertLessThan(a.speechDb, InputLevel.rescueFloorDb)
        XCTAssertTrue(a.isSilent)
        XCTAssertEqual(a.gain, 1)
    }

    func testNormalSpeechIsLeftBitForBit() {
        let x = speech(seconds: 2, peakDb: -6)
        let a = InputLevel.analyze(x)
        XCTAssertTrue(a.hasSpeechEvidence)
        XCTAssertGreaterThan(a.speechDb, InputLevel.boostBelowDb)
        var y = x
        InputLevel.prepare(&y, enabled: true)
        XCTAssertEqual(y, x)
    }

    func testOneShortWordAfterLongSilenceIsMeasuredOnTheWordNotTheSilence() {
        // A normal "hi" after 8 s of quiet: the level comes from the word, so no boost.
        let word = Array(speech(seconds: 0.4, peakDb: -12).prefix(sr * 3 / 10))
        let clip = noise(sr * 8, seed: 11).map { $0 * self.db(-80) } + word
        XCTAssertEqual(InputLevel.analyze(clip).gain, 1)
    }

    func testABuzzIsNeverBoostedOrRescued() {
        for peakDb: Float in [-60, -50, -40, -30] {
            for gated in [false, true] {
                let a = InputLevel.analyze(buzz(seconds: 3, peakDb: peakDb, gated: gated))
                XCTAssertFalse(a.hasSpeechEvidence, "buzz \(peakDb) gated \(gated)")
                XCTAssertEqual(a.gain, 1)
                XCTAssertEqual(a.isSilent, peakDb < -48)
            }
        }
    }

    func testRumbleAndHissAreNotSpeech() {
        var y: Float = 0
        let brown = noise(sr * 3, seed: 12).map { v -> Float in y = 0.995 * y + v * 0.1; return y }
        for x in [noise(sr * 3, seed: 13), brown] {
            for level: Float in [-60, -50, -30] {
                let g = db(level) / rms(x)
                let a = InputLevel.analyze(x.map { $0 * g })
                XCTAssertFalse(a.hasSpeechEvidence)
                XCTAssertEqual(a.gain, 1)
            }
        }
    }

    func testDigitalSilenceAndDitherAreSilent() {
        XCTAssertTrue(InputLevel.analyze([Float](repeating: 0, count: sr * 3)).isSilent)
        XCTAssertTrue(InputLevel.analyze(noise(sr * 3, seed: 1).map { $0 / 32767 }).isSilent)
    }

    // MARK: - Gain arithmetic

    func testGainLimits() {
        XCTAssertEqual(InputLevel.gain(speechDb: -10, peak: 0.3), 1, "never attenuates")
        XCTAssertEqual(InputLevel.gain(speechDb: InputLevel.targetSpeechDb - 3, peak: 0.01), 1,
                       "small boosts are skipped")
        XCTAssertEqual(InputLevel.dbfs(InputLevel.gain(speechDb: -100, peak: 1e-5)),
                       InputLevel.maxGainDb, accuracy: 0.01)
        let g = InputLevel.gain(speechDb: -60, peak: 0.1)
        XCTAssertLessThanOrEqual(0.1 * g, InputLevel.peakCeiling + 1e-4)
    }

    func testLongImportsKeepTheOldBehaviour() {
        let long = [Float](repeating: 0.001, count: (InputLevel.maxAnalysedSeconds + 1) * sr)
        let a = InputLevel.analyze(long)
        XCTAssertTrue(a.isSilent)
        XCTAssertEqual(a.gain, 1)
    }

    func testEmptyAndTinyClips() {
        XCTAssertTrue(InputLevel.analyze([]).isSilent)
        XCTAssertFalse(InputLevel.analyze([Float](repeating: 0.3, count: 100)).isSilent)
        XCTAssertEqual(InputLevel.analyze([Float](repeating: 0.3, count: 100)).gain, 1)
    }
}
