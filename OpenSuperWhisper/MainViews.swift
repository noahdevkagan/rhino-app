import SwiftUI

// The main window's sidebar navigation (mockup: Typeless-style — white-first,
// generous whitespace, typography-led). Three destinations; Settings stays a
// separate window reached from the sidebar footer.

enum MainTab: String, CaseIterable, Identifiable {
    // History lives inside Home now (Willow-style: stats strip on top, history
    // below) — Paul S.: "you can merge the home tab with history to simplify".
    case home, dictionary
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .dictionary: return "Dictionary"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .dictionary: return "character.book.closed"
        }
    }
}

struct MainSidebar: View {
    @Binding var selection: MainTab
    let openSettings: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var transcriptionService = TranscriptionService.shared

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rhino")
                .scaledFont(size: 19, weight: .bold)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 14)

            ForEach(MainTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: tab.icon)
                            .frame(width: 18)
                        Text(tab.title)
                            .scaledFont(size: 13, weight: .medium)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .foregroundColor(selection == tab ? .primary : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection == tab ? Color.primary.opacity(0.06) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Quiet warm-up pill: the engine preloads at launch so the first
            // dictation is instant; this is the only place that says so.
            if transcriptionService.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Warming up…")
                        .scaledFont(size: 11)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            HStack {
                Button(action: openSettings) {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
                Spacer()
                Text("v\(version)")
                    .scaledFont(size: 10.5, design: .monospaced)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 6)
        .frame(width: 168)
        .background(ThemePalette.panelSurface(colorScheme).opacity(0.5))
    }
}

// MARK: - Home (stats)

/// Lifetime dictation stats computed from the local history DB. All of this
/// exists BECAUSE everything stores to this Mac — the stats page is the
/// visible payoff of local history.
@MainActor
final class DictationStats: ObservableObject {
    @Published var totalSeconds: Double = 0
    @Published var totalWords: Int = 0
    @Published var dictations: Int = 0

    /// Words-per-minute while actually speaking (words / recorded time).
    var averageWPM: Int {
        totalSeconds > 5 ? Int((Double(totalWords) / (totalSeconds / 60)).rounded()) : 0
    }

    /// Typing the same words at 40 WPM, minus the time spent dictating.
    var secondsSaved: Double {
        max(0, Double(totalWords) / 40.0 * 60.0 - totalSeconds)
    }

    func reload() {
        Task {
            // History is capped by retention settings; 20k rows ≈ years of use.
            let rows = (try? await RecordingStore.shared.fetchRecordings(limit: 20000, offset: 0)) ?? []
            let done = rows.filter { $0.status == .completed }
            totalSeconds = done.reduce(0) { $0 + max($1.duration, 0) }
            totalWords = done.reduce(0) { $0 + $1.transcription.split(whereSeparator: \.isWhitespace).count }
            dictations = done.count
        }
    }

    static func format(seconds: Double) -> (String, String) {
        let total = Int(seconds)
        if total >= 3600 { return ("\(total / 3600)", "hr \((total % 3600) / 60) min") }
        if total >= 60 { return ("\(total / 60)", "min") }
        return ("\(total)", "sec")
    }
}

/// The fixed header of the merged Home tab: title, stats strip, and the
/// shortcut + active-model row. The history list scrolls below it (ContentView).
struct HomeHeaderView: View {
    @StateObject private var stats = DictationStats()
    @Environment(\.colorScheme) private var colorScheme
    @State private var modelMissing = false
    @State private var shortcutDescription = "—"
    @State private var modelInfo: (name: String, description: String)? = Self.activeModelInfo()

    /// Name + one-line description of the model that will transcribe the next
    /// dictation. Shown on Home so quality tradeoffs are attributable to the model
    /// choice ("I picked the fast model") instead of reading as the app being bad.
    private static func activeModelInfo() -> (name: String, description: String)? {
        guard let option = ModelCatalog.activeOption() else { return nil }
        switch option.engine {
        case "fluidaudio":
            let match = SettingsFluidAudioModels.availableModels
                .first { $0.version == option.identifier }
            return (match?.name ?? "Parakeet \(option.identifier)",
                    match?.description ?? "Fast, on-device")
        default:
            let filename = URL(fileURLWithPath: option.identifier).lastPathComponent
            let match = SettingsDownloadableModels.availableModels
                .first { $0.filename == filename }
            return (match?.name ?? option.displayName,
                    match?.description ?? "Whisper, on-device")
        }
    }

    /// True when the first dictation would fail before it starts: the active engine is
    /// Whisper and no model file is on disk (never picked one, or the pref points at a
    /// file that's gone — migrated installs and pre-0.1.0 test builds land here). The
    /// onboarding gate can't catch these, so Home says it instead of the first
    /// dictation failing. Parakeet fetches its model on first use, so it never trips.
    private static func isModelMissing() -> Bool {
        let prefs = AppPreferences.shared
        guard prefs.selectedEngine == "whisper" else { return false }
        guard let path = prefs.selectedWhisperModelPath ?? prefs.selectedModelPath,
              FileManager.default.fileExists(atPath: path) else {
            // Any downloaded model on disk still counts — the engine can't use it until
            // it's selected, so the banner stays until the user picks one in Settings.
            return true
        }
        return false
    }

    private func reloadShortcutDescription() {
        shortcutDescription = RecordingTriggerSet
            .load(from: AppPreferences.shared.recordingTriggers)
            .primaryDescription
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Speak, don't type")
                    .scaledFont(size: 26, weight: .bold)
                HStack(spacing: 6) {
                    Image(systemName: "lock")
                        .imageScale(.small)
                    Text("Everything stays on this Mac.")
                }
                .scaledFont(size: 12.5)
                .foregroundColor(.secondary)
            }
            .padding(.top, 22)

            if modelMissing {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No speech model installed")
                            .scaledFont(size: 13, weight: .semibold)
                        Text("Dictation won't work until a model is downloaded to this Mac.")
                            .scaledFont(size: 12)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Get a model") {
                        NotificationCenter.default.post(name: .openSettingsModelsTab, object: nil)
                    }
                    .controlSize(.regular)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.35), lineWidth: 1))
            }

            // One-row stats strip (Willow-style) — label above, value below.
            let time = DictationStats.format(seconds: stats.totalSeconds)
            let saved = DictationStats.format(seconds: stats.secondsSaved)
            HStack(alignment: .top, spacing: 0) {
                statColumn(label: "Dictated words", big: compact(stats.totalWords), small: "words")
                statColumn(label: "Time saved", big: saved.0, small: saved.1)
                statColumn(label: "Dictation time", big: time.0, small: time.1)
                statColumn(label: "Average speed",
                           big: stats.averageWPM > 0 ? "\(stats.averageWPM)" : "—", small: "wpm")
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ThemePalette.panelSurface(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ThemePalette.panelBorder(colorScheme), lineWidth: 1)
            )

            HStack(spacing: 10) {
                Text("Dictate")
                    .scaledFont(size: 12.5)
                    .foregroundColor(.secondary)
                Text(shortcutDescription)
                    .scaledFont(size: 12.5, weight: .semibold, design: .monospaced)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ThemePalette.panelSurface(colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ThemePalette.panelBorder(colorScheme), lineWidth: 1)
                    )
                Text("anywhere, in any app")
                    .scaledFont(size: 12.5)
                    .foregroundColor(.secondary)
                Spacer()

                // The active model, always visible — so "transcription felt off" can be
                // traced to "ah, I picked the fast model" without opening Settings.
                if let modelInfo {
                    Button {
                        NotificationCenter.default.post(name: .openSettingsModelsTab, object: nil)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .imageScale(.small)
                                .foregroundColor(.secondary)
                            Text(modelInfo.name)
                                .scaledFont(size: 12, weight: .semibold)
                            Text(modelInfo.description)
                                .scaledFont(size: 12)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .scaledFont(size: 9, weight: .semibold)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(ThemePalette.panelSurface(colorScheme)))
                        .overlay(Capsule().stroke(ThemePalette.panelBorder(colorScheme), lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Change the dictation model")
                }
            }
        }
        .padding(.horizontal, 24)
        .onAppear {
            stats.reload()
            modelMissing = Self.isModelMissing()
            reloadShortcutDescription()
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotkeySettingsChanged)) { _ in
            reloadShortcutDescription()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: RecordingStore.recordingsDidUpdateNotification)) { _ in stats.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .modelSelectionDidChange)) { _ in
            modelMissing = Self.isModelMissing()
            modelInfo = Self.activeModelInfo()
        }
        // Re-check when the main window comes back to front — the user typically fixes
        // this in Settings and returns here expecting the banner gone.
        .onReceive(NotificationCenter.default.publisher(
            for: NSWindow.didBecomeKeyNotification)) { _ in
            modelMissing = Self.isModelMissing()
            modelInfo = Self.activeModelInfo()
        }
    }

    private func compact(_ n: Int) -> String {
        n >= 10_000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)"
    }

    /// One column of the stats strip: small gray label above, value + unit below.
    private func statColumn(label: String, big: String, small: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .scaledFont(size: 11.5)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(big)
                    .scaledFont(size: 22, weight: .bold)
                Text(small)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
    }
}

// MARK: - Dictionary tab

struct DictionaryTabView: View {
    @State private var entries: [CustomDictionaryEntry] =
        CustomDictionary.merged(AppPreferences.shared.customDictionaryEntries)
    @State private var enabled = AppPreferences.shared.customDictionaryEnabled
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Dictionary")
                        .scaledFont(size: 34, weight: .bold)
                    Spacer()
                    Toggle("", isOn: $enabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: enabled) { _, on in
                            AppPreferences.shared.customDictionaryEnabled = on
                        }
                }
                .padding(.top, 26)

                Text("Your names and jargon, spelled right every time — fixed after transcription and boosted during it. Stored only on this Mac.")
                    .scaledFont(size: 12.5)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                DictionaryBadgeEditor(entries: $entries)
                    .onChange(of: entries) { _, new in
                        AppPreferences.shared.customDictionaryEntries = new
                    }
                    .opacity(enabled ? 1 : 0.4)
                    .disabled(!enabled)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemePalette.windowBackground(colorScheme))
        .onReceive(NotificationCenter.default.publisher(for: .customDictionaryDidChange)) { _ in
            // Another editor (Settings) changed the rules; refresh our copy.
            entries = CustomDictionary.merged(AppPreferences.shared.customDictionaryEntries)
        }
    }
}

extension Notification.Name {
    static let customDictionaryDidChange = Notification.Name("customDictionaryDidChange")
}

// MARK: - Permissions banner

/// Slim banner shown at the top of the main window while microphone or Accessibility is missing.
struct PermissionsBanner: View {
    @ObservedObject var permissionsManager: PermissionsManager

    private var message: String {
        let mic = permissionsManager.isMicrophonePermissionGranted
        let ax = permissionsManager.isAccessibilityPermissionGranted
        switch (mic, ax) {
        case (false, true):
            return "Rhino needs Microphone access to hear you."
        case (true, false):
            return "Rhino needs Accessibility so Fn works globally and text can be typed into other apps."
        default:
            return "Rhino needs Microphone and Accessibility permissions."
        }
    }

    /// Deep-link to the exact privacy pane instead of the Privacy & Security front
    /// page. Microphone goes first, then Accessibility for global Fn and text insertion.
    private var settingsPaneURL: String {
        if !permissionsManager.isMicrophonePermissionGranted {
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        }
        return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .scaledFont(size: 12, weight: .medium)
            Spacer()
            Button("Open System Settings") {
                if let url = URL(string: settingsPaneURL) {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }
}

// (HistoryKeepBar was retired when History merged into Home — the keep-history
// toggle lives in Settings → History & Privacy.)
