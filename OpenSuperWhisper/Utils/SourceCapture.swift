import AppKit
import ApplicationServices
import Foundation

/// Best-effort capture of "where" a dictation happened, beyond the app name:
/// the focused window's title (Accessibility). Browser-URL capture was cut in
/// the 80/20 simplification — it needed AppleScript automation permission per
/// browser and only served the removed per-site rules.
enum SourceCapture {
    /// Title of the target app's focused window (e.g. a browser tab or document).
    /// Without a PID, uses the system-wide focus. Call off-main for recording metadata.
    static func focusedWindowTitle(processID: pid_t? = nil) -> String? {
        // Bound synchronous IPC even on a worker so a wedged app cannot leave
        // metadata requests waiting indefinitely.
        let system = processID.map { AXUIElementCreateApplication($0) }
            ?? AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, FocusUtils.axMessagingTimeout)
        var windowRef: AnyObject?
        guard AXUIElementCopyAttributeValue(
            system, kAXFocusedWindowAttribute as CFString, &windowRef
        ) == .success, let windowRef else { return nil }

        let window = windowRef as! AXUIElement
        AXUIElementSetMessagingTimeout(window, FocusUtils.axMessagingTimeout)
        var titleRef: AnyObject?
        guard AXUIElementCopyAttributeValue(
            window, kAXTitleAttribute as CFString, &titleRef
        ) == .success else { return nil }

        let title = titleRef as? String
        return (title?.isEmpty == false) ? title : nil
    }

    /// Bare host of a stored source URL, for the history row's "· site" suffix. New rows no
    /// longer capture URLs, but rows written by older versions still render theirs.
    static func host(of urlString: String?) -> String? {
        guard let urlString,
              let host = URLComponents(string: urlString)?.host,
              !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
