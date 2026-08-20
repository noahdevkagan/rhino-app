import AppKit
import Foundation

/// Picks, labels and re-inserts the transcriptions offered in the status bar's "Recent"
/// submenu.
///
/// Reaching an earlier dictation used to mean opening the main window and copying out of the
/// history list.
enum RecentTranscripts {

    /// How many rows the submenu offers. Enough to cover "not that one, the one before",
    /// short enough that the menu stays a menu.
    static let menuCount = 6

    /// How many stored recordings are scanned to fill those rows. Only failed, in-flight and
    /// empty clips are skipped, so the usable ones are nearly always near the top.
    static let scanDepth = 30

    /// Menu rows are single-line, and a long dictation would otherwise stretch the menu to the
    /// width of the screen.
    static let titleLimit = 48

    /// Transcriptions worth re-inserting, newest first.
    ///
    /// Skips clips that failed (their `transcription` holds the retry placeholder), clips still
    /// being transcribed, and ones that produced nothing. Ordering is computed here rather than
    /// trusted from the caller, so a change in how the store sorts can't silently reorder the
    /// menu.
    static func pick(from recordings: [Recording], limit: Int) -> [Recording] {
        recordings
            .filter {
                $0.status == .completed
                    && !$0.transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }

    /// A one-line label. Newlines and runs of spaces collapse, because a dictation that spans
    /// paragraphs would otherwise render as a row of blanks with a word at each end.
    static func menuTitle(for transcription: String, limit: Int = titleLimit) -> String {
        let collapsed = transcription
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard collapsed.count > limit else { return collapsed }
        return collapsed.prefix(limit).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Puts a chosen transcription where the caret is.
    @MainActor
    static func insert(_ text: String) async {
        await waitForModifiersToClear()

        // `honorAutoPastePreference: false` — asking for this insertion *is* the request, so a
        // user who dictates to the clipboard only still gets text where the cursor is.
        let outcome = TranscriptInserter.insert(IndicatorViewModel.applyPostProcessing(text),
                                                honorAutoPastePreference: false)
        switch outcome {
        case .noTarget:
            IndicatorWindowManager.shared.flash(.info("Copied — press ⌘V"))
        case .noPermission:
            IndicatorWindowManager.shared.flash(.error(
                "Couldn't paste — re-add Rhino in System Settings → Accessibility. Copied — press ⌘V"))
        case .inserted, .skipped:
            break
        }
    }

    /// Waits (briefly) for any physically-held modifiers to come back up.
    ///
    /// The insertion is a synthetic ⌘V, and macOS merges the physically-held modifiers into it.
    /// Fire while ⌃⌘ is still down and the frontmost app sees ⌃⌘V — not a paste — so the text
    /// silently fails to appear. Typing mode is just as exposed: held modifiers turn the
    /// keystrokes into shortcuts.
    @MainActor
    static func waitForModifiersToClear(timeout: TimeInterval = 1.0,
                                        pollInterval: TimeInterval = 0.02) async {
        let deadline = Date().addingTimeInterval(timeout)
        while modifiersAreHeld(), Date() < deadline {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    @MainActor
    private static func modifiersAreHeld() -> Bool {
        !NSEvent.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
    }
}
