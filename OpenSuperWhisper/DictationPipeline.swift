import Combine
import Foundation

/// Runs hotkey dictations (transcribe → save → paste) on a background, serial queue so the user is
/// never blocked from starting the next recording while a previous one is still being transcribed.
/// Items are processed strictly in recording-start order, so their pasted text lands in the same
/// order the clips were recorded — recording is decoupled from transcription, but output order is
/// preserved.
///
/// Concurrency: the pipeline drains its own queue serially, and `TranscriptionService.transcribeAudio`
/// additionally serializes against every other transcription source (file-drop queue, reruns) via a
/// shared gate — the engines share one non-thread-safe context. Because no other transcription can
/// interleave a given item's run, reading `lastUsedModel`/`lastUsedFallback` right after it is safe.
@MainActor
final class DictationPipeline: ObservableObject {
    static let shared = DictationPipeline()

    /// Frontmost-app context captured at record time, carried per dictation so the history row
    /// shows where THIS clip was dictated — not wherever focus moved to by the time it's processed.
    struct ContextSnapshot {
        var appName: String? = nil
        var bundleID: String? = nil
        var windowTitle: String? = nil
        var fullURL: String? = nil
    }

    private struct PendingDictation {
        let id: UUID
        let seq: Int
        let startedAt: Date
        let tempURL: URL
        let streamedFallback: String
        let context: ContextSnapshot
        /// Model that was active when this clip was recorded. Applied for this clip's transcription
        /// even if a later recording has since switched the global model. (#model-snapshot)
        let modelOption: DictationModelOption?
        /// This take was started by the submit mouse button, so press Return after inserting (#50).
        let submitAfterInsert: Bool
    }

    /// Dictations waiting in the queue plus the one currently being processed. Drives optional
    /// UI (the indicator shows the count while recording) and diagnostics.
    @Published private(set) var pendingCount = 0
    /// True while the background loop is draining the queue.
    @Published private(set) var isProcessing = false

    /// Set by `discardEverything()` and cleared once the queue drains.
    ///
    /// A dictation you have changed your mind about is worse than a slow one: it lands in
    /// whatever you were typing while you watched it come. Transcription happens off the
    /// recording, so by then there is nothing left to stop except the insertion itself.
    private var discarding = false

    /// Test seam: when set, used instead of the real engine so unit tests can exercise queue
    /// ordering / pendingCount / no-speech / failure paths without a model. nil in production.
    var transcribeOverride: ((URL, Settings) async throws -> String)?

    /// Throws away everything queued and in flight: nothing is inserted, saved, or pasted.
    ///
    /// The clip being transcribed cannot be un-transcribed, so the engine is asked to stop and
    /// whatever it returns is dropped on the floor. Anything still queued never starts.
    func discardEverything() {
        guard isProcessing || !queue.isEmpty else { return }

        discarding = true
        for item in queue {
            try? FileManager.default.removeItem(at: item.tempURL)
        }
        queue.removeAll()
        refreshPendingCount()
        transcriptionService.cancelTranscription()
    }

    private var queue: [PendingDictation] = []
    private var inFlight = false
    private var seqCounter = 0
    private var loopTask: Task<Void, Never>?

    private let transcriptionService = TranscriptionService.shared
    private let recordingStore = RecordingStore.shared
    private let recorder = AudioRecorder.shared

    private init() {}

    /// Enqueue a finished recording for background transcription + paste. Returns immediately; the
    /// work drains on the serial loop. Called on the main actor from the indicator's stop handler.
    /// `seq` is monotonic and assigned here, so append order == recording-start order.
    func enqueue(tempURL: URL, startedAt: Date, streamedFallback: String,
                 context: ContextSnapshot, modelOption: DictationModelOption?,
                 submitAfterInsert: Bool = false) {
        seqCounter += 1
        queue.append(PendingDictation(
            id: UUID(),
            seq: seqCounter,
            startedAt: startedAt,
            tempURL: tempURL,
            streamedFallback: streamedFallback,
            context: context,
            modelOption: modelOption,
            submitAfterInsert: submitAfterInsert))
        refreshPendingCount()
        startLoopIfNeeded()
    }

    private func startLoopIfNeeded() {
        guard loopTask == nil else { return }
        isProcessing = true
        loopTask = Task { [weak self] in
            guard let self else { return }
            while let next = self.dequeue() {
                self.inFlight = true
                await self.process(next)
                self.inFlight = false
                self.refreshPendingCount()
            }
            self.isProcessing = false
            self.loopTask = nil
            // Only the run that was discarded is affected; the next dictation starts clean.
            self.discarding = false
            self.refreshPendingCount()
        }
    }

    /// Pop the earliest-recorded pending dictation. FIFO == start order (seq is monotonic and the
    /// queue is only appended to on the main actor), so no explicit sort is needed. There is no
    /// `await` between a failing `dequeue()` and the loop clearing `loopTask`, so — on the main
    /// actor — a concurrent `enqueue` can never strand an item.
    private func dequeue() -> PendingDictation? {
        guard !queue.isEmpty else { return nil }
        let item = queue.removeFirst()
        refreshPendingCount()
        return item
    }

    private func refreshPendingCount() {
        pendingCount = queue.count + (inFlight ? 1 : 0)
    }

    private func process(_ item: PendingDictation) async {
        let settings = Settings()
        do {
            let rawText: String
            if let transcribeOverride {
                rawText = try await transcribeOverride(item.tempURL, settings)
            } else {
                rawText = try await transcriptionService.transcribeAudio(
                    url: item.tempURL, settings: settings, modelOverride: item.modelOption)
            }
            // Which model actually produced this text — snapshot it *now*, before the LLM and
            // audio-duration awaits below. transcribeAudio has returned so these are still this
            // item's values, but its engine gate is already released: during those awaits a
            // file-drop/rerun transcription could acquire the gate and overwrite
            // `lastUsedModel`/`lastUsedFallback`, mislabeling this history row. (parallel-recording review)
            // Checked after the engine returns rather than before: a cancelled transcription
            // still comes back here, and this is the last point before the text reaches the
            // user's document. Nothing is saved or inserted.
            if discarding {
                try? FileManager.default.removeItem(at: item.tempURL)
                return
            }

            let modelUsed = transcriptionService.lastUsedModel?.displayName ?? ModelCatalog.activeOption()?.displayName
            let wasFallback = transcriptionService.lastUsedFallback
            var text = AppPreferences.shared.cleanTranscription(rawText)

            // File pass found nothing. Fall back to the live preview if it caught the words (short
            // clip); only with neither is it genuinely "no speech" — then drop it (no empty
            // recording) and surface a brief notice. (#short-dictation)
            if text == TranscriptionResult.noSpeech
                || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let fallback = AppPreferences.shared
                    .cleanTranscription(item.streamedFallback)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !fallback.isEmpty else {
                    try? FileManager.default.removeItem(at: item.tempURL)
                    IndicatorWindowManager.shared.flash(.info("No speech detected"))
                    return
                }
                text = fallback
            }

            // Optional LLM cleanup (no-op when disabled; returns the raw text on failure). The
            // app-aware formatting rules are keyed off the app that was frontmost when the clip was
            // RECORDED — the app the user was dictating into — not whatever is frontmost now that
            // the background queue got to it. (parallel-recording)
            text = await LLMPostProcessor.process(text, bundleID: item.context.bundleID)

            // Trailing "press enter" voice command (opt-in): strip it and remember to press Return
            // after insertion, submitting the message/prompt.
            let (strippedText, spokenSubmit) = AppPreferences.shared.stripSubmitCommand(text)
            text = strippedText
            // Either route asks for the same thing: send Return once the text is in.
            let shouldSubmit = spokenSubmit || item.submitAfterInsert
            let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            // Insert BEFORE the history save: the user is watching the cursor, not the history
            // list, so the file move + duration probe below must not sit between the engine
            // finishing and the text landing. (#latency)
            let outcome: TranscriptInserter.Outcome = hasText ? insertText(text) : .skipped

            // Submit only when auto-paste actually inserted text somewhere. A short settle delay lets
            // the pasted text land in the field before Return reaches it.
            if shouldSubmit && outcome == .inserted {
                try? await Task.sleep(nanoseconds: 120_000_000)
                TextInserter.pressReturn()
            }

            // The text could not be inserted but is on the clipboard — tell the user what happened
            // and what to do, instead of letting the dictation appear to vanish.
            switch outcome {
            case .noTarget:
                IndicatorWindowManager.shared.flash(.info("Copied — press ⌘V to paste"))
            case .noPermission:
                IndicatorWindowManager.shared.flash(.error(
                    "Couldn't paste — re-add Rhino in System Settings → Accessibility. Copied — press ⌘V"))
            case .inserted, .skipped:
                break
            }

            if hasText && AppPreferences.shared.saveTranscriptionHistory {
                // Use the record-start time as the row timestamp (when the user actually dictated),
                // not the later processing time. The id suffix keeps two clips that finish within
                // the same second from colliding on one on-disk file.
                let timestamp = item.startedAt
                let recordingId = item.id
                let fileName = "\(Int(timestamp.timeIntervalSince1970))-\(recordingId.uuidString.prefix(8)).wav"
                let finalURL = Recording(
                    id: recordingId,
                    timestamp: timestamp,
                    fileName: fileName,
                    transcription: text,
                    duration: 0,
                    status: .completed,
                    progress: 1.0,
                    sourceFileURL: nil
                ).url

                do {
                    try recorder.moveTemporaryRecording(from: item.tempURL, to: finalURL)
                    await storeRecording(
                        id: recordingId, timestamp: timestamp, fileName: fileName,
                        finalURL: finalURL, transcription: text,
                        status: .completed, progress: 1.0, context: item.context,
                        modelUsed: modelUsed, wasFallback: wasFallback)
                } catch {
                    // The text already reached the user, so a failed history save must not surface
                    // as a failed dictation. Drop the audio and keep the successful insertion.
                    print("Failed to save dictation to history: \(error)")
                    try? FileManager.default.removeItem(at: item.tempURL)
                }
            } else {
                try? FileManager.default.removeItem(at: item.tempURL)
            }
        } catch {
            let reason = Self.failureReason(for: error)
            let detail = Self.failureDetail(
                for: error,
                engineError: transcriptionService.engineError,
                attemptedModel: item.modelOption?.displayName ?? ModelCatalog.activeOption()?.displayName)
            print("Dictation transcription failed: \(detail)")
            // Unconditionally into the unified log (not gated on Diag.isEnabled): failures are
            // rare, and when history is off this line is the only durable record of what broke.
            Diag.log.error("dictation failed: \(detail, privacy: .public)")
            // Don't lose the audio on failure. When history is on, keep the recording with a .failed
            // status + retry message so it shows in the log and can be re-run with the regenerate (↻)
            // button. Otherwise discard. Either way, surface the failure — silent loss is worse.
            if AppPreferences.shared.saveTranscriptionHistory,
               let saved = persistFailedRecording(timestamp: item.startedAt, tempURL: item.tempURL) {
                await storeRecording(
                    id: saved.id, timestamp: saved.timestamp, fileName: saved.fileName,
                    finalURL: saved.url, transcription: "\(reason) — click ↻ to try again.",
                    status: .failed, progress: 0, context: item.context,
                    modelUsed: nil, wasFallback: false, failureDetail: detail)
            } else {
                try? FileManager.default.removeItem(at: item.tempURL)
            }
            IndicatorWindowManager.shared.flash(.error(reason))
        }
    }

    /// The one thing the user can act on, not a stack trace. The generic labels stay short so
    /// they fit the indicator flash; the raw error goes into the row's failureDetail instead.
    /// Internal (not private) so tests can pin the mapping.
    nonisolated static func failureReason(for error: Error) -> String {
        switch error {
        case TranscriptionError.contextInitializationFailed:
            return "Model not loaded — check Settings → Models"
        case TranscriptionError.audioConversionFailed:
            return "Couldn't read the recording's audio"
        default:
            return "Transcription failed"
        }
    }

    /// Verbatim technical detail persisted alongside a failed recording: the raw error, the
    /// engine loader's message when there is one (missing model file, corrupt download, …), and
    /// the model that was attempted. This is what a later debug pass reads — the empty-modelUsed
    /// failed rows in the field were undiagnosable precisely because none of it was kept.
    nonisolated static func failureDetail(for error: Error, engineError: String?, attemptedModel: String?) -> String {
        var parts = [String(describing: error)]
        if let engineError, !engineError.isEmpty {
            parts.append(engineError)
        }
        if let attemptedModel, !attemptedModel.isEmpty {
            parts.append("model: \(attemptedModel)")
        }
        return parts.joined(separator: " · ")
    }

    /// Insert a recording (already at its final URL) into the store with the measured audio duration
    /// and the captured source context (app / window / URL / model used). Moved here from the
    /// indicator view model so the save path is shared and can't drift.
    private func storeRecording(id: UUID, timestamp: Date, fileName: String, finalURL: URL,
                                transcription: String, status: RecordingStatus, progress: Float,
                                context: ContextSnapshot,
                                modelUsed: String?, wasFallback: Bool,
                                failureDetail: String? = nil) async {
        // `modelUsed`/`wasFallback` are captured by the caller right after `transcribeAudio`
        // returns — NOT read here, because the `await` below can suspend long enough for another
        // transcription to overwrite them on the shared service. (parallel-recording review)
        let realDuration = await IndicatorViewModel.audioDuration(of: finalURL)
        recordingStore.addRecording(Recording(
            id: id,
            timestamp: timestamp,
            fileName: fileName,
            transcription: transcription,
            duration: realDuration,
            status: status,
            progress: progress,
            sourceFileURL: nil,
            sourceAppName: context.appName,
            sourceWindowTitle: context.windowTitle,
            sourceURL: context.fullURL,
            modelUsed: modelUsed,
            wasFallback: wasFallback,
            failureDetail: failureDetail))
    }

    /// Move a temp recording to its permanent location after a FAILED transcription so the audio
    /// survives and can be re-run from the history list. Returns the saved identity, or nil if the
    /// move failed (then the temp is discarded).
    private func persistFailedRecording(timestamp: Date, tempURL: URL) -> (id: UUID, timestamp: Date, fileName: String, url: URL)? {
        let id = UUID()
        let fileName = "\(Int(timestamp.timeIntervalSince1970))-\(id.uuidString.prefix(8)).wav"
        let finalURL = Recording(
            id: id,
            timestamp: timestamp,
            fileName: fileName,
            transcription: "",
            duration: 0,
            status: .failed,
            progress: 0,
            sourceFileURL: nil
        ).url
        do {
            try recorder.moveTemporaryRecording(from: tempURL, to: finalURL)
            return (id, timestamp, fileName, finalURL)
        } catch {
            print("Failed to persist failed recording: \(error)")
            return nil
        }
    }

    /// Runs the shared insertion policy (`TranscriptInserter`, shared with the re-paste shortcut)
    /// and reports what happened, so the caller can flash the right notice when the text ended up
    /// on the clipboard instead of in the focused app.
    @discardableResult
    private func insertText(_ text: String) -> TranscriptInserter.Outcome {
        TranscriptInserter.insert(IndicatorViewModel.applyPostProcessing(text),
                                  honorAutoPastePreference: true)
    }
}
