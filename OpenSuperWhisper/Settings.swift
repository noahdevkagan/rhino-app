import AppKit
import Carbon
import Combine
import Foundation
import KeyboardShortcuts
import SwiftUI
import FluidAudio

class SettingsViewModel: ObservableObject {
    /// True while re-syncing the @Published copies from AppPreferences (e.g. after the
    /// menu-bar Model picker changed the active model). Suppresses the model didSets'
    /// side effects so the sync doesn't write back, double-reload, or clobber the engine.
    private var isSyncing = false
    private var modelSyncObserver: NSObjectProtocol?
    private var languageSyncObserver: NSObjectProtocol?

    @Published var selectedEngine: String {
        didSet {
            guard !isSyncing else { return }
            // The active selection is owned by ModelSelectionStore (see the select* methods,
            // which persist + reload the engine). This observer only refreshes the model list
            // shown for whatever engine is now displayed.
            if selectedEngine == "whisper" {
                loadAvailableModels()
            } else {
                initializeFluidAudioModels()
            }
            clampLanguageToSupported()
        }
    }
    
    @Published var fluidAudioModelVersion: String {
        didSet {
            guard !isSyncing else { return }
            // Selection (engine switch + persistence + reload) is applied via selectParakeet(_:);
            // this observer only refreshes the row download states.
            initializeFluidAudioModels()
        }
    }
    
    @Published var selectedModelURL: URL? {
        didSet {
            guard !isSyncing else { return }
            if let url = selectedModelURL {
                AppPreferences.shared.selectedWhisperModelPath = url.path
            }
        }
    }

    /// User-initiated model selections. Each routes through the single mutation point —
    /// `ModelSelectionStore.select` — so the menu bar and Settings change
    /// the active model the same way and can't drift. The store persists to AppPreferences,
    /// reloads the engine, and posts `.modelSelectionDidChange`, which syncs our @Published copies
    /// back (`syncModelSelectionFromPreferences`). Call these for explicit user actions only —
    /// never from init/restore — so a routine reload can't override the language.
    func selectModel(_ url: URL) {
        MainActor.assumeIsolated {
            ModelSelectionStore.shared.select(DictationModelOption(
                engine: "whisper",
                identifier: url.path,
                displayName: url.deletingPathExtension().lastPathComponent))
        }
        // A model may declare a preferred language (e.g. the ivrit.ai Hebrew model) — switch to it.
        if let lang = SettingsDownloadableModels.preferredLanguage(forFilename: url.lastPathComponent),
           selectedLanguage != lang {
            selectedLanguage = lang
        }
    }

    func selectParakeet(_ version: String) {
        MainActor.assumeIsolated {
            ModelSelectionStore.shared.select(DictationModelOption(
                engine: "fluidaudio", identifier: version, displayName: version))
        }
    }

    @Published var availableModels: [URL] = []
    
    @Published var downloadableModels: [SettingsDownloadableModel] = []
    @Published var downloadableFluidAudioModels: [SettingsFluidAudioModel] = []
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadingModelName: String?
    /// Sub-caption under the Parakeet progress bar while FluidAudio compiles the
    /// downloaded CoreML models — the bar sits full there and would look stuck.
    @Published var downloadPhaseText: String?
    private var downloadTask: Task<Void, Error>?
    
    @Published var selectedLanguage: String {
        didSet {
            // Single mutation point (LanguageStore) — persists + notifies the menu. Idempotent,
            // so the menu→Settings sync setting this back to the same value is a harmless no-op.
            MainActor.assumeIsolated { LanguageStore.shared.select(selectedLanguage) }
        }
    }

    /// Languages the selected engine+model can transcribe — filters the language picker (#155).
    var supportedLanguages: [String] {
        EngineCapabilities.supportedLanguages(engine: selectedEngine, fluidAudioModelVersion: fluidAudioModelVersion)
    }

    /// Reset the language to a supported one when the current engine/model can't transcribe the
    /// previously selected one (e.g. switching to a model without that language) (#155). Prefers
    /// Auto-detect, then English, then whatever the model lists first — so the picker is never blank.
    func clampLanguageToSupported() {
        let supported = supportedLanguages
        guard !supported.contains(selectedLanguage) else { return }
        selectedLanguage = supported.first(where: { $0 == "auto" })
            ?? supported.first(where: { $0 == "en" })
            ?? supported.first ?? "auto"
    }

    @Published var suppressBlankAudio: Bool {
        didSet {
            AppPreferences.shared.suppressBlankAudio = suppressBlankAudio
        }
    }

    @Published var customDictionaryEnabled: Bool {
        didSet {
            AppPreferences.shared.customDictionaryEnabled = customDictionaryEnabled
        }
    }

    @Published var customDictionaryBoostEnabled: Bool {
        didSet {
            AppPreferences.shared.customDictionaryBoostEnabled = customDictionaryBoostEnabled
        }
    }

    @Published var customDictionaryEntries: [CustomDictionaryEntry] {
        didSet {
            AppPreferences.shared.customDictionaryEntries = customDictionaryEntries
        }
    }

    @Published var debugMode: Bool {
        didSet {
            AppPreferences.shared.debugMode = debugMode
        }
    }
    
    @Published var playSoundOnRecordStart: Bool {
        didSet {
            AppPreferences.shared.playSoundOnRecordStart = playSoundOnRecordStart
        }
    }

    @Published var startHidden: Bool {
        didSet {
            AppPreferences.shared.startHidden = startHidden
        }
    }

    /// Cancel is key-combination only, but the recorder field needs a binding,
    /// so this stays parked at `.none`.
    @Published var cancelModifierUnused: ModifierKey = .none

    @Published var textScale: Double {
        didSet { AppPreferences.shared.textScale = TextScale.clamped(textScale) }
    }

    @Published var indicatorPosition: String {
        didSet {
            AppPreferences.shared.indicatorPosition = indicatorPosition
        }
    }

    @Published var liveTranscriptionEnabled: Bool {
        didSet {
            AppPreferences.shared.liveTranscriptionEnabled = liveTranscriptionEnabled
        }
    }

    @Published var modifierOnlyHotkey: ModifierKey {
        didSet {
            AppPreferences.shared.modifierOnlyHotkey = modifierOnlyHotkey.rawValue
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        }
    }

    @Published var holdToRecord: Bool {
        didSet {
            AppPreferences.shared.holdToRecord = holdToRecord
        }
    }

    @Published var doubleTapLock: Bool {
        didSet {
            AppPreferences.shared.doubleTapLock = doubleTapLock
        }
    }

    @Published var addSpaceAfterSentence: Bool {
        didSet {
            AppPreferences.shared.addSpaceAfterSentence = addSpaceAfterSentence
        }
    }

    @Published var aiPostProcessingEnabled: Bool {
        didSet {
            AppPreferences.shared.aiPostProcessingEnabled = aiPostProcessingEnabled
            guard aiPostProcessingEnabled else { return }
            if builtInModelDownloaded {
                // Warm the ~1 GB context now, while the user is here in Settings, so their first
                // dictation doesn't wait several seconds for it. Released again after an idle spell.
                BuiltInLlamaBackend.shared.preload()
            } else if builtInModelDownloadProgress == nil {
                // Without the model every cleanup pass silently no-ops, and testers read that as
                // "formatting doesn't work" — so the toggle itself is the consent to download.
                downloadBuiltInModel()
            }
        }
    }

    @Published var smartFormattingEnabled: Bool {
        didSet {
            AppPreferences.shared.smartFormattingEnabled = smartFormattingEnabled
        }
    }

    /// Whether the built-in model's GGUF is present on disk.
    @Published var builtInModelDownloaded: Bool = LLMModelManager.shared.isDefaultModelDownloaded()
    /// Download progress in 0...1 while the built-in model is downloading; nil when idle.
    @Published var builtInModelDownloadProgress: Double?
    /// Set when a built-in model download fails, for inline feedback.
    @Published var builtInModelDownloadError: String?

    /// Downloads the default built-in model (~1 GB), updating progress for the UI.
    func downloadBuiltInModel() {
        builtInModelDownloadError = nil
        builtInModelDownloadProgress = 0
        Task { @MainActor in
            do {
                try await LLMModelManager.shared.downloadDefaultModel { progress in
                    Task { @MainActor in self.builtInModelDownloadProgress = progress }
                }
                self.builtInModelDownloaded = LLMModelManager.shared.isDefaultModelDownloaded()
                // Load it straight away: the download already made them wait, and this keeps the
                // load out of their first dictation.
                BuiltInLlamaBackend.shared.preload()
            } catch {
                self.builtInModelDownloadError = error.localizedDescription
            }
            self.builtInModelDownloadProgress = nil
        }
    }

    @Published var removeFillerWords: Bool {
        didSet {
            AppPreferences.shared.removeFillerWords = removeFillerWords
        }
    }

    @Published var autoCopyToClipboard: Bool {
        didSet {
            AppPreferences.shared.autoCopyToClipboard = autoCopyToClipboard
        }
    }

    @Published var autoPasteTranscription: Bool {
        didSet {
            AppPreferences.shared.autoPasteTranscription = autoPasteTranscription
        }
    }

    @Published var pasteInsteadOfTyping: Bool {
        didSet {
            AppPreferences.shared.pasteInsteadOfTyping = pasteInsteadOfTyping
        }
    }

    @Published var notifyWhenNoPasteTarget: Bool {
        didSet {
            AppPreferences.shared.notifyWhenNoPasteTarget = notifyWhenNoPasteTarget
        }
    }

    @Published var pauseMediaOnRecord: Bool {
        didSet {
            AppPreferences.shared.pauseMediaOnRecord = pauseMediaOnRecord
        }
    }

    // MARK: - Retention / storage policy

    @Published var retentionMaxCountEnabled: Bool {
        didSet {
            AppPreferences.shared.retentionMaxCountEnabled = retentionMaxCountEnabled
            enforceRetention()
        }
    }

    @Published var retentionMaxCount: Int {
        didSet {
            // Clamp the published property itself (not only the stored value) so the UI and
            // the persisted/enforced value can never diverge. The re-assignment re-enters
            // didSet once with an already-clamped value, which then falls through.
            let clamped = max(1, retentionMaxCount)
            if clamped != retentionMaxCount {
                retentionMaxCount = clamped
                return
            }
            AppPreferences.shared.retentionMaxCount = clamped
            enforceRetention()
        }
    }

    @Published var retentionMaxAgeEnabled: Bool {
        didSet {
            AppPreferences.shared.retentionMaxAgeEnabled = retentionMaxAgeEnabled
            enforceRetention()
        }
    }

    @Published var retentionMaxAgeValue: Int {
        didSet {
            // Clamp the published property itself (see retentionMaxCount) so the UI and the
            // persisted/enforced value can never diverge.
            let clamped = max(1, retentionMaxAgeValue)
            if clamped != retentionMaxAgeValue {
                retentionMaxAgeValue = clamped
                return
            }
            AppPreferences.shared.retentionMaxAgeValue = clamped
            enforceRetention()
        }
    }

    @Published var retentionMaxAgeUnit: RetentionUnit {
        didSet {
            AppPreferences.shared.retentionMaxAgeUnit = retentionMaxAgeUnit.rawValue
            enforceRetention()
        }
    }

    private var retentionEnforceTimer: Timer?

    /// Applies the retention policy after a short debounce so the user sees the effect of
    /// toggling a switch or changing a limit, without the data-loss footgun of enforcing on
    /// every keystroke: the count/age TextFields use `format: .number`, whose binding commits
    /// (and fires didSet) on each parsed value, so typing "500" passes through 5 and 50.
    /// Enforcing immediately would permanently delete recordings at those intermediate values.
    /// Debouncing coalesces a burst of edits into a single enforcement at the final value.
    private func enforceRetention() {
        retentionEnforceTimer?.invalidate()
        retentionEnforceTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
            Task { @MainActor in
                await RecordingStore.shared.enforceRetentionPolicy()
            }
        }
    }

    @Published var saveTranscriptionHistory: Bool {
        didSet {
            AppPreferences.shared.saveTranscriptionHistory = saveTranscriptionHistory
        }
    }

    init() {
        let prefs = AppPreferences.shared
        self.selectedEngine = prefs.selectedEngine
        self.fluidAudioModelVersion = prefs.fluidAudioModelVersion
        self.selectedLanguage = prefs.whisperLanguage
        self.suppressBlankAudio = prefs.suppressBlankAudio
        self.customDictionaryEnabled = prefs.customDictionaryEnabled
        self.customDictionaryBoostEnabled = prefs.customDictionaryBoostEnabled
        // Folded when the window opens rather than as the user types: merging live would yank a
        // row away mid-keystroke the moment its replacement matched another.
        self.customDictionaryEntries = CustomDictionary.merged(prefs.customDictionaryEntries)
        self.debugMode = prefs.debugMode
        self.playSoundOnRecordStart = prefs.playSoundOnRecordStart
        self.startHidden = prefs.startHidden
        self.indicatorPosition = prefs.indicatorPosition
        self.textScale = prefs.textScale
        self.liveTranscriptionEnabled = prefs.liveTranscriptionEnabled
        self.modifierOnlyHotkey = ModifierKey(rawValue: prefs.modifierOnlyHotkey) ?? .none
        self.holdToRecord = prefs.holdToRecord
        self.doubleTapLock = prefs.doubleTapLock
        self.addSpaceAfterSentence = prefs.addSpaceAfterSentence
        self.aiPostProcessingEnabled = prefs.aiPostProcessingEnabled
        self.smartFormattingEnabled = prefs.smartFormattingEnabled
        self.removeFillerWords = prefs.removeFillerWords
        self.autoCopyToClipboard = prefs.autoCopyToClipboard
        self.autoPasteTranscription = prefs.autoPasteTranscription
        self.pasteInsteadOfTyping = prefs.pasteInsteadOfTyping
        self.notifyWhenNoPasteTarget = prefs.notifyWhenNoPasteTarget
        self.pauseMediaOnRecord = prefs.pauseMediaOnRecord
        self.retentionMaxCountEnabled = prefs.retentionMaxCountEnabled
        self.retentionMaxCount = prefs.retentionMaxCount
        self.retentionMaxAgeEnabled = prefs.retentionMaxAgeEnabled
        self.retentionMaxAgeValue = prefs.retentionMaxAgeValue
        self.retentionMaxAgeUnit = RetentionUnit(rawValue: prefs.retentionMaxAgeUnit) ?? .days
        self.saveTranscriptionHistory = prefs.saveTranscriptionHistory

        if let savedPath = prefs.selectedWhisperModelPath ?? prefs.selectedModelPath {
            self.selectedModelURL = URL(fileURLWithPath: savedPath)
        }
        loadAvailableModels()
        initializeDownloadableModels()
        initializeFluidAudioModels()

        // Reflect external model changes (the menu-bar Model picker) while Settings is open.
        modelSyncObserver = NotificationCenter.default.addObserver(
            forName: .modelSelectionDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.syncModelSelectionFromPreferences()
        }
        // Same for the menu-bar Language picker. The @Published didSets route back through
        // the stores idempotently, so setting the same value here doesn't loop.
        languageSyncObserver = NotificationCenter.default.addObserver(
            forName: .appPreferencesLanguageChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.selectedLanguage = AppPreferences.shared.whisperLanguage }
        }
    }

    deinit {
        for observer in [modelSyncObserver, languageSyncObserver] {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }

    /// Re-read the active engine/model from AppPreferences (the source of truth) into the
    /// @Published copies, without triggering their write-back/reload side effects. Keeps an
    /// open Settings window in sync when the menu-bar Model picker changes the selection.
    func syncModelSelectionFromPreferences() {
        let prefs = AppPreferences.shared
        let newURL = (prefs.selectedWhisperModelPath ?? prefs.selectedModelPath).map { URL(fileURLWithPath: $0) }
        guard selectedEngine != prefs.selectedEngine
            || fluidAudioModelVersion != prefs.fluidAudioModelVersion
            || selectedModelURL != newURL else { return }

        isSyncing = true
        selectedEngine = prefs.selectedEngine
        fluidAudioModelVersion = prefs.fluidAudioModelVersion
        selectedModelURL = newURL
        isSyncing = false

        // Refresh the model list shown for the now-active engine.
        if selectedEngine == "whisper" { loadAvailableModels() }
        else if selectedEngine == "fluidaudio" { initializeFluidAudioModels() }
        clampLanguageToSupported()
    }

    func initializeFluidAudioModels() {
        downloadableFluidAudioModels = SettingsFluidAudioModels.availableModels.map { model in
            var updatedModel = model
            updatedModel.isDownloaded = isFluidAudioModelDownloaded(version: model.version)
            return updatedModel
        }
    }
    
    func isFluidAudioModelDownloaded(version: String) -> Bool {
        let asrVersion: AsrModelVersion = version == "v2" ? .v2 : .v3
        
        // Используем правильный путь к кэшу согласно документации:
        // ~/Library/Application Support/FluidAudio/Models/<version-folder>/
        let cacheDirectory = AsrModels.defaultCacheDirectory(for: asrVersion)
        
        // Проверяем наличие всех необходимых файлов модели
        return AsrModels.modelsExist(at: cacheDirectory, version: asrVersion)
    }
    
    func initializeDownloadableModels() {
        let modelManager = WhisperModelManager.shared
        downloadableModels = SettingsDownloadableModels.availableModels.map { model in
            var updatedModel = model
            let filename = model.filename
            updatedModel.isDownloaded = modelManager.isModelDownloaded(name: filename)
            return updatedModel
        }
    }
    
    func loadAvailableModels() {
        availableModels = WhisperModelManager.shared.getAvailableModels()
        if selectedModelURL == nil {
            selectedModelURL = availableModels.first
        }
        initializeDownloadableModels()
    }
    
    @MainActor
    func downloadModel(_ model: SettingsDownloadableModel) async throws {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadingModelName = model.name
        downloadProgress = 0.0
        
        downloadTask = Task {
            do {
                let filename = model.filename
                
                try await WhisperModelManager.shared.downloadModel(url: model.url, name: filename) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self = self, !Task.isCancelled else { return }
                        guard let task = self.downloadTask, !task.isCancelled else { return }
                        
                        self.downloadProgress = progress
                        if let index = self.downloadableModels.firstIndex(where: { $0.name == model.name }) {
                            self.downloadableModels[index].downloadProgress = progress
                            if progress >= 1.0 {
                                self.downloadableModels[index].isDownloaded = true
                            }
                        }
                    }
                }
                
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isDownloading = false
                        self.downloadingModelName = nil
                        self.downloadProgress = 0.0
                        if let index = self.downloadableModels.firstIndex(where: { $0.name == model.name }) {
                            self.downloadableModels[index].downloadProgress = 0.0
                        }
                    }
                    return
                }
                
                await MainActor.run {
                    if let index = downloadableModels.firstIndex(where: { $0.name == model.name }) {
                        downloadableModels[index].isDownloaded = true
                        downloadableModels[index].downloadProgress = 0.0
                    }
                    loadAvailableModels()
                    let modelPath = WhisperModelManager.shared.modelsDirectory.appendingPathComponent(filename).path
                    selectModel(URL(fileURLWithPath: modelPath))
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    
                    Task { @MainActor in
                        TranscriptionService.shared.reloadModel(with: modelPath)
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    if let index = downloadableModels.firstIndex(where: { $0.name == model.name }) {
                        downloadableModels[index].downloadProgress = 0.0
                    }
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    if let index = downloadableModels.firstIndex(where: { $0.name == model.name }) {
                        downloadableModels[index].downloadProgress = 0.0
                    }
                }
                throw error
            }
        }
        
        try await downloadTask?.value
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        if let modelName = downloadingModelName {
            if selectedEngine == "whisper", let model = downloadableModels.first(where: { $0.name == modelName }) {
                let filename = model.filename
                WhisperModelManager.shared.cancelDownload(name: filename)
            }
            // Reset progress for the downloading model
            if let index = downloadableModels.firstIndex(where: { $0.name == modelName }) {
                downloadableModels[index].downloadProgress = 0.0
            }
            if let index = downloadableFluidAudioModels.firstIndex(where: { $0.name == modelName }) {
                downloadableFluidAudioModels[index].downloadProgress = 0.0
            }
        }
        isDownloading = false
        downloadingModelName = nil
        downloadProgress = 0.0
        downloadPhaseText = nil
    }

    @MainActor
    func downloadFluidAudioModel(_ model: SettingsFluidAudioModel) async throws {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadingModelName = model.name
        downloadProgress = 0.0
        
        if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
            downloadableFluidAudioModels[index].downloadProgress = 0.0
        }
        
        var wasCancelled = false
        
        downloadTask = Task {
            do {
                let version: AsrModelVersion = model.version == "v2" ? .v2 : .v3
                
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isDownloading = false
                        self.downloadingModelName = nil
                        self.downloadProgress = 0.0
                        if let index = self.downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                            self.downloadableFluidAudioModels[index].downloadProgress = 0.0
                        }
                    }
                    throw CancellationError()
                }
                
                let models = try await AsrModels.downloadAndLoad(version: version) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, self.isDownloading else { return }
                        self.downloadProgress = progress.fractionCompleted
                        if let index = self.downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                            self.downloadableFluidAudioModels[index].downloadProgress = progress.fractionCompleted
                        }
                        if case .compiling = progress.phase {
                            self.downloadPhaseText = "Optimizing for this Mac… (one-time, can take a few minutes)"
                        } else {
                            self.downloadPhaseText = nil
                        }
                    }
                }

                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isDownloading = false
                        self.downloadingModelName = nil
                        self.downloadProgress = 0.0
                        self.downloadPhaseText = nil
                        if let index = self.downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                            self.downloadableFluidAudioModels[index].downloadProgress = 0.0
                        }
                    }
                    throw CancellationError()
                }

                await MainActor.run { downloadPhaseText = "Loading model…" }
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)
                
                await MainActor.run {
                    if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                        downloadableFluidAudioModels[index].isDownloaded = true
                        downloadableFluidAudioModels[index].downloadProgress = 1.0
                    }
                    // Just-downloaded model becomes the active selection (persists + reloads
                    // the engine through the single mutation point).
                    selectParakeet(model.version)
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 1.0
                    downloadPhaseText = nil
                }
            } catch is CancellationError {
                wasCancelled = true
                await MainActor.run {
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    downloadPhaseText = nil
                    if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                        downloadableFluidAudioModels[index].downloadProgress = 0.0
                    }
                }
                // Don't re-throw CancellationError - it's a manual cancellation
            } catch {
                // Check if we were cancelled before the error occurred
                if Task.isCancelled {
                    wasCancelled = true
                    await MainActor.run {
                        isDownloading = false
                        downloadingModelName = nil
                        downloadProgress = 0.0
                        downloadPhaseText = nil
                        if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                            downloadableFluidAudioModels[index].downloadProgress = 0.0
                        }
                    }
                } else {
                    await MainActor.run {
                        isDownloading = false
                        downloadingModelName = nil
                        downloadProgress = 0.0
                        downloadPhaseText = nil
                        if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                            downloadableFluidAudioModels[index].downloadProgress = 0.0
                        }
                    }
                    throw error
                }
            }
        }
        
        // Handle cancellation gracefully - don't throw if cancelled
        do {
            try await downloadTask?.value
        } catch is CancellationError {
            // Already handled in catch block above, just consume the error
            wasCancelled = true
        } catch {
            // If we were cancelled, don't throw
            if !wasCancelled {
                throw error
            }
        }
    }
    
    @MainActor
    func downloadFluidAudioModel() async throws {
        let versionString = AppPreferences.shared.fluidAudioModelVersion
        if let model = downloadableFluidAudioModels.first(where: { $0.version == versionString }) {
            try await downloadFluidAudioModel(model)
        }
    }
}

struct SettingsDownloadableModel: Identifiable {
    let id = UUID()
    let name: String
    var isDownloaded: Bool
    let url: URL
    let size: Int
    let description: String
    var downloadProgress: Double = 0.0
    /// On-disk filename. Defaults to the URL's basename, but some sources (e.g. the ivrit.ai
    /// model served as a generic `ggml-model.bin`) need an explicit, distinct name.
    let filename: String
    /// Language to switch to when this model is selected (e.g. "he" for the Hebrew model).
    let preferredLanguage: String?

    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(size) * 1000000)
    }

    init(name: String, isDownloaded: Bool, url: URL, size: Int, description: String,
         filename: String? = nil, preferredLanguage: String? = nil) {
        self.name = name
        self.isDownloaded = isDownloaded
        self.url = url
        self.size = size
        self.description = description
        self.filename = filename ?? url.lastPathComponent
        self.preferredLanguage = preferredLanguage
    }
}

struct SettingsDownloadableModels {
    static let availableModels = [
        SettingsDownloadableModel(
            name: "Turbo V3 large",
            isDownloaded: false,
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin?download=true")!,
            size: 1624,
            description: "High accuracy, best quality"
        ),
        SettingsDownloadableModel(
            name: "Turbo V3 medium",
            isDownloaded: false,
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin?download=true")!,
            size: 874,
            description: "Balanced speed and accuracy"
        ),
        SettingsDownloadableModel(
            name: "Turbo V3 small",
            isDownloaded: false,
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin?download=true")!,
            size: 574,
            description: "Fastest processing"
        ),
        // Distil large-v3 was here briefly — dropped after our FLEURS benchmark: on
        // Metal it matches large-v3-turbo's speed exactly (the shared large encoder
        // dominates short dictation clips) with worse accuracy (8% vs 5.9% WER) and
        // English only. Anyone who downloaded it keeps using it via the on-disk list.
        SettingsDownloadableModel(
            name: "Hebrew — ivrit.ai Turbo v3",
            isDownloaded: false,
            url: URL(string: "https://huggingface.co/ivrit-ai/whisper-large-v3-turbo-ggml/resolve/main/ggml-model.bin?download=true")!,
            size: 1624,
            description: "Hebrew-optimized model by ivrit.ai. Selecting it sets the language to Hebrew.",
            filename: "ggml-ivrit-large-v3-turbo.bin",
            preferredLanguage: "he"
        )
    ]

    static func preferredLanguage(forFilename filename: String) -> String? {
        availableModels.first { $0.filename == filename }?.preferredLanguage
    }
}

struct Settings {
    /// A prompt kept in a file wins over the one typed in Settings.
    ///
    /// Whisper copies the style of whatever it is primed with, so anyone writing to a house
    /// style wants a sample of their own prose here: punctuation, dialogue, names. That belongs
    /// in a file next to their work and under version control, not retyped into a text field on
    /// every machine. Read fresh each time, so editing it takes effect on the next dictation.
    static let promptFileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/opensuperwhisper/prompt.md")

    /// Whisper keeps only its last ~224 tokens of prompt anyway, and this is read on the
    /// dictation path, so a file pointed at something enormous is truncated rather than read
    /// whole.
    static let promptFileByteLimit = 16 * 1024

    static func promptFileContents(at url: URL = promptFileURL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: promptFileByteLimit),
              let text = String(data: data, encoding: .utf8)
        else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    var selectedLanguage: String
    var translateToEnglish: Bool
    var suppressBlankAudio: Bool
    var showTimestamps: Bool
    var temperature: Double
    var noSpeechThreshold: Double
    var initialPrompt: String
    var useBeamSearch: Bool
    var beamSize: Int
    var customDictionaryEnabled: Bool
    var customDictionaryBoostEnabled: Bool
    var customDictionaryEntries: [CustomDictionaryEntry]

    var shouldApplyCustomDictionary: Bool {
        customDictionaryEnabled && !customDictionaryEntries.isEmpty
    }

    /// Whether to also bias recognition toward the dictionary terms (opt-in, on top of the
    /// always-on text replacement). Gated by the separate `customDictionaryBoostEnabled` flag.
    var shouldBoostCustomDictionary: Bool {
        customDictionaryBoostEnabled && shouldApplyCustomDictionary
    }

    init() {
        let prefs = AppPreferences.shared
        self.selectedLanguage = prefs.whisperLanguage
        // Translate-to-English was cut from the UI; the pref survives but the engines
        // always see it off.
        self.translateToEnglish = false
        self.suppressBlankAudio = prefs.suppressBlankAudio
        self.showTimestamps = prefs.showTimestamps
        self.temperature = prefs.temperature
        self.noSpeechThreshold = prefs.noSpeechThreshold
        self.initialPrompt = Settings.promptFileContents() ?? prefs.initialPrompt
        self.useBeamSearch = prefs.useBeamSearch
        self.beamSize = prefs.beamSize
        self.customDictionaryEnabled = prefs.customDictionaryEnabled
        self.customDictionaryBoostEnabled = prefs.customDictionaryBoostEnabled
        self.customDictionaryEntries = prefs.customDictionaryEntries
    }
}

/// A small "ⓘ" button that reveals a longer explanation in a popover, so setting rows can
/// show a short caption by default and keep the full details one click away.
struct InfoButton: View {
    let text: LocalizedStringKey
    @State private var isShown = false

    var body: some View {
        Button {
            isShown.toggle()
        } label: {
            Image(systemName: "info.circle")
                .scaledFont(size: 12)
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("More info")
        .popover(isPresented: $isShown, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .frame(width: 300, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
        }
    }
}

/// The settings tabs, shown as a vertical sidebar in the dedicated settings window.
enum SettingsTab: String, CaseIterable, Identifiable {
    case dictation, models, output, history, advanced, updates
    var id: String { rawValue }

    /// Main navigation (sidebar top) vs utility items (sidebar footer).
    static let main: [SettingsTab] = [.dictation, .models, .output, .history, .advanced]
    static let footer: [SettingsTab] = [.updates]

    var title: String {
        switch self {
        case .dictation: return "Dictation"
        case .models: return "Models"
        case .output: return "Output"
        case .history: return "History & Privacy"
        case .advanced: return "Advanced"
        case .updates: return "Updates"
        }
    }
    // Icons carried over from the previous sidebar (kept on purpose).
    var icon: String {
        switch self {
        case .dictation: return "slider.horizontal.3"
        case .models: return "cpu"
        case .output: return "text.bubble"
        case .history: return "clock.arrow.circlepath"
        case .advanced: return "gearshape"
        case .updates: return "sparkles"
        }
    }
}

struct SettingsView: View {
    /// Tab to land on when the sheet opens (e.g. Home's "Get a model" → .models).
    /// Passed in rather than via notification: the notification fires before the
    /// sheet's SettingsView exists, so a fresh sheet would miss it.
    private let initialTab: SettingsTab?

    init(initialTab: SettingsTab? = nil) {
        self.initialTab = initialTab
    }

    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab = .dictation
    @State private var sidebarSearch = ""
    @FocusState private var sidebarSearchFocused: Bool
    @ObservedObject private var micService = MicrophoneService.shared
    /// Live permission state for the Dictation tab's Permissions section. The manager re-checks
    /// every second while a window is key, so the rows flip to green as soon as macOS grants.
    @StateObject private var permissions = PermissionsManager()
    /// The engine whose models are currently being *browsed* (navigation only — the active engine
    /// in `viewModel.selectedEngine` changes only when the user clicks a model).
    @State private var browseEngine: String = AppPreferences.shared.selectedEngine
    @State private var previousModelURL: URL?
    @State private var appLanguage = LanguageManager.selected
    @State private var langNeedsRelaunch = false
    @State private var showPunctuationCalibration = false

    /// Engine → display name for the "active engine" indicator.
    private func engineDisplayName(_ engine: String) -> String {
        switch engine {
        case "fluidaudio": return "Parakeet"
        case "whisper": return "Whisper"
        default: return engine
        }
    }

    /// Content for the currently-selected sidebar tab.
    @ViewBuilder private var detailContent: some View {
        switch selectedTab {
        case .dictation: dictationSettings
        case .models:    modelSettings
        case .output:    transcriptionSettings
        case .history:   storageSettings
        case .advanced:  advancedSettings
        case .updates:   UpdatesView()
        }
    }

    /// One row in the left sidebar. Selection = soft copper tint (design: "teinte douce").
    private func sidebarRow(_ tab: SettingsTab, compact: Bool = false) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .scaledFont(size: compact ? 11 : 12, weight: .medium)
                    .frame(width: 18, alignment: .center)
                    .foregroundColor(selectedTab == tab ? STheme.accent : STheme.hint)
                Text(tab.title)
                    .scaledFont(size: compact ? 12 : 13, weight: .medium)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, compact ? 5 : 7)
            .foregroundStyle(selectedTab == tab ? STheme.accent : STheme.sidebarItem)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedTab == tab ? STheme.accentSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Sidebar tabs matching the search box (matches everything when it's empty).
    private func matchesSearch(_ tab: SettingsTab) -> Bool {
        let q = sidebarSearch.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || tab.title.localizedCaseInsensitiveContains(q)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Vertical sidebar — search on top, main categories, utility footer
            // (Updates with a badge when one is available, Feedback, Support us, version).
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .scaledFont(size: 10)
                        .foregroundColor(STheme.hint)
                    TextField("Search…", text: $sidebarSearch)
                        .textFieldStyle(.plain)
                        .scaledFont(size: 12)
                        .foregroundColor(STheme.text)
                        .focused($sidebarSearchFocused)
                    Text("⌘F")
                        .scaledFont(size: 10, design: .monospaced)
                        .foregroundColor(STheme.hint)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4).fill(STheme.controlBg))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(STheme.inputBg))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(STheme.controlBorder, lineWidth: 1))
                .padding(.bottom, 12)
                .background(
                    Button("") { sidebarSearchFocused = true }
                        .keyboardShortcut("f", modifiers: .command)
                        .opacity(0)
                )

                ForEach(SettingsTab.main.filter(matchesSearch)) { tab in
                    sidebarRow(tab)
                }
                Spacer(minLength: 0)

                // Sits with the navigation rather than in the list being downloaded from, so it
                // survives the user wandering to another page while a model comes down.
                DownloadsSidebarCard(viewModel: viewModel)
                    .padding(.bottom, 8)

                Rectangle().fill(STheme.border).frame(height: 1).padding(.vertical, 8)
                ForEach(SettingsTab.footer.filter(matchesSearch)) { tab in
                    sidebarRow(tab, compact: true)
                }
                HStack {
                    Spacer()
                    Text("v\(UpdatesView.currentVersion)")
                        .scaledFont(size: 10.5, design: .monospaced)
                        .foregroundColor(STheme.hint.opacity(0.8))
                }
                .padding(.horizontal, 10).padding(.top, 6)
            }
            .padding(12)
            .frame(width: 224)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(STheme.sidebarBg)

            Rectangle().fill(STheme.border).frame(width: 1)

            // The ✕ gets its own strip above the pane content (not an overlay), so
            // trailing header items — the Models "● Active" pill, SPane subtitles —
            // can never slide under it at any window width. Esc works too.
            VStack(alignment: .trailing, spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundColor(STheme.hint)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(STheme.controlBg))
                        .overlay(Circle().stroke(STheme.controlBorder, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close settings")
                .padding(.top, 10)
                .padding(.trailing, 12)

                detailContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(STheme.windowBg)
            // The old footer's Done button carried this legacy reload; the sheet now
            // just closes, so run it when the view goes away instead. (Model selection
            // reloads through ModelSelectionStore anyway — this is belt-and-suspenders
            // for a Whisper path that predates the stores.)
            .onDisappear {
                if viewModel.selectedEngine == "whisper",
                   viewModel.selectedModelURL != previousModelURL,
                   let modelPath = viewModel.selectedModelURL?.path {
                    TranscriptionService.shared.reloadModel(with: modelPath)
                }
            }
        }
        .tint(STheme.accent)
        .frame(minWidth: 720, idealWidth: 780, minHeight: 540, idealHeight: 600)
        .onAppear {
            if let initialTab { selectedTab = initialTab }
            previousModelURL = viewModel.selectedModelURL
            launchAtLogin.refresh()
            if viewModel.selectedEngine == "fluidaudio" {
                viewModel.initializeFluidAudioModels()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsModelsTab)) { _ in
            selectedTab = .models
        }
        .onChange(of: viewModel.selectedEngine) { _, newEngine in
            if newEngine == "fluidaudio" {
                viewModel.initializeFluidAudioModels()
            }
        }
        .onChange(of: viewModel.fluidAudioModelVersion) { _, _ in
            Task { @MainActor in
                TranscriptionService.shared.reloadEngine()
            }
        }
        .onChange(of: viewModel.selectedModelURL) { _, newURL in
            if viewModel.selectedEngine == "whisper", let modelPath = newURL?.path {
                Task { @MainActor in
                    TranscriptionService.shared.reloadModel(with: modelPath)
                }
            }
        }
        // Injected from the view model rather than read from preferences at window
        // construction: preferences aren't observed, so the slider wrote a value nothing
        // ever re-read and the setting appeared to do nothing until the app restarted.
        .environment(\.appTextScale, viewModel.textScale)
        .sheet(isPresented: $showPunctuationCalibration) {
            PunctuationCalibrationView(
                onFinish: { entries in
                    viewModel.customDictionaryEntries.append(contentsOf: entries)
                    showPunctuationCalibration = false
                },
                onCancel: { showPunctuationCalibration = false })
            .environment(\.appTextScale, viewModel.textScale)
        }
    }
    
    /// Compact engine card (design 1b): name + one-line subtitle, copper when browsed.
    private func engineCard(tag: String, name: String, sub: LocalizedStringKey) -> some View {
        Button { browseEngine = tag } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(browseEngine == tag ? STheme.accent : STheme.text)
                    .lineLimit(1)
                Text(sub)
                    .scaledFont(size: 10.5)
                    .foregroundColor(STheme.hint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9)
                .fill(browseEngine == tag ? STheme.accentSoft : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .stroke(browseEngine == tag ? STheme.accent : STheme.controlBorder, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "● Active · Engine / model" pill (green — the one live-status element).
    private var activeModelPill: some View {
        let model = ModelCatalog.activeOption()?.displayName
        return Text("● Active · \(engineDisplayName(viewModel.selectedEngine))\(model.map { " / \($0)" } ?? "")")
            .scaledFont(size: 11, weight: .semibold)
            .foregroundColor(STheme.ok)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 9).padding(.vertical, 2)
            .background(Capsule().fill(STheme.okBg))
            .frame(maxWidth: 340, alignment: .trailing)
    }

    /// Models-directory row (Storage section of the local engines).
    private func storageSection(path: String, open: @escaping () -> Void) -> some View {
        SSection(title: "Storage") {
            SRow(title: "Models directory", hint: LocalizedStringKey(path)) {
                Button("Open in Finder", action: open)
                    .controlSize(.small)
            }
        }
    }

    private var modelSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Models")
                    .scaledFont(size: 19, weight: .bold)
                    .foregroundColor(STheme.textBright)
                Spacer()
                activeModelPill
            }
            // Modest top padding, matching SPane: the close-button strip above
            // already provides the headroom.
            .padding(.horizontal, 24).padding(.top, 2)

            HStack(spacing: 8) {
                engineCard(tag: "fluidaudio", name: "Parakeet", sub: "Fast, on-device")
                engineCard(tag: "whisper", name: "Whisper", sub: "Accurate · 99 langs")
            }
            .padding(.horizontal, 24).padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if browseEngine == "whisper" {
                        SSection(title: "Whisper models") {
                            VStack(spacing: 8) {
                                ForEach($viewModel.downloadableModels) { $model in
                                    ModelDownloadItemView(model: $model, viewModel: viewModel)
                                }
                            }
                        }
                        storageSection(path: WhisperModelManager.shared.modelsDirectory.path) {
                            NSWorkspace.shared.open(WhisperModelManager.shared.modelsDirectory)
                        }
                    } else if browseEngine == "fluidaudio" {
                        SSection(title: "Parakeet models") {
                            VStack(spacing: 8) {
                                ForEach($viewModel.downloadableFluidAudioModels) { $model in
                                    FluidAudioModelDownloadItemView(model: $model, viewModel: viewModel)
                                }
                            }
                        }
                        storageSection(path: AsrModels.defaultCacheDirectory(for: .v3).deletingLastPathComponent().path) {
                            NSWorkspace.shared.open(AsrModels.defaultCacheDirectory(for: .v3).deletingLastPathComponent())
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 14)
            }
        }
        .background(STheme.windowBg)
    }

    @ViewBuilder private var builtInCleanupFields: some View {
        HStack(spacing: 8) {
            if viewModel.builtInModelDownloaded {
                Text("✓ Model ready — runs on-device")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundColor(STheme.ok)
                    .padding(.horizontal, 9).padding(.vertical, 2)
                    .background(Capsule().fill(STheme.okBg))
                Text("Loads on first use (a few seconds), then frees its ~1 GB after 5 minutes idle.")
                    .scaledFont(size: 11).foregroundColor(STheme.hint)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let progress = viewModel.builtInModelDownloadProgress {
                ProgressView(value: progress).frame(width: 160).controlSize(.small)
                Text("\(Int(progress * 100))%").scaledFont(size: 11).foregroundColor(STheme.hint)
            } else {
                Button("Download model (~1 GB)") { viewModel.downloadBuiltInModel() }
                    .controlSize(.small)
                Text("Required — cleanup is skipped until it's downloaded. Qwen2.5 1.5B, Apache-2.0. One-time download; no server needed.")
                    .scaledFont(size: 11).foregroundColor(STheme.hint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.leading, 16)
        if let err = viewModel.builtInModelDownloadError {
            Text("✕ \(err)")
                .scaledFont(size: 11)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 16)
        }
    }

    private var transcriptionSettings: some View {
        SPane(title: "Output", subtitle: "What happens to your text, in pipeline order") {
            SSection(title: "Language") {
                SRow(title: "Transcription language") {
                    Picker("", selection: $viewModel.selectedLanguage) {
                        ForEach(viewModel.supportedLanguages, id: \.self) { code in
                            Text(LanguageUtil.languageNames[code] ?? code).tag(code)
                        }
                    }
                    // Recreate the picker when the engine's language set changes, so its
                    // selection never gets stuck blank on a value that left the list; and
                    // clamp the stored language to a supported one when this view appears.
                    .id(viewModel.supportedLanguages)
                    .onAppear { viewModel.clampLanguageToSupported() }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SSection(title: "Cleanup") {
                SRow(title: "Remove filler words", hint: "Strip um, uh, er… before inserting") {
                    SToggle(isOn: $viewModel.removeFillerWords)
                }
                HStack(spacing: 8) {
                    Text("Clean up with an LLM")
                        .scaledFont(size: 13).foregroundColor(STheme.text)
                    Spacer()
                    SToggle(isOn: $viewModel.aiPostProcessingEnabled)
                }
                .frame(minHeight: 26)
                if viewModel.aiPostProcessingEnabled {
                    builtInCleanupFields
                    HStack(spacing: 8) {
                        Text("Smart formatting")
                            .scaledFont(size: 12).foregroundColor(STheme.text)
                        InfoButton(text: "Lay dictated lists out as lists: “item 1, yes, item 2, no” becomes bulleted lines instead of one run-on sentence. Normal sentences stay prose.")
                        Spacer()
                        SToggle(isOn: $viewModel.smartFormattingEnabled)
                    }
                    .padding(.leading, 16)
                    .frame(minHeight: 24)
                }
            }

            SSection(title: "Dictionary") {
                SRow(title: "Custom dictionary", hint: "Whole-word replacement, case-insensitive") {
                    SToggle(isOn: $viewModel.customDictionaryEnabled)
                }
                if viewModel.customDictionaryEnabled {
                    HStack(spacing: 8) {
                        Text("Boost recognition")
                            .scaledFont(size: 12).foregroundColor(STheme.text)
                        STag("Advanced")
                        InfoButton(text: "Also bias the model toward these terms while listening, not just fix them afterward. Helps rare, distinctive words (e.g. “Kubernetes”) — but can over-correct short, common ones. Leave off if it replaces too much.")
                        Spacer()
                        SToggle(isOn: $viewModel.customDictionaryBoostEnabled)
                    }
                    .padding(.leading, 16)
                    .frame(minHeight: 24)

                    DictionaryBadgeEditor(entries: $viewModel.customDictionaryEntries)
                        .padding(.leading, 16)

                    // Punctuation is the case nobody gets right by hand: the phrasing is
                    // personal and the spacing is fiddly. Reading a few sentences settles both,
                    // and the rules land in the badges above.
                    Button {
                        showPunctuationCalibration = true
                    } label: {
                        Label("Teach punctuation", systemImage: "text.quote")
                            .scaledFont(size: 11.5, weight: .medium)
                    }
                    .controlSize(.small)
                    .padding(.leading, 16)
                }
            }

            SSection(title: "Delivery") {
                SRow(title: "Copy to clipboard", hint: "Also place the transcription on the clipboard. When off, the previous clipboard contents are preserved") {
                    SToggle(isOn: $viewModel.autoCopyToClipboard)
                }
                SRow(title: "Auto-paste transcription", hint: "Insert the transcription into the focused app") {
                    SToggle(isOn: $viewModel.autoPasteTranscription)
                }
                SRow(title: "Paste instead of typing",
                     hint: "⌘V instead of synthetic keystrokes — helps in Electron apps and Messages") {
                    SToggle(isOn: $viewModel.pasteInsteadOfTyping)
                }
                SRow(title: "Notify when no paste target",
                     hint: "\"Copied — press ⌘V\" if no text field is focused") {
                    SToggle(isOn: $viewModel.notifyWhenNoPasteTarget)
                }
                SRow(title: "Suppress blank audio") {
                    SToggle(isOn: $viewModel.suppressBlankAudio)
                }
                SRow(title: "Add space after sentence", hint: "Useful when dictating in bursts") {
                    SToggle(isOn: $viewModel.addSpaceAfterSentence)
                }
            }
        }
    }

    private var storageSettings: some View {
        SPane(title: "History & Privacy") {
            SSection(title: "Privacy") {
                SRow(title: "Save transcription history",
                     hint: "Off = nothing is ever written to disk — only the current transcription is kept in memory for pasting") {
                    SToggle(isOn: $viewModel.saveTranscriptionHistory)
                }
                SRow(title: "Transcriptions directory",
                     hint: LocalizedStringKey(Recording.recordingsDirectory.path)) {
                    Button("Open in Finder") { NSWorkspace.shared.open(Recording.recordingsDirectory) }
                        .controlSize(.small)
                }
            }

            SSection(title: "Retention") {
                SRow(title: "Limit number of recordings",
                     hint: "Keep only the most recent recordings & transcriptions") {
                    SToggle(isOn: $viewModel.retentionMaxCountEnabled)
                }
                if viewModel.retentionMaxCountEnabled {
                    SRow(title: "Keep at most", indented: true) {
                        HStack(spacing: 6) {
                            TextField("", value: $viewModel.retentionMaxCount, format: .number)
                                .textFieldStyle(.plain)
                                .scaledFont(size: 12, design: .monospaced)
                                .multilineTextAlignment(.trailing)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .frame(width: 64)
                                .background(RoundedRectangle(cornerRadius: 7).fill(STheme.inputBg))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(STheme.controlBorder, lineWidth: 1))
                            Stepper("", value: $viewModel.retentionMaxCount, in: 1...100000)
                                .labelsHidden()
                            Text("recordings").scaledFont(size: 11).foregroundColor(STheme.hint)
                        }
                    }
                }
                SRow(title: "Delete old recordings",
                     hint: "Automatically remove recordings older than the chosen age") {
                    SToggle(isOn: $viewModel.retentionMaxAgeEnabled)
                }
                if viewModel.retentionMaxAgeEnabled {
                    SRow(title: "Delete after", indented: true) {
                        HStack(spacing: 6) {
                            TextField("", value: $viewModel.retentionMaxAgeValue, format: .number)
                                .textFieldStyle(.plain)
                                .scaledFont(size: 12, design: .monospaced)
                                .multilineTextAlignment(.trailing)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .frame(width: 56)
                                .background(RoundedRectangle(cornerRadius: 7).fill(STheme.inputBg))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(STheme.controlBorder, lineWidth: 1))
                            Stepper("", value: $viewModel.retentionMaxAgeValue, in: 1...100000)
                                .labelsHidden()
                            Picker("", selection: $viewModel.retentionMaxAgeUnit) {
                                ForEach(RetentionUnit.allCases, id: \.self) { unit in
                                    Text(unit.displayName).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
                Text("Both limits combine — whichever is hit first wins. Cleanup runs automatically, never while a transcription is being processed.")
                    .scaledFont(size: 11).foregroundColor(STheme.hint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "Advanced" — app-level odds and ends: language, launch behavior, debug.
    private var advancedSettings: some View {
        SPane(title: "Advanced") {
            SSection(title: "App") {
                SRow(title: "App language", hint: "Relaunch to apply.") {
                    Picker("", selection: $appLanguage) {
                        Text("System").tag("system")
                        Text("English").tag("en")
                        Text("Français").tag("fr")
                        Text("Deutsch").tag("de")
                        Text("Español").tag("es")
                        Text("Italiano").tag("it")
                        Text("Português (BR)").tag("pt-BR")
                        Text("Tiếng Việt").tag("vi")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .labelsHidden()
                    .onChange(of: appLanguage) { _, newValue in
                        LanguageManager.selected = newValue
                        langNeedsRelaunch = true
                    }
                }
                if langNeedsRelaunch {
                    SRow(title: "Relaunch to apply the new language", indented: true) {
                        Button("Relaunch Now") { LanguageManager.relaunch() }
                            .controlSize(.small)
                    }
                }
                SRow(title: "Launch at login", hint: "Start Rhino automatically when you log in.") {
                    SToggle(isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                }
                SRow(title: "Start in the menu bar", hint: "Launch without the main window — open it from the menu bar icon.") {
                    SToggle(isOn: $viewModel.startHidden)
                }
            }

            SSection(title: "Debug") {
                SRow(title: "Debug mode", hint: "Extra logging and diagnostic output.") {
                    SToggle(isOn: $viewModel.debugMode)
                }
            }
        }
    }

    /// "Dictation" — the redesigned first screen (Settings Explorations 2a):
    /// Trigger / Recording bar / Input, in the Atelier style.
    private var dictationSettings: some View {
        SPane(title: "Dictation") {
            // The complete permission story in one place: Rhino needs exactly these two.
            // (Input Monitoring rows some users see in System Settings are not needed —
            // Accessibility covers event listening too. Apple Events / Automation went
            // away with browser-URL capture.)
            SSection(title: "Permissions") {
                permissionRow(granted: permissions.isMicrophonePermissionGranted,
                              title: "Microphone",
                              hint: "To hear your dictation. Audio never leaves this Mac.") {
                    permissions.requestMicrophonePermissionOrOpenSystemPreferences()
                }
                permissionRow(granted: permissions.isAccessibilityPermissionGranted,
                              title: "Accessibility",
                              hint: "To paste text into other apps and watch the recording shortcut. These two are the only permissions Rhino needs.") {
                    permissions.requestAccessibilityPermissionOrOpenSystemPreferences()
                }
                if !permissions.isAccessibilityPermissionGranted {
                    SWarnBox {
                        Text("Checkbox already on in System Settings but pasting doesn't work? The grant has gone stale — in Privacy & Security → Accessibility, remove Rhino with the − button, add it back, then relaunch Rhino.")
                    }
                }
            }

            SSection(title: "Trigger") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recording trigger")
                        .scaledFont(size: 13)
                        .foregroundColor(STheme.text)
                    Text("Click Add, then do the thing: press a combination with ⌘ ⌥ ⌃, or tap a single modifier on its own. Keep several and use whichever suits the moment.")
                        .scaledFont(size: 11)
                        .foregroundColor(STheme.hint)
                        .fixedSize(horizontal: false, vertical: true)
                    TriggerRecorderField(name: .toggleRecord,
                                         modifierKey: $viewModel.modifierOnlyHotkey,
                                         allowsMultiple: true)
                        .padding(.top, 2)
                    if let note = fnEmojiFootnote {
                        Text(note)
                            .scaledFont(size: 11)
                            .foregroundColor(STheme.hint)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SRow(title: "Cancel shortcut",
                     hint: "Discards the recording. Esc on its own is fine here; ⌫ clears it") {
                    TriggerRecorderField(name: .escape,
                                         modifierKey: $viewModel.cancelModifierUnused,
                                         allowsModifier: false,
                                         allowsBareEscape: true)
                        .frame(width: 168)
                }
                SRow(title: "Hold to record", hint: "Hold the shortcut to record, release to stop") {
                    SToggle(isOn: $viewModel.holdToRecord)
                }
                SRow(title: "Hands-free mode",
                     hint: "Double-press the shortcut to lock recording on; press again to stop") {
                    SToggle(isOn: $viewModel.doubleTapLock)
                }
            }

            SSection(title: "While recording") {
                SRow(title: "Play sound when recording starts") {
                    SToggle(isOn: $viewModel.playSoundOnRecordStart)
                }
                HStack(spacing: 8) {
                    Text("Live transcription")
                        .scaledFont(size: 13)
                        .foregroundColor(STheme.text)
                        .opacity(viewModel.selectedEngine == "fluidaudio" ? 1 : 0.45)
                    STag("Parakeet only")
                    Spacer()
                    SToggle(isOn: $viewModel.liveTranscriptionEnabled,
                            disabled: viewModel.selectedEngine != "fluidaudio")
                }
                .frame(minHeight: 26)
                SRow(title: "Pause media during recording",
                     hint: "Resumes what was actually playing when you stop") {
                    SToggle(isOn: $viewModel.pauseMediaOnRecord)
                }
            }

            SSection(title: "Input") {
                SRow(title: "Microphone",
                     hint: micService.followsSystemDefault
                        ? "Following the system input\(micService.currentMicrophone.map { " (\($0.name))" } ?? "") — switch headsets and it follows"
                        : "Also switchable from the menu bar") {
                    Picker("", selection: Binding(
                        get: {
                            micService.followsSystemDefault
                                ? MicrophoneService.systemDefaultID
                                : (micService.selectedMicrophone?.id ?? MicrophoneService.systemDefaultID)
                        },
                        set: { newID in
                            if newID == MicrophoneService.systemDefaultID {
                                micService.resetToDefault()
                            } else if let device = micService.availableMicrophones.first(where: { $0.id == newID }) {
                                micService.selectMicrophone(device)
                            }
                        }
                    )) {
                        Text("System Default").tag(MicrophoneService.systemDefaultID)
                        Divider()
                        ForEach(micService.availableMicrophones, id: \.id) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SSection(title: "Indicator") {
                SRow(title: "Position", hint: "Where the bubble appears while recording") {
                    Picker("", selection: $viewModel.indicatorPosition) {
                        Text("Near cursor").tag("cursor")
                        Text("Notch").tag("notch")
                        Text("Top").tag("top")
                        Text("Center").tag("center")
                        Text("Bottom").tag("bottom")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    /// Footnote under the trigger field when Fn is a dictate key: what happened to the
    /// Mac's "press 🌐 for emoji" behavior, or how to stop it if it's still active.
    /// Onboarding only whispers about this ("Emoji stays available with ⌃⌘Space") —
    /// the full story lives here for the few who go looking.
    private var fnEmojiFootnote: String? {
        let triggers = RecordingTriggerSet.load(from: AppPreferences.shared.recordingTriggers)
        guard triggers.modifiers.contains(.fn) else { return nil }
        if FnGlobeKeySetting.conflictsWithFnTrigger {
            return "Your Mac also opens the emoji picker when Fn is pressed on its own, so it will pop up when you dictate. Stop it in System Settings → Keyboard → “Press 🌐 key to” → Do Nothing."
        }
        return "Setup turned off the Mac's press-Fn-for-emoji shortcut so it doesn't pop up mid-dictation. Emoji stays available with ⌃⌘Space; undo in System Settings → Keyboard."
    }

    /// One permission row: green check when granted, a Grant button when not.
    private func permissionRow(granted: Bool,
                               title: LocalizedStringKey,
                               hint: LocalizedStringKey,
                               grant: @escaping () -> Void) -> some View {
        SRow(title: title, hint: hint) {
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(STheme.ok)
            } else {
                Button("Grant…", action: grant)
                    .controlSize(.small)
            }
        }
    }
}

struct SettingsFluidAudioModel: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    var isDownloaded: Bool
    let description: String
    var size: Int = 0   // approximate download size, MB
    var downloadProgress: Double = 0.0

    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(size) * 1_000_000)
    }
}

struct SettingsFluidAudioModels {
    static let availableModels = [
        SettingsFluidAudioModel(
            name: "Parakeet v3",
            version: "v3",
            isDownloaded: false,
            description: "Multilingual, 25 languages",
            size: 461
        ),
        SettingsFluidAudioModel(
            name: "Parakeet v2",
            version: "v2",
            isDownloaded: false,
            description: "English-only, higher recall",
            size: 460
        )
    ]
}

enum OnboardingModelType {
    case whisper(url: URL, size: Int)
    case parakeet(version: String)
}

struct OnboardingUnifiedModel: Identifiable {
    let id = UUID()
    let name: String
    var isDownloaded: Bool
    let description: String
    let type: OnboardingModelType
    var downloadProgress: Double = 0.0
    var isRecommended = false
}

struct OnboardingUnifiedModels {
    /// First-run is a two-choice decision: the recommended Parakeet v3 or best-accuracy
    /// Whisper. The list used to also offer Parakeet v2 and two compression variants of
    /// the same Whisper model — five near-identical rows that read as an accuracy ladder
    /// and stalled new users on a choice that barely matters. The trimmed variants remain
    /// available in Settings → Models.
    static let availableModels = [
        OnboardingUnifiedModel(
            name: "Parakeet v3",
            isDownloaded: false,
            description: "Fastest processing and accurate",
            type: .parakeet(version: "v3"),
            isRecommended: true
        ),
        OnboardingUnifiedModel(
            name: "Whisper Large v3 Turbo",
            isDownloaded: false,
            description: "Best accuracy, 1.6 GB",
            type: .whisper(
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin?download=true")!,
                size: 1624
            )
        ),
    ]
}

struct FluidAudioModelDownloadItemView: View {
    @Binding var model: SettingsFluidAudioModel
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showError = false
    @State private var errorMessage = ""
    
    var isSelected: Bool {
        viewModel.fluidAudioModelVersion == model.version
    }

    /// The model actually used for transcription: selected *and* its engine is active.
    /// Only the active model shows the solid green check (resolves the two-checkmarks
    /// ambiguity of #139).
    var isActive: Bool {
        isSelected && viewModel.selectedEngine == "fluidaudio"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if model.isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.small)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(model.description)
                    Text("·")
                    Text(model.sizeString)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if viewModel.isDownloading && viewModel.downloadingModelName == model.name {
                    // Real byte progress (was a bare spinner that read as "stuck"
                    // through the multi-minute download + CoreML compile).
                    ProgressView(value: min(model.downloadProgress, 1.0))
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 6)
                        .padding(.top, 4)
                    if let phase = viewModel.downloadPhaseText {
                        Text(phase)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if model.downloadProgress > 0 && model.downloadProgress < 1 {
                    ProgressView(value: model.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 6)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
            
            if viewModel.isDownloading && viewModel.downloadingModelName == model.name {
                Button("Cancel") {
                    viewModel.cancelDownload()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if model.isDownloaded {
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .imageScale(.large)
                } else {
                    // Not the active model → offer Select. One global selection, so a
                    // non-active model shows no "remembered" checkmark (selecting here
                    // activates Parakeet and deselects other engines).
                    Button(action: {
                        viewModel.selectParakeet(model.version)
                    }) {
                        Text("Select")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                Button(action: {
                    Task {
                        do {
                            try await viewModel.downloadFluidAudioModel(model)
                        } catch is CancellationError {
                            // Don't show error for manual cancellation
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isDownloading)
            }
        }
        .padding(12)
        // Inset surface inside the white section cell; the active model gets the
        // soft accent tint so the selection reads at a glance.
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isActive ? STheme.accentSoft : STheme.windowBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isActive ? STheme.accent.opacity(0.4) : STheme.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Activate on tap whenever this isn't already the *active* model — even if it's the
            // selected version but Parakeet isn't the active engine (browse ≠ select).
            if model.isDownloaded && !isActive {
                viewModel.selectParakeet(model.version)
            }
        }
        .alert("Download Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

struct ModelDownloadItemView: View {
    @Binding var model: SettingsDownloadableModel
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showError = false
    @State private var errorMessage = ""
    
    var isSelected: Bool {
        if let selectedURL = viewModel.selectedModelURL {
            let filename = model.filename
            return selectedURL.lastPathComponent == filename
        }
        return false
    }

    /// The model actually used for transcription: selected *and* Whisper is the
    /// active engine. Only the active model shows the solid green check (#139).
    var isActive: Bool {
        isSelected && viewModel.selectedEngine == "whisper"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if model.isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.small)
                    }
                }

                HStack(spacing: 6) {
                    Text(model.description)
                    Text("·")
                    Text(model.sizeString)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if model.downloadProgress > 0 && model.downloadProgress < 1 {
                    ProgressView(value: model.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 6)
                        .padding(.top, 4)
                } else if viewModel.isDownloading && viewModel.downloadingModelName == model.name {
                    // Between the click and the first byte there is no percentage to show, and
                    // an empty row reads as nothing having happened.
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 6)
                        .padding(.top, 4)
                }
            }

            Spacer()

            if viewModel.isDownloading && viewModel.downloadingModelName == model.name {
                Button("Cancel") {
                    viewModel.cancelDownload()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if model.isDownloaded {
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .imageScale(.large)
                } else {
                    // Not the active model → offer Select. The app has one global
                    // selection, so a non-active model shows no "remembered" checkmark
                    // (selecting here activates Whisper and deselects other engines).
                    Button(action: {
                        let modelPath = WhisperModelManager.shared.modelsDirectory.appendingPathComponent(model.filename).path
                        viewModel.selectModel(URL(fileURLWithPath: modelPath))
                    }) {
                        Text("Select")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                Button(action: {
                    Task {
                        do {
                            try await viewModel.downloadModel(model)
                        } catch is CancellationError {
                            // Don't show error for manual cancellation
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isDownloading)
            }
        }
        .padding(12)
        // Inset surface inside the white section cell; the active model gets the
        // soft accent tint so the selection reads at a glance.
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isActive ? STheme.accentSoft : STheme.windowBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isActive ? STheme.accent.opacity(0.4) : STheme.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Activate on tap whenever this isn't the active model (works even if it's the selected
            // file but Whisper isn't the active engine).
            if model.isDownloaded && !isActive {
                let modelPath = WhisperModelManager.shared.modelsDirectory.appendingPathComponent(model.filename).path
                viewModel.selectModel(URL(fileURLWithPath: modelPath))
            }
        }
        .alert("Download Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

