import Foundation

extension Notification.Name {
    static let appPreferencesLanguageChanged = Notification.Name("AppPreferencesLanguageChanged")
    static let hotkeySettingsChanged = Notification.Name("HotkeySettingsChanged")
    /// Posted when Accessibility or Input Monitoring authorizes global event listening so the
    /// modifier event tap can be built without requiring Rhino itself to be relaunched.
    static let globalEventListeningPermissionChanged = Notification.Name("GlobalEventListeningPermissionChanged")
    static let indicatorWindowDidHide = Notification.Name("IndicatorWindowDidHide")
    static let openSettings = Notification.Name("OpenSettings")
    /// Bridges the AppKit-owned menu-bar item to SwiftUI's feedback Window scene.
    static let openFeedback = Notification.Name("OpenFeedback")
    /// Posted when the active engine/model changes outside the Settings view (the
    /// menu-bar Model picker), so an open Settings window re-syncs from AppPreferences.
    static let modelSelectionDidChange = Notification.Name("ModelSelectionDidChange")
    /// Posted alongside .openSettings to land the window on the Models tab (Home's
    /// missing-model banner deep-links there).
    static let openSettingsModelsTab = Notification.Name("OpenSettingsModelsTab")
    /// Deep-links the main window straight to the Dictionary tab (menu-bar item),
    /// skipping Open Window → sidebar navigation.
    static let openDictionary = Notification.Name("OpenDictionary")
    /// Posted when the "hide menu bar icon" preference flips, so the AppKit-owned
    /// status item is added/removed without a relaunch.
    static let menuBarIconVisibilityChanged = Notification.Name("MenuBarIconVisibilityChanged")
}
