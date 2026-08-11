import SwiftUI

/// The "Updates" settings tab: shows the current version. Updates go
/// exclusively through Sparkle against Rhino's own appcast — which doesn't
/// exist yet, so checking is disabled entirely rather than pointed at the
/// upstream project's feed (which would offer to replace this build with
/// stock OpenSuperWhisper).
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
                 hint: "Update checks are disabled in this build. Releases will ship with signed in-app updates over our own feed — the app's only update mechanism.") {
                EmptyView()
            }
        }
    }
}
