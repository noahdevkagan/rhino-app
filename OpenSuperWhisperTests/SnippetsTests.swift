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

    func testTriggerMatchesInItsTranscriptForm() {
        let room = Snippet(trigger: "my zoom room two", expansion: "https://zoom.us/j/1")
        let form: (String) -> String = { $0.replacingOccurrences(of: "two", with: "2") }
        XCTAssertEqual(Snippets.match("My zoom room 2.", in: [room], transcriptForm: form), room)
        XCTAssertEqual(Snippets.match("my zoom room two", in: [room], transcriptForm: form), room)
        XCTAssertNil(Snippets.match("My zoom room 2.", in: [room]))
    }

    /// The real transform: the dictionary, number formatting and British spelling that the
    /// transcript went through all apply to the trigger too.
    func testRealTranscriptFormAppliesDictionaryAndNumbers() {
        let prefs = AppPreferences.shared
        let saved = (on: prefs.customDictionaryEnabled, entries: prefs.customDictionaryEntries,
                     snippets: prefs.snippets, enabled: prefs.snippetsEnabled)
        defer {
            prefs.customDictionaryEnabled = saved.on
            prefs.customDictionaryEntries = saved.entries
            prefs.snippets = saved.snippets
            prefs.snippetsEnabled = saved.enabled
        }
        prefs.customDictionaryEnabled = true
        prefs.customDictionaryEntries = [CustomDictionaryEntry(original: "clavio", replacement: "Klaviyo")]
        prefs.snippetsEnabled = true
        let klaviyo = Snippet(trigger: "my clavio link", expansion: "https://klaviyo.com/x")
        let room = Snippet(trigger: "zoom room twenty five", expansion: "https://zoom.us/j/25")
        prefs.snippets = [klaviyo, room]
        let settings = Settings()
        let form = { prefs.snippetTriggerTranscriptForm($0, settings: settings) }

        XCTAssertEqual(prefs.matchingSnippet("My Klaviyo link.", transcriptForm: form), klaviyo)
        // Whatever the number style makes of it, the transcript and trigger agree.
        let spokenRoom = NumberCompaction.apply("Zoom room twenty five.", style: prefs.numberFormattingStyle)
        XCTAssertEqual(prefs.matchingSnippet(spokenRoom, transcriptForm: form), room)
    }

    func testDuplicateWarningFollowsTheMatcher() {
        let blank = Snippet(trigger: "my link", expansion: " ")
        let first = Snippet(trigger: "My link.", expansion: "one")
        let second = Snippet(trigger: "my link", expansion: "two")
        let all = [blank, first, second]
        XCTAssertNil(Snippets.shadowing(blank, in: all), "nothing above it")
        XCTAssertNil(Snippets.shadowing(first, in: all), "a blank row above doesn't take the phrase")
        XCTAssertEqual(Snippets.shadowing(second, in: all), first)
        XCTAssertEqual(Snippets.match("my link", in: all), first)
    }

    func testDecodeIsTolerantPerRow() {
        let json = """
        [{"trigger":"no id","expansion":"a"},
         {"id":"not-a-uuid","trigger":"bad id","expansion":"b"},
         42,
         {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","trigger":"ok","expansion":"c"}]
        """
        let decoded = Snippets.decode(Data(json.utf8))
        XCTAssertEqual(decoded.snippets.map(\.trigger), ["no id", "bad id", "ok"])
        XCTAssertEqual(decoded.snippets.last?.id.uuidString, "6F9619FF-8B86-D011-B42D-00C04FC964FF")
        XCTAssertFalse(decoded.lossless, "the 42 row was lost")

        XCTAssertEqual(Snippets.decode(nil), Snippets.Decoded(snippets: [], lossless: true))
        XCTAssertFalse(Snippets.decode(Data("{\"not\":\"a list\"}".utf8)).lossless)
    }

    func testUnreadableStoredDataIsBackedUpBeforeOverwrite() {
        let prefs = AppPreferences.shared
        let defaults = DefaultsStore.current
        let savedData = defaults.data(forKey: "snippetsData")
        let savedBackup = prefs.snippetsDataUnreadableBackup
        defer {
            defaults.set(savedData, forKey: "snippetsData")
            prefs.snippetsDataUnreadableBackup = savedBackup
        }
        prefs.snippetsDataUnreadableBackup = nil
        let garbage = Data("{\"future\":true}".utf8)
        defaults.set(garbage, forKey: "snippetsData")
        XCTAssertEqual(prefs.snippets, [])

        prefs.snippets = [calendar]
        XCTAssertEqual(prefs.snippets, [calendar])
        XCTAssertEqual(prefs.snippetsDataUnreadableBackup, garbage)

        // A later write of a readable list leaves the first backup alone.
        prefs.snippets = [address]
        XCTAssertEqual(prefs.snippetsDataUnreadableBackup, garbage)
    }

    func testMultilineDetection() {
        XCTAssertTrue(DictationPipeline.isMultiline("1 Main St\nAustin"))
        XCTAssertTrue(DictationPipeline.isMultiline("a\r\nb"))
        XCTAssertFalse(DictationPipeline.isMultiline("https://cal.com/noah/30min"))
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

    /// Snippets are saved text: zero words toward the free weekly limit. A normal dictation
    /// still counts.
    func testSnippetCountsNoFreeTierWords() async {
        let gate = UnlockRhino.shared.gate
        let snippets = [Snippet(trigger: "my address", expansion: "1 Main St\nAustin, TX 78701 USA")]

        let before = gate.wordsThisWeek
        _ = await runPipeline(transcript: "My address.", snippets: snippets, aiCleanup: false)
        XCTAssertEqual(gate.wordsThisWeek, before, "a snippet must not count words")

        _ = await runPipeline(transcript: "three words here", snippets: snippets, aiCleanup: false)
        XCTAssertEqual(gate.wordsThisWeek, before + 3, "a normal dictation still counts")
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
