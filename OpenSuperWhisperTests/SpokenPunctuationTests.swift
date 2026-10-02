import XCTest

@testable import OpenSuperWhisper

/// Spoken punctuation commands ("period", "comma", "new paragraph") become the marks they
/// name, as part of smart formatting. The speech model brackets a dictated command with the
/// punctuation of its pause; a word that is part of the sentence has none, and stays.
final class SpokenPunctuationTests: XCTestCase {

    /// The customer email that reported it (2026-09-29), as the speech model produced it.
    /// Every command converts; every mention of the word ("put a period", "the word
    /// period", "new paragraphs") stays.
    func testCustomerEmail() {
        let raw = "Hey, so I just bought the tool and it seems pretty rad. Period. I will tell "
            + "you that based on using dictation on my phone, I'm in the habit of dictating when "
            + "to use punctuation and paragraph, like new paragraphs, period. And so when I do "
            + "that here in Rhino, it does not remove those, it actually inserts them as words. "
            + "Period. New paragraph: I did not clean up any of this message that I dictated, "
            + "comma, so you can see everything that I'm talking about here, period. New "
            + "paragraph. I get that it would be ideal not to do that. But I wasn't sure if "
            + "there was another way to have Rhino see that I was saying period in order to "
            + "put a period, not to have the word period. Etc."
        let expected = "Hey, so I just bought the tool and it seems pretty rad. I will tell "
            + "you that based on using dictation on my phone, I'm in the habit of dictating when "
            + "to use punctuation and paragraph, like new paragraphs. And so when I do "
            + "that here in Rhino, it does not remove those, it actually inserts them as words."
            + "\n\nI did not clean up any of this message that I dictated, "
            + "so you can see everything that I'm talking about here."
            + "\n\nI get that it would be ideal not to do that. But I wasn't sure if "
            + "there was another way to have Rhino see that I was saying period in order to "
            + "put a period, not to have the word period. Etc."
        XCTAssertEqual(SpokenPunctuation.apply(raw), expected)
    }

    /// Captured from Parakeet with pauses around the commands.
    func testPausedCommands() {
        XCTAssertEqual(
            SpokenPunctuation.apply(
                "Hi Sam comma. New paragraph. The site is live. Period. Thanks exclamation point."),
            "Hi Sam,\n\nThe site is live. Thanks!")
    }

    func testQuestionMarkReplacesTheGuessedMark() {
        XCTAssertEqual(SpokenPunctuation.apply("Is it ready. Question mark."), "Is it ready?")
        XCTAssertEqual(SpokenPunctuation.apply("Is it ready, question mark, the team asked"),
                       "Is it ready? The team asked")
    }

    func testNewLineAndColon() {
        XCTAssertEqual(SpokenPunctuation.apply("Action items. Colon. New line. Review the deck."),
                       "Action items:\nReview the deck.")
    }

    func testCommandAtTheEndOfTheText() {
        XCTAssertEqual(SpokenPunctuation.apply("See you there, period"), "See you there.")
        XCTAssertEqual(SpokenPunctuation.apply("See you there. New paragraph."), "See you there.")
    }

    // MARK: - Prose stays prose

    func testUnpunctuatedWordsStay() {
        for text in [
            "The trial period ended last week.",
            "We offer a grace period.",
            "The waiting period, as you know, is over.",
            "We're launching a new line of products.",
            "We're launching a new line.",
            "Start a new paragraph.",
            "He used a comma.",
            "Is this a question mark?",
            "Remove the word comma, then send it.",
            "Hey so it seems pretty rad period I will tell you",
            "I love the Oxford comma.",
            "His future is a big question mark.",
            "Remove that stray comma.",
            "Add one more comma, then send it.",
        ] {
            XCTAssertEqual(SpokenPunctuation.apply(text), text, text)
        }
    }

    /// The determiner lookback stays inside the clause: "that" ends the previous sentence.
    func testMentionCheckStopsAtTheClause() {
        XCTAssertEqual(SpokenPunctuation.apply("Love that. Sam comma. New paragraph. Bye."),
                       "Love that. Sam,\n\nBye.")
    }

    func testCommandAtTheStartIsLeftAlone() {
        XCTAssertEqual(SpokenPunctuation.apply("Period. That's final."), "Period. That's final.")
    }

    func testDoesNotTouchExistingLineBreaks() {
        XCTAssertEqual(SpokenPunctuation.apply("First line\n\nsecond, comma, third"),
                       "First line\n\nsecond, third")
    }
}
