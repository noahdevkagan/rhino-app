import AppKit
import ApplicationServices
import Foundation

/// Best-effort capture of "where" a dictation happened, beyond the app name:
/// the focused window's title (Accessibility). Browser-URL capture was cut in
/// the 80/20 simplification — it needed AppleScript automation permission per
/// browser and only served the removed per-site rules.
enum SourceCapture {
    /// Title of the system-wide focused window (e.g. a browser tab or document).
    static func focusedWindowTitle() -> String? {
        // These AX calls are synchronous IPC to the frontmost app and run on the
        // main thread at record-start / menu-open; a wedged target would freeze the
        // recording hotkey without a timeout (#freeze). Bound every request, exactly
        // as FocusUtils does.
        let system = AXUIElementCreateSystemWide()
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
