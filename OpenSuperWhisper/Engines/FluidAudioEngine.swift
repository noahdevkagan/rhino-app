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
        let samples = try LocalAudioReader.samples(at: url)
        let loadConvertMs = (CFAbsoluteTimeGetCurrent() - loadStart) * 1000

        // Parakeet has no VAD front-end (Whisper's Silero gate doesn't run on this path), so
        // a dead-mic / pure-silence clip still reaches the decoder, which can emit a stray
        // token. Same digital-silence bail Whisper uses: a peak below any plausible speech
        // means there is nothing to transcribe.
        if WhisperEngine.isNearSilence(samples) {
            let timings = TranscriptionStageTimings(
                path: "parakeet-silence",
                audioSeconds: Double(samples.count) / 16000.0,
                loadConvertMs: loadConvertMs,
                inferenceMs: 0,
                postProcessMs: 0)
            lastStageTimings = timings
            print("ASR stages: \(timings.logLine)")
            onProgressUpdate?(1.0)
            return TranscriptionResult.noSpeech
        }

        // Always the offline AsrManager. Dictionary boosting used to route through
        // SlidingWindowAsrManager, which on real dictations dropped 5% of the words (whole
        // sentences at a time), inserted dictionary terms nobody said and ran 6x slower
        // (docs/performance-audit-2026-10-05.md). The dictionary's replacement and
        // sound-alike pass below fixes the same names without touching the decoder.
        let inferStart = CFAbsoluteTimeGetCurrent()
        // A fresh TDT decoder state per file keeps transcriptions independent.
        var decoderState = TdtDecoderState.make(decoderLayers: await asrManager.decoderLayerCount)
        let rawText = try await asrManager.transcribe(
            samples, decoderState: &decoderState,
            language: Self.languageHint(for: settings.selectedLanguage)).text
        let inferenceMs = (CFAbsoluteTimeGetCurrent() - inferStart) * 1000

        guard !isCancelled else {
            throw CancellationError()
        }

        // Finalize
        onProgressUpdate?(0.95)

        let postStart = CFAbsoluteTimeGetCurrent()
        var processedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        processedText = settings.applyCustomDictionary(processedText)
        let postProcessMs = (CFAbsoluteTimeGetCurrent() - postStart) * 1000

        let timings = TranscriptionStageTimings(
            path: "parakeet-offline",
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
}
