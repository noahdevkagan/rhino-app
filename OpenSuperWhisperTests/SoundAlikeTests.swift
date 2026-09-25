import XCTest

@testable import OpenSuperWhisper

/// A rule's word fixes the spellings a model invents for it, without the user listing them.
///
/// The report that started this (2026-09-25): "Klaviyo" always landed as "Clavio", and the user
/// had no way to know that was the spelling to type into a rule. The cases here pin both halves
/// of the contract: near-misses are fixed, and real words never are.
final class SoundAlikeTests: XCTestCase {

    private let klaviyo = CustomDictionaryEntry(replacement: "Klaviyo")

    /// Tests use a fixed word list so they don't depend on the machine's /usr/share/dict.
    private let realWords: Set<String> = ["strip", "notion", "air", "table", "git", "hub", "the"]
    private func isRealWord(_ word: String) -> Bool { realWords.contains(word.lowercased()) }

    private func fix(_ text: String, _ entries: [CustomDictionaryEntry]) -> String {
        SoundAlike.apply(text, entries: entries, isRealWord: isRealWord)
    }

    func testTheReportedMishearingIsFixedWithoutAnyPhrasing() {
        XCTAssertEqual(fix("I set up the Clavio flow.", [klaviyo]), "I set up the Klaviyo flow.")
    }

    func testOtherNearMissesAreFixedToo() {
        for heard in ["Claviyo", "Klavio", "clavio", "klaviyo"] {
            XCTAssertEqual(fix("send it to \(heard) today", [klaviyo]), "send it to Klaviyo today",
                           heard)
        }
    }

    func testPossessivesKeepTheirEnding() {
        XCTAssertEqual(fix("Clavio's editor", [klaviyo]), "Klaviyo's editor")
    }

    func testRealWordsAreNeverChanged() {
        let stripe = CustomDictionaryEntry(replacement: "Stripe")
        XCTAssertEqual(fix("strip the text", [stripe]), "strip the text")

        // Same spelling, different casing — but the brand is also an ordinary word.
        let notion = CustomDictionaryEntry(replacement: "Notion")
        XCTAssertEqual(fix("I had a notion", [notion]), "I had a notion")
    }

    func testDifferentSoundingWordsAreLeftAlone() {
        XCTAssertEqual(fix("Clive and Olivia", [klaviyo]), "Clive and Olivia")
        XCTAssertEqual(fix("classic video", [klaviyo]), "classic video")
    }

    func testSplitCompoundsAreJoined() {
        let github = CustomDictionaryEntry(replacement: "GitHub")
        XCTAssertEqual(fix("push it to git hub now", [github]), "push it to GitHub now")

        let airtable = CustomDictionaryEntry(replacement: "Airtable")
        XCTAssertEqual(fix("the air table base", [airtable]), "the Airtable base")
    }

    /// Close-but-not-exact pairs were the main source of false fixes over real text.
    func testPairsMustSpellTheWordExactly() {
        let asana = CustomDictionaryEntry(replacement: "Asana")
        XCTAssertEqual(fix("as an example", [asana]), "as an example")

        let youtube = CustomDictionaryEntry(replacement: "YouTube")
        XCTAssertEqual(fix("you type it", [youtube]), "you type it")
    }

    func testLinksAndAddressesAreLeftAlone() {
        let github = CustomDictionaryEntry(replacement: "GitHub")
        XCTAssertEqual(fix("see github.com/me/repo", [github]), "see github.com/me/repo")

        let gmail = CustomDictionaryEntry(replacement: "Gmail")
        XCTAssertEqual(fix("mail noah@gmial.com", [gmail]), "mail noah@gmial.com")
    }

    func testCloseTechnicalWordsNeedMoreThanTwoLetterSwaps() {
        let github = CustomDictionaryEntry(replacement: "GitHub")
        XCTAssertEqual(fix("run gitweb locally", [github]), "run gitweb locally")
    }

    func testShortWordsNeedAnExactPhrasing() {
        let figma = CustomDictionaryEntry(replacement: "Figma")
        XCTAssertEqual(fix("open Figmo", [figma]), "open Figma")

        let loom = CustomDictionaryEntry(replacement: "Loom")
        XCTAssertEqual(fix("record a Lume", [loom]), "record a Lume")
    }

    func testAnotherRulesWordIsNotTreatedAsAMishearing() {
        let clavio = CustomDictionaryEntry(original: "clavio pay", replacement: "Clavio")
        XCTAssertEqual(fix("Clavio and Klaviyo", [klaviyo, clavio]), "Clavio and Klaviyo")
    }

    func testMultiWordAndPunctuationRulesDontGuess() {
        let phrase = CustomDictionaryEntry(replacement: "My Monkey")
        let quote = CustomDictionaryEntry(original: "open quote", replacement: "\"")
        XCTAssertTrue(SoundAlike.eligibleTerms([phrase, quote]).isEmpty)
    }

    func testSkeletonCollapsesWhatModelsConfuse() {
        XCTAssertEqual(SoundAlike.skeleton("Klaviyo"), SoundAlike.skeleton("Clavio"))
        XCTAssertEqual(SoundAlike.skeleton("Kubernetes"), SoundAlike.skeleton("Cubernetes"))
        XCTAssertNotEqual(SoundAlike.skeleton("Notion"), SoundAlike.skeleton("motion"))
    }

    func testTheSystemWordListGuardsTheRealPass() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/usr/share/dict/words"))
        XCTAssertTrue(SystemWordList.contains("strip"))
        XCTAssertFalse(SystemWordList.contains("clavio"))
        XCTAssertEqual(SoundAlike.apply("the Clavio flow", entries: [klaviyo]), "the Klaviyo flow")
    }
}

/// The dictionary runs again after LLM cleanup, so a rule must not compound on the second pass.
final class DictionaryReapplyTests: XCTestCase {

    func testRulesThatContainTheirTriggerRunOnlyOnce() {
        let growing = CustomDictionaryEntry(original: "noah", replacement: "Noah Kagan")
        let plain = CustomDictionaryEntry(original: "clavio", replacement: "Klaviyo")
        XCTAssertEqual(CustomDictionary.reapplicable([growing, plain]).map(\.replacement),
                       ["Klaviyo"])
    }

    func testTheSecondPassPutsBackASpellingCleanupUndid() {
        let rule = CustomDictionaryEntry(original: "clavio", replacement: "Klaviyo")
        let afterCleanup = "We moved the flows to Clavio."
        XCTAssertEqual(CustomDictionary.correct(afterCleanup,
                                                entries: CustomDictionary.reapplicable([rule]),
                                                soundAlikes: false),
                       "We moved the flows to Klaviyo.")
    }
}

/// Teaching a word from a history row.
final class DictionaryTeachingTests: XCTestCase {

    func testTeachingAddsARule() {
        let entries = CustomDictionary.teaching(heard: "Clavio", correct: "Klaviyo", to: [])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(CustomDictionary.apply("the Clavio flow", entries: entries),
                       "the Klaviyo flow")
    }

    func testTeachingFoldsIntoTheRuleThatAlreadyWritesIt() {
        let existing = CustomDictionaryEntry(original: "claviyo", replacement: "Klaviyo")
        let entries = CustomDictionary.teaching(heard: "Clavio", correct: "Klaviyo",
                                                to: [existing])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].triggers, ["claviyo", "Clavio"])
    }

    func testNothingToTeachChangesNothing() {
        let existing = [CustomDictionaryEntry(original: "a", replacement: "b")]
        XCTAssertEqual(CustomDictionary.teaching(heard: " ", correct: "Klaviyo", to: existing),
                       existing)
        XCTAssertEqual(CustomDictionary.teaching(heard: "Klaviyo", correct: "Klaviyo",
                                                 to: existing), existing)
    }

    func testPickableWordsDropSentencePunctuationAndRepeats() {
        XCTAssertEqual(CustomDictionary.pickableWords(in: "Clavio's flow, then Clavio's list. 42!"),
                       ["Clavio's", "flow", "then", "list"])
    }
}
