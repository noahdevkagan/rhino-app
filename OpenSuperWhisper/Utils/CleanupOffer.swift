import Foundation

/// When to offer the AI-cleanup model download. Cleanup is on by default, but its model
/// is ~1 GB and downloads only on a click, so setup never mentions it: the first minutes
/// stay about dictating. The offer appears on Home once it is likely to help — after a
/// handful of dictations, or straight away when someone dictates a list or an email,
/// which is exactly what cleanup formats.
enum CleanupOffer {
    static let dictationsBeforeOffer = 5

    /// Counts a finished dictation toward the offer. `text` is the transcript before
    /// cleanup, checked for the same layout cues that make cleanup run.
    static func noteDictation(_ text: String) {
        let prefs = AppPreferences.shared
        guard !prefs.cleanupOfferEarned else { return }
        prefs.cleanupOfferDictations += 1
        guard prefs.cleanupOfferDictations >= dictationsBeforeOffer
            || LLMPostProcessor.containsLayoutCue(text) else { return }
        prefs.cleanupOfferEarned = true
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cleanupOfferChanged, object: nil)
        }
    }

    /// Earned, not waved away, cleanup still on, and the model not on disk yet.
    static var shouldShow: Bool {
        let prefs = AppPreferences.shared
        return prefs.cleanupOfferEarned && !prefs.cleanupOfferDismissed
            && prefs.aiPostProcessingEnabled
            && !LLMModelManager.shared.isDefaultModelDownloaded()
    }
}
