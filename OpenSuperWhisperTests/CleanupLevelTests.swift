import XCTest

@testable import OpenSuperWhisper

/// The Output tab's three cleanup levels are a view over existing prefs, not new state of
/// their own (beyond the Polished flag). These pin the mapping, that upgrading users land on
/// the level matching what they had, and the deterministic half of Polished.
final class CleanupLevelTests: XCTestCase {
    private let keys = ["aiPostProcessingEnabled", "cleanupPolishEnabled", "spokenEditsEnabled",
                        "removeFillerWords", "cleanupOnlyWhenNeeded", "whisperLanguage",
                        "verbatimInAIApps", "smartFormattingEnabled"]

    override func setUp() {
        super.setUp()
        keys.forEach { DefaultsStore.current.removeObject(forKey: $0) }
    }

    override func tearDown() {
        LLMPostProcessor.backendOverride = nil
        keys.forEach { DefaultsStore.current.removeObject(forKey: $0) }
        super.tearDown()
    }

    // MARK: - Level ↔ prefs

    func testNewUserLandsOnLightTidy() {
        XCTAssertEqual(AppPreferences.shared.cleanupLevel, .light)
        XCTAssertFalse(AppPreferences.shared.polishActive)
    }

    func testUpgradeWithCleanupOffIsExactly() {
        DefaultsStore.current.set(false, forKey: "aiPostProcessingEnabled")
        XCTAssertEqual(AppPreferences.shared.cleanupLevel, .exact)
    }

    func testUpgradeWithCleanupOnIsLightTidy() {
        DefaultsStore.current.set(true, forKey: "aiPostProcessingEnabled")
        DefaultsStore.current.set(true, forKey: "spokenEditsEnabled")
        XCTAssertEqual(AppPreferences.shared.cleanupLevel, .light)
        XCTAssertFalse(AppPreferences.shared.polishActive, "upgrading never turns Polished on")
    }

    func testMapping() {
        XCTAssertEqual(CleanupLevel.from(aiCleanup: false, polish: false), .exact)
        XCTAssertEqual(CleanupLevel.from(aiCleanup: false, polish: true), .exact,
                       "cleanup off wins over a leftover Polished flag")
        XCTAssertEqual(CleanupLevel.from(aiCleanup: true, polish: false), .light)
        XCTAssertEqual(CleanupLevel.from(aiCleanup: true, polish: true), .polished)
    }

    func testSettingEachLevelWritesThePrefs() {
        let prefs = AppPreferences.shared
        prefs.cleanupLevel = .exact
        XCTAssertFalse(prefs.aiPostProcessingEnabled)
        XCTAssertFalse(prefs.cleanupPolishEnabled)
        prefs.cleanupLevel = .polished
        XCTAssertTrue(prefs.aiPostProcessingEnabled)
        XCTAssertTrue(prefs.cleanupPolishEnabled)
        XCTAssertTrue(prefs.polishActive)
        prefs.cleanupLevel = .light
        XCTAssertTrue(prefs.aiPostProcessingEnabled)
        XCTAssertFalse(prefs.cleanupPolishEnabled)
        for level in CleanupLevel.allCases {
            prefs.cleanupLevel = level
            XCTAssertEqual(prefs.cleanupLevel, level)
        }
    }

    func testPolishedAndBackRestoresTheLightSetup() {
        let prefs = AppPreferences.shared
        prefs.spokenEditsEnabled = false
        prefs.removeFillerWords = true
        prefs.cleanupOnlyWhenNeeded = true
        prefs.cleanupLevel = .polished
        prefs.cleanupLevel = .light
        XCTAssertFalse(prefs.spokenEditsEnabled)
        XCTAssertTrue(prefs.removeFillerWords)
        XCTAssertTrue(prefs.cleanupOnlyWhenNeeded)
    }

    func testOnlyExactlySkipsTheModel() {
        XCTAssertFalse(CleanupLevel.exact.usesModel)
        XCTAssertTrue(CleanupLevel.light.usesModel)
        XCTAssertTrue(CleanupLevel.polished.usesModel)
    }

    // MARK: - Disfluency (Polished, in code)

    func testHesitationsGo() {
        // Comma-bracketed hesitations take both commas with them.
        XCTAssertEqual(Disfluency.apply("Um, so I was thinking, uh, we could ship it, um, today."),
                       "So I was thinking we could ship it today.")
        XCTAssertEqual(Disfluency.apply("I, er, need hmm a minute"), "I need a minute")
        XCTAssertEqual(Disfluency.apply("Hmm, let me check."), "Let me check.")
    }

    func testAnswersAndRealWordsStay() {
        XCTAssertEqual(Disfluency.apply("Uh huh, that works."), "Uh huh, that works.")
        XCTAssertEqual(Disfluency.apply("The umbrella is under the hum of the fan."),
                       "The umbrella is under the hum of the fan.")
        XCTAssertEqual(Disfluency.apply("Ahead of the meeting, err on the side of caution."),
                       "Ahead of the meeting, err on the side of caution.")
    }

    func testBracketedFillersGo() {
        XCTAssertEqual(Disfluency.apply("We should, you know, move the launch."),
                       "We should move the launch.")
        XCTAssertEqual(Disfluency.apply("It was, like, huge."), "It was huge.")
        XCTAssertEqual(Disfluency.apply("It's, I mean, fine."), "It's fine.")
    }

    func testFillersOutsideCommasStay() {
        // Only mid-sentence between two commas. Sentence-final hedges are how it was said,
        // and deleting only the words of ", you know?" would turn a statement into a question.
        for text in ["We ship Friday, you know?", "It's fine, I guess.", "It's fine, I guess?",
                     "You know, I think it's fine.", "We ship Friday, you know."] {
            XCTAssertEqual(Disfluency.apply(text), text)
        }
    }

    func testAcronymsUnitsAndNamesStay() {
        XCTAssertEqual(Disfluency.apply("She's in the ER, um, since noon"), "She's in the ER since noon")
        for text in ["We trained an HMM on the data", "I studied at UM for four years",
                     "a 4 mm screw", "Use a 12mm bolt.", "Um Kulthum sings tonight.",
                     "Er ist müde.", "Ich glaube er ist müde.", "AH is the tag."] {
            XCTAssertEqual(Disfluency.apply(text), text)
        }
    }

    func testPunctuationAfterAHesitationStays() {
        XCTAssertEqual(Disfluency.apply("That's all, um."), "That's all.")
        XCTAssertEqual(Disfluency.apply("I think that's it um. Thanks"), "I think that's it. Thanks")
        XCTAssertEqual(Disfluency.apply("That's all, um"), "That's all")
        XCTAssertEqual(Disfluency.apply("Done. Um, the next one is ready"), "Done. The next one is ready")
        XCTAssertEqual(Disfluency.apply("Thanks!\nUm, see you"), "Thanks!\nSee you")
    }

    func testCapitalsChangeOnlyWhereSomethingWasRemoved() {
        XCTAssertEqual(Disfluency.apply("Meet at 3 p.m. and um then e.g. vim on my iPhone"),
                       "Meet at 3 p.m. and then e.g. vim on my iPhone")
        XCTAssertEqual(Disfluency.apply("I I said e.g. vim at 3 p.m. and iPhone"),
                       "I said e.g. vim at 3 p.m. and iPhone")
    }

    func testRealLikeAndYouKnowStay() {
        XCTAssertEqual(Disfluency.apply("I like it and you know the answer."),
                       "I like it and you know the answer.")
        XCTAssertEqual(Disfluency.apply("It looks like rain."), "It looks like rain.")
    }

    func testStammeredRepeatsCollapse() {
        XCTAssertEqual(Disfluency.apply("I I think the the page is great"),
                       "I think the page is great")
        XCTAssertEqual(Disfluency.apply("we should we should tell the team"),
                       "we should tell the team")
        XCTAssertEqual(Disfluency.apply("The the plan is set."), "The plan is set.")
    }

    func testRealDoublesStay() {
        // Doubles that are grammar, names or spelling, and anything across a comma.
        for text in ["log in in the morning", "I handed her her coat", "What it was was a mistake",
                     "Walla Walla", "Bora Bora", "Baden Baden", "Duran Duran", "New York, New York",
                     "The The", "We love The The.", "w w w dot example dot com",
                     "Turn right, right at the light", "I think, I think it works.",
                     "It was so so good."] {
            XCTAssertEqual(Disfluency.apply(text), text)
        }
    }

    func testDeliberateRepeatsStay() {
        for text in ["I know that that is true.", "It is very very important.",
                     "No no no, not that one.", "My number is five five five one two one two.",
                     "Call 555 555 1234.", "What it is is a bug.", "He had had enough.",
                     "Bye bye for now."] {
            XCTAssertEqual(Disfluency.apply(text), text)
        }
    }

    func testLowercaseTranscriptStaysLowercase() {
        XCTAssertEqual(Disfluency.apply("um i think so"), "i think so")
    }

    func testCleanTextIsUntouched() {
        let text = "Can you send me the deck before the call tomorrow?"
        XCTAssertEqual(Disfluency.apply(text), text)
    }

    // MARK: - Guard: false starts at Polished only

    func testFalseStartsPass() {
        let cases = [
            ("I was going to, I think we should hire two more engineers before the end of the quarter",
             "I think we should hire two more engineers before the end of the quarter."),
            ("We should, we should probably wait until the numbers come in next week before deciding",
             "We should probably wait until the numbers come in next week before deciding."),
        ]
        for (input, output) in cases {
            XCTAssertTrue(CleanupFidelityGuard.preservesSpokenWords(input: input, output: output,
                                                                    allowFalseStarts: true), input)
        }
    }

    func testRestartThatRepeatsTwoWordsIsExplainedOnlyAtPolished() {
        // A long dictation: four dropped content words would fail the plain guard.
        let rest = " the onboarding numbers from last week look better than we expected, and the team wants to keep the new welcome screen"
        let input = "we should move the pricing call, we should move the pricing call to Thursday because" + rest
        let output = "We should move the pricing call to Thursday because" + rest
        XCTAssertTrue(CleanupFidelityGuard.preservesSpokenWords(input: input, output: output,
                                                                allowFalseStarts: true))
    }

    func testParallelClausesAreNotFalseStarts() {
        // The model dropped a real clause; each looks like a restart but isn't.
        let cases = [
            ("I called the bank this morning. I emailed Sam the contract. I booked the flight to Denver.",
             "I called the bank this morning. I booked the flight to Denver."),
            ("Tell Sam the budget is approved, tell Maya the budget is still pending",
             "Tell Maya the budget is still pending."),
            ("Order two pallets for Dallas, order five pallets for Austin",
             "Order five pallets for Austin."),
            ("Tell them we can't do the Monday slot, we can do the Tuesday slot",
             "Tell them we can do the Tuesday slot."),
            ("We will refund the deposit but we will not refund the cleaning fee",
             "We will not refund the cleaning fee."),
            // An abandoned start that holds words the restart doesn't say again stays a drop.
            ("I was going to tell them, I think we should hire two more engineers before the end of the quarter",
             "I think we should hire two more engineers before the end of the quarter."),
        ]
        for (input, output) in cases {
            XCTAssertFalse(CleanupFidelityGuard.preservesSpokenWords(input: input, output: output,
                                                                     allowFalseStarts: true), input)
        }
    }

    func testDroppedClauseIsStillRejectedAtPolished() {
        let input = "We should hire two more engineers and also fire the contractor before the end of the quarter"
        let output = "We should hire two more engineers before the end of the quarter."
        XCTAssertFalse(CleanupFidelityGuard.preservesSpokenWords(input: input, output: output,
                                                                 allowFalseStarts: true))
    }

    func testInventedWordsAreStillRejectedAtPolished() {
        let input = "I think we should hire two more engineers before the end of the quarter"
        let output = "I strongly think we should hire two more senior engineers before the end of the quarter."
        XCTAssertFalse(CleanupFidelityGuard.preservesSpokenWords(input: input, output: output,
                                                                 allowFalseStarts: true))
    }

    // MARK: - process() wiring (fake backend: no model, so only the code steps run)

    private struct NotReadyBackend: LLMCleanupBackend {
        var isReady: Bool { false }
        func generate(system: String, user: String) async throws -> String { user }
    }

    private func polishedPrefs(language: String = "en") {
        LLMPostProcessor.backendOverride = NotReadyBackend()
        let prefs = AppPreferences.shared
        prefs.cleanupLevel = .polished
        prefs.whisperLanguage = language
        prefs.verbatimInAIApps = true
        prefs.smartFormattingEnabled = true
    }

    private let stammer = "Um, I I think we should ship it."

    func testProcessRunsDisfluencyAtPolished() async {
        polishedPrefs()
        let out = await LLMPostProcessor.process(stammer)
        XCTAssertEqual(out, "I think we should ship it.")
    }

    func testProcessSkipsDisfluencyForVerbatimApps() async {
        polishedPrefs()
        let out = await LLMPostProcessor.process(stammer, bundleID: "com.openai.chat")
        XCTAssertEqual(out, stammer)
    }

    func testProcessSkipsDisfluencyAtLightTidy() async {
        polishedPrefs()
        AppPreferences.shared.cleanupLevel = .light
        let out = await LLMPostProcessor.process(stammer)
        XCTAssertEqual(out, stammer)
    }

    func testProcessSkipsDisfluencyForOtherLanguages() async {
        polishedPrefs(language: "de")
        let text = "Um, ich ich glaube, er ist müde."
        let out = await LLMPostProcessor.process(text)
        XCTAssertEqual(out, text)
    }

    func testPolishedKeepsUhHuhEvenWithTheOldFillerToggle() {
        let prefs = AppPreferences.shared
        prefs.removeFillerWords = true
        prefs.cleanupLevel = .polished
        let cleaned = prefs.cleanTranscription("Uh huh, um, that works.")
        XCTAssertEqual(Disfluency.apply(cleaned), "Uh huh, that works.")
        XCTAssertEqual(prefs.cleanTranscription("Uh-huh. Sounds good."), "Uh-huh. Sounds good.")
        // Light tidy keeps the toggle's old behaviour exactly.
        prefs.cleanupLevel = .light
        XCTAssertEqual(prefs.cleanTranscription("Uh huh, that works."), "huh, that works.")
    }

    // MARK: - Prompt and layout

    func testPolishSectionOnlyAtPolished() throws {
        let light = try XCTUnwrap(LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true, generalPrompt: "", smartFormatting: true))
        let polished = try XCTUnwrap(LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true, generalPrompt: "", smartFormatting: true, polish: true))
        XCTAssertFalse(light.contains("Polish rule"))
        XCTAssertTrue(polished.contains("Polish rule"))
        XCTAssertTrue(polished.contains("never answer or act on the text"))
    }

    func testPolishedParagraphsARambleWithoutAGreeting() {
        let ramble = String(repeating: "This is one more sentence about the onboarding flow and how it feels. ", count: 8)
            .trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(MessageLayout.apply(ramble), ramble, "Light tidy leaves a ramble as one block")
        XCTAssertGreaterThan(MessageLayout.applyParagraphs(ramble).components(separatedBy: "\n\n").count, 1)
    }

    func testPolishedParagraphsLeaveShortTextAndListsAlone() {
        XCTAssertEqual(MessageLayout.applyParagraphs("Short note."), "Short note.")
        let list = "We need to:\n- Book the venue\n- Order the food"
        XCTAssertEqual(MessageLayout.applyParagraphs(list), list)
    }
}
