import XCTest

@testable import OpenSuperWhisper

final class DictionaryLearnerTests: XCTestCase {
    /// Uses the real system word list (/usr/share/dict/words): the real-word rules depend on
    /// which words it has and in which case ("mark" and "Mark", "John" only as a name).
    private func learn(_ inserted: String, _ edited: String, open: Bool = false,
                       start: Bool = false) -> DictionaryLearner.Correction? {
        DictionaryLearner.correction(inserted: DictionaryLearner.words(inserted),
                                     edited: DictionaryLearner.words(edited), trailingOpen: open,
                                     atSentenceStart: start)
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

    func testRealWordMishearingIsLearned() {
        XCTAssertEqual(learn("the shatter in the room", "the chatter in the room"),
                       .init(heard: "shatter", correct: "chatter"))
    }

    func testLowercaseFixIsLearned() {
        XCTAssertEqual(learn("we use slak daily", "we use slack daily"),
                       .init(heard: "slak", correct: "slack"))
        XCTAssertEqual(learn("deploy to kubernets today", "deploy to kubernetes today"),
                       .init(heard: "kubernets", correct: "kubernetes"))
    }

    func testRealWordSwapThatChangesTheWordIsNotLearned() {
        for (heard, typed) in [("ran", "run"), ("write", "wrote"), ("man", "men"), ("form", "from"),
                               ("quite", "quiet"), ("angel", "angle"), ("advice", "advise"),
                               ("bad", "bed"), ("sit", "set"), ("three", "tree"), ("fast", "last")] {
            XCTAssertNil(learn("we \(heard) it today", "we \(typed) it today"), "\(heard) → \(typed)")
        }
        XCTAssertNil(learn("a good call", "a great call"), "too far apart")
    }

    func testGrammarWordsAreNeverRewritten() {
        XCTAssertNil(learn("put it in their folder", "put it in there folder"))
        XCTAssertNil(learn("ask the team", "ask they team"))
    }

    func testRealWordIntoNonWordIsNotLearned() {
        XCTAssertNil(learn("we are going now", "we are goin now"))
        XCTAssertNil(learn("we use it daily", "we use it dialy"))
    }

    func testOrdinaryWordIntoANameIsNotLearned() {
        XCTAssertNil(learn("please mark it done", "please Marc it done"))
        XCTAssertNil(learn("Mark it done", "Marc it done", start: true))
    }

    func testNamesAreNotLowercasedAtASentenceStart() {
        XCTAssertNil(learn("Jon called today", "John called today", start: true),
                     "two real names: a different person, not a mishearing")
        XCTAssertEqual(learn("Clavio is great", "Klaviyo is great", start: true),
                       .init(heard: "Clavio", correct: "Klaviyo"))
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

    func testJoinIntoAnOrdinaryWordIsNotLearned() {
        XCTAssertNil(learn("Any way we can meet", "Anyway we can meet", start: true))
        for (heard, typed) in [("may be", "maybe"), ("every day", "everyday"), ("in to", "into"),
                               ("all ready", "already")] {
            XCTAssertNil(learn("we \(heard) there", "we \(typed) there"), "\(heard) → \(typed)")
        }
    }

    func testHalfTypedWordIsNotLearned() {
        XCTAssertNil(learn("deploy to kubernets today", "deploy to kuber today"))
        XCTAssertNil(learn("we use Apsumo", "we use Ap", open: true))
    }

    func testCorrectionMustHoldForSeveralPolls() {
        let fix = DictionaryLearner.Correction(heard: "Apsumo", correct: "AppSumo")
        let other = DictionaryLearner.Correction(heard: "Apsumo", correct: "AppSum")
        var stability = DictionaryLearner.Stability()
        XCTAssertFalse(stability.observe(other, required: 3))
        XCTAssertFalse(stability.observe(fix, required: 3), "changed since the last poll")
        XCTAssertFalse(stability.observe(fix, required: 3))
        XCTAssertFalse(stability.observe(nil, required: 3), "a poll without it resets")
        XCTAssertFalse(stability.observe(fix, required: 3))
        XCTAssertFalse(stability.observe(fix, required: 3))
        XCTAssertTrue(stability.observe(fix, required: 3))
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
        XCTAssertEqual(CustomDictionary.apply("step 2.Shatter", entries: rules), "step 2.chatter",
                       "a period with no space after isn't a sentence end")
        XCTAssertEqual(CustomDictionary.apply("loud ones, e.g. Shatter", entries: rules),
                       "loud ones, e.g. chatter")
    }

    func testLowercaseRuleMatchesWholeWordsOnly() {
        let rules = [CustomDictionaryEntry(original: "slak", replacement: "slack")]
        XCTAssertEqual(CustomDictionary.apply("slaked and slak", entries: rules), "slaked and slack")
    }

    func testCapitalizedRuleIsWrittenAsTyped() {
        let rules = [CustomDictionaryEntry(original: "apsumo", replacement: "AppSumo")]
        XCTAssertEqual(CustomDictionary.apply("apsumo rocks", entries: rules), "AppSumo rocks")
    }

    func testOrdinaryLowercaseWordIsNotASoundAlikeTerm() {
        let rules = [CustomDictionaryEntry(original: "shatter", replacement: "chatter")]
        XCTAssertEqual(SoundAlike.apply("the chattar", entries: rules,
                                        isRealWord: { ["chatter", "shatter"].contains($0) }),
                       "the chattar", "a learned ordinary word is an exact rule only")
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
