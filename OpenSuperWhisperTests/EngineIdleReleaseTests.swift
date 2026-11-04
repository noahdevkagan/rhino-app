//
//  EngineIdleReleaseTests.swift
//  OpenSuperWhisperTests
//
//  The speech engine leaves memory after an idle spell and comes back for the next
//  dictation, without ever being pulled out from under a transcription.
//

import AVFoundation
import XCTest
@testable import OpenSuperWhisper

@MainActor
final class EngineIdleReleaseTests: XCTestCase {
    private var service: TranscriptionService!
    private var clip: URL!
    private let originalDelay = TranscriptionService.idleReleaseDelay

    override func setUp() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let model = root.appendingPathComponent("ggml-tiny.en.bin")
        guard FileManager.default.fileExists(atPath: model.path) else {
            throw XCTSkip("Local Whisper tiny model not present")
        }
        let prefs = AppPreferences.shared
        prefs.selectedEngine = "whisper"
        prefs.selectedWhisperModelPath = model.path
        prefs.hasCompletedOnboarding = true
        service = TranscriptionService()
        clip = try Self.writeToneClip()
    }

    override func tearDown() async throws {
        TranscriptionService.idleReleaseDelay = originalDelay
        service?.reloadEngine()
        if let clip { try? FileManager.default.removeItem(at: clip) }
    }

    func testEngineIsReleasedAfterIdleDelay() async throws {
        TranscriptionService.idleReleaseDelay = 0.2
        service.preloadEngine()
        try await waitUntil { self.service.isEngineReady }
        try await waitUntil { !self.service.isEngineReady }
        XCTAssertNil(service.engineError)
    }

    func testTranscriptionReloadsAReleasedEngine() async throws {
        TranscriptionService.idleReleaseDelay = 0.2
        service.preloadEngine()
        try await waitUntil { self.service.isEngineReady }
        try await waitUntil { !self.service.isEngineReady }

        _ = try await service.transcribeAudio(url: clip, settings: Self.settings())
        XCTAssertEqual(service.engineLoadsStarted, 2)
        try await waitUntil { !self.service.isEngineReady }
    }

    func testReleaseNeverInterruptsATranscription() async throws {
        TranscriptionService.idleReleaseDelay = 0.001
        for _ in 0..<3 {
            _ = try await service.transcribeAudio(url: clip, settings: Self.settings())
        }
    }

    func testWarmUpAndTranscriptionShareOneLoad() async throws {
        service.prewarmEngine()
        service.prewarmEngine()
        _ = try await service.transcribeAudio(url: clip, settings: Self.settings())
        XCTAssertEqual(service.engineLoadsStarted, 1)
    }

    func testWarmUpSkipsAModelThatIsNotInstalled() async throws {
        AppPreferences.shared.selectedWhisperModelPath = "/nonexistent/ggml-missing.bin"
        service.prewarmEngine()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(service.engineLoadsStarted, 0)
        XCTAssertNil(service.engineError)
    }

    func testModelSwitchMidLoadStillEndsLoaded() async throws {
        let path = try XCTUnwrap(AppPreferences.shared.selectedWhisperModelPath)
        service.prewarmEngine()
        await Task.yield()
        service.reloadModel(with: path)
        _ = try await service.transcribeAudio(url: clip, settings: Self.settings())
        XCTAssertTrue(service.isEngineReady)
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.engineError)
    }

    private static func settings() -> Settings {
        var settings = Settings()
        settings.selectedLanguage = "en"
        settings.initialPrompt = ""
        settings.customDictionaryEnabled = false
        return settings
    }

    /// Two seconds of tone: loud enough to skip the silence bail, so whisper really runs.
    private static func writeToneClip() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("idle-release-\(UUID().uuidString).wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let frames = AVAudioFrameCount(32_000)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for i in 0..<Int(frames) {
            samples[i] = 0.3 * sin(2 * .pi * 220 * Float(i) / 16_000)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    private func waitUntil(timeout: TimeInterval = 30, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("Timed out waiting for condition") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
