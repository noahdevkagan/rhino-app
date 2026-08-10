import SwiftUI

/// The "Updates" settings tab: shows the current version and a manual update
/// check. Updates go exclusively through Sparkle (download + verify + relaunch
/// against our own appcast) — the app makes no other update-related network
/// calls, so there is no passive release feed here.
struct UpdatesView: View {
    /// The running app's marketing version, straight from the bundle.
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        SPane(title: "Updates") {
            versionSection
        }
    }

    private var versionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SRow(title: "Version \(Self.currentVersion)",
                 hint: "Checks our update feed, then installs in place and relaunches. This is the app's only update mechanism.") {
                Button("Check for Updates") { SparkleUpdater.shared.checkForUpdates() }
                    .controlSize(.small)
            }
        }
    }
}
