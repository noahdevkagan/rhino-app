import Foundation

extension Notification.Name {
    static let appPreferencesLanguageChanged = Notification.Name("AppPreferencesLanguageChanged")
    static let hotkeySettingsChanged = Notification.Name("HotkeySettingsChanged")
    /// Posted when Input Monitoring becomes available so the modifier event tap can be built
    /// without requiring Rhino itself to be relaunched.
    static let inputMonitoringPermissionChanged = Notification.Name("InputMonitoringPermissionChanged")
    static let indicatorWindowDidHide = Notification.Name("IndicatorWindowDidHide")
    static let openSettings = Notification.Name("OpenSettings")
    /// Posted when the active engine/model changes outside the Settings view (the
    /// menu-bar Model picker), so an open Settings window re-syncs from AppPreferences.
    static let modelSelectionDidChange = Notification.Name("ModelSelectionDidChange")
    /// Posted alongside .openSettings to land the window on the Models tab (Home's
    /// missing-model banner deep-links there).
    static let openSettingsModelsTab = Notification.Name("OpenSettingsModelsTab")
}
