import XCTest

@testable import OpenSuperWhisper

final class DictionaryLearnerTests: XCTestCase {
    /// Deterministic stand-in for the system word list.
    private let realWords: Set<String> = ["we", "use", "it", "daily", "their", "there", "the", "call",
                                          "with", "and", "tidy", "cal", "send", "hello", "jon",
                                          "any", "way", "anyway", "going", "can", "meet", "team", "ask",
                                          "shatter", "chatter", "fast", "last", "they", "tea",
                                          "good", "great"]
    private func learn(_ inserted: String, _ edited: String, open: Bool = false,
                       start: Bool = false) -> DictionaryLearner.Correction? {
        DictionaryLearner.correction(inserted: DictionaryLearner.words(inserted),
                                     edited: DictionaryLearner.words(edited), trailingOpen: open,
                                     atSentenceStart: start,
                                     isRealWord: { self.realWords.contains($0.lowercased()) })
    }

    func testRetypedBrandIsLearned() {
        XCTAssertEqual(learn("We use Apsumo daily.", "We use AppSumo daily."),
                       .init(heard: "Apsumo", correct: "AppSumo"))
        XCTAssertEqual(learn("Ask Clavio about it", "Ask Klaviyo about it"),
                       .init(heard: "Clavio", correct: "Klaviyo"))
    }

    func testCapitalsAddedInsideAWordAreLearned() {
        XCTAssertEqual(learn("post it on Appsumo today", "post it on AppSumo today"),
                       .init(heard: "Appsumo", correct: "AppSumo"))
    }

    func testJoinedNameIsLearned() {
        XCTAssertEqual(learn("the Tidy Cal sidebar", "the TidyCal sidebar"),
                       .init(heard: "Tidy Cal", correct: "TidyCal"))
    }

    func testRealWordSwapThatSoundsAlikeIsLearned() {
        XCTAssertEqual(learn("the shatter in the room", "the chatter in the room"),
                       .init(heard: "shatter", correct: "chatter"))
        XCTAssertEqual(learn("call Jon today", "call John today"), .init(heard: "Jon", correct: "John"))
    }

    func testLowercaseFixIsLearned() {
        XCTAssertEqual(learn("we use slak daily", "we use slack daily"),
                       .init(heard: "slak", correct: "slack"))
        XCTAssertEqual(learn("deploy to kubernets today", "deploy to kubernetes today"),
                       .init(heard: "kubernets", correct: "kubernetes"))
    }

    func testRealWordSwapThatChangesTheWordIsNotLearned() {
        XCTAssertNil(learn("we ship fast", "we ship last"), "close spelling, different sound")
        XCTAssertNil(learn("a good call", "a great call"), "too far apart")
    }

    func testGrammarWordsAreNeverRewritten() {
        XCTAssertNil(learn("put it in their folder", "put it in there folder"))
        XCTAssertNil(learn("ask the team", "ask they team"))
    }

    func testDistantWordIsNotLearned() {
        XCTAssertNil(learn("we use Apsumo daily", "we use Stripe daily"))
    }

    func testRewritesAreNotLearned() {
        XCTAssertNil(learn("we use Apsumo daily", "we use AppSumo every single day"))
        XCTAssertNil(learn("we use Apsumo daily", "We use Apsumo daily"), "sentence casing only")
        XCTAssertNil(learn("we use Apsumo daily", "we use Apsumo daily"))
    }

    func testTwoFixesAtOnceAreNotGuessed() {
        XCTAssertNil(learn("ask Clavio and Apsumo", "ask Klaviyo and AppSumo"))
    }

    func testTypingOnAfterTheDictationStillLearns() {
        XCTAssertEqual(learn("we use Apsumo daily", "we use AppSumo daily and love it", open: true),
                       .init(heard: "Apsumo", correct: "AppSumo"))
        XCTAssertEqual(learn("the Tidy Cal sidebar", "the TidyCal sidebar is live", open: true),
                       .init(heard: "Tidy Cal", correct: "TidyCal"))
    }

    func testFindsTheDictationInTheField() {
        let field = DictionaryLearner.words("Earlier text. We use Apsumo daily. More after")
        XCTAssertEqual(DictionaryAutoLearn.lastRange(of: DictionaryLearner.words("we use Apsumo daily"),
                                                     in: field), 2..<6)
        XCTAssertNil(DictionaryAutoLearn.lastRange(of: ["missing"], in: field))
    }

    // From code review (2026-11-11).

    func testSentenceStartCapitalIsNotKeptForARealWord() {
        XCTAssertEqual(learn("Shatter in the room", "Chatter in the room", start: true),
                       .init(heard: "shatter", correct: "chatter"))
        XCTAssertEqual(learn("we can meet. Shatter is loud", "we can meet. Chatter is loud"),
                       .init(heard: "shatter", correct: "chatter"))
        XCTAssertEqual(learn("Apsumo is great", "AppSumo is great", start: true),
                       .init(heard: "Apsumo", correct: "AppSumo"), "a name keeps its capitals")
    }

    func testSentenceCasingOnlyIsNotLearned() {
        XCTAssertNil(learn("Hello team", "hello team", start: true))
        XCTAssertNil(learn("we can meet. Going is fine", "we can meet. going is fine"))
    }

    func testJoinIntoAnOrdinaryWordIsLearned() {
        XCTAssertEqual(learn("Any way we can meet", "Anyway we can meet", start: true),
                       .init(heard: "any way", correct: "anyway"))
    }

    func testHalfTypedWordIsNotLearned() {
        XCTAssertNil(learn("ask the team", "ask the tea"), "deleting letters mid-edit")
    }

    // Casing where a learned lowercase rule is applied.

    func testLowercaseRuleKeepsASentenceStartCapital() {
        let rules = [CustomDictionaryEntry(original: "shatter", replacement: "chatter")]
        XCTAssertEqual(CustomDictionary.apply("Shatter is loud. The shatter stopped.", entries: rules),
                       "Chatter is loud. The chatter stopped.")
        XCTAssertEqual(CustomDictionary.apply("ok\nShatter again", entries: rules), "ok\nChatter again")
        XCTAssertEqual(CustomDictionary.apply("\"Shatter,\" she said", entries: rules), "\"Chatter,\" she said")
        XCTAssertEqual(CustomDictionary.apply("the Shatter app", entries: rules), "the chatter app",
                       "mid-sentence a lowercase rule writes lowercase")
    }

    func testLowercaseRuleMatchesWholeWordsOnly() {
        let rules = [CustomDictionaryEntry(original: "slak", replacement: "slack")]
        XCTAssertEqual(CustomDictionary.apply("slaked and slak", entries: rules), "slaked and slack")
    }

    func testCapitalizedRuleIsWrittenAsTyped() {
        let rules = [CustomDictionaryEntry(original: "apsumo", replacement: "AppSumo")]
        XCTAssertEqual(CustomDictionary.apply("apsumo rocks", entries: rules), "AppSumo rocks")
    }

    func testSoundAlikeKeepsASentenceStartCapitalForALowercaseTerm() {
        let rules = [CustomDictionaryEntry(original: "kubernets", replacement: "kubernetes")]
        XCTAssertEqual(SoundAlike.apply("Kubernetis is up. We run kubernetis.", entries: rules,
                                        isRealWord: { _ in false }),
                       "Kubernetes is up. We run kubernetes.")
    }

    func testPluralOrPossessiveIsNotLearned() {
        XCTAssertNil(learn("ask Klaviyo team", "ask Klaviyo's team"))
        XCTAssertNil(learn("ask Klaviyo", "ask Klaviyo's", open: true))
    }
}
