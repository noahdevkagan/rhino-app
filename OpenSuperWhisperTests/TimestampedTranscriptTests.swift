import AVFoundation
import FluidAudio
import XCTest
@testable import OpenSuperWhisper

final class TimestampedTranscriptTests: XCTestCase {
    private func token(_ text: String, _ start: Double, _ end: Double) -> TokenTiming {
        TokenTiming(token: text, tokenId: 1, startTime: start, endTime: end, confidence: 1)
    }

    private func result(_ tokens: [TokenTiming]?, text: String = "Some speech") -> ASRResult {
        ASRResult(text: text, confidence: 1, duration: 120, processingTime: 1, tokenTimings: tokens)
    }

    func testTimeCarriesMillisecondsAndHours() {
        XCTAssertEqual(TimestampedTranscript.time(59.9996), "00:01:00.000")
        XCTAssertEqual(TimestampedTranscript.time(3661.125), "01:01:01.125")
        XCTAssertEqual(TimestampedTranscript.time(0), "00:00:00.000")
    }

    func testEmptySegmentsDoNotLeaveTimestampOnlyLines() {
        XCTAssertNil(TimestampedTranscript.line(text: " \n", start: 0, end: 2))
    }

    func testSubwordsAndPunctuationStayTogetherWithOriginalOffset() throws {
        let output = try TimestampedTranscript.parakeet(result([
            token(" Hello", 4, 4.4), token(" para", 4.5, 4.7), token("keet", 4.7, 5),
            token(".", 5, 5.1), token(" Next", 6, 6.5), token("!", 6.5, 6.6)
        ]), transform: { $0 })
        XCTAssertEqual(output, "[00:00:04.000 → 00:00:05.100] Hello parakeet.\n[00:00:06.000 → 00:00:06.600] Next!")
    }

    func testLongLinesBreakAtWordBoundaryWithoutSplittingWord() throws {
        let output = try TimestampedTranscript.parakeet(result([
            token(" Some", 1, 2), token(" long", 2, 10), token(" word", 10.5, 10.8),
            token("piece", 11, 11.4), token(" next", 12, 13)
        ]), transform: { $0 })
        XCTAssertTrue(output.contains("wordpiece"))
        XCTAssertEqual(output.components(separatedBy: "\n").count, 2)
    }

    func testLongFormTimesDoNotResetAtChunkBoundary() throws {
        let output = try TimestampedTranscript.parakeet(result([
            token(" First.", 10, 11), token(" Later.", 75, 76)
        ]), transform: { $0 })
        XCTAssertTrue(output.hasSuffix("[00:01:15.000 → 00:01:16.000] Later."))
    }

    func testUnspacedLanguagePreservesCharacters() throws {
        let output = try TimestampedTranscript.parakeet(result([
            token("你好", 2, 3), token("。", 3, 3.1), token("再见", 4, 5), token("。", 5, 5.1)
        ]), transform: { $0 })
        XCTAssertEqual(output.components(separatedBy: "\n").count, 2)
        XCTAssertTrue(output.contains("你好。"))
        XCTAssertTrue(output.contains("再见。"))
    }

    func testMissingOrInvalidTimingsFailInsteadOfInventingTimes() {
        for tokens: [TokenTiming]? in [nil, [], [token(" hi", .nan, 1)], [token(" hi", 2, 1)]] {
            XCTAssertThrowsError(try TimestampedTranscript.parakeet(result(tokens), transform: { $0 }))
        }
    }

    func testSilenceIsEmptyEvenWithoutTimings() throws {
        XCTAssertEqual(try TimestampedTranscript.parakeet(result(nil, text: " "), transform: { $0 }), "")
    }

    func testFormattingCannotRewriteTimes() throws {
        let output = try TimestampedTranscript.parakeet(result([token(" Brand", 7, 8)]), transform: {
            $0.replacingOccurrences(of: "Brand", with: "Rhino")
        })
        let formatted = TimestampedTranscript.mapText(output) { $0.replacingOccurrences(of: "00", with: "oops") }
        XCTAssertEqual(formatted, "[00:00:07.000 → 00:00:08.000] Rhino")
    }

    func testWhisperTimedLinesDropTrailingSilenceHallucination() {
        let texts = ["Send the invoice today.", " Thank you."]
        let kept = WhisperEngine.trimmingTrailingHallucinations(
            texts: texts, noSpeechProbs: [0.05, 0.92], threshold: 0.6)
        let output = WhisperEngine.timestampedText(
            texts: kept, times: [(150, 420), (3000, 3200)], transform: { $0 })
        XCTAssertEqual(output, "[00:00:01.500 → 00:00:04.200] Send the invoice today.\n")
    }

    func testSettingAppliesOnlyToImportedFiles() {
        let prefs = AppPreferences.shared
        let old = prefs.showTimestamps
        defer { prefs.showTimestamps = old }
        prefs.showTimestamps = true
        XCTAssertTrue(Settings(forImportedFile: true).showTimestamps)
        XCTAssertFalse(Settings().showTimestamps)
        prefs.showTimestamps = false
        XCTAssertFalse(Settings(forImportedFile: true).showTimestamps)
    }

    func testImportIdentitySurvivesRetainedAudioRerun() throws {
        var recording = Recording(id: UUID(), timestamp: Date(), fileName: "\(UUID()).wav",
                                  transcription: "", duration: 2, status: .completed, progress: 1)
        XCTAssertFalse(recording.isImportedFile)
        recording.sourceFileURL = recording.url.path
        XCTAssertFalse(recording.isImportedFile)
        recording.sourceFileURL = "/missing-original-\(UUID()).mp3"
        XCTAssertTrue(recording.isImportedFile)
        try FileManager.default.createDirectory(at: Recording.recordingsDirectory, withIntermediateDirectories: true)
        try Data().write(to: recording.url)
        defer { try? FileManager.default.removeItem(at: recording.url) }
        XCTAssertEqual(TranscriptionQueue.transcriptionSource(for: recording,
            original: URL(fileURLWithPath: recording.sourceFileURL!)), recording.url)
    }
}

final class WhisperFileTimestampTests: XCTestCase {
    func testRealLocalFileIncludesTimes() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let model = root.appendingPathComponent("ggml-tiny.en.bin")
        guard FileManager.default.fileExists(atPath: model.path) else {
            throw XCTSkip("Local Whisper tiny model not present")
        }
        let engine = WhisperEngine(modelPathOverride: model.path)
        try await engine.initialize()
        var settings = Settings()
        settings.showTimestamps = true
        settings.selectedLanguage = "en"
        settings.customDictionaryEnabled = false
        settings.initialPrompt = ""
        let text = try await engine.transcribeAudio(url: root.appendingPathComponent("jfk.wav"), settings: settings)
        XCTAssertTrue(text.hasPrefix("[00:00:"), text)
        XCTAssertTrue(text.contains(" → "), text)
        XCTAssertTrue(text.lowercased().contains("country"), text)
        let attachment = XCTAttachment(string: text)
        attachment.name = "Whisper file with timestamps"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

final class ParakeetFileTimestampTests: XCTestCase {
    func testLocalLongFileKeepsWordsAndAbsoluteTimes() async throws {
        let directory = AsrModels.defaultCacheDirectory(for: .v2)
        guard AsrModels.modelsExist(at: directory, version: .v2) else {
            throw XCTSkip("Local Parakeet v2 model not present; never download in a test")
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let speech = try LocalAudioReader.samples(at: root.appendingPathComponent("jfk.wav"))
        let pause = [Float](repeating: 0, count: 32_000)
        let samples = [Float](repeating: 0, count: 80_000) + speech + pause + speech + pause + speech
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("timestamp-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let engine = FluidAudioEngine(versionOverride: "v2")
        try await engine.initialize()
        var settings = Settings()
        settings.selectedLanguage = "en"
        settings.customDictionaryEnabled = false
        settings.showTimestamps = false
        let plain = try await engine.transcribeAudio(url: url, settings: settings)
        settings.showTimestamps = true
        let timed = try await engine.transcribeAudio(url: url, settings: settings)
        let withoutTimes = timed.components(separatedBy: "\n").map { line in
            line.range(of: "] ").map { String(line[$0.upperBound...]) } ?? line
        }.joined(separator: " ")
        XCTAssertEqual(withoutTimes, plain)
        XCTAssertTrue(timed.contains("country"), timed)
        // Leading silence and later chunks must remain on the original media clock.
        let starts = timed.components(separatedBy: "\n").compactMap { line -> Double? in
            guard line.hasPrefix("[00:00:") else { return nil }
            return Double(line.dropFirst(7).prefix(6))
        }
        XCTAssertGreaterThan(try XCTUnwrap(starts.first), 3)
        XCTAssertGreaterThan(try XCTUnwrap(starts.last), 30)
        let attachment = XCTAttachment(string: timed)
        attachment.name = "Parakeet long file with leading silence"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
