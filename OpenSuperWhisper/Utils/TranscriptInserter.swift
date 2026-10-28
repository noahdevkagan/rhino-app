import AppKit
import ApplicationServices
import Foundation

/// The single place that decides *how* a finished transcription reaches the focused app:
/// clipboard stash, paste-vs-type, and the no-editable-target fallback.
///
/// Shared by the automatic insertion at the end of a dictation (`DictationPipeline`) and by any
/// explicit, user-triggered insertion, so the two can't drift apart.
enum TranscriptInserter {

    /// The clipboard insertion stashes on and borrows. Tests swap in a private named pasteboard
    /// so they never touch the developer's real clipboard. Main-thread only, like `insert`.
    static var pasteboard: NSPasteboard = .general

    /// What actually happened to the text, so callers can tell the user the right thing.
    enum Outcome {
        /// Sent to the focused app (paste or typing).
        case inserted
        /// Auto-paste preference is off and this was an automatic insertion: nothing sent to the
        /// app, the text is on the clipboard for the user to paste.
        case skipped
        /// Typing mode found no editable field; the text is on the clipboard instead.
        case noTarget
        /// Accessibility trust is missing or stale, so macOS would silently drop the synthetic
        /// keystrokes. The text is on the clipboard instead.
        case noPermission
    }

    /// Inserts `text` into the focused app.
    ///
    /// - Parameters:
    ///   - text: Post-processed transcription, ready to insert.
    ///   - honorAutoPastePreference: `true` for automatic insertion after a dictation, where the
    ///     "Auto-paste transcription" preference decides whether anything is inserted at all.
    ///     `false` when the user explicitly asked for this insertion — the request itself is the
    ///     intent, so a clipboard-only workflow still gets text where the cursor is.
    ///   - spokenTrailingMark: The user said the closing "period"/"comma" out loud, so
    ///     `ContextCasing` must keep it.
    @MainActor
    @discardableResult
    static func insert(_ text: String, honorAutoPastePreference: Bool,
                       spokenTrailingMark: Bool = false) -> Outcome {
        let prefs = AppPreferences.shared
        let pasteboard = Self.pasteboard

        // Optional, independent clipboard stash (never the insertion mechanism).
        if prefs.autoCopyToClipboard {
            ClipboardUtil.copyToClipboard(text, to: pasteboard)
        }

        // Auto-paste off: the clipboard is how this user gets the text, so it goes there as a
        // normal copy whatever "Copy to clipboard" says, like the fallbacks below. (Before
        // "Copy to clipboard" defaulted off, its old ON default is what delivered it.)
        guard prefs.autoPasteTranscription || !honorAutoPastePreference else {
            if !prefs.autoCopyToClipboard {
                ClipboardUtil.copyToClipboard(text, to: pasteboard)
            }
            return .skipped
        }

        // Both insertion modes post synthetic keyboard events, and macOS drops those without a
        // *live* Accessibility grant — silently, no error anywhere. The System Settings checkbox
        // can show ON while the grant is stale (app updated, moved, or a different copy granted),
        // so preflight here and fall back to the clipboard with an explicit outcome instead of
        // letting the text vanish. (#silent-paste)
        guard AXIsProcessTrusted() else {
            if !prefs.autoCopyToClipboard {
                ClipboardUtil.copyToClipboard(text, to: pasteboard)
            }
            return .noPermission
        }

        if prefs.pasteInsteadOfTyping {
            let fitted = fitToCaret(text, spokenTrailingMark: spokenTrailingMark)
            // Paste is universal: ⌘V lands in any text field, including apps the accessibility check
            // can't read (Messages, Electron), and is a harmless no-op otherwise. So no editable-
            // target gate — it only ever produces false negatives (#paste-messages).
            if prefs.autoCopyToClipboard {
                // The stash above holds the transcript as dictated; paste what fits the caret.
                if fitted != text { ClipboardUtil.copyToClipboard(fitted, to: pasteboard) }
                Diag.measure("TextInserter.paste") { TextInserter.paste() }
            } else {
                // The clipboard is only the paste vehicle here — the user opted out of keeping the
                // text on it (#44) — so put the previous contents back after the ⌘V lands.
                ClipboardUtil.borrowForPaste(fitted, on: pasteboard) {
                    Diag.measure("TextInserter.paste") { TextInserter.paste() }
                }
            }
            return .inserted
        }

        // Typing mode: synthetic keystrokes go wherever focus is, so only type when we're confident
        // there's an editable target; otherwise stash on the clipboard and notify ⌘V.
        let targetMissing = prefs.notifyWhenNoPasteTarget
            && Diag.measure("focusedElementIsEditable") { FocusUtils.focusedElementIsEditable() } == false
        if targetMissing {
            if !prefs.autoCopyToClipboard {
                ClipboardUtil.copyToClipboard(text, to: pasteboard)
            }
            return .noTarget
        }
        let fitted = fitToCaret(text, spokenTrailingMark: spokenTrailingMark)
        Diag.measure("TextInserter.type") { TextInserter.type(fitted) }
        return .inserted
    }

    /// Adjusts the dictation to the text around the caret (`ContextCasing`): lowercase and no
    /// closing period mid-sentence, no period on a one-to-three-word field value, one space at
    /// each seam. Unchanged whenever the focused app doesn't expose its text.
    @MainActor
    static func fitToCaret(_ text: String, spokenTrailingMark: Bool) -> String {
        guard let context = Diag.measure("FocusUtils.caretContext", { FocusUtils.caretContext() }) else {
            return text
        }
        return ContextCasing.apply(text: text, before: context.before, after: context.after,
                                   spokenTrailingMark: spokenTrailingMark,
                                   isProperNoun: isProperNoun)
    }

    /// Words that keep their capital mid-sentence: anything in the user's custom dictionary,
    /// and words whose lowercase form the system spell checker doesn't know (names, places:
    /// "steve" is not a word, "the" is). On-device; NSSpellChecker makes no network calls.
    @MainActor
    static func isProperNoun(_ word: String) -> Bool {
        let prefs = AppPreferences.shared
        if prefs.customDictionaryEnabled {
            for entry in prefs.customDictionaryEntries {
                let words = entry.replacement.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                if words.contains(where: { $0 == word }) { return true }
            }
        }
        let lower = word.lowercased()
        let miss = NSSpellChecker.shared.checkSpelling(of: lower, startingAt: 0)
        return miss.location != NSNotFound
    }
}
