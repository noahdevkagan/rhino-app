import AVFoundation
import XCTest
@testable import OpenSuperWhisper

final class VideoAudioExtractorTests: XCTestCase {
    private func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("tests/fixtures/mp4/\(name).mp4")
    }

    func testStereoVideoProducesMono16kWAV() async throws {
        let url = try await VideoAudioExtractor.extract(from: fixture("stereo-audio"))
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.processingFormat.sampleRate, 16_000)
        XCTAssertEqual(file.processingFormat.channelCount, 1)
        XCTAssertEqual(Double(file.length) / 16_000, 2, accuracy: 0.1)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                     frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0],
                                          count: Int(buffer.frameLength))
        XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.01)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture("stereo-audio").path))
    }

    func testVideoWithoutAudioExplainsFailure() async {
        do {
            let url = try await VideoAudioExtractor.extract(from: fixture("no-audio"))
            try? FileManager.default.removeItem(at: url)
            XCTFail("Expected missing audio failure")
        } catch VideoAudioExtractor.ExtractionError.noAudio {
            // Expected; the queue presents this localized error in history.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancelledExtractionDoesNotReturnAFile() async {
        let source = fixture("stereo-audio")
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await VideoAudioExtractor.extract(from: source)
        }
        do {
            let url = try await task.value
            try? FileManager.default.removeItem(at: url)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testVideoDetectionMatchesDropTypes() {
        for name in ["clip.mp4", "clip.MP4", "clip.m4v"] {
            XCTAssertTrue(VideoAudioExtractor.isVideo(URL(fileURLWithPath: "/tmp/\(name)")), name)
        }
        for name in ["clip.m4a", "clip.wav", "clip.mov"] {
            XCTAssertFalse(VideoAudioExtractor.isVideo(URL(fileURLWithPath: "/tmp/\(name)")), name)
        }
    }

    func testRemoteURLIsRejectedBeforeReading() async {
        do {
            _ = try await VideoAudioExtractor.extract(from: URL(string: "https://example.invalid/video.mp4")!)
            XCTFail("Expected local-file restriction")
        } catch VideoAudioExtractor.ExtractionError.nonLocalFile {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCorruptVideoFails() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).mp4")
        try Data("not a video".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        do {
            let url = try await VideoAudioExtractor.extract(from: source)
            try? FileManager.default.removeItem(at: url)
            XCTFail("Expected corrupt video failure")
        } catch {
            XCTAssertFalse(error is CancellationError)
        }
    }
}
