import AppKit
import NaturalLanguage
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
    ///   - fitToContext: Adjust casing, the closing period and spacing to the text around the
    ///     caret (`ContextCasing`). On for a fresh dictation; off for an explicit re-insert of a
    ///     stored transcript, where the user picked that exact text.
    ///   - spokenTrailingMark: The user said the closing "period"/"comma" out loud, so
    ///     `ContextCasing` must keep it.
    @MainActor
    @discardableResult
    static func insert(_ text: String, honorAutoPastePreference: Bool,
                       fitToContext: Bool = false,
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
            let fitted = fitToContext ? fitToCaret(text, spokenTrailingMark: spokenTrailingMark) : text
            // Paste is universal: ⌘V lands in any text field, including apps the accessibility check
            // can't read (Messages, Electron), and is a harmless no-op otherwise. So no editable-
            // target gate — it only ever produces false negatives (#paste-messages).
            if prefs.autoCopyToClipboard && fitted == text {
                Diag.measure("TextInserter.paste") { TextInserter.paste() }
            } else {
                // Also taken when the text was fitted to the caret: the "Copy to clipboard" stash
                // above keeps the transcript as dictated, so borrow the clipboard for the fitted
                // text and put the stash back after the paste.
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
        let fitted = fitToContext ? fitToCaret(text, spokenTrailingMark: spokenTrailingMark) : text
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
        let prefs = AppPreferences.shared
        let dictionaryWords: Set<Substring> = prefs.customDictionaryEnabled
            ? Set(prefs.customDictionaryEntries.flatMap {
                $0.replacement.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            })
            : []
        let language = prefs.whisperLanguage
        return ContextCasing.apply(
            text: text, before: context.before, after: context.after,
            spokenTrailingMark: spokenTrailingMark,
            isProperNoun: { word in
                isProperNoun(word, in: context.before + text, dictionaryWords: dictionaryWords,
                             language: language)
            })
    }

    /// Whether the dictation's first word is a name that keeps its capital mid-sentence. Only
    /// asked about ordinary-looking capitalized words (ContextCasing already protects "I",
    /// acronyms, mixed case, weekdays and months). All on-device; none of these make network
    /// calls.
    /// - A word in the user's custom dictionary.
    /// - A name the on-device tagger finds in context ("and Mark said it works": Mark is a
    ///   person), which catches names that are also dictionary words.
    /// - A word whose lowercase form the spell checker rejects ("steve"), in the dictation
    ///   language when one is set.
    @MainActor
    static func isProperNoun(_ word: String, in sentence: String,
                             dictionaryWords: Set<Substring>, language: String) -> Bool {
        if dictionaryWords.contains(Substring(word)) { return true }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sentence
        let nameTags: Set<NLTag> = [.personalName, .placeName, .organizationName]
        var tagged = false
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word,
                             scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            if let tag, nameTags.contains(tag),
               sentence[range].split(separator: " ").contains(Substring(word)) {
                tagged = true
                return false
            }
            return true
        }
        if tagged { return true }

        let checker = NSSpellChecker.shared
        let spellLanguage = language == "auto" || !checker.availableLanguages.contains(language)
            ? nil : language
        let miss = checker.checkSpelling(of: word.lowercased(), startingAt: 0, language: spellLanguage,
                                         wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
        return miss.location != NSNotFound
    }
}
