import XCTest

@testable import OpenSuperWhisper

/// The VAD gate is allowed to make whisper faster, never to lose words. These pin the rule
/// that trimming only ever *removes silence*, and that every degenerate case the VAD can hand
/// back falls through to "transcribe everything" instead of returning an empty buffer.
final class SpeechTrimmingTests: XCTestCase {

    private let sampleRate = 16000

    /// A ramp makes each sample identifiable, so we can assert *which* audio survived.
    private func ramp(seconds: Int) -> [Float] {
        (0..<(seconds * sampleRate)).map { Float($0) }
    }

    func testKeepsOnlyTheSpeechRegion() {
        let samples = ramp(seconds: 10)
        // Speech from 2s to 4s, plus the 0.1s of trailing overlap whisper.cpp also keeps.
        let trimmed = WhisperEngine.speechOnlySamples(
            from: samples, segments: [WhisperVadSegment(startCs: 200, endCs: 400)])

        XCTAssertEqual(trimmed.count, 2 * sampleRate + sampleRate / 10)
        XCTAssertEqual(trimmed.first, Float(2 * sampleRate),
                       "the kept audio must start exactly where speech starts")
    }

    /// Two segments are separated by a short silence so the decoder still hears a pause,
    /// rather than two phrases welded into one sentence.
    func testInsertsSilenceBetweenSegments() {
        let samples = ramp(seconds: 10)
        let trimmed = WhisperEngine.speechOnlySamples(
            from: samples,
            segments: [WhisperVadSegment(startCs: 100, endCs: 200),
                       WhisperVadSegment(startCs: 500, endCs: 600)])

        let oneSecond = sampleRate
        let overlap = sampleRate / 10
        XCTAssertEqual(trimmed.count, 2 * (oneSecond + overlap) + overlap)

        let gapStart = oneSecond + overlap
        XCTAssertEqual(Array(trimmed[gapStart..<(gapStart + overlap)]),
                       [Float](repeating: 0, count: overlap))
    }

    /// No speech found is *not* a verdict of silence: the caller re-sends the whole clip, so
    /// a sentence the VAD failed to hear is still transcribed.
    func testNoSegmentsYieldsEmptySoCallerCanFallBack() {
        XCTAssertTrue(WhisperEngine.speechOnlySamples(from: ramp(seconds: 3), segments: []).isEmpty)
    }

    /// Backwards or zero-length segments are skipped rather than trusted into a crash.
    func testDegenerateSegmentsAreSkipped() {
        let samples = ramp(seconds: 5)
        let trimmed = WhisperEngine.speechOnlySamples(
            from: samples,
            segments: [WhisperVadSegment(startCs: 300, endCs: 100),
                       WhisperVadSegment(startCs: 200, endCs: 200)])

        XCTAssertTrue(trimmed.isEmpty)
    }

    /// A segment running past the end of the clip is clamped, not read out of bounds.
    func testSegmentBeyondTheEndIsClamped() {
        let samples = ramp(seconds: 2)
        let trimmed = WhisperEngine.speechOnlySamples(
            from: samples, segments: [WhisperVadSegment(startCs: 100, endCs: 9999)])

        XCTAssertEqual(trimmed.count, sampleRate, "clamped to what the clip actually holds")
        XCTAssertEqual(trimmed.last, Float(2 * sampleRate - 1))
    }

    /// Trimming must never invent audio: the result is always shorter than the input.
    func testTrimmingNeverGrowsTheBuffer() {
        let samples = ramp(seconds: 6)
        let segments: [WhisperVadSegment] = (0..<5).map { (i: Int) -> WhisperVadSegment in
            WhisperVadSegment(startCs: Int64(i * 100), endCs: Int64(i * 100 + 50))
        }
        let trimmed = WhisperEngine.speechOnlySamples(from: samples, segments: segments)

        XCTAssertLessThan(trimmed.count, samples.count)
    }

    /// Digital silence is near-silence; the faintest real speech is not. The threshold
    /// separates "no speech exists" (return nothing, never hallucinate) from "quiet
    /// sentence the VAD may have missed" (send the full clip to whisper).
    func testNearSilenceSeparatesSilenceFromQuietSpeech() {
        XCTAssertTrue(WhisperEngine.isNearSilence([Float](repeating: 0, count: 16000)))
        XCTAssertTrue(WhisperEngine.isNearSilence([Float](repeating: 0.001, count: 16000)),
                      "mic noise floor is still silence")
        XCTAssertFalse(WhisperEngine.isNearSilence([Float](repeating: 0.02, count: 16000)),
                       "quiet speech must NOT be treated as silence")
        var oneSpike = [Float](repeating: 0, count: 16000)
        oneSpike[8000] = 0.5
        XCTAssertFalse(WhisperEngine.isNearSilence(oneSpike),
                       "a single loud sample disqualifies the silence path")
    }

    /// The model has to actually be in the bundle, or the gate silently never runs. This is
    /// the check that a bundling slip would otherwise hide until someone timed a dictation.
    func testVadModelIsBundled() {
        XCTAssertNotNil(WhisperEngine.vadModelPath,
                        "ggml-silero-v5.1.2.bin must ship inside the app bundle")
    }
}
