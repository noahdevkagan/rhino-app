import XCTest

@testable import OpenSuperWhisper

/// The cleanup pass runs only when a dictation has layout to produce
/// (`cleanupOnlyWhenNeeded`). These pin what counts as a cue.
final class CleanupLayoutCueTests: XCTestCase {
    func testDefaultsOn() {
        DefaultsStore.current.removeObject(forKey: "cleanupOnlyWhenNeeded")
        XCTAssertTrue(AppPreferences.shared.cleanupOnlyWhenNeeded)
    }

    func testMessagesListsAndLayoutCommandsAreCued() {
        for cued in [
            "Hey Sarah, thanks for sending the proposal over.",
            "Hello, team. I am curious about the outcome.",
            "Good morning, Monday. I wanted to follow up on the invoice.",
            "Looks amazing, let me know when works. Thanks so much.",
            "can you send the deck over when you get a chance best wishes Tim",
            "Let me know. Cheers, Noah",
            "quick update new paragraph the site is live",
            "action items new line review the deck",
            "bullet buy milk",
            "Alright, I want to make a list. One, Noah, two, Sam, three, Alex.",
            "Number 1: Noah, Number 2, Sam",
            "item one yes item two no",
            "we need three things first the update second the changelog third the codes",
            "todo for tomorrow one review the plan two email sam three book the room",
        ] {
            XCTAssertTrue(LLMPostProcessor.containsLayoutCue(cued), cued)
        }
    }

    func testOrdinarySentencesAreNotCued() {
        for plain in [
            "Sounds good, let's do Thursday at 2.",
            "I think the design is fine, ship it and we'll fix the edge cases next week.",
            "Tell Sam thanks for the help on the launch.",
            "We're launching a line of products in the spring.",
            "Draft Matt a message to see if he could give us any discounts.",
            "Revenue is tracking 8% ahead of plan, mostly from the annual push.",
            "She said hello to everyone and then left the room early.",
            "That was the best one we looked at all week.",
        ] {
            XCTAssertFalse(LLMPostProcessor.containsLayoutCue(plain), plain)
        }
    }
}
