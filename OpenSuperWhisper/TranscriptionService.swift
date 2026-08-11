import AVFoundation
import Foundation

@MainActor
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()

    /// One-permit gate serializing every transcription across the whole app. See the note in
    /// `transcribeAudio` — the engines share one non-thread-safe context. (parallel-recording #2)
    private static let engineGate = AsyncSemaphore(1)

    @Published private(set) var isTranscribing = false
    @Published private(set) var transcribedText = ""
    @Published private(set) var currentSegment = ""
    @Published private(set) var isLoading = false
    @Published private(set) var progress: Float = 0.0
    @Published private(set) var isConverting = false
    @Published private(set) var conversionProgress: Float = 0.0
    @Published private(set) var engineError: String?

    var isEngineReady: Bool {
        currentEngine != nil && !isLoading
    }

    private var currentEngine: TranscriptionEngine?
    private var loadedEngineKind: String?
    private var totalDuration: Float = 0.0

    /// The model that actually produced the most recent transcription. Read by the
    /// recording-save paths so history shows the real model. Set on the main actor per
    /// run. `lastUsedFallback` is always false now that all engines are on-device; it
    /// survives only because history rows persist a usedLocalFallback column.
    private(set) var lastUsedModel: DictationModelOption?
    private(set) var lastUsedFallback = false
    private var transcriptionTask: Task<String, Error>? = nil
    private var isCancelled = false
    
    init() {
        // Engines load lazily on first transcription (see ensureEngineLoaded), so
        // merely selecting an engine in Settings — or launching the app — never
        // triggers a model download. The download happens only when you actually
        // transcribe with that engine.
    }

    func cancelTranscription() {
        isCancelled = true
        currentEngine?.cancelTranscription()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        
        isTranscribing = false
        currentSegment = ""
        progress = 0.0
        isCancelled = false
    }
    
    /// Initialize the engine matching the current preference if it isn't already
    /// active. Called lazily from transcribeAudio, so selecting an engine in
    /// Settings only records the choice — the model isn't downloaded/loaded until
    /// you actually transcribe with it. Heavy work runs off the main actor.
    private func ensureEngineLoaded() async {
        let selectedEngine = AppPreferences.shared.selectedEngine
        if currentEngine != nil, loadedEngineKind == selectedEngine { return }

        isLoading = true
        engineError = nil
        print("Loading engine: \(selectedEngine)")

        let result = await Task.detached(priority: .userInitiated) { () -> Result<TranscriptionEngine?, Error> in
            let engine: TranscriptionEngine?

            if selectedEngine == "fluidaudio" {
                engine = await FluidAudioEngine()
            } else {
                engine = await WhisperEngine()
            }

            do {
                try await engine?.initialize()
                return .success(engine)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let engine):
            currentEngine = engine
            loadedEngineKind = (engine != nil) ? selectedEngine : nil
            print("Engine loaded: \(selectedEngine)")
        case .failure(let error):
            currentEngine = nil
            loadedEngineKind = nil
            engineError = "Failed to load engine: \(error.localizedDescription)"
            print("Failed to load engine: \(error)")
        }
        isLoading = false
    }

    /// Load the selected engine now instead of on the first dictation, so the first
    /// hotkey press of the day is as fast as the tenth. Called at launch, only after
    /// onboarding (a model was chosen and downloaded there — preloading never triggers
    /// a surprise download for a configured install). No-op if already loaded.
    func preloadEngine() {
        guard AppPreferences.shared.hasCompletedOnboarding else { return }
        Task { await ensureEngineLoaded() }
    }

    /// Invalidate the active engine so the next transcription re-initializes it
    /// (used when the engine selection or model changes). Intentionally does NOT
    /// load or download anything — that's deferred to next use. Clears any stale
    /// load error, since the invalidated engine gets a fresh attempt next time.
    func reloadEngine() {
        currentEngine = nil
        loadedEngineKind = nil
        engineError = nil
    }
    
    func reloadModel(with path: String) {
        if AppPreferences.shared.selectedEngine == "whisper" {
            AppPreferences.shared.selectedWhisperModelPath = path
            reloadEngine()
        }
    }

    /// Temporarily switch to `option` for one transcription and return a closure that restores the
    /// previous engine/model. No-op (returns an empty closure) when `option` is nil or already the
    /// active model. Called from inside `transcribeAudio`'s serialization gate so the swap can't
    /// leak to a concurrent caller — every one-off model (dictation clip AND the rerun dropdown,
    /// which now passes its option through `transcribeAudio(modelOverride:)`) runs through here.
    private func applyOneOffModel(_ option: DictationModelOption?) -> () -> Void {
        guard let option else { return {} }
        let current = ModelCatalog.activeOption()
        if current?.engine == option.engine && current?.identifier == option.identifier { return {} }

        let prefs = AppPreferences.shared
        let previousEngine = prefs.selectedEngine
        let previousWhisper = prefs.selectedWhisperModelPath
        let previousFluid = prefs.fluidAudioModelVersion

        prefs.selectedEngine = option.engine
        switch option.engine {
        case "whisper": prefs.selectedWhisperModelPath = option.identifier
        case "fluidaudio": prefs.fluidAudioModelVersion = option.identifier
        default: break
        }
        reloadEngine()

        return {
            prefs.selectedEngine = previousEngine
            prefs.selectedWhisperModelPath = previousWhisper
            prefs.fluidAudioModelVersion = previousFluid
            self.reloadEngine()
        }
    }
    
    func transcribeAudio(url: URL, settings: Settings, modelOverride: DictationModelOption? = nil) async throws -> String {
        // Serialize every transcription across the app (dictation pipeline, file-drop queue,
        // reruns, CLI): the engines share one non-thread-safe context (e.g. whisper.cpp) and this
        // object's per-run state (isTranscribing/progress/lastUsedModel). Two overlapping calls
        // would crash or corrupt output. (parallel-recording #2)
        await Self.engineGate.wait()
        // Apply a per-call model INSIDE the gate — the clip was recorded under this model, but a
        // later recording may since have switched the global one — so it can't leak to a concurrent
        // caller, and restore it before releasing. No-op when nil or already active. (#model-snapshot)
        let restoreModel = applyOneOffModel(modelOverride)
        defer {
            restoreModel()
            Task { await Self.engineGate.signal() }
        }

        await MainActor.run {
            self.progress = 0.0
            self.conversionProgress = 0.0
            self.isConverting = true
            self.isTranscribing = true
            self.transcribedText = ""
            self.currentSegment = ""
            self.isCancelled = false
        }
        
        defer {
            Task { @MainActor in
                self.isTranscribing = false
                self.isConverting = false
                self.currentSegment = ""
                if !self.isCancelled {
                    self.progress = 1.0
                }
                self.transcriptionTask = nil
            }
        }
        
        let durationInSeconds: Float = await (try? Task.detached(priority: .userInitiated) {
            let asset = AVAsset(url: url)
            let duration = try await asset.load(.duration)
            return Float(CMTimeGetSeconds(duration))
        }.value) ?? 0.0
        
        await MainActor.run {
            self.totalDuration = durationInSeconds
        }

        return try await transcribe(url: url, settings: settings)
    }

    /// Load the appropriate engine and transcribe. All engines are on-device.
    private func transcribe(url: URL, settings: Settings) async throws -> String {
        // Lazily initialize the selected engine on first use (downloads a local
        // model only now, never on mere engine selection in Settings).
        await ensureEngineLoaded()
        guard let engine = currentEngine else {
            throw TranscriptionError.contextInitializationFailed
        }
        lastUsedModel = ModelCatalog.activeOption()
        lastUsedFallback = false

        // Deterministic formatting AFTER the engine, BEFORE any LLM cleanup:
        // spoken numbers/percent/meridiem become digits ("forty-two thousand"
        // → "42,000") without depending on a small model's compliance.
        let raw = try await runOnEngine(engine, url: url, settings: settings)
        return NumberCompaction.apply(raw)
    }

    /// Run one transcription on a specific engine: wire its progress callback, run it
    /// off the main actor, and honor cancellation. Any engine error propagates so the
    /// caller (`transcribe`) can decide whether to fall back.
    private func runOnEngine(_ engine: TranscriptionEngine, url: URL, settings: Settings) async throws -> String {
        if let whisperEngine = engine as? WhisperEngine {
            whisperEngine.onProgressUpdate = { [weak self] newProgress in
                Task { @MainActor in
                    guard let self = self, !self.isCancelled else { return }
                    self.progress = newProgress
                }
            }
        } else if let fluidEngine = engine as? FluidAudioEngine {
            fluidEngine.onProgressUpdate = { [weak self] newProgress in
                Task { @MainActor in
                    guard let self = self, !self.isCancelled else { return }
                    self.progress = newProgress
                }
            }
        }

        let task = Task.detached(priority: .userInitiated) { [weak self] in
            try Task.checkCancellation()

            let cancelled = await MainActor.run {
                guard let self = self else { return true }
                return self.isCancelled
            }
            guard !cancelled else { throw CancellationError() }

            let result = try await engine.transcribeAudio(url: url, settings: settings)

            try Task.checkCancellation()

            let finalCancelled = await MainActor.run {
                guard let self = self else { return true }
                return self.isCancelled
            }

            await MainActor.run {
                guard let self = self, !self.isCancelled else { return }
                self.transcribedText = result
                self.progress = 1.0
            }

            guard !finalCancelled else { throw CancellationError() }

            return result
        }

        await MainActor.run {
            self.transcriptionTask = task
        }

        do {
            return try await task.value
        } catch is CancellationError {
            await MainActor.run {
                self.isCancelled = true
            }
            throw TranscriptionError.processingFailed
        }
    }

}

enum TranscriptionError: Error {
    case contextInitializationFailed
    case audioConversionFailed
    case processingFailed
}

/// Minimal async counting semaphore. Used as a 1-permit mutex to serialize transcriptions across
/// the app (see `TranscriptionService.transcribeAudio`). Correct under actor reentrancy: `signal`
/// hands the permit directly to the first waiter instead of bumping the count, so a waiter resumed
/// by `signal` stays mutually exclusive with everyone else.
actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(_ permits: Int = 1) { self.permits = permits }

    func wait() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func signal() {
        if !waiters.isEmpty {
            waiters.removeFirst().resume()   // hand the held permit straight to the next waiter
        } else {
            permits += 1
        }
    }
}
