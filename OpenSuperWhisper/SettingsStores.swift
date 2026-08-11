import Foundation
import Combine

/// Single source of truth **and** single mutation point for the dictation language.
///
/// Both the menu-bar Language picker and the Settings language picker change it — route both
/// through `select(_:)` so they can't drift (the same multi-writer problem `ModelSelectionStore`
/// solves for the active model). Persistence lives in `AppPreferences`; this is the observable
/// façade over it. Changes post `.appPreferencesLanguageChanged`, which the menu and an open
/// Settings window observe.
///
/// `select` is idempotent — a no-op (no write, no post) when the value is unchanged — so the
/// menu↔Settings sync observers can't ping-pong.
@MainActor
final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()

    @Published private(set) var language: String

    private var observer: NSObjectProtocol?

    private init() {
        language = AppPreferences.shared.whisperLanguage
        // Stay current if the language changes anywhere (defensive — all writers go through select).
        observer = NotificationCenter.default.addObserver(
            forName: .appPreferencesLanguageChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.language = AppPreferences.shared.whisperLanguage }
        }
    }

    func select(_ code: String) {
        guard code != AppPreferences.shared.whisperLanguage else { return }
        AppPreferences.shared.whisperLanguage = code
        language = code
        NotificationCenter.default.post(name: .appPreferencesLanguageChanged, object: nil)
    }
}
