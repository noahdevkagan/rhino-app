import AppKit
import ApplicationServices
import Foundation
import os

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
///
/// Fields longer than `FocusUtils.caretContextValueFallbackLimit` (Terminal and iTerm expose
/// their whole scrollback, often 100k+ characters) are watched through a tail window instead:
/// the baseline read fixes a start offset `tailWindow` characters before the end, and every later
/// poll reads from that same offset to the end with `kAXStringForRangeParameterizedAttribute`.
/// Text before the offset is never read. Because the start never moves, the words line up the
/// way they do for a whole-field read; output printed after the dictation, or scrollback trimmed
/// off the top, breaks the alignment and the poll counts as "no correction".
@MainActor
final class DictionaryAutoLearn {
    static let shared = DictionaryAutoLearn()

    static let watchDuration: TimeInterval = 30
    static let pollInterval: TimeInterval = 1.5
    /// A correction must read the same this many polls in a row (~3 s still) before it is
    /// learned, so a word the user paused on mid-typing ("Klavi…") isn't taken.
    static let stablePolls = 3
    /// How much of a long field's end the baseline read takes (UTF-16 units, as AX counts).
    nonisolated static let tailWindow = 8_000
    /// A windowed read that has grown past this many characters since the baseline (output kept
    /// printing) stops the watch: the words after the dictation can't still match.
    nonisolated static let maxWindowSpan = 16_000

    nonisolated static let log = Logger(subsystem: "com.noahkagan.rhino", category: "autolearn")

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
    /// Where reads of this field start: 0 for a whole-field read, else the tail window's offset.
    private var windowStart = 0
    private var stability = DictionaryLearner.Stability()
    /// The last poll's outcome after the baseline, for the log line when the watch times out.
    private var lastOutcome = "no poll after the baseline"

    private init() {}

    /// Starts watching for `text`, just inserted into the focused app.
    func watch(inserted text: String) {
        stop(reason: "replaced by a new dictation")
        let prefs = AppPreferences.shared
        guard prefs.autoLearnDictionary, prefs.customDictionaryEnabled, AXIsProcessTrusted() else {
            Self.log.info("autolearn: not watching (setting off: \(!prefs.autoLearnDictionary, privacy: .public), dictionary off: \(!prefs.customDictionaryEnabled, privacy: .public), no Accessibility: \(!AXIsProcessTrusted(), privacy: .public))")
            return
        }
        let words = DictionaryLearner.words(text)
        guard !words.isEmpty else { return }
        Self.log.info("autolearn: watching a \(words.count, privacy: .public)-word dictation")
        SystemWordList.prewarm()  // loaded off the main thread before the learner needs it
        inserted = words
        deadline = Date().addingTimeInterval(Self.watchDuration)
        // The first tick also gives the paste a moment to land before the baseline read.
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Ends the watch. `reason` is logged when a watch was running.
    func stop(reason: String? = nil) {
        if let reason, timer != nil {
            Self.log.info("autolearn: watch ended: \(reason, privacy: .public)")
        }
        generation += 1
        timer?.invalidate()
        timer = nil
        reading = false
        element = nil
        inserted = []
        before = []
        after = []
        baselineTaken = false
        windowStart = 0
        lastOutcome = "no poll after the baseline"
        stability = DictionaryLearner.Stability()
    }

    private func tick() {
        guard Date() < deadline else {
            return stop(reason: baselineTaken ? "timed out; last poll: \(lastOutcome)"
                                              : "timed out before the field could be read")
        }
        guard !reading else { return }  // a slow app is still answering the last read
        guard AppPreferences.shared.autoLearnDictionary else { return stop(reason: "setting turned off") }
        reading = true
        let current = generation, watched = element
        let start: Int? = baselineTaken ? windowStart : nil
        readQueue.async {
            let read = Self.readFocusedField(expecting: watched, windowStart: start)
            Task { @MainActor [weak self] in
                guard let self, self.generation == current else { return }
                self.reading = false
                self.handle(read)
            }
        }
    }

    private func handle(_ read: FieldRead) {
        let focused: AXUIElement, text: String, start: Int, role: String
        switch read {
        case .gone(let reason):
            return stop(reason: reason.rawValue + (baselineTaken ? "" : " (at baseline)"))
        case .retry:
            return note("character count didn't answer; retrying next poll")
        case .text(let e, let t, let s, let r):
            (focused, text, start, role) = (e, t, s, r)
        }
        let words = DictionaryLearner.words(text)

        guard baselineTaken else {
            var pid: pid_t = 0
            AXUIElementGetPid(focused, &pid)
            let app = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "unknown"
            // Find the dictation in the field; without it there is nothing to compare.
            guard let range = Self.lastRange(of: inserted, in: words) else {
                return stop(reason: "dictated words not found in the \(start > 0 ? "tail window" : "field") (app \(app), role \(role), \(text.utf16.count) chars read)")
            }
            element = focused
            windowStart = start
            before = Array(words[..<range.lowerBound])
            after = Array(words[range.upperBound...])
            baselineTaken = true
            Self.log.info("autolearn: baseline taken: app \(app, privacy: .public), role \(role, privacy: .public), \(text.utf16.count, privacy: .public) chars read from offset \(start, privacy: .public)\(start > 0 ? " (tail window)" : "", privacy: .public)")
            return
        }

        // The words around the dictation must be where they were; otherwise the user is
        // editing something else (or output scrolled in) and the stretch can't be lined up.
        guard let stretch = Self.stretch(in: words, before: before, after: after) else {
            note("text around the dictation changed")
            _ = stability.observe(nil, required: Self.stablePolls)
            return
        }
        let sentenceStart = before.last.map { $0.last.map { ".!?".contains($0) } ?? false } ?? true
        let verdict = DictionaryLearner.verdict(
            inserted: inserted, edited: stretch, trailingOpen: after.isEmpty,
            atSentenceStart: sentenceStart)
        guard case .learn(let found) = verdict else {
            if case .reject(let why) = verdict { note("learner rejected: \(why.rawValue)") }
            _ = stability.observe(nil, required: Self.stablePolls)
            return
        }
        // Learn only when the notice (and its Undo) can show; otherwise wait for the next poll.
        let stable = stability.observe(found, required: Self.stablePolls)
        if stable, IndicatorWindowManager.shared.canFlash {
            learn(found)
        } else {
            note(stable ? "correction found, waiting for the notice to be able to show"
                        : "correction found, not stable yet (\(stability.count)/\(Self.stablePolls) polls)")
        }
    }

    /// Records a poll's outcome; logged when it differs from the last one, so a 30 s watch logs
    /// a handful of lines rather than one per poll.
    private func note(_ outcome: String) {
        guard outcome != lastOutcome else { return }
        lastOutcome = outcome
        Self.log.info("autolearn: poll: \(outcome, privacy: .public)")
    }

    private func learn(_ correction: DictionaryLearner.Correction) {
        stop()
        let prefs = AppPreferences.shared
        let previous = prefs.customDictionaryEntries
        // Already taught (or a rule already writes it from this spelling): nothing to add.
        if CustomDictionary.apply(correction.heard, entries: previous) == correction.correct {
            Self.log.info("autolearn: watch ended: correction already in the dictionary")
            return
        }
        let updated = CustomDictionary.teaching(heard: correction.heard, correct: correction.correct,
                                                to: previous)
        guard updated != previous else {
            Self.log.info("autolearn: watch ended: dictionary unchanged by the correction")
            return
        }
        prefs.customDictionaryEntries = updated
        // Open dictionary editors hold their own copy; without this they'd write it back over us.
        NotificationCenter.default.post(name: .customDictionaryDidChange, object: nil)
        print("Dictionary: learned a correction from the user's edit")
        Self.log.notice("autolearn: learned \(correction.heard, privacy: .private) → \(correction.correct, privacy: .private) (\(correction.heard.count, privacy: .public) → \(correction.correct.count, privacy: .public) chars)")
        IndicatorWindowManager.shared.flashLearned(correction.correct) {
            // Undo only what this added; leave any later dictionary edits alone.
            guard AppPreferences.shared.customDictionaryEntries == updated else { return }
            AppPreferences.shared.customDictionaryEntries = previous
            NotificationCenter.default.post(name: .customDictionaryDidChange, object: nil)
        }
    }

    // MARK: - Accessibility (runs on readQueue)

    enum SkipReason: String {
        case noFocus = "no focused element"
        case focusMoved = "focus left the field"
        case secure = "password field"
        case tooBig = "field too big and no range reads"
        case unreadable = "field text unreadable"
        case shrank = "field shrank below the tail window"
        case outputGrew = "too much new text after the tail window start"
    }

    private enum FieldRead {
        /// The text read and the offset it starts at in the field (0 for the whole field).
        case text(AXUIElement, String, start: Int, role: String)
        case gone(SkipReason)
        /// Nothing read this poll; try again next poll.
        case retry
    }

    /// How a poll reads the field.
    enum ReadPlan: Equatable {
        /// Copy the whole value (`kAXValueAttribute`).
        case whole
        /// Read nothing this poll and try again next poll (a windowed field's length didn't answer).
        case wait
        /// Read `location..<location+length` with `kAXStringForRangeParameterizedAttribute`.
        case range(location: Int, length: Int)
        case skip(SkipReason)
    }

    /// Pure: picks how to read a field of `count` characters (`nil` when the app didn't say).
    /// `windowStart` is `nil` for the baseline read, else the offset the baseline used (0 = the
    /// whole field). A whole-field watch never switches to a window mid-watch (the words wouldn't
    /// line up), and a window never moves.
    nonisolated static func readPlan(count: Int?, windowStart: Int?,
                                     limit: Int = FocusUtils.caretContextValueFallbackLimit,
                                     tail: Int = tailWindow, maxSpan: Int = maxWindowSpan) -> ReadPlan {
        switch windowStart {
        case nil:
            guard let count, count > limit else { return .whole }
            let location = max(0, count - tail)
            return .range(location: location, length: count - location)
        case 0?:
            if let count, count > limit { return .skip(.tooBig) }
            return .whole
        case let start?:
            guard let count else { return .wait }
            guard count >= start else { return .skip(.shrank) }
            guard count - start <= maxSpan else { return .skip(.outputGrew) }
            return .range(location: start, length: count - start)
        }
    }

    /// Pure: the words between the baseline's `before` and `after`, or `nil` when the words around
    /// the dictation are not where they were. Reads from the same window start line up word for
    /// word, so `before` must be an exact prefix and `after` an exact suffix.
    nonisolated static func stretch(in words: [String], before: [String], after: [String]) -> [String]? {
        guard words.count >= before.count + after.count,
              zip(before, words).allSatisfy({ $0 == $1 }),
              zip(after.reversed(), words.reversed()).allSatisfy({ $0 == $1 }) else { return nil }
        return Array(words[before.count..<(words.count - after.count)])
    }

    /// The focused field's text (or its tail window), or `.gone` with the reason when focus moved
    /// off `expecting`, the field is a password field, or its text can't be read. `windowStart`
    /// is `nil` for the baseline read; see `readPlan`.
    nonisolated private static func readFocusedField(expecting: AXUIElement?, windowStart: Int?) -> FieldRead {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.2)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString,
                                            &focusedRef) == .success,
              let focusedCF = focusedRef, CFGetTypeID(focusedCF) == AXUIElementGetTypeID()
        else { return .gone(.noFocus) }
        let element = focusedCF as! AXUIElement
        if let expecting, !CFEqual(expecting, element) { return .gone(.focusMoved) }
        AXUIElementSetMessagingTimeout(element, 0.2)

        var roleRef: CFTypeRef?
        let role = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success
            ? (roleRef as? String) ?? "?" : "?"
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           (subrole as? String) == (kAXSecureTextFieldSubrole as String) { return .gone(.secure) }
        let limit = FocusUtils.caretContextValueFallbackLimit
        var countRef: CFTypeRef?
        let count: Int? = AXUIElementCopyAttributeValue(
            element, kAXNumberOfCharactersAttribute as CFString, &countRef) == .success
            ? countRef as? Int : nil

        switch readPlan(count: count, windowStart: windowStart) {
        case .skip(let reason):
            return .gone(reason)
        case .wait:
            return .retry
        case .range(let location, let length):
            var range = CFRange(location: location, length: length)
            guard let rangeValue = AXValueCreate(.cfRange, &range) else { return .gone(.unreadable) }
            var result: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(
                element, kAXStringForRangeParameterizedAttribute as CFString, rangeValue, &result) == .success,
                  let text = result as? String
            else { return .gone(windowStart == nil ? .tooBig : .unreadable) }
            return .text(element, text, start: location, role: role)
        case .whole:
            var valueRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
                  let value = valueRef as? String else { return .gone(.unreadable) }
            guard value.count <= limit else { return .gone(.tooBig) }
            return .text(element, value, start: 0, role: role)
        }
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
