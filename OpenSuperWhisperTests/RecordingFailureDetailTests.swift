//
//  RecordingFailureDetailTests.swift
//  OpenSuperWhisperTests
//
//  Failed dictations used to persist only a generic reason ("Transcription
//  failed") — the raw error, the engine loader's message, and the attempted
//  model were printed to the console and lost, leaving field failures
//  undiagnosable. These tests pin the failureDetail builder and the
//  short-reason mapping that together fix that.
//

import XCTest
@testable import OpenSuperWhisper

final class FailureDetailBuilderTests: XCTestCase {

    func testDetailCarriesRawErrorDescription() {
        let detail = DictationPipeline.failureDetail(
            for: TranscriptionError.contextInitializationFailed,
            engineError: nil,
            attemptedModel: nil)
        XCTAssertTrue(detail.contains("contextInitializationFailed"),
                      "detail must keep the raw error, got: \(detail)")
    }

    func testDetailIncludesEngineLoaderMessage() {
        let detail = DictationPipeline.failureDetail(
            for: TranscriptionError.contextInitializationFailed,
            engineError: "Failed to load engine: model file truncated",
            attemptedModel: nil)
        XCTAssertTrue(detail.contains("model file truncated"),
                      "the loader's message is the diagnosis — it must be kept, got: \(detail)")
    }

    func testDetailIncludesAttemptedModel() {
        let detail = DictationPipeline.failureDetail(
            for: TranscriptionError.processingFailed,
            engineError: nil,
            attemptedModel: "Parakeet v2")
        XCTAssertTrue(detail.contains("model: Parakeet v2"),
                      "failed rows have nil modelUsed, so the attempted model belongs in the detail, got: \(detail)")
    }

    func testDetailOmitsEmptyParts() {
        let detail = DictationPipeline.failureDetail(
            for: TranscriptionError.audioConversionFailed,
            engineError: "",
            attemptedModel: nil)
        XCTAssertFalse(detail.contains("·"),
                       "empty engineError / nil model must not leave separators, got: \(detail)")
    }

    func testDetailJoinsAllThreeParts() {
        let detail = DictationPipeline.failureDetail(
            for: TranscriptionError.contextInitializationFailed,
            engineError: "Failed to load engine: no such file",
            attemptedModel: "whisper-large-v3-turbo")
        XCTAssertTrue(detail.contains("contextInitializationFailed"))
        XCTAssertTrue(detail.contains("no such file"))
        XCTAssertTrue(detail.contains("model: whisper-large-v3-turbo"))
    }
}

final class FailureReasonMappingTests: XCTestCase {

    // The flash / row reason stays short and actionable; the technical detail lives in
    // failureDetail. These pin the user-facing strings so a refactor can't swap them.

    func testModelLoadFailurePointsAtSettings() {
        XCTAssertEqual(
            DictationPipeline.failureReason(for: TranscriptionError.contextInitializationFailed),
            "Model not loaded — check Settings → Models")
    }

    func testAudioConversionFailureNamesTheAudio() {
        XCTAssertEqual(
            DictationPipeline.failureReason(for: TranscriptionError.audioConversionFailed),
            "Couldn't read the recording's audio")
    }

    func testUnknownErrorStaysGeneric() {
        struct SomeError: Error {}
        XCTAssertEqual(DictationPipeline.failureReason(for: SomeError()), "Transcription failed")
    }
}

final class RecordingFailureDetailFieldTests: XCTestCase {

    func testFailureDetailDefaultsToNil() {
        let recording = Recording(
            id: UUID(), timestamp: Date(), fileName: "x.wav", transcription: "",
            duration: 0, status: .completed, progress: 1.0, sourceFileURL: nil)
        XCTAssertNil(recording.failureDetail)
    }

    func testFailureDetailRoundTripsThroughCodable() throws {
        var recording = Recording(
            id: UUID(), timestamp: Date(), fileName: "x.wav", transcription: "failed",
            duration: 0, status: .failed, progress: 0, sourceFileURL: nil)
        recording.failureDetail = "contextInitializationFailed · model: Parakeet v2"

        let data = try JSONEncoder().encode(recording)
        let decoded = try JSONDecoder().decode(Recording.self, from: data)
        XCTAssertEqual(decoded.failureDetail, "contextInitializationFailed · model: Parakeet v2")
    }
}
