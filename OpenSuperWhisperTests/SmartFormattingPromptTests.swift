import XCTest

@testable import OpenSuperWhisper

/// Smart formatting asks the cleanup LLM to lay dictated enumerations out as lists
/// ("item 1, yes, item 2, no" → bulleted lines) and dictated emails out as messages
/// (greeting line, paragraph breaks, sign-off block) instead of one run-on sentence.
/// It is opt-in and only active alongside LLM cleanup. These tests pin the
/// off-by-default contract, the prompt section's gating, the user-wrapper carve-out,
/// and that the reformatted layouts clear the length guard. The model's actual
/// compliance is measured in bench/, not here.
final class SmartFormattingPromptTests: XCTestCase {

    func testSmartFormattingIsOffByDefault() {
        DefaultsStore.current.removeObject(forKey: "smartFormattingEnabled")
        XCTAssertFalse(AppPreferences.shared.smartFormattingEnabled)
    }

    func testSystemPromptOmitsFormattingRuleWhenOff() {
        let system = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            smartFormatting: false)
        XCTAssertNotNil(system)
        XCTAssertFalse(system!.contains("Formatting rule"))
    }

    func testSystemPromptIncludesFormattingRuleWhenOn() {
        let system = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            smartFormatting: true)
        XCTAssertNotNil(system)
        XCTAssertTrue(system!.contains("one item per line"))
        XCTAssertTrue(system!.contains("- Item 1: yes"),
                      "the worked example is what a 1.5B model actually follows")
        XCTAssertTrue(system!.contains("'bullet buy milk' becomes:\n- Buy milk"),
                      "an explicit bullet cue must work for a one-item list")
        XCTAssertTrue(system!.contains("never force a list onto normal sentences"),
                      "the rule must not turn every dictation into bullets")
    }

    func testSystemPromptIncludesMessageRuleWhenOn() {
        let system = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            smartFormatting: true)
        XCTAssertNotNil(system)
        XCTAssertTrue(system!.contains("the greeting on its own line"))
        XCTAssertTrue(system!.contains("Thanks so much.\n\nBest wishes,\nTim"),
                      "the worked email example is what a 1.5B model actually follows")
        XCTAssertTrue(system!.contains("merely mentions a greeting or thanks is not a message"),
                      "the counter-example keeps ordinary prose out of email layout")
        // Real dictated emails run several sentences; without a long worked example the
        // model formats only short inputs shaped like the short examples (see decisions.md
        // on one-example lookup behavior) and returns long emails as a single block.
        XCTAssertTrue(system!.contains("never one solid block"))
        XCTAssertTrue(system!.contains(
            "Thanks for your message. Please be introduced to Jamie, my partner for Contaktly."),
                      "the long email example carries the paragraph-grouping behavior")
        XCTAssertTrue(system!.contains("never takes a period"),
                      "the sign-off name must not gain a period from sentence punctuation")
    }

    func testSystemPromptIncludesParagraphRuleWhenOn() {
        // Field report (2026-09-01): LLM cleanup + smart formatting on, and a long plain
        // dictation still lands as "1 paragraph block". The message rule's paragraph
        // grouping is gated on greeting/sign-off cues, so nothing asked the model to
        // break up long non-email prose.
        let system = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            smartFormatting: true)
        XCTAssertNotNil(system)
        XCTAssertTrue(system!.contains("Paragraph rule"))
        XCTAssertTrue(system!.contains(
            "I still need the final pricing from Sam before we flip it live."),
                      "the worked example is what a 1.5B model actually follows")
        XCTAssertTrue(system!.contains("one to three sentences stays a single block"),
                      "the counter-example keeps short dictations unbroken")
    }

    func testSystemPromptIncludesLayoutCommandsWhenOn() {
        let system = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            smartFormatting: true)
        XCTAssertNotNil(system)
        XCTAssertTrue(system!.contains("'new paragraph' becomes a blank line"))
        XCTAssertTrue(system!.contains("Quick update.\n\nThe site is live."),
                      "the worked example is what a 1.5B model actually follows")
        XCTAssertTrue(system!.contains("launching a new line of products"),
                      "the counter-example keeps literal uses of the command words intact")
    }

    func testUserWrapperCarvesOutLayoutOnlyWhenOn() {
        // Off: the blanket no-additions clause stays, so cleanup-only behavior is unchanged.
        XCTAssertTrue(LLMPostProcessor.wrapUserText("hello").contains("do not add anything"))
        // On: bullets, paragraph breaks, and newlines are additions, so the wrapper must not
        // forbid them outright.
        let wrapped = LLMPostProcessor.wrapUserText("hello", smartFormatting: true)
        XCTAssertFalse(wrapped.contains("do not add anything"))
        XCTAssertTrue(wrapped.contains("beyond the layout"))
        XCTAssertTrue(wrapped.contains("paragraph breaks"))
    }

    func testSpuriousListMarkerIsStrippedFromOneLineProse() {
        // The 1.5B model over-applies the list examples to prose ("- Can we move the
        // review…"); without an explicit list cue in the input, the marker goes.
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "- Can we move the review?", originalInput: "can we move the review"),
                       "Can we move the review?")
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "1. Can we move the review?", originalInput: "can we move the review"),
                       "Can we move the review?")
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "1. First, we need to review the plan.",
            originalInput: "first we need to review the plan"),
                       "First, we need to review the plan.")
        // Real (multi-line) lists and unmarked prose pass through untouched.
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "- Item 1: yes\n- Item 2: no", originalInput: "item 1 yes item 2 no"),
                       "- Item 1: yes\n- Item 2: no")
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "Plain sentence.", originalInput: "plain sentence"),
                       "Plain sentence.")
        // A dictated negative number is not a list marker (no space after the dash).
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "-5 degrees tonight", originalInput: "negative 5 degrees tonight"),
                       "-5 degrees tonight")
    }

    func testIntentionalOneItemListMarkersArePreserved() {
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "- Buy milk", originalInput: "bullet buy milk"),
                       "- Buy milk")
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "1. Buy milk", originalInput: "number one buy milk"),
                       "1. Buy milk")
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "1. Buy milk", originalInput: "item one buy milk"),
                       "1. Buy milk")
        XCTAssertEqual(LLMPostProcessor.stripSpuriousListMarker(
            "1. Buy milk", originalInput: "1. Buy milk"),
                       "1. Buy milk")
    }

    func testBulletedExpansionPassesTheLengthGuard() {
        // List layout adds a "- " and a newline per item; the guard's 3x ceiling must not
        // reject the reformatted output and silently fall back to the run-on transcription.
        let input = "item 1, yes, item 2, no, item 3, maybe"
        let output = "- Item 1: yes\n- Item 2: no\n- Item 3: maybe"
        XCTAssertTrue(LLMPostProcessor.passesLengthGuard(input: input, output: output))
    }

    func testParagraphLayoutPassesTheLengthGuard() {
        // Paragraph grouping adds only blank lines; the guard must not reject it and
        // silently fall back to the one-block transcription.
        let input = "okay quick update on the launch the landing page is done and checkout "
            + "works end to end i still need the final pricing from sam before we flip it "
            + "live once that lands we can announce tomorrow morning"
        let output = "Okay, quick update on the launch. The landing page is done and "
            + "checkout works end to end.\n\nI still need the final pricing from Sam before "
            + "we flip it live.\n\nOnce that lands, we can announce tomorrow morning."
        XCTAssertTrue(LLMPostProcessor.passesLengthGuard(input: input, output: output))
    }

    func testMessageLayoutPassesTheLengthGuard() {
        // Email layout adds blank lines between paragraphs; the guard must not reject the
        // reformatted message and silently fall back to the run-on transcription.
        let input = "hello madelief could you please still get back to me about this "
            + "thanks so much best wishes tim"
        let output = "Hello Madelief,\n\nCould you please still get back to me about this?\n\n"
            + "Thanks so much.\n\nBest wishes,\nTim"
        XCTAssertTrue(LLMPostProcessor.passesLengthGuard(input: input, output: output))
    }
}
