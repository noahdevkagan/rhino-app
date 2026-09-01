import Foundation
import AVFoundation
import FluidAudio

class FluidAudioEngine: TranscriptionEngine {
    var engineName: String { "FluidAudio" }

    private var asrManager: AsrManager?
    private var asrModels: AsrModels?
    private var isCancelled = false
    private var transcriptionTask: Task<String, Error>?
    private var progressTask: Task<Void, Never>?

    /// Stage breakdown of the most recent transcription (see `TranscriptionStageTimings`).
    /// Written at the end of each `transcribeAudio` run; the engine gate serializes runs,
    /// so the caller can read it right after the call returns.
    private(set) var lastStageTimings: TranscriptionStageTimings?

    /// CTC vocabulary context for the boosting path, cached across dictations. Building it
    /// (`CustomVocabularyContext.loadWithCtcTokens`) loads the CTC model set and tokenizer —
    /// hundreds of ms per call, and a full model download on the very first one — for a result
    /// that only changes when the dictionary changes. Keyed by the boost terms; the engine
    /// itself is rebuilt on model-version change, so terms alone identify the entry.
    private var cachedBoostVocabulary: (terms: [String], vocab: CustomVocabularyContext, models: CtcModels)?

    /// When set ("v2"/"v3"), overrides the pref-selected model version — lets the
    /// remote local-fallback build an engine for a specific model without mutating
    /// global prefs.
    private let versionOverride: String?

    init(versionOverride: String? = nil) {
        self.versionOverride = versionOverride
    }
    
    var onProgressUpdate: ((Float) -> Void)?
    
    var isModelLoaded: Bool {
        asrManager != nil
    }
    
    func initialize() async throws {
        let versionString = versionOverride ?? AppPreferences.shared.fluidAudioModelVersion
        let version: AsrModelVersion = versionString == "v2" ? .v2 : .v3

        // Shared model set (ParakeetModelCache): the engine, live preview, and the
        // boosting path all reference one loaded copy per version instead of each
        // building their own MLModel instances.
        let models = try await ParakeetModelCache.shared.models(for: version)
        let manager = AsrManager(config: Self.asrConfig(for: version))
        try await manager.loadModels(models)

        asrManager = manager
        asrModels = models

        // Warm-up inference on half a second of silence. The first prediction on a freshly
        // loaded CoreML model pays one-time specialization/ANE setup (~300ms measured on an
        // M-series Mac; the field report's 835ms-then-603ms first-call gap) — pay it here,
        // during the launch preload / model switch, instead of on the user's first dictation.
        // Failures are ignored: warm-up is an optimization, never a reason to fail init.
        let warmupStart = CFAbsoluteTimeGetCurrent()
        var warmupState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let silence = [Float](repeating: 0, count: 8000)
        _ = try? await manager.transcribe(silence, decoderState: &warmupState)
        print(String(format: "FluidAudioEngine: warm-up inference took %.0fms",
                     (CFAbsoluteTimeGetCurrent() - warmupStart) * 1000))
    }

    func transcribeAudio(url: URL, settings: Settings) async throws -> String {
        guard let asrManager = asrManager else {
            throw TranscriptionError.contextInitializationFailed
        }
        
        isCancelled = false
        
        // Notify start
        onProgressUpdate?(0.02)
        
        guard !isCancelled else {
            throw CancellationError()
        }
        
        // Start progress monitoring task using FluidAudio's transcriptionProgressStream
        let onProgress = onProgressUpdate
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Get the real progress stream from FluidAudio
                let progressStream = await asrManager.transcriptionProgressStream
                
                for try await progress in progressStream {
                    guard !Task.isCancelled, !self.isCancelled else { break }
                    
                    // FluidAudio reports 0.0-1.0, we map to 0.05-0.95
                    let scaledProgress = 0.05 + Float(progress) * 0.90
                    
                    await MainActor.run {
                        onProgress?(scaledProgress)
                    }
                }
            } catch {
                // Stream finished or error
            }
        }
        
        defer {
            progressTask?.cancel()
            progressTask = nil
        }

        // Load + convert the audio here (not inside FluidAudio's URL entry point) so the file
        // stage and the inference stage are timed separately. The recorder writes 16kHz mono
        // WAV, so for a real dictation this is a plain read — any resample cost showing up in
        // `loadConvertMs` means the input wasn't ours. (#latency)
        let loadStart = CFAbsoluteTimeGetCurrent()
        let samples = try AudioConverter().resampleAudioFile(url)
        let loadConvertMs = (CFAbsoluteTimeGetCurrent() - loadStart) * 1000

        // Two inference paths:
        //  • No custom dictionary  → the offline AsrManager (full accuracy, the default).
        //  • Custom dictionary set  → a sliding-window pass with vocabulary boosting, the only
        //    place FluidAudio 0.15.4 exposes decoder boosting. We feed the samples through it
        //    rather than the mic (see `transcribeSamplesWithBoosting`).
        let boostTerms = activeBoostTerms()
        let inferStart = CFAbsoluteTimeGetCurrent()
        let rawText: String
        if boostTerms.isEmpty {
            // A fresh TDT decoder state per file keeps transcriptions independent.
            var decoderState = TdtDecoderState.make(decoderLayers: await asrManager.decoderLayerCount)
            rawText = try await asrManager.transcribe(
                samples, decoderState: &decoderState,
                language: Self.languageHint(for: settings.selectedLanguage)).text
        } else {
            // Known gap: SlidingWindowAsrManager (FluidAudio 0.15.4) has no language
            // parameter, so the boosting path still decodes unhinted.
            rawText = try await transcribeSamplesWithBoosting(samples: samples, boostTerms: boostTerms)
        }
        let inferenceMs = (CFAbsoluteTimeGetCurrent() - inferStart) * 1000

        guard !isCancelled else {
            throw CancellationError()
        }

        // Finalize
        onProgressUpdate?(0.95)

        let postStart = CFAbsoluteTimeGetCurrent()
        var processedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        if settings.shouldApplyCustomDictionary {
            processedText = CustomDictionary.apply(processedText, entries: settings.customDictionaryEntries)
        }
        let postProcessMs = (CFAbsoluteTimeGetCurrent() - postStart) * 1000

        let timings = TranscriptionStageTimings(
            path: boostTerms.isEmpty ? "parakeet-offline" : "parakeet-boosted",
            audioSeconds: Double(samples.count) / 16000.0,
            loadConvertMs: loadConvertMs,
            inferenceMs: inferenceMs,
            postProcessMs: postProcessMs)
        lastStageTimings = timings
        print("ASR stages: \(timings.logLine)")

        onProgressUpdate?(1.0)

        return processedText.isEmpty ? TranscriptionResult.noSpeech : processedText
    }
    
    func cancelTranscription() {
        isCancelled = true
        progressTask?.cancel()
        progressTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
    }
    
    func getSupportedLanguages() -> [String] {
        EngineCapabilities.supportedLanguages(
            engine: "fluidaudio", fluidAudioModelVersion: AppPreferences.shared.fluidAudioModelVersion)
    }

    /// The decoder's script filter for the selected dictation language. Without it the v3
    /// multilingual model auto-detects per chunk and can drift into the wrong script
    /// mid-dictation — reported as German dictations coming back in Russian. The hint makes
    /// the TDT decoder skip top-K tokens whose script doesn't match the language (FluidAudio's
    /// TokenLanguageFilter, added upstream for exactly this: Cyrillic output on Polish audio,
    /// their #512). "auto" and codes the filter doesn't cover (tr, ar, zh, ja, ca) map to nil
    /// — no filtering, identical to the old behavior — and v2/tdtJa models ignore the hint
    /// upstream, so this is safe to pass unconditionally.
    static func languageHint(for selectedLanguage: String) -> Language? {
        Language(rawValue: selectedLanguage)
    }

    /// v3 runs with `melChunkContext` off, per upstream's guidance on the flag: with it on,
    /// the 80ms mel-context prepend on long-form chunks can shift the encoder's first-frame
    /// distribution enough that the multilingual decoder "drifts back to its English-biased
    /// prior" (their #594) — i.e. non-English dictations come back in English. Off, v3 uses
    /// acoustic warmup plus silence-aligned starts instead, which upstream documents as the
    /// correct v3 configuration. v2 (English-only, where the prepend fixes all-blank chunk
    /// boundaries) keeps the default.
    static func asrConfig(for version: AsrModelVersion) -> ASRConfig {
        version == .v3 ? ASRConfig(melChunkContext: false) : .default
    }

    /// The custom-dictionary terms to bias recognition toward, or `[]` when the dictionary
    /// is disabled/empty. Single source shared with Whisper's prompt boost and the live
    /// streaming preview (`CustomDictionary.boostTerms`).
    private func activeBoostTerms() -> [String] {
        let prefs = AppPreferences.shared
        // Boosting is opt-in (separate from the always-on text replacement): only bias the
        // decoder when the user explicitly enabled it for rare/distinctive terms (#over-boost).
        guard prefs.customDictionaryEnabled, prefs.customDictionaryBoostEnabled else { return [] }
        return CustomDictionary.boostTerms(entries: prefs.customDictionaryEntries)
    }

    /// Transcribes converted samples through a `SlidingWindowAsrManager` configured with
    /// vocabulary boosting — the only API surface in FluidAudio 0.15.4 that biases the Parakeet
    /// decoder toward custom terms. The 11+2+2 `.default` window matches the offline chunking, so
    /// output quality tracks the offline path; boosting only nudges misrecognized terms.
    ///
    /// The audio comes entirely from `streamAudio(_:)` (the converted samples, sliced), never a
    /// microphone — `startStreaming(source:)` only records the source as metadata and opens no
    /// input device. `finish()` returns the merged transcript.
    private func transcribeSamplesWithBoosting(samples: [Float], boostTerms: [String]) async throws -> String {
        // Same override-aware version as initialize(), so the cached set the engine
        // already holds is reused instead of loading a second full copy per
        // dictation (the boosting path used to do exactly that).
        let versionString = versionOverride ?? AppPreferences.shared.fluidAudioModelVersion
        let version: AsrModelVersion = versionString == "v2" ? .v2 : .v3
        let models = try await ParakeetModelCache.shared.models(for: version)

        let manager = SlidingWindowAsrManager(config: .default)
        try await configureVocabulary(on: manager, boostTerms: boostTerms)
        try await manager.loadModels(models)
        try await manager.startStreaming(source: .system)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)
        else {
            await manager.cancel()
            return ""
        }

        // Feed in window-sized chunks (the manager re-buffers internally for its sliding window).
        let samplesPerChunk = Int(SlidingWindowAsrConfig.default.chunkSeconds * format.sampleRate)
        var position = 0
        while position < samples.count {
            if isCancelled {
                await manager.cancel()
                throw CancellationError()
            }
            let chunkSize = min(samplesPerChunk, samples.count - position)
            guard let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(chunkSize))
            else { break }
            samples.withUnsafeBufferPointer { src in
                chunk.floatChannelData![0].update(from: src.baseAddress! + position, count: chunkSize)
            }
            chunk.frameLength = AVAudioFrameCount(chunkSize)
            await manager.streamAudio(chunk)
            position += chunkSize
            await Task.yield()
        }

        return try await manager.finish()
    }

    /// Configures vocabulary boosting on a `SlidingWindowAsrManager` from the dictionary terms.
    /// Throws on failure so the caller surfaces it rather than silently transcribing without the
    /// requested boost.
    ///
    /// The tokenized vocabulary + CTC model set is cached on the engine across dictations:
    /// `loadWithCtcTokens` loads the CTC models and tokenizer every call (hundreds of ms, plus a
    /// full model download on the first ever call), for a result that only changes when the
    /// dictionary's terms change. The temp-file + CTC-token approach itself is unchanged.
    private func configureVocabulary(on manager: SlidingWindowAsrManager, boostTerms: [String]) async throws {
        let terms = boostTerms.filter { !$0.isEmpty }
        guard !terms.isEmpty else { return }

        let vocabulary: (vocab: CustomVocabularyContext, models: CtcModels)
        if let cached = cachedBoostVocabulary, cached.terms == terms {
            vocabulary = (cached.vocab, cached.models)
        } else {
            let vocabularyURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Rhino-ParakeetVocabulary-\(UUID().uuidString)")
                .appendingPathExtension("txt")
            try terms.joined(separator: "\n").write(to: vocabularyURL, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: vocabularyURL) }

            vocabulary = try await CustomVocabularyContext.loadWithCtcTokens(from: vocabularyURL.path)
            cachedBoostVocabulary = (terms, vocabulary.vocab, vocabulary.models)
        }
        guard !vocabulary.vocab.terms.isEmpty else { return }

        try await manager.configureVocabularyBoosting(
            vocabulary: vocabulary.vocab,
            ctcModels: vocabulary.models
        )
    }
}

