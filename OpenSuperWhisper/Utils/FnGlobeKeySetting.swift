import Foundation

/// The system-wide "Press 🌐 key to" behavior (System Settings → Keyboard),
/// stored as `AppleFnUsageType` in com.apple.HIToolbox.
///
/// Rhino watches Fn with a listen-only tap, which cannot consume the event —
/// macOS acts on the same press. On a factory-default Mac (value unset) a lone
/// Fn press shows the emoji palette, so every Fn dictation would also pop it.
enum FnGlobeKeySetting {
    private static let domain = "com.apple.HIToolbox" as CFString
    private static let key = "AppleFnUsageType" as CFString

    /// Raw values macOS uses for "Press 🌐 key to".
    enum Action: Int {
        case doNothing = 0
        case changeInputSource = 1
        case showEmoji = 2
        case startDictation = 3
    }

    static var current: Action {
        let raw = CFPreferencesCopyValue(key, domain,
                                         kCFPreferencesCurrentUser,
                                         kCFPreferencesAnyHost) as? Int
        // Unset = factory default = the emoji palette.
        return Action(rawValue: raw ?? Action.showEmoji.rawValue) ?? .showEmoji
    }

    /// True when a lone Fn press triggers a system action alongside Rhino's trigger.
    static var conflictsWithFnTrigger: Bool {
        current != .doNothing
    }

    /// Sets "Press 🌐 key to" → "Do Nothing". Mutates a system preference, so it is
    /// only ever called from an explicit user click. Emoji stays reachable via ⌃⌘Space.
    static func setDoNothing() {
        CFPreferencesSetValue(key, Action.doNothing.rawValue as CFNumber, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
}
