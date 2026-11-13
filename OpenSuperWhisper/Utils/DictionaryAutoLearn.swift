import AppKit
import ApplicationServices
import Foundation

/// Watches the field a dictation just went into, and when the user retypes a word Rhino got
/// wrong (Apsumo → AppSumo, kubernets → kubernetes), adds a dictionary rule for it with an Undo
/// notice. `DictionaryLearner` decides which edits are corrections.
///
/// After a paste it reads the focused text field through Accessibility every `pollInterval`
/// for `watchDuration`, the way `FocusUtils.caretContext` already reads around the caret. The
/// reads run off the main thread, so a slow app can't stall the hotkey. The field text is
/// compared in memory and never stored or sent anywhere; only a learned rule is kept, in the
/// user's dictionary. It stops at the first of: the time is up, focus leaves the field, a rule
/// was learned, or the next dictation starts watching instead. Fields that don't expose their
/// text (many web and Electron apps) and password fields are skipped.
@MainActor
final class DictionaryAutoLearn {
    static let shared = DictionaryAutoLearn()

    static let watchDuration: TimeInterval = 30
    static let pollInterval: TimeInterval = 1.5
    /// A correction must read the same this many polls in a row (~3 s still) before it is
    /// learned, so a word the user paused on mid-typing ("Klavi…") isn't taken.
    static let stablePolls = 3

    private let readQueue = DispatchQueue(label: "com.noahkagan.rhino.auto-learn", qos: .utility)
    private var timer: Timer?
    private var generation = 0
    private var reading = false
    private var element: AXUIElement?
    private var deadline = Date()
    private var inserted: [String] = []
    private var before: [String] = []
    private var after: [String] = []
    private var baselineTaken = false
    private var pending: DictionaryLearner.Correction?
    private var pendingCount = 0

    private init() {}

    /// Starts watching for `text`, just inserted into the focused app.
    func watch(inserted text: String) {
        stop()
        let prefs = AppPreferences.shared
        guard prefs.autoLearnDictionary, prefs.customDictionaryEnabled, AXIsProcessTrusted() else { return }
        let words = DictionaryLearner.words(text)
        guard !words.isEmpty else { return }
        SystemWordList.prewarm()  // loaded off the main thread before the learner needs it
        inserted = words
        deadline = Date().addingTimeInterval(Self.watchDuration)
        // The first tick also gives the paste a moment to land before the baseline read.
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        generation += 1
        timer?.invalidate()
        timer = nil
        reading = false
        element = nil
        inserted = []
        before = []
        after = []
        baselineTaken = false
        pending = nil
        pendingCount = 0
    }

    private func tick() {
        guard Date() < deadline else { return stop() }
        guard !reading else { return }  // a slow app is still answering the last read
        guard AppPreferences.shared.autoLearnDictionary else { return stop() }
        reading = true
        let current = generation, watched = element
        readQueue.async {
            let read = Self.readFocusedField(expecting: watched)
            Task { @MainActor [weak self] in
                guard let self, self.generation == current else { return }
                self.reading = false
                self.handle(read)
            }
        }
    }

    private func handle(_ read: FieldRead) {
        guard case .text(let focused, let text) = read else { return stop() }
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
              zip(after.reversed(), words.reversed()).allSatisfy({ $0 == $1 }) else {
            pending = nil
            return
        }
        let stretch = Array(words[before.count..<(words.count - after.count)])
        let sentenceStart = before.last.map { $0.last.map { ".!?".contains($0) } ?? false } ?? true
        guard let found = DictionaryLearner.correction(
            inserted: inserted, edited: stretch, trailingOpen: after.isEmpty,
            atSentenceStart: sentenceStart) else {
            pending = nil
            return
        }
        if found == pending {
            pendingCount += 1
        } else {
            pending = found
            pendingCount = 1
        }
        // Learn only when the notice (and its Undo) can show; otherwise wait for the next poll.
        if pendingCount >= Self.stablePolls, IndicatorWindowManager.shared.canFlash {
            learn(found)
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
        // Open dictionary editors hold their own copy; without this they'd write it back over us.
        NotificationCenter.default.post(name: .customDictionaryDidChange, object: nil)
        print("Dictionary: learned a correction from the user's edit")
        IndicatorWindowManager.shared.flashLearned(correction.correct) {
            // Undo only what this added; leave any later dictionary edits alone.
            guard AppPreferences.shared.customDictionaryEntries == updated else { return }
            AppPreferences.shared.customDictionaryEntries = previous
            NotificationCenter.default.post(name: .customDictionaryDidChange, object: nil)
        }
    }

    // MARK: - Accessibility (runs on readQueue)

    private enum FieldRead {
        case text(AXUIElement, String)
        case gone
    }

    /// The focused field's text, or `.gone` when focus moved off `expecting`, the field is a
    /// password field, too long, or doesn't expose its text.
    nonisolated private static func readFocusedField(expecting: AXUIElement?) -> FieldRead {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.2)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString,
                                            &focusedRef) == .success,
              let focusedCF = focusedRef, CFGetTypeID(focusedCF) == AXUIElementGetTypeID() else { return .gone }
        let element = focusedCF as! AXUIElement
        if let expecting, !CFEqual(expecting, element) { return .gone }
        AXUIElementSetMessagingTimeout(element, 0.2)

        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           (subrole as? String) == (kAXSecureTextFieldSubrole as String) { return .gone }
        let limit = FocusUtils.caretContextValueFallbackLimit
        var countRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXNumberOfCharactersAttribute as CFString,
                                         &countRef) == .success,
           let count = countRef as? Int, count > limit { return .gone }
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let value = valueRef as? String, value.count <= limit else { return .gone }
        return .text(element, value)
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
