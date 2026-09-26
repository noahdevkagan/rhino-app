import SwiftUI

/// The "Updates" settings tab: current version + the release notes that shipped
/// in this build (CHANGELOG.md is bundled at build time, so the app and its
/// notes can't drift apart), plus the auto-install switch.
struct UpdatesView: View {
    /// The running app's marketing version, straight from the bundle.
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    /// Version → bullet lines, parsed from the bundled changelog, newest first.
    /// "Unreleased" and empty sections are skipped.
    static func releaseNotes() -> [(version: String, bullets: [String])] {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var sections: [(String, [String])] = []
        var current: (String, [String])? = nil
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.hasPrefix("## ") {
                if let done = current, !done.1.isEmpty { sections.append(done) }
                let title = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                current = title.lowercased().hasPrefix("unreleased") ? nil : (title, [])
            } else if current != nil, line.hasPrefix("- ") {
                current!.1.append(String(line.dropFirst(2)))
            } else if current != nil, line.hasPrefix("  "), !current!.1.isEmpty {
                // wrapped continuation of the previous bullet
                current!.1[current!.1.count - 1] += " " + line.trimmingCharacters(in: .whitespaces)
            }
        }
        if let done = current, !done.1.isEmpty { sections.append(done) }
        return sections.map { (version: $0.0, bullets: $0.1) }
    }

    private let notes = Self.releaseNotes()
    @State private var autoInstall = SparkleUpdater.shared.automaticallyInstallsUpdates

    var body: some View {
        SPane(title: "Updates") {
            SRow(title: "Version \(Self.currentVersion)",
                 hint: "Updates install in place over Rhino's own signed feed, then the app relaunches.") {
                Button("Check for Updates") { SparkleUpdater.shared.checkForUpdates() }
                    .controlSize(.small)
            }

            SRow(title: "Install updates automatically",
                 hint: "Downloads in the background and installs while you're away, never mid-dictation. Off: you'll see a red dot on the menu bar icon instead.") {
                SToggle(isOn: $autoInstall)
                    .onChange(of: autoInstall) { _, on in
                        SparkleUpdater.shared.automaticallyInstallsUpdates = on
                    }
            }

            ForEach(notes, id: \.version) { section in
                SSection(title: "What's new in \(section.version)") {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(section.bullets, id: \.self) { bullet in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•").scaledFont(size: 12).foregroundColor(STheme.accent)
                                Text(bullet)
                                    .scaledFont(size: 12)
                                    .foregroundColor(STheme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
