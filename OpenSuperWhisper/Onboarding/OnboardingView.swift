//
//  OnboardingView.swift
//  Rhino
//
//  Created by user on 08.02.2025.
//

import Foundation
import SwiftUI
import FluidAudio

enum OnboardingShortcutOption: String, CaseIterable {
    case fn
    // Right ⌘, not Right ⌥: on European layouts Right Option is AltGr (€ @ #),
    // so offering it as the alternative broke typing for international users.
    // Right Command has no meaning as a lone press on any layout.
    case rightCommand

    var modifierKey: ModifierKey {
        switch self {
        case .fn: return .fn
        case .rightCommand: return .rightCommand
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
        self.selectedShortcut = armed.modifiers.contains(.rightCommand) ? .rightCommand : .fn

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

/// The three setup steps, shown one at a time. User feedback on the old
/// single-screen layout: it "looked like a settings screen … I wasn't sure
/// that I was supposed to action on it" — numbered steps that advance on
/// completion make the required actions unmissable.
enum OnboardingStep: Int, CaseIterable, Comparable {
    case permissions = 0, dictateKey, speechModel
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .permissions: return "Permissions"
        case .dictateKey: return "Dictate key"
        case .speechModel: return "Speech model"
        }
    }
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var permissionsManager = PermissionsManager()
    @EnvironmentObject private var appState: AppState
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isVerifyingModel = false
    @State private var fnGlobeConflict = FnGlobeKeySetting.conflictsWithFnTrigger

    @State private var step: OnboardingStep = .permissions
    /// Slide direction for the step transition (forward = new step enters from the right).
    @State private var movingForward = true

    /// Setup reads as a centered column, not full-bleed rows: at the window's real
    /// widths (780–900+) full-width cards push each row's trailing control (Grant…,
    /// Download) far from the text it belongs to.
    private let contentWidth: CGFloat = 620

    private var permissionsComplete: Bool {
        permissionsManager.isMicrophonePermissionGranted
            && permissionsManager.isAccessibilityPermissionGranted
    }

    var body: some View {
        // Same visual system as Settings (Atelier / grouped cells): STheme window
        // background, gray section labels above white cards. The old gradient-header
        // look predated the light-only restyle and read as a different app.
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                VStack(spacing: 3) {
                    Text("Welcome to Rhino")
                        .scaledFont(size: 19, weight: .bold)
                        .foregroundColor(STheme.textBright)
                    Text("Dictate anywhere on your Mac — everything stays on it")
                        .scaledFont(size: 11)
                        .foregroundColor(STheme.hint)
                }
                OnboardingStepIndicator(current: step) { go(to: $0) }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 14)

            ScrollView {
                Group {
                    switch step {
                    case .permissions: permissionsStep
                    case .dictateKey: dictateKeyStep
                    case .speechModel: speechModelStep
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)))
                .frame(maxWidth: contentWidth, alignment: .leading)
                .padding(.horizontal, 24).padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }

            Divider().overlay(STheme.border)

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(STheme.windowBg)
        .alert("Model Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Both permissions already granted (reinstall, or the seeded prefs of a
            // shared Mac): don't replay a completed step.
            if permissionsComplete { step = .dictateKey }
        }
        .onChange(of: permissionsComplete) { done in
            // Auto-advance the moment both rows turn green (the tester's ask). The
            // pause lets the second checkmark land before the slide — an instant
            // jump reads as a glitch, not a completion.
            guard done, step == .permissions else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if step == .permissions && permissionsComplete { advance() }
            }
        }
    }

    // MARK: Steps

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeading("First, two permissions",
                        "Rhino needs to hear you and type for you. Once both are granted, setup moves on by itself.")
            stepCard {
                // Accessibility second: it needs Rhino to register itself in System
                // Settings before the user can even find it there. Rows mirror
                // Settings → Dictation → Permissions so the surfaces read as one app.
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
        }
    }

    private var dictateKeyStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeading("Choose your dictate key",
                        "Hold it down to talk, release to insert the text.")
            stepCard {
                HStack(spacing: 8) {
                    OnboardingShortcutCard(
                        title: "fn",
                        subtitle: "Hold fn (default)",
                        isSelected: viewModel.selectedShortcut == .fn
                    ) {
                        viewModel.selectedShortcut = .fn
                        advanceAfterKeyPick()
                    }

                    OnboardingShortcutCard(
                        title: "Right ⌘",
                        subtitle: "Hold Right Command",
                        isSelected: viewModel.selectedShortcut == .rightCommand
                    ) {
                        viewModel.selectedShortcut = .rightCommand
                        advanceAfterKeyPick()
                    }
                }

                // One sentence, one line (Noah). The emoji clause appears only when
                // Continue will actually rewrite the Mac's Fn behavior — macOS acts
                // on a lone Fn press by factory default and Rhino's listen-only tap
                // can't consume it, so setup fixes the setting automatically.
                // Settings → Dictation carries the full explanation.
                Text(viewModel.selectedShortcut == .fn && fnGlobeConflict
                     ? "Emoji stays available with ⌃⌘Space, and you can pick any key or combination later in Settings."
                     : "You can pick any key or combination later in Settings.")
                    .scaledFont(size: 11)
                    .foregroundColor(STheme.hint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var speechModelStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                stepHeading("Pick a speech model",
                            "This is what turns your voice into text, right on this Mac. You can switch anytime.")
                stepCard {
                    // Language lives with the model (it tells the engine what to
                    // listen for), not in the window header like the old layout.
                    SRow(title: "Language", hint: "The language you'll dictate in") {
                        Picker("Language", selection: $viewModel.selectedLanguage) {
                            ForEach(LanguageUtil.availableLanguages, id: \.self) { code in
                                Text(LanguageUtil.languageNames[code] ?? code)
                                    .tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    ForEach($viewModel.unifiedModels) { $model in
                        OnboardingUnifiedModelItemView(model: $model, viewModel: viewModel)
                    }
                }
            }

            // Separate section, not another model row: the cleanup pass is an
            // optional add-on, and in one card the rows read as peers (user feedback).
            SSection(title: "Optional add-on") {
                OnboardingCleanupOffer()
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if step > .permissions {
                Button("Back") {
                    go(to: OnboardingStep(rawValue: step.rawValue - 1) ?? .permissions)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.isDownloading || isVerifyingModel)
            }

            Spacer()

            switch step {
            case .permissions:
                // Quiet escape for Macs where Accessibility can't be granted right
                // now (managed devices) — the old screen never blocked on permissions.
                if !permissionsComplete {
                    Button("Set up later") { advance() }
                        .buttonStyle(.plain)
                        .scaledFont(size: 12)
                        .foregroundColor(STheme.hint)
                }
                nextButton(enabled: permissionsComplete)
            case .dictateKey:
                nextButton(enabled: true)
            case .speechModel:
                Button(action: {
                    handleContinueButtonTap()
                }) {
                    HStack(spacing: 6) {
                        if isVerifyingModel {
                            ProgressView().controlSize(.small)
                            Text("Checking model…")
                        } else {
                            Text("Finish")
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
        }
        .frame(maxWidth: contentWidth)
        .padding(16)
    }

    private func nextButton(enabled: Bool) -> some View {
        Button(action: { advance() }) {
            HStack(spacing: 6) {
                Text("Next")
                Image(systemName: "arrow.right")
                    .scaledFont(size: 12, weight: .semibold)
            }
            .frame(minWidth: 100)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!enabled)
    }

    // MARK: Step plumbing

    private func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        movingForward = true
        withAnimation(.easeInOut(duration: 0.28)) { step = next }
    }

    private func go(to target: OnboardingStep) {
        guard target != step else { return }
        movingForward = target > step
        withAnimation(.easeInOut(duration: 0.28)) { step = target }
    }

    /// Picking a key IS completing the step — pause just long enough for the
    /// selection tint to land, then slide on.
    private func advanceAfterKeyPick() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if step == .dictateKey { advance() }
        }
    }

    private func stepHeading(_ title: LocalizedStringKey, _ sub: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .scaledFont(size: 15, weight: .semibold)
                .foregroundColor(STheme.textBright)
            Text(sub)
                .scaledFont(size: 12)
                .foregroundColor(STheme.hint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// SSection's white cell without the gray header — the step indicator
    /// already names the step, a second label would echo it.
    private func stepCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(STheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(STheme.border, lineWidth: 1)
            )
    }

    /// Same row layout as Settings → Dictation → Permissions. The button is a
    /// prominent "Enable" here (Settings uses a quiet "Grant…"): on a setup screen
    /// these are the required next actions, not a repair tool.
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
                Button(action: grant) {
                    Text("Enable")
                        .frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
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
                // Committing to Fn as the dictate key: stop macOS from also opening
                // the emoji palette on it (disclosed in the Dictate key section).
                if viewModel.selectedShortcut == .fn && FnGlobeKeySetting.conflictsWithFnTrigger {
                    FnGlobeKeySetting.setDoNothing()
                }
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

/// Numbered 1·2·3 progress rail. Current step: filled copper circle; done:
/// soft copper with a checkmark (clickable to go back); upcoming: hairline
/// outline. The numbers are the point — they say "this is a sequence you
/// act through", which the old settings-like layout never did.
struct OnboardingStepIndicator: View {
    let current: OnboardingStep
    let onSelect: (OnboardingStep) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                if s != .permissions {
                    Rectangle()
                        .fill(s <= current ? STheme.accent.opacity(0.45) : STheme.border)
                        .frame(width: 28, height: 1)
                }
                stepPill(s)
            }
        }
    }

    private func stepPill(_ s: OnboardingStep) -> some View {
        let done = s < current
        let active = s == current
        return Button(action: { onSelect(s) }) {
            HStack(spacing: 7) {
                ZStack {
                    Circle().fill(active ? STheme.accent : (done ? STheme.accentSoft : Color.clear))
                    if done {
                        Image(systemName: "checkmark")
                            .scaledFont(size: 10, weight: .bold)
                            .foregroundColor(STheme.accent)
                    } else {
                        Text(verbatim: "\(s.rawValue + 1)")
                            .scaledFont(size: 11, weight: .semibold)
                            .foregroundColor(active ? .white : STheme.hint)
                    }
                }
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(active || done ? Color.clear : STheme.controlBorder, lineWidth: 1)
                )

                Text(s.label)
                    .scaledFont(size: 12, weight: active ? .semibold : .regular)
                    .foregroundColor(active ? STheme.textBright : (done ? STheme.text : STheme.hint))
            }
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Only completed steps navigate — jumping ahead would skip required actions.
        .disabled(!done)
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
                HStack(spacing: 8) {
                    Text("Punctuation & cleanup")
                        .scaledFont(size: 13, weight: .semibold)
                        .foregroundColor(STheme.textBright)
                    STag("Recommended")
                }
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
