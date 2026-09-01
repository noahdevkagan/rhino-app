import XCTest

@testable import OpenSuperWhisper

/// The phantom-word filter may only ever drop whisper's stock silence phrases, and only when
/// paired with acoustic evidence. These pin both halves: what counts as a stock phrase, and
/// that segments are dropped strictly from the end and only above the no-speech threshold —
/// a customer really dictating "Thank you." must always keep it.
final class SilenceHallucinationTests: XCTestCase {

    // MARK: - Phrase matching

    func testMatchesStockPhrasesThroughCaseAndPunctuation() {
        XCTAssertTrue(WhisperEngine.isKnownSilenceHallucination("Thank you."))
        XCTAssertTrue(WhisperEngine.isKnownSilenceHallucination(" THANK YOU! "))
        XCTAssertTrue(WhisperEngine.isKnownSilenceHallucination("Thanks for watching!"))
        XCTAssertTrue(WhisperEngine.isKnownSilenceHallucination("you"))
        XCTAssertTrue(WhisperEngine.isKnownSilenceHallucination("Bye-bye."))
        XCTAssertTrue(WhisperEngine.isKnownSilenceHallucination(
            "Subtitles by the Amara.org community"))
    }

    func testDoesNotMatchRealDictation() {
        XCTAssertFalse(WhisperEngine.isKnownSilenceHallucination(""))
        XCTAssertFalse(WhisperEngine.isKnownSilenceHallucination(
            "Thank you for the report, I'll review it tomorrow."))
        XCTAssertFalse(WhisperEngine.isKnownSilenceHallucination("you are right"))
        XCTAssertFalse(WhisperEngine.isKnownSilenceHallucination("thanks everyone, see you Monday"))
    }

    // MARK: - Trailing-segment trim

    private let threshold: Float = 0.6

    func testDropsTrailingHallucinationWhisperScoredAsNonSpeech() {
        let kept = WhisperEngine.trimmingTrailingHallucinations(
            texts: ["Send the invoice today.", " Thank you."],
            noSpeechProbs: [0.05, 0.92],
            threshold: threshold)
        XCTAssertEqual(kept, ["Send the invoice today."])
    }

    func testDropsSeveralTrailingHallucinations() {
        let kept = WhisperEngine.trimmingTrailingHallucinations(
            texts: ["Ship it.", " Thank you.", " Bye."],
            noSpeechProbs: [0.1, 0.8, 0.95],
            threshold: threshold)
        XCTAssertEqual(kept, ["Ship it."])
    }

    /// A confident final "Thank you." is the user actually saying thank you.
    func testKeepsTrailingThankYouWhisperHeardAsSpeech() {
        let texts = ["That would be great.", " Thank you."]
        let kept = WhisperEngine.trimmingTrailingHallucinations(
            texts: texts, noSpeechProbs: [0.05, 0.1], threshold: threshold)
        XCTAssertEqual(kept, texts)
    }

    /// A non-speech score alone never drops a segment whose text isn't a stock phrase.
    func testKeepsUnrecognizedTextRegardlessOfScore() {
        let texts = ["The quarterly numbers look solid."]
        let kept = WhisperEngine.trimmingTrailingHallucinations(
            texts: texts, noSpeechProbs: [0.99], threshold: threshold)
        XCTAssertEqual(kept, texts)
    }

    /// Interior segments are never touched, even when they'd qualify at the end.
    func testOnlyTrimsFromTheEnd() {
        let texts = [" Thank you.", "Now the real content."]
        let kept = WhisperEngine.trimmingTrailingHallucinations(
            texts: texts, noSpeechProbs: [0.9, 0.05], threshold: threshold)
        XCTAssertEqual(kept, texts)
    }

    func testAllSegmentsHallucinatedYieldsEmpty() {
        let kept = WhisperEngine.trimmingTrailingHallucinations(
            texts: [" Thank you."], noSpeechProbs: [0.9], threshold: threshold)
        XCTAssertTrue(kept.isEmpty)
    }
}
