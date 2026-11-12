import XCTest

@testable import OpenSuperWhisper

final class DictionaryLearnerTests: XCTestCase {
    /// Deterministic stand-in for the system word list.
    private let realWords: Set<String> = ["we", "use", "it", "daily", "their", "there", "the", "call",
                                          "with", "and", "tidy", "cal", "send", "hello", "jon"]
    private func learn(_ inserted: String, _ edited: String, open: Bool = false) -> DictionaryLearner.Correction? {
        DictionaryLearner.correction(inserted: DictionaryLearner.words(inserted),
                                     edited: DictionaryLearner.words(edited), trailingOpen: open,
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

    func testRealWordSwapIsNeverLearned() {
        XCTAssertNil(learn("put it in their folder", "put it in There folder"))
        XCTAssertNil(learn("call Jon today", "call John today"), "a real name the user knows stays")
    }

    func testLowercaseFixIsNotLearned() {
        XCTAssertNil(learn("we use slak daily", "we use slack daily"))
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
}
