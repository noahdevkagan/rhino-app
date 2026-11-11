import AppKit
import XCTest
@testable import OpenSuperWhisper

final class SnippetsMatchingTests: XCTestCase {

    private let calendar = Snippet(trigger: "my calendar link", expansion: "https://cal.com/noah/30min")
    private let address = Snippet(trigger: "My address", expansion: "1 Main St\nAustin, TX 78701")

    func testNormalizeFoldsCasePunctuationAndSpacing() {
        XCTAssertEqual(Snippets.normalize("  My calendar link. "), "my calendar link")
        XCTAssertEqual(Snippets.normalize("My, calendar-link!"), "my calendar link")
        XCTAssertEqual(Snippets.normalize("my   calendar\nlink…"), "my calendar link")
        XCTAssertEqual(Snippets.normalize("Café"), "cafe")
        XCTAssertEqual(Snippets.normalize("Noah’s link"), Snippets.normalize("noah's link"))
        XCTAssertEqual(Snippets.normalize(" .?! "), "")
    }

    func testWholeUtteranceMatchesDespiteEngineDecoration() {
        let all = [calendar, address]
        XCTAssertEqual(Snippets.match("My calendar link.", in: all), calendar)
        XCTAssertEqual(Snippets.match("my calendar link", in: all), calendar)
        XCTAssertEqual(Snippets.match("\"My address?\"", in: all), address)
    }

    func testLongerSentenceDoesNotMatch() {
        let all = [calendar, address]
        XCTAssertNil(Snippets.match("Here is my calendar link.", in: all))
        XCTAssertNil(Snippets.match("My calendar link is broken.", in: all))
        XCTAssertNil(Snippets.match("My calendar", in: all))
        XCTAssertNil(Snippets.match("", in: all))
        XCTAssertNil(Snippets.match("...", in: all))
    }

    func testBlankTriggerOrExpansionNeverMatches() {
        let blankTrigger = Snippet(trigger: "  ", expansion: "x")
        let blankExpansion = Snippet(trigger: "my link", expansion: " \n ")
        XCTAssertNil(Snippets.match("", in: [blankTrigger]))
        XCTAssertNil(Snippets.match("My link.", in: [blankExpansion]))
    }

    func testFirstDuplicateWins() {
        let second = Snippet(trigger: "My calendar link!", expansion: "other")
        XCTAssertEqual(Snippets.match("my calendar link", in: [calendar, second]), calendar)
    }

    func testPrunedDropsOnlyFullyBlankRows() {
        let blank = Snippet(trigger: " ", expansion: "")
        let half = Snippet(trigger: "my link", expansion: "")
        XCTAssertEqual(Snippets.pruned([blank, half, calendar]), [half, calendar])
    }

    func testPreferenceRoundTripAndToggle() {
        let prefs = AppPreferences.shared
        let saved = prefs.snippets
        let savedEnabled = prefs.snippetsEnabled
        defer {
            prefs.snippets = saved
            prefs.snippetsEnabled = savedEnabled
        }
        prefs.snippets = [address]
        XCTAssertEqual(prefs.snippets, [address])
        XCTAssertEqual(prefs.snippets.first?.expansion, "1 Main St\nAustin, TX 78701")

        prefs.snippetsEnabled = true
        XCTAssertEqual(prefs.matchingSnippet("My address."), address)
        prefs.snippetsEnabled = false
        XCTAssertNil(prefs.matchingSnippet("My address."))
    }
}

/// A dictated trigger reaches the document as the stored expansion, untouched by cleanup,
/// spoken punctuation, the dictionary or sentence spacing.
@MainActor
final class SnippetsPipelineTests: XCTestCase {

    func testTriggerInsertsExpansionVerbatimAndSkipsCleanup() async {
        // Each of these would change the text if it reached the normal path:
        // - "period" → "." via spoken punctuation (AI cleanup + smart formatting on),
        // - "teh" → "the" via the dictionary rule below,
        // - "one.Two" → "one. Two" and a trailing space after the final "." via sentence spacing.
        let expansion = "line one.Two teh period\n  https://cal.com/noah/30min."
        let output = await runPipeline(transcript: "My calendar link.",
                                       snippets: [Snippet(trigger: "my calendar link",
                                                          expansion: expansion)])
        XCTAssertEqual(output, expansion)
    }

    func testNonMatchingDictationStillGoesThroughNormalPath() async {
        // AI cleanup off here so a cleanup model on the test Mac can't make this nondeterministic;
        // sentence spacing still runs on the normal path.
        let output = await runPipeline(transcript: "fix it.Now",
                                       snippets: [Snippet(trigger: "my calendar link",
                                                          expansion: "https://cal.com/noah/30min")],
                                       aiCleanup: false)
        XCTAssertEqual(output, "fix it. Now")
    }

    /// Runs one dictation through `DictationPipeline` with auto-paste off, so the inserted text
    /// lands on a private pasteboard, and returns it.
    private func runPipeline(transcript: String, snippets: [Snippet],
                             aiCleanup: Bool = true) async -> String? {
        let prefs = AppPreferences.shared
        let saved = (history: prefs.saveTranscriptionHistory, paste: prefs.autoPasteTranscription,
                     copy: prefs.autoCopyToClipboard, ai: prefs.aiPostProcessingEnabled,
                     smart: prefs.smartFormattingEnabled, space: prefs.addSpaceAfterSentence,
                     dictOn: prefs.customDictionaryEnabled, dict: prefs.customDictionaryEntries,
                     snipOn: prefs.snippetsEnabled, snips: prefs.snippets)
        prefs.saveTranscriptionHistory = false
        prefs.autoPasteTranscription = false
        prefs.autoCopyToClipboard = false
        prefs.aiPostProcessingEnabled = aiCleanup
        prefs.smartFormattingEnabled = true
        prefs.addSpaceAfterSentence = true
        prefs.customDictionaryEnabled = true
        prefs.customDictionaryEntries = [CustomDictionaryEntry(original: "teh", replacement: "the")]
        prefs.snippetsEnabled = true
        prefs.snippets = snippets

        let board = NSPasteboard(name: NSPasteboard.Name("OpenSuperWhisperTests." + UUID().uuidString))
        let savedBoard = TranscriptInserter.pasteboard
        TranscriptInserter.pasteboard = board
        let pipeline = DictationPipeline.shared
        pipeline.transcribeOverride = { _, _ in transcript }
        defer {
            pipeline.transcribeOverride = nil
            TranscriptInserter.pasteboard = savedBoard
            board.releaseGlobally()
            prefs.saveTranscriptionHistory = saved.history
            prefs.autoPasteTranscription = saved.paste
            prefs.autoCopyToClipboard = saved.copy
            prefs.aiPostProcessingEnabled = saved.ai
            prefs.smartFormattingEnabled = saved.smart
            prefs.addSpaceAfterSentence = saved.space
            prefs.customDictionaryEnabled = saved.dictOn
            prefs.customDictionaryEntries = saved.dict
            prefs.snippetsEnabled = saved.snipOn
            prefs.snippets = saved.snips
        }

        pipeline.enqueue(tempURL: URL(fileURLWithPath: "/tmp/osw-snippet-test-\(UUID().uuidString).wav"),
                         startedAt: Date(), streamedFallback: "",
                         context: DictationPipeline.ContextSnapshot(), modelOption: nil)
        var waited = 0
        while pipeline.isProcessing && waited < 1000 {
            try? await Task.sleep(nanoseconds: 10_000_000)
            waited += 1
        }
        XCTAssertFalse(pipeline.isProcessing, "pipeline should finish")
        return board.string(forType: .string)
    }
}
