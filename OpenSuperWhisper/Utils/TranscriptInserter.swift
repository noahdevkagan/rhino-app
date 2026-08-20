import ApplicationServices
import Foundation

/// The single place that decides *how* a finished transcription reaches the focused app:
/// clipboard stash, paste-vs-type, and the no-editable-target fallback.
///
/// Shared by the automatic insertion at the end of a dictation (`DictationPipeline`) and by any
/// explicit, user-triggered insertion, so the two can't drift apart.
enum TranscriptInserter {

    /// What actually happened to the text, so callers can tell the user the right thing.
    enum Outcome {
        /// Sent to the focused app (paste or typing).
        case inserted
        /// Auto-paste preference is off and this was an automatic insertion — nothing sent.
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
    @MainActor
    @discardableResult
    static func insert(_ text: String, honorAutoPastePreference: Bool) -> Outcome {
        let prefs = AppPreferences.shared

        // Optional, independent clipboard stash (never the insertion mechanism).
        if prefs.autoCopyToClipboard {
            ClipboardUtil.copyToClipboard(text)
        }

        guard prefs.autoPasteTranscription || !honorAutoPastePreference else { return .skipped }

        // Both insertion modes post synthetic keyboard events, and macOS drops those without a
        // *live* Accessibility grant — silently, no error anywhere. The System Settings checkbox
        // can show ON while the grant is stale (app updated, moved, or a different copy granted),
        // so preflight here and fall back to the clipboard with an explicit outcome instead of
        // letting the text vanish. (#silent-paste)
        guard AXIsProcessTrusted() else {
            if !prefs.autoCopyToClipboard {
                ClipboardUtil.copyToClipboard(text)
            }
            return .noPermission
        }

        if prefs.pasteInsteadOfTyping {
            // Paste is universal: ⌘V lands in any text field, including apps the accessibility check
            // can't read (Messages, Electron), and is a harmless no-op otherwise. So no editable-
            // target gate — it only ever produces false negatives (#paste-messages).
            if prefs.autoCopyToClipboard {
                Diag.measure("TextInserter.paste") { TextInserter.paste() }
            } else {
                // The clipboard is only the paste vehicle here — the user opted out of keeping the
                // text on it (#44) — so put the previous contents back after the ⌘V lands.
                ClipboardUtil.borrowForPaste(text) {
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
                ClipboardUtil.copyToClipboard(text)
            }
            return .noTarget
        }
        Diag.measure("TextInserter.type") { TextInserter.type(text) }
        return .inserted
    }
}
