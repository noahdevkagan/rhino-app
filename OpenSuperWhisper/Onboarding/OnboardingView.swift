//
//  OnboardingView.swift
//  OpenSuperWhisper
//
//  Created by user on 08.02.2025.
//

import Foundation
import SwiftUI
import FluidAudio

enum OnboardingShortcutOption: String, CaseIterable {
    case fn
    case rightOption

    var modifierKey: ModifierKey {
        switch self {
        case .fn: return .fn
        case .rightOption: return .rightOption
        }
    }
}

class OnboardingViewModel: ObservableObject {
    @Published var selectedLanguage: String {
        didSet {
            AppPreferences.shared.whisperLanguage = selectedLanguage
        }
    }

    /// Writes the choice into `recordingTriggers` — the set ShortcutManager actually arms.
    /// (An earlier version wrote the legacy `modifierOnlyHotkey` slot, which nothing reads
    /// anymore: the picker looked functional but the trigger silently stayed the seeded
    /// hold-Fn default, whatever the user chose.)
    @Published var selectedShortcut: OnboardingShortcutOption {
        didSet {
            var set = RecordingTriggerSet.load(from: AppPreferences.shared.recordingTriggers)
            set.triggers.removeAll { if case .modifier = $0 { return true } else { return false } }
            set.add(.modifier(selectedShortcut.modifierKey))
            AppPreferences.shared.recordingTriggers = set.json
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        }
    }

    @Published var unifiedModels: [OnboardingUnifiedModel] = []
    @Published var selectedModelId: UUID?
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadingModelName: String?
    /// Sub-caption under the Parakeet progress bar. The download reports real byte
    /// progress, but the bar alone would sit full during the CoreML compile that
    /// follows (minutes on first install) — the exact "is it stuck?" moment the
    /// spinner used to create.
    @Published var downloadPhaseText: String?

    private let modelManager = WhisperModelManager.shared
    private var downloadTask: Task<Void, Error>?

    init() {
        let systemLanguage = LanguageUtil.getSystemLanguage()
        AppPreferences.shared.whisperLanguage = systemLanguage
        self.selectedLanguage = systemLanguage

        // Reflect what's actually armed: a fresh install's trigger set is seeded to
        // hold-Fn (AppPreferences.migrateRecordingTriggers), so the Fn card starts
        // selected and the UI agrees with the key that really starts a recording.
        let armed = RecordingTriggerSet.load(from: AppPreferences.shared.recordingTriggers)
        self.selectedShortcut = armed.modifiers.contains(.rightOption) ? .rightOption : .fn

        initializeUnifiedModels()
    }

    func initializeUnifiedModels() {
        unifiedModels = OnboardingUnifiedModels.availableModels.map { model in
            var updatedModel = model
            switch model.type {
            case .whisper(let url, _):
                let filename = url.lastPathComponent
                updatedModel.isDownloaded = modelManager.isModelDownloaded(name: filename)
            case .parakeet(let version):
                updatedModel.isDownloaded = isFluidAudioModelDownloaded(version: version)
            }
            return updatedModel
        }
        
        if selectedModelId == nil, let firstDownloaded = unifiedModels.first(where: { $0.isDownloaded }) {
            // Commit through selectModel so AppPreferences (engine + model) match the row
            // the UI shows as selected. Setting only the id left prefs on the "whisper"
            // default when a Parakeet cache already existed, so Continue's verify tried to
            // load a Whisper model that was never downloaded ("TranscriptionError error 0").
            selectModel(firstDownloaded)
        }
    }
    
    func isFluidAudioModelDownloaded(version: String) -> Bool {
        let asrVersion: AsrModelVersion = version == "v2" ? .v2 : .v3
        let cacheDirectory = AsrModels.defaultCacheDirectory(for: asrVersion)
        return AsrModels.modelsExist(at: cacheDirectory, version: asrVersion)
    }
    
    var canContinue: Bool {
        guard let selectedId = selectedModelId else { return false }
        return unifiedModels.contains { $0.id == selectedId && $0.isDownloaded }
    }

    func selectModel(_ model: OnboardingUnifiedModel) {
        selectedModelId = model.id

        switch model.type {
        case .whisper(let url, _):
            AppPreferences.shared.selectedEngine = "whisper"
            let modelPath = modelManager.modelsDirectory.appendingPathComponent(url.lastPathComponent).path
            AppPreferences.shared.selectedWhisperModelPath = modelPath
        case .parakeet(let version):
            AppPreferences.shared.selectedEngine = "fluidaudio"
            AppPreferences.shared.fluidAudioModelVersion = version
        }
    }

    @MainActor
    func downloadModel(_ model: OnboardingUnifiedModel) async throws {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadingModelName = model.name
        downloadProgress = 0.0
        
        if let index = unifiedModels.firstIndex(where: { $0.id == model.id }) {
            unifiedModels[index].downloadProgress = 0.0
        }
        
        switch model.type {
        case .whisper(let url, _):
            try await downloadWhisperModel(model: model, url: url)
        case .parakeet(let version):
            try await downloadParakeetModel(model: model, version: version)
        }
    }
    
    @MainActor
    private func downloadWhisperModel(model: OnboardingUnifiedModel, url: URL) async throws {
        downloadTask = Task {
            do {
                let filename = url.lastPathComponent
                var expectedMB: Int?
                if case .whisper(_, let sizeMB) = model.type { expectedMB = sizeMB }

                try await modelManager.downloadModel(url: url, name: filename, expectedMB: expectedMB) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self = self, !Task.isCancelled else { return }
                        guard let task = self.downloadTask, !task.isCancelled else { return }
                        
                        self.downloadProgress = progress
                        if let index = self.unifiedModels.firstIndex(where: { $0.id == model.id }) {
                            self.unifiedModels[index].downloadProgress = progress
                            if progress >= 1.0 {
                                self.unifiedModels[index].isDownloaded = true
                            }
                        }
                    }
                }
                
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isDownloading = false
                        self.downloadingModelName = nil
                        self.downloadProgress = 0.0
                        if let index = self.unifiedModels.firstIndex(where: { $0.id == model.id }) {
                            self.unifiedModels[index].downloadProgress = 0.0
                        }
                    }
                    throw CancellationError()
                }
                
                await MainActor.run {
                    if let index = unifiedModels.firstIndex(where: { $0.id == model.id }) {
                        unifiedModels[index].isDownloaded = true
                        unifiedModels[index].downloadProgress = 0.0
                    }
                    selectModel(model)
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                }
            } catch is CancellationError {
                await MainActor.run {
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    if let index = unifiedModels.firstIndex(where: { $0.id == model.id }) {
                        unifiedModels[index].downloadProgress = 0.0
                    }
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    if let index = unifiedModels.firstIndex(where: { $0.id == model.id }) {
                        unifiedModels[index].downloadProgress = 0.0
                    }
                }
                throw error
            }
        }
        
        try await downloadTask?.value
    }
    
    private func downloadParakeetModel(model: OnboardingUnifiedModel, version: String) async throws {
        var wasCancelled = false
        
        downloadTask = Task {
            do {
                let asrVersion: AsrModelVersion = version == "v2" ? .v2 : .v3
                
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isDownloading = false
                        self.downloadingModelName = nil
                        self.downloadProgress = 0.0
                        if let index = self.unifiedModels.firstIndex(where: { $0.id == model.id }) {
                            self.unifiedModels[index].downloadProgress = 0.0
                        }
                    }
                    throw CancellationError()
                }
                
                let models = try await AsrModels.downloadAndLoad(version: asrVersion) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, self.isDownloading else { return }
                        self.downloadProgress = progress.fractionCompleted
                        if let index = self.unifiedModels.firstIndex(where: { $0.id == model.id }) {
                            self.unifiedModels[index].downloadProgress = progress.fractionCompleted
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
                        if let index = self.unifiedModels.firstIndex(where: { $0.id == model.id }) {
                            self.unifiedModels[index].downloadProgress = 0.0
                        }
                    }
                    throw CancellationError()
                }
                
                await MainActor.run { downloadPhaseText = "Loading model…" }
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)

                await MainActor.run {
                    if let index = unifiedModels.firstIndex(where: { $0.id == model.id }) {
                        unifiedModels[index].isDownloaded = true
                        unifiedModels[index].downloadProgress = 1.0
                    }
                    selectModel(model)
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
                    if let index = unifiedModels.firstIndex(where: { $0.id == model.id }) {
                        unifiedModels[index].downloadProgress = 0.0
                    }
                }
            } catch {
                if Task.isCancelled {
                    wasCancelled = true
                    await MainActor.run {
                        isDownloading = false
                        downloadingModelName = nil
                        downloadProgress = 0.0
                        downloadPhaseText = nil
                        if let index = unifiedModels.firstIndex(where: { $0.id == model.id }) {
                            unifiedModels[index].downloadProgress = 0.0
                        }
                    }
                } else {
                    await MainActor.run {
                        isDownloading = false
                        downloadingModelName = nil
                        downloadProgress = 0.0
                        downloadPhaseText = nil
                        if let index = unifiedModels.firstIndex(where: { $0.id == model.id }) {
                            unifiedModels[index].downloadProgress = 0.0
                        }
                    }
                    throw error
                }
            }
        }
        
        do {
            try await downloadTask?.value
        } catch is CancellationError {
            wasCancelled = true
        } catch {
            if !wasCancelled {
                throw error
            }
        }
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        if let modelName = downloadingModelName {
            if let model = unifiedModels.first(where: { $0.name == modelName }) {
                if case .whisper(let url, _) = model.type {
                    let filename = url.lastPathComponent
                    modelManager.cancelDownload(name: filename)
                }
            }
            if let index = unifiedModels.firstIndex(where: { $0.name == modelName }) {
                unifiedModels[index].downloadProgress = 0.0
            }
        }
        isDownloading = false
        downloadingModelName = nil
        downloadProgress = 0.0
        downloadPhaseText = nil
    }
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var permissionsManager = PermissionsManager()
    @EnvironmentObject private var appState: AppState
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isVerifyingModel = false

    var body: some View {
        // Same visual system as Settings (Atelier / grouped cells): STheme window
        // background, gray section labels above white cards. The old gradient-header
        // look predated the light-only restyle and read as a different app.
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Rhino")
                        .scaledFont(size: 19, weight: .bold)
                        .foregroundColor(STheme.textBright)
                    Text("Dictate anywhere on your Mac — everything stays on it")
                        .scaledFont(size: 11)
                        .foregroundColor(STheme.hint)
                }
                Spacer()
                Picker("Language", selection: $viewModel.selectedLanguage) {
                    ForEach(LanguageUtil.availableLanguages, id: \.self) { code in
                        Text(LanguageUtil.languageNames[code] ?? code)
                            .tag(code)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Permissions — first, because nothing works without them, and
                    // Accessibility needs Rhino to register itself in System Settings
                    // before the user can even find it there. Rows mirror Settings →
                    // Dictation → Permissions so the two surfaces read as one app.
                    SSection(title: "Permissions") {
                        onboardingPermissionRow(
                            granted: permissionsManager.isMicrophonePermissionGranted,
                            title: "Microphone",
                            hint: "To hear your dictation. Audio never leaves this Mac.") {
                            permissionsManager.requestMicrophonePermissionOrOpenSystemPreferences()
                        }
                        onboardingPermissionRow(
                            granted: permissionsManager.isAccessibilityPermissionGranted,
                            title: "Accessibility",
                            hint: "So the dictate key works everywhere and text lands in the app you're using.") {
                            permissionsManager.requestAccessibilityPermissionOrOpenSystemPreferences()
                        }
                    }

                    SSection(title: "Dictate key") {
                        Text("Hold it down to talk, release to insert the text")
                            .scaledFont(size: 13)
                            .foregroundColor(STheme.text)

                        HStack(spacing: 8) {
                            OnboardingShortcutCard(
                                title: "fn",
                                subtitle: "Hold fn (default)",
                                isSelected: viewModel.selectedShortcut == .fn
                            ) {
                                viewModel.selectedShortcut = .fn
                            }

                            OnboardingShortcutCard(
                                title: "Right ⌥",
                                subtitle: "Hold Right Option",
                                isSelected: viewModel.selectedShortcut == .rightOption
                            ) {
                                viewModel.selectedShortcut = .rightOption
                            }
                        }

                        Text("Rhino watches only this one key — never your typing. You can pick any key or combination later in Settings.")
                            .scaledFont(size: 11)
                            .foregroundColor(STheme.hint)
                    }

                    SSection(title: "Model") {
                        Text("Download a model to get started")
                            .scaledFont(size: 13)
                            .foregroundColor(STheme.text)

                        ForEach($viewModel.unifiedModels) { $model in
                            OnboardingUnifiedModelItemView(model: $model, viewModel: viewModel)
                        }

                        OnboardingCleanupOffer()
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().overlay(STheme.border)

            // Footer with Continue button
            HStack {
                Spacer()
                Button(action: {
                    handleContinueButtonTap()
                }) {
                    HStack(spacing: 6) {
                        if isVerifyingModel {
                            ProgressView().controlSize(.small)
                            Text("Checking model…")
                        } else {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                                .scaledFont(size: 12, weight: .semibold)
                        }
                    }
                    .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canContinue || viewModel.isDownloading || isVerifyingModel)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(STheme.windowBg)
        .alert("Model Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    /// Same row Settings → Dictation → Permissions uses: green check when granted,
    /// a Grant button when not.
    private func onboardingPermissionRow(granted: Bool,
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

    private func handleContinueButtonTap() {
        // Prove the chosen model actually loads before finishing setup. Onboarding only
        // checks that a model file EXISTS; a truncated download or unloadable model would
        // otherwise pass here and turn every first dictation into "Transcription failed"
        // (the shared-DMG new-user bug of 2026-08-11). On success the engine is now warm,
        // so this also replaces the post-onboarding lazy load.
        isVerifyingModel = true
        Task { @MainActor in
            // Re-commit the visible selection to AppPreferences before verifying, so the
            // engine we load is always the one the checkmark points at — regardless of how
            // selectedModelId was set (tap, download completion, or auto-select).
            if let selected = viewModel.unifiedModels.first(where: { $0.id == viewModel.selectedModelId }) {
                viewModel.selectModel(selected)
            }
            let failure = await TranscriptionService.shared.verifyEngineLoads()
            isVerifyingModel = false
            if let failure {
                errorMessage = "The selected model didn't load: \(failure)\n\nTry re-downloading it, or pick a different model."
                showError = true
            } else {
                appState.hasCompletedOnboarding = true
            }
        }
    }
}

struct OnboardingUnifiedModelItemView: View {
    @Binding var model: OnboardingUnifiedModel
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showError = false
    @State private var errorMessage = ""
    
    var isSelected: Bool {
        viewModel.selectedModelId == model.id
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // No downloaded-arrow icon here: on first run it read as a badge or
                    // button. The row's trailing state (Select / checkmark / Download)
                    // already says whether the model is on this Mac.
                    if model.isRecommended {
                        STag("Recommended")
                    }
                }
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if viewModel.isDownloading && viewModel.downloadingModelName == model.name {
                    // Determinate bar for every engine. Parakeet used to show a bare
                    // spinner here (its download API looked progress-less), which read
                    // as "stuck" during the multi-minute fetch + CoreML compile.
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
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .imageScale(.large)
                } else {
                    Button(action: {
                        viewModel.selectModel(model)
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
        // Inset surface inside the white section cell, same as Settings' model rows:
        // the selected model gets the soft accent tint so the choice reads at a glance.
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? STheme.accentSoft : STheme.windowBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isSelected ? STheme.accent.opacity(0.4) : STheme.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if model.isDownloaded && !isSelected {
                viewModel.selectModel(model)
            }
        }
        .alert("Download Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

struct OnboardingShortcutCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(STheme.textBright)

                Text(subtitle)
                    .scaledFont(size: 11)
                    .foregroundColor(STheme.hint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            // Same selected/idle surfaces as the model rows (copper tint, hairline).
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? STheme.accentSoft : STheme.windowBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? STheme.accent.opacity(0.4) : STheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
}


/// Optional AI-cleanup offer, right under the required model pick. A choice,
/// never a default: dictation works without it, and the ~1 GB download only
/// starts on an explicit click (the app's only sanctioned network calls are
/// updates and user-initiated model downloads).
struct OnboardingCleanupOffer: View {
    @State private var downloaded = LLMModelManager.shared.isDefaultModelDownloaded()
    @State private var progress: Double?
    @State private var error: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .scaledFont(size: 16)
                .foregroundColor(STheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Punctuation & cleanup — recommended")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(STheme.textBright)
                Text(downloaded
                     ? "On: dictations come out tidy — punctuation, casing, numbers as digits. Runs on this Mac."
                     : "Tidies punctuation, casing, and numbers with an on-device model (~1 GB, one-time download). Your words never leave this Mac.")
                    .scaledFont(size: 11)
                    .foregroundColor(STheme.hint)
                    .fixedSize(horizontal: false, vertical: true)
                if let error {
                    Text(error).scaledFont(size: 11).foregroundColor(.red)
                }
            }
            Spacer()
            if downloaded {
                // Explicit state, not a bare checkmark — users tried to click the
                // check expecting something to happen.
                Label("On", systemImage: "checkmark.circle.fill")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(STheme.ok)
            } else if let progress {
                ProgressView(value: progress)
                    .frame(width: 90)
            } else {
                Button("Download") {
                    error = nil
                    progress = 0
                    Task { @MainActor in
                        do {
                            try await LLMModelManager.shared.downloadDefaultModel { p in
                                Task { @MainActor in progress = p }
                            }
                            AppPreferences.shared.aiPostProcessingEnabled = true
                            downloaded = true
                            BuiltInLlamaBackend.shared.preload()
                        } catch {
                            self.error = error.localizedDescription
                        }
                        progress = nil
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(STheme.windowBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(STheme.border, lineWidth: 1)
        )
    }
}
