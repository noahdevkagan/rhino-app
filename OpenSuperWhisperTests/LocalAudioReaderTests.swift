import AVFoundation
import XCTest
@testable import OpenSuperWhisper

final class LocalAudioReaderTests: XCTestCase {
    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func writeAudio(_ url: URL, rate: Double, channels: AVAudioChannelCount,
                            aac: Bool = false) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate)))
        buffer.frameLength = buffer.frameCapacity
        for channel in 0..<Int(channels) {
            for frame in 0..<Int(buffer.frameLength) {
                buffer.floatChannelData![channel][frame] = Float(sin(Double(frame) * 2 * .pi * 440 / rate)) * 0.25
            }
        }
        let settings: [String: Any] = aac ? [AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: rate, AVNumberOfChannelsKey: channels, AVEncoderBitRateKey: 128_000] : format.settings
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }

    func testRecorderWAVPreservesSamples() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("recording.wav")
            try writeAudio(url, rate: 16_000, channels: 1)
            let samples = try LocalAudioReader.samples(at: url)
            XCTAssertEqual(samples.count, 16_000)
            for frame in samples.indices {
                XCTAssertEqual(samples[frame], Float(sin(Double(frame) * 2 * .pi * 440 / 16_000)) * 0.25,
                               accuracy: 0.00001)
            }
        }
    }

    func testStereoWAVResamplesToMono16k() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("stereo.wav")
            try writeAudio(url, rate: 44_100, channels: 2)
            let samples = try LocalAudioReader.samples(at: url)
            XCTAssertEqual(Double(samples.count), 16_000, accuracy: 10)
            XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.1)
            XCTAssertTrue(samples.allSatisfy(\.isFinite))
        }
    }

    func testAACContainerDecodesIncludingWhenSavedWithWAVExtension() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("import.m4a")
            try writeAudio(url, rate: 44_100, channels: 2, aac: true)
            let samples = try LocalAudioReader.samples(at: url)
            XCTAssertEqual(Double(samples.count), 16_000, accuracy: 1_600)
            XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.1)
            let saved = directory.appendingPathComponent("history.wav")
            try FileManager.default.copyItem(at: url, to: saved)
            XCTAssertEqual(try LocalAudioReader.samples(at: saved), samples)
        }
    }

    func testMalformedEmptyAndMissingFilesThrow() throws {
        try withDirectory { directory in
            for (name, data) in [("broken.m4a", Data("not an audio container".utf8)), ("empty.m4a", Data())] {
                let url = directory.appendingPathComponent(name)
                try data.write(to: url)
                XCTAssertThrowsError(try LocalAudioReader.samples(at: url))
            }
            XCTAssertThrowsError(try LocalAudioReader.samples(at: directory.appendingPathComponent("missing.m4a")))
        }
    }

    func testRejectsRemoteURLsBeforeOpening() {
        XCTAssertThrowsError(try LocalAudioReader.samples(at: URL(string: "https://example.invalid/audio.m4a")!))
    }

    func testCancellationStopsDecoding() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            // Valid input ensures cancellation is checked in the decode loop.
            try withDirectory { directory in
                let url = directory.appendingPathComponent("cancel.wav")
                try writeAudio(url, rate: 16_000, channels: 1)
                XCTAssertThrowsError(try LocalAudioReader.samples(at: url)) { error in
                    XCTAssertTrue(error is CancellationError)
                }
            }
        }
        try await task.value
    }
}
