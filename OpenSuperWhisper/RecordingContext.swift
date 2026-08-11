import AppKit
import Foundation

/// The app the user is currently targeting — refreshed at record-start — so the
/// history row can say where a dictation happened. Runtime-only, never persisted
/// by itself. (The per-app rules feature this once powered was cut in the 80/20
/// simplification; this is the surviving 20%: context for history.)
final class RecordingContext {
    static let shared = RecordingContext()
    private(set) var appName: String?
    private(set) var bundleID: String?
    /// Focused window title at capture time (for transcript metadata).
    private(set) var windowTitle: String?
    /// Browser-tab URL capture was cut with the Rules feature (it needed an
    /// Apple Events permission). Kept as always-nil so history rows written by
    /// older versions still render their stored URLs.
    var fullURL: String? { nil }
    private init() {}

    /// Capture the current frontmost app as the active context. Opening a
    /// status-bar menu doesn't steal focus, so this is the app the cursor is
    /// in. If our own app is frontmost, keep the previous context.
    func captureFrontmost() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              let bundle = front.bundleIdentifier,
              bundle != Bundle.main.bundleIdentifier
        else { return }
        appName = front.localizedName
        bundleID = bundle
        windowTitle = SourceCapture.focusedWindowTitle()
    }
}
