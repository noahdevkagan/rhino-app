import XCTest

@testable import OpenSuperWhisper

/// Smart formatting asks the cleanup LLM to lay dictated enumerations out as lists
/// ("item 1, yes, item 2, no" → bulleted lines) instead of one run-on sentence. It is
/// opt-in and only active alongside LLM cleanup. These tests pin the off-by-default
/// contract, the prompt section's gating, the user-wrapper carve-out, and that a list
/// expansion clears the length guard. The model's actual compliance is measured in
/// bench/, not here.
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

    func testUserWrapperCarvesOutListLayoutOnlyWhenOn() {
        // Off: the blanket no-additions clause stays, so cleanup-only behavior is unchanged.
        XCTAssertTrue(LLMPostProcessor.wrapUserText("hello").contains("do not add anything"))
        // On: bullets and newlines are additions, so the wrapper must not forbid them outright.
        let wrapped = LLMPostProcessor.wrapUserText("hello", smartFormatting: true)
        XCTAssertFalse(wrapped.contains("do not add anything"))
        XCTAssertTrue(wrapped.contains("beyond the list layout"))
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
}
