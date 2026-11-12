import AppKit
import ApplicationServices
import Foundation

/// Watches the field a dictation just went into, and when the user retypes a word Rhino got
/// wrong (Apsumo → AppSumo), adds a dictionary rule for it with an Undo notice.
///
/// After a paste it reads the focused text field through Accessibility every `pollInterval`
/// for `watchDuration`, the way `FocusUtils.caretContext` already reads around the caret. The
/// field text is compared in memory and never stored or sent anywhere; only a learned rule is
/// kept, in the user's dictionary. It stops at the first of: the time is up, focus leaves the
/// field, a rule was learned, or the next dictation starts watching instead. Fields that don't
/// expose their text (many web and Electron apps) and password fields are skipped.
@MainActor
final class DictionaryAutoLearn {
    static let shared = DictionaryAutoLearn()

    static let watchDuration: TimeInterval = 30
    static let pollInterval: TimeInterval = 1.5
    /// Long fields cost an IPC copy of the whole text per poll; skip them.
    static let maximumFieldLength = 20_000

    private var timer: Timer?
    private var element: AXUIElement?
    private var deadline = Date()
    private var inserted: [String] = []
    private var before: [String] = []
    private var after: [String] = []
    private var baselineTaken = false
    /// A correction is learned only once two polls in a row agree, so a word the user is still
    /// typing ("AppS…") is never taken.
    private var pending: DictionaryLearner.Correction?

    private init() {}

    /// Starts watching for `text`, just inserted into the focused app.
    func watch(inserted text: String) {
        stop()
        let prefs = AppPreferences.shared
        guard prefs.autoLearnDictionary, prefs.customDictionaryEnabled, AXIsProcessTrusted() else { return }
        let words = DictionaryLearner.words(text)
        guard !words.isEmpty else { return }
        inserted = words
        deadline = Date().addingTimeInterval(Self.watchDuration)
        // The paste needs a moment to land before the baseline read.
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        element = nil
        inserted = []
        before = []
        after = []
        baselineTaken = false
        pending = nil
    }

    private func poll() {
        guard Date() < deadline, let focused = Self.focusedElement() else { return stop() }
        if let element, !CFEqual(element, focused) { return stop() }
        guard let text = Self.value(of: focused) else { return stop() }
        let words = DictionaryLearner.words(text)

        guard baselineTaken else {
            // Find the dictation in the field; without it there is nothing to compare.
            guard let range = Self.lastRange(of: inserted, in: words) else { return stop() }
            element = focused
            before = Array(words[..<range.lowerBound])
            after = Array(words[range.upperBound...])
            baselineTaken = true
            return
        }

        // The words around the dictation must be where they were; otherwise the user is
        // editing something else and the stretch can't be lined up.
        guard words.count >= before.count + after.count,
              zip(before, words).allSatisfy({ $0 == $1 }),
              zip(after.reversed(), words.reversed()).allSatisfy({ $0 == $1 }) else { return }
        let stretch = Array(words[before.count..<(words.count - after.count)])
        guard let found = DictionaryLearner.correction(
            inserted: inserted, edited: stretch, trailingOpen: after.isEmpty) else {
            pending = nil
            return
        }
        if found == pending {
            learn(found)
        } else {
            pending = found
        }
    }

    private func learn(_ correction: DictionaryLearner.Correction) {
        stop()
        let prefs = AppPreferences.shared
        let previous = prefs.customDictionaryEntries
        // Already taught (or a rule already writes it from this spelling): nothing to add.
        if CustomDictionary.apply(correction.heard, entries: previous) == correction.correct { return }
        let updated = CustomDictionary.teaching(heard: correction.heard, correct: correction.correct,
                                                to: previous)
        guard updated != previous else { return }
        prefs.customDictionaryEntries = updated
        print("Dictionary: learned a correction from the user's edit")
        IndicatorWindowManager.shared.flashLearned(correction.correct) {
            // Undo only what this added; leave any later dictionary edits alone.
            if AppPreferences.shared.customDictionaryEntries == updated {
                AppPreferences.shared.customDictionaryEntries = previous
            }
        }
    }

    // MARK: - Accessibility

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.2)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString,
                                            &focused) == .success,
              let focusedCF = focused, CFGetTypeID(focusedCF) == AXUIElementGetTypeID() else { return nil }
        return (focusedCF as! AXUIElement)
    }

    private static func value(of element: AXUIElement) -> String? {
        AXUIElementSetMessagingTimeout(element, 0.2)
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           (subrole as? String) == (kAXSecureTextFieldSubrole as String) { return nil }
        var countRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXNumberOfCharactersAttribute as CFString,
                                         &countRef) == .success,
           let count = countRef as? Int, count > maximumFieldLength { return nil }
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString,
                                            &valueRef) == .success else { return nil }
        guard let value = valueRef as? String, value.count <= maximumFieldLength else { return nil }
        return value
    }

    /// The last place the dictation's words appear in the field, ignoring case and edge
    /// punctuation (the paste may have been fitted to the sentence around it).
    nonisolated static func lastRange(of needle: [String], in haystack: [String]) -> Range<Int>? {
        let key = { (w: String) in DictionaryLearner.clean(w).lowercased() }
        let n = needle.map(key)
        guard !n.isEmpty, haystack.count >= n.count else { return nil }
        let h = haystack.map(key)
        for start in stride(from: h.count - n.count, through: 0, by: -1)
            where Array(h[start..<(start + n.count)]) == n {
            return start..<(start + n.count)
        }
        return nil
    }
}
