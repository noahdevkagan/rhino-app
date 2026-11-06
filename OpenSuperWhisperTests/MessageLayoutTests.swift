import XCTest

@testable import OpenSuperWhisper

/// Long dictated messages get their layout from code because the cleanup model returns
/// them as one block (decisions.md, 2026-11-05). What matters here: every spoken word
/// survives, the message shape is right, and ordinary dictations are left alone.
final class MessageLayoutTests: XCTestCase {
    private let body = "I wanted to follow up on the website launch we talked about on Monday. "
        + "The designers finished the new homepage and it looks really good to me. "
        + "We still need the final copy for the pricing section before we can ship it. "
        + "Maria said she can get that done by Thursday if nothing else comes up. "
        + "Second thing is the customer webinar, which I think we should move to next month. "
        + "Attendance has been low in the summer and the team is pretty stretched right now. "
        + "That would give us more room to edit and a cleaner video for the blog afterward. "
        + "In terms of the budget, finance approved the extra spend for the conference booth."

    private func words(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func paragraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
    }

    func testGreetingGetsItsOwnLineAndTheNextSentenceACapital() {
        let output = MessageLayout.apply("Hey Sam, hope your week is going well. " + body)
        XCTAssertEqual(paragraphs(output).first, "Hey Sam,")
        XCTAssertTrue(paragraphs(output)[1].hasPrefix("Hope your week"), output)
    }

    func testEveryWordSurvivesInOrder() {
        let input = "Hey Sam, hope your week is going well. " + body + " Thanks so much. Best wishes, Noah."
        XCTAssertEqual(words(MessageLayout.apply(input)), words(input))
    }

    func testTopicCuesOpenParagraphs() {
        let output = paragraphs(MessageLayout.apply("Hey Sam, hope your week is going well. " + body))
        XCTAssertTrue(output.contains { $0.hasPrefix("Second thing is the customer webinar") }, "\(output)")
        XCTAssertTrue(output.contains { $0.hasPrefix("In terms of the budget") }, "\(output)")
    }

    func testNoParagraphRunsPastTheSentenceLimit() {
        let plain = (1...20).map { "This plain sentence number \($0) has no topic cue in it." }
        let output = paragraphs(MessageLayout.apply("Hi Sam, " + plain.joined(separator: " ")))
        XCTAssertGreaterThan(output.count, 4)
        for paragraph in output {
            XCTAssertLessThanOrEqual(paragraph.components(separatedBy: ". ").count, 4, paragraph)
        }
    }

    func testAContinuationStaysWithTheSentenceBeforeIt() {
        let output = paragraphs(MessageLayout.apply("Hey Sam, hope your week is going well. " + body))
        XCTAssertFalse(output.contains { $0.hasPrefix("That would give us") }, "\(output)")
    }

    func testSignOffBlock() {
        let output = MessageLayout.apply("Hi Sam, " + body + " Thanks so much. Best wishes, Noah.")
        XCTAssertTrue(output.hasSuffix("\n\nThanks so much.\n\nBest wishes,\nNoah"), output)
    }

    func testASignOffAloneMakesItAMessage() {
        let output = MessageLayout.apply(body + " Cheers, Noah.")
        XCTAssertTrue(output.hasSuffix("\n\nCheers,\nNoah"), output)
        XCTAssertTrue(output.contains("\n\nSecond thing"), output)
    }

    func testNamelessGreetingsAndSentencesThatOnlyStartLikeOne() {
        XCTAssertEqual(paragraphs(MessageLayout.apply("Hey, " + body)).first, "Hey,")
        XCTAssertEqual(paragraphs(MessageLayout.apply("Hi team, " + body)).first, "Hi team,")
        for opening in ["Hey I think we should talk, ", "Hey there's a problem, "] {
            let output = MessageLayout.apply(opening + body)
            XCTAssertTrue(paragraphs(output)[0].hasPrefix(opening), output)
        }
    }

    func testShortMessagesAreLeftToTheModel() {
        let short = "Hey Sam, can we move the review to Tuesday? Thanks, Noah."
        XCTAssertFalse(MessageLayout.qualifies(short))
        XCTAssertEqual(MessageLayout.apply(short), short)
    }

    func testLongProseWithoutMessageCuesIsUntouched() {
        XCTAssertFalse(MessageLayout.qualifies(body))
        XCTAssertEqual(MessageLayout.apply(body), body)
        let endsWithBest = body + " I think this option is the best."
        XCTAssertEqual(MessageLayout.apply(endsWithBest), endsWithBest)
    }

    func testExistingBreaksAreKeptAndLongRunsStillSplit() {
        let output = MessageLayout.apply("Hey Sam,\n\n" + body)
        XCTAssertTrue(output.hasPrefix("Hey Sam,\n\nI wanted to follow up"), output)
        XCTAssertTrue(output.contains("\n\nSecond thing"), output)
    }

    func testListLinesAreNeverSplit() {
        let item = "- " + body
        let input = "Hey Sam,\n" + item
        XCTAssertFalse(MessageLayout.qualifies(input))
        XCTAssertEqual(MessageLayout.apply(input), input)
    }

    func testAbbreviationsAndNumbersDoNotBreakSentences() {
        let text = "Hi Sam, Dr. Patel said the 3.5% rate is fine. " + body
        let output = MessageLayout.apply(text)
        XCTAssertEqual(paragraphs(output).first, "Hi Sam,")
        XCTAssertTrue(output.contains("Dr. Patel said the 3.5% rate is fine."), output)
        XCTAssertEqual(paragraphs(MessageLayout.apply("Hi Dr. Patel, " + body)).first, "Hi Dr. Patel,")
    }

    func testListCuesAreSeparateFromMessageCues() {
        XCTAssertTrue(LLMPostProcessor.containsListOrBreakCue("first the update, second the codes"))
        XCTAssertTrue(LLMPostProcessor.containsListOrBreakCue("item 1 yes"))
        XCTAssertFalse(LLMPostProcessor.containsListOrBreakCue("Hey Sam, can we talk. Thanks, Noah."))
        XCTAssertTrue(LLMPostProcessor.containsLayoutCue("Hey Sam, can we talk. Thanks, Noah."))
    }
}
