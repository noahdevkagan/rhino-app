import XCTest

@testable import OpenSuperWhisper

/// Cleanup outputs that pass the length-ratio guard while no longer saying what was
/// dictated. Shapes taken from real dictations replayed through the embedded model
/// (docs/performance-audit-2026-10-05.md); the wording here is invented.
final class CleanupFidelityGuardTests: XCTestCase {
    private func preserved(_ input: String, _ output: String) -> Bool {
        CleanupFidelityGuard.preservesSpokenWords(input: input, output: output)
    }

    func testDeletedSentenceIsRejected() {
        let input = "I want to write a post about the bakery on Fifth Street. I think what's "
            + "interesting is how the owner pays her staff and the fact that she opened a second "
            + "shop last winter. What are the questions I can ask to make it stand out? So help me with that."
        let output = "I want to write a post about the bakery on Fifth Street. What are the "
            + "questions I can ask to make it stand out? So help me with that."
        XCTAssertTrue(LLMPostProcessor.passesLengthGuard(input: input, output: output),
                      "the length guard alone lets this through")
        XCTAssertFalse(preserved(input, output))
    }

    func testDraftedReplyIsRejected() {
        let input = "Sam write a message to them asking for the best price possible, do it in a "
            + "very friendly and funny way around those dates."
        let output = "Sam: Hey there,\n\nCould you please let us know the best price possible "
            + "around those dates?\n\nThanks, Sam"
        XCTAssertFalse(preserved(input, output))
    }

    func testDroppedLeadInIsRejected() {
        let input = "Two things I was thinking about on the drive this morning that could be "
            + "good ideas. One was the pricing page, we could show the yearly plan first. The "
            + "second thing is the onboarding email, it reads too long."
        let output = "Idea 1: The pricing page, we could show the yearly plan first.\n\n"
            + "Idea 2: The second thing is the onboarding email, it reads too long."
        XCTAssertFalse(preserved(input, output))
    }

    func testPunctuationCasingAndLayoutPass() {
        let input = "hey jane thanks for sending the proposal over the scope looks right but the "
            + "timeline feels optimistic can we add a buffer week thanks so much"
        let output = "Hey Jane,\n\nThanks for sending the proposal over. The scope looks right, "
            + "but the timeline feels optimistic.\n\nCan we add a buffer week?\n\nThanks so much."
        XCTAssertTrue(preserved(input, output))
    }

    func testSmallFixesPass() {
        let input = "And so Rob sent me a note about how we can make the the reports smarter, "
            + "and I didn't fully understand it, so can you review what he said and and make recommendations."
        let output = "So Rob sent me a note about how we can make the reports smarter, and I "
            + "didn't fully understand it. Can you review what he said and make recommendations?"
        XCTAssertTrue(preserved(input, output))
    }

    func testDictatedListMayLoseCuesAndLeadIn() {
        let input = "Alright, I want to make a list. Make a list one, call the bank, two, renew "
            + "the passport, three, book the flights."
        let output = "1. Call the bank\n2. Renew the passport\n3. Book the flights"
        XCTAssertTrue(preserved(input, output))
    }

    func testNumbersChangingFormPass() {
        let input = "revenue went from forty two thousand to fifty eight thousand which is "
            + "roughly thirty eight percent growth quarter over quarter"
        let output = "Revenue went from 42,000 to 58,000, which is roughly 38% growth quarter over quarter."
        XCTAssertTrue(preserved(input, output))
    }

    // Short dictations (under 40 words): the floors above let these through.

    func testShortRequestTurnedIntoAHeadingIsRejected() {
        let input = "Draft Lena a message to see if she can push our review to Monday morning "
            + "because the deck still needs another pass"
        let output = "Draft Lena: see if you can push our review to Monday morning. The deck still needs another pass."
        XCTAssertFalse(preserved(input, output))
    }

    func testShortDictationWithAnInventedWordIsRejected() {
        let input = "Hi Omar, really enjoyed, really liked the venue, could we hold it again "
            + "for the last week of March. Thanks a lot"
        let output = "Hi Omar,\n\nReally looking forward to the venue. Really liked it. Could we "
            + "hold it again for the last week of March. Thanks a lot."
        XCTAssertFalse(preserved(input, output))
    }

    func testShortDictationWithASwappedWordIsRejected() {
        let input = "I also think the shipping delay thing was a bigger issue than most of the team expected"
        let output = "I also think the shipping delay issue was a bigger problem than most of the team expected."
        XCTAssertFalse(preserved(input, output))
    }

    func testShortDictationJoinsFragmentsAndWordFormsPass() {
        XCTAssertTrue(preserved(
            "We saw it in a post hog chart and you had great call outs on the seatbelt's design notes today",
            "We saw it in a posthog chart and you had great callouts on the seatbelt design notes today."))
        XCTAssertTrue(preserved(
            "There's no refund option in the old checkout as f as long as I remember it honestly",
            "There's no refund option in the old checkout as far as I remember it honestly."))
    }

    // From code review (2026-11-11): the explain-away rules must not accept these.

    func testShortDictationNegationFlipIsRejected() {
        let pairs = [
            ("We should ship the release on Friday because the payment flow is finally ready for customers",
             "We shouldn't ship the release on Friday because the payment flow is finally ready for customers."),
            ("I don't want you to cancel the order before the supplier confirms the new delivery date",
             "I do want you to cancel the order before the supplier confirms the new delivery date."),
            ("Can you confirm we did sign the contract with the venue for the March offsite",
             "Can you confirm we didn't sign the contract with the venue for the March offsite?"),
        ]
        for (input, output) in pairs { XCTAssertFalse(preserved(input, output), output) }
    }

    func testShortDictationSamePrefixSwapIsRejected() {
        XCTAssertFalse(preserved(
            "Can you approve the budget for the offsite before Thursday so we can book the venue",
            "Can you approach the budget for the offsite before Thursday so we can book the venue?"))
    }

    func testFragmentOnlyCompletesIntoAShortWord() {
        XCTAssertFalse(preserved(
            "There's no refund option in the old checkout as f as long as I remember it honestly",
            "There's no refund option in the old checkout as fired as I remember it honestly."))
    }

    func testJoinNeedsAdjacentSpokenWords() {
        XCTAssertFalse(preserved(
            "There is no real excuse for the thing we shipped last week to the beta customers",
            "There is real nothing we shipped last week to the beta customers."))
    }

    func testShortListMayGainAHeading() {
        XCTAssertTrue(preserved(
            "okay make a list milk eggs bread butter coffee and some apples for the kids lunches",
            "Shopping list:\n- Milk\n- Eggs\n- Bread\n- Butter\n- Coffee\n- Some apples for the kids lunches"))
    }

    func testVerdictDoesNotDependOnHashOrder() {
        let input = "we went f fast on the rollout and honestly it was too much for the support team to handle"
        let output = "We went far faster on the rollout, and honestly it was too much for the support team to handle."
        let first = preserved(input, output)
        for _ in 0..<50 { XCTAssertEqual(preserved(input, output), first) }
    }

    func testShortTextIsLeftToTheLengthGuard() {
        XCTAssertTrue(preserved("screen like I do", "I do like a screen."))
    }

    func testTextWithoutSpacesIsNotJudged() {
        let input = String(repeating: "今天的会议改到明天下午三点请大家准时参加", count: 14)
        XCTAssertTrue(preserved(input, "今天的会议改到明天下午三点。"))
    }
}
