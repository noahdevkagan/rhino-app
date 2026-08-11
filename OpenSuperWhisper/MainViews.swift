import KeyboardShortcuts
import SwiftUI

// The main window's sidebar navigation (mockup: Typeless-style — white-first,
// generous whitespace, typography-led). Three destinations; Settings stays a
// separate window reached from the sidebar footer.

enum MainTab: String, CaseIterable, Identifiable {
    case home, history, dictionary
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .history: return "History"
        case .dictionary: return "Dictionary"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock.arrow.circlepath"
        case .dictionary: return "character.book.closed"
        }
    }
}

struct MainSidebar: View {
    @Binding var selection: MainTab
    let openSettings: () -> Void
    @Environment(\.colorScheme) private var colorScheme

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

struct HomeStatsView: View {
    @StateObject private var stats = DictationStats()
    @Environment(\.colorScheme) private var colorScheme

    private var shortcutDescription: String {
        let modifier = ModifierKey(rawValue: AppPreferences.shared.modifierOnlyHotkey) ?? .none
        if modifier != .none { return modifier.shortSymbol }
        return KeyboardShortcuts.getShortcut(for: .toggleRecord)?.description ?? "—"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speak, don't type")
                        .scaledFont(size: 34, weight: .bold)
                    HStack(spacing: 6) {
                        Image(systemName: "lock")
                            .imageScale(.small)
                        Text("Everything stays on this Mac.")
                    }
                    .scaledFont(size: 12.5)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 26)

                let time = DictationStats.format(seconds: stats.totalSeconds)
                let saved = DictationStats.format(seconds: stats.secondsSaved)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                          spacing: 14) {
                    statTile(icon: "clock", big: time.0, small: time.1, label: "Total dictation time")
                    statTile(icon: "mic", big: compact(stats.totalWords), small: "words",
                             label: "Words dictated")
                    statTile(icon: "hourglass", big: saved.0, small: saved.1, label: "Time saved vs typing")
                    statTile(icon: "bolt", big: stats.averageWPM > 0 ? "\(stats.averageWPM)" : "—",
                             small: "WPM", label: "Average dictation speed")
                }

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
                }
                .padding(.top, 2)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemePalette.windowBackground(colorScheme))
        .onAppear { stats.reload() }
        .onReceive(NotificationCenter.default.publisher(
            for: RecordingStore.recordingsDidUpdateNotification)) { _ in stats.reload() }
    }

    private func compact(_ n: Int) -> String {
        n >= 10_000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)"
    }

    private func statTile(icon: String, big: String, small: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: icon)
                    .imageScale(.medium)
                    .foregroundColor(.secondary)
                Text(big)
                    .scaledFont(size: 26, weight: .bold)
                Text(small)
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundColor(.secondary)
            }
            Text(label)
                .scaledFont(size: 12)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ThemePalette.panelSurface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ThemePalette.panelBorder(colorScheme), lineWidth: 1)
        )
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

/// Slim banner shown at the top of the main window while mic/accessibility
/// are missing. Replaces the old full-window "Required Permissions" wall.
struct PermissionsBanner: View {
    @ObservedObject var permissionsManager: PermissionsManager

    private var message: String {
        let mic = permissionsManager.isMicrophonePermissionGranted
        let ax = permissionsManager.isAccessibilityPermissionGranted
        switch (mic, ax) {
        case (false, false): return "Rhino needs Microphone (to hear you) and Accessibility (to type for you)."
        case (false, true): return "Rhino needs Microphone access to hear you."
        default: return "Rhino needs Accessibility access to type into other apps."
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .scaledFont(size: 12, weight: .medium)
            Spacer()
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
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

// MARK: - History header (keep-history control, mockup-style)

struct HistoryKeepBar: View {
    @State private var keep = AppPreferences.shared.saveTranscriptionHistory
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "internaldrive")
                .imageScale(.small)
                .foregroundColor(.secondary)
            Text("Keep history on this Mac")
                .scaledFont(size: 12, weight: .medium)
            Text("— never leaves your device")
                .scaledFont(size: 12)
                .foregroundColor(.secondary)
            Spacer()
            Toggle("", isOn: $keep)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .onChange(of: keep) { _, on in
                    AppPreferences.shared.saveTranscriptionHistory = on
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ThemePalette.panelSurface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ThemePalette.panelBorder(colorScheme), lineWidth: 1)
        )
        .padding([.horizontal, .top])
    }
}
