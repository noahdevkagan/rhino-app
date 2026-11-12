import XCTest

@testable import OpenSuperWhisper

/// Spoken edits apply mid-dictation self-corrections ("wait, scrap that — the demo
/// moved to Thursday") as edits instead of transcribing them. They run as a dedicated
/// model pass BEFORE cleanup, gated by an edit-cue detector: as a cleanup-prompt
/// section the rule was ignored by the real 1.5B model even on a verbatim worked
/// example, because the cleanup contract's repeated "keep every word" instructions
/// beat an instruction to delete words (decisions.md, 2026-08-26). These tests pin
/// the off-by-default contract, the pass prompt's worked examples, the cue detector
/// that gates the pass and unlocks the length guard's condensing floor, and that the
/// cleanup prompt no longer carries the dead section form. The model's actual
/// compliance is measured with `Rhino cleanup` probes and in bench/, not here.
final class SpokenEditsPromptTests: XCTestCase {

    func testSpokenEditsIsOffByDefault() {
        DefaultsStore.current.removeObject(forKey: "spokenEditsEnabled")
        XCTAssertFalse(AppPreferences.shared.spokenEditsEnabled)
    }

    func testPassPromptCarriesWorkedExamplesAndCounterExamples() {
        let system = LLMPostProcessor.spokenEditsPassPrompt
        XCTAssertTrue(system.contains("tell alex the demo moved to thursday"),
                      "the worked replacement example is what a 1.5B model actually follows")
        XCTAssertTrue(system.contains("I'll call you tomorrow"),
                      "the scrap-everything example must show only the restart surviving")
        XCTAssertTrue(system.contains("she said we should scrap that feature"),
                      "the counter-example keeps literal uses of the command words intact")
        XCTAssertTrue(system.contains("never answer the text"),
                      "the pass must not turn question-shaped dictations into answers")
        XCTAssertTrue(system.contains("what day is the meeting"),
                      "the question-shaped example shows editing, not answering")
    }

    func testCleanupPromptDoesNotCarryTheSectionForm() {
        // The section form is dead: the model ignored it (see decisions.md), and a second
        // copy of the rule inside the cleanup prompt would reintroduce the keep-every-word
        // conflict the dedicated pass exists to avoid.
        let system = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            smartFormatting: true)
        XCTAssertNotNil(system)
        XCTAssertFalse(system!.contains("dictation editor"))
        XCTAssertFalse(system!.contains("Self-correction"))
        XCTAssertFalse(system!.contains("scrap that"))
    }

    func testSpokenEditsUserWrapperTreatsTextAsDataToEdit() {
        let wrapped = LLMPostProcessor.wrapSpokenEditsUserText("hello")
        XCTAssertTrue(wrapped.contains("do not answer it"))
        XCTAssertTrue(wrapped.hasSuffix("hello"),
                      "the dictation must sit verbatim at the end, after the instruction")
    }

    func testSpokenEditCueDetection() {
        for cued in ["we launch tuesday wait scrap that friday",
                     "the price is 50 actually make that 45",
                     "send it to sam I mean sarah",
                     "okay scratch that let's start over",
                     "no wait delete that",
                     "scrap all of that just say thanks"] {
            XCTAssertTrue(LLMPostProcessor.containsSpokenEditCue(cued), cued)
        }
        for plain in ["can we move the review to tuesday",
                      "I actually think the design is fine",
                      "the scrapyard is on fifth street",
                      "they mean well"] {
            XCTAssertFalse(LLMPostProcessor.containsSpokenEditCue(plain), plain)
        }
    }

    func testAppliedEditPassesTheLengthGuardOnlyWhenCondensingAllowed() {
        // Applying "scrap all of that" collapses the dictation far below the prose floor
        // (0.3x); the edits pass validates its own output with the condensing floor, while
        // the cleanup pass that follows keeps the strict one.
        let input = "okay so the plan is we start with the deck and then wait no "
            + "scrap all of that just say I'll call you tomorrow"
        let output = "I'll call you tomorrow."
        XCTAssertFalse(LLMPostProcessor.passesLengthGuard(
            input: input, output: output, condensingAllowed: false))
        XCTAssertTrue(LLMPostProcessor.containsSpokenEditCue(input))
        XCTAssertTrue(LLMPostProcessor.passesLengthGuard(
            input: input, output: output, condensingAllowed: true))
    }

    // Outputs below are what the real 1.5B model returned on 2026-11-11 (decisions.md).

    func testAppliedEditsAreAccepted() {
        let cases = [
            ("Let's meet at the office at three, actually no, make that four o'clock",
             "Let's meet at the office at four o'clock"),
            ("The price is fifty dollars. Actually, make that forty five.", "The price is forty five dollars."),
            ("The call is with Dana. Scratch that, it's with Omar.", "The call is with Omar."),
            ("Move the launch to Friday. Wait, no, Thursday.", "Move the launch to Thursday."),
            ("okay so the plan is we start with the deck and then wait no scrap all of that just say "
                + "I'll call you tomorrow", "I'll call you tomorrow."),
        ]
        for (input, output) in cases {
            XCTAssertTrue(LLMPostProcessor.spokenEditIsSafe(input: input, output: output), input)
        }
    }

    func testUnchangedTextIsAlwaysAccepted() {
        XCTAssertTrue(LLMPostProcessor.spokenEditIsSafe(
            input: "I mean, this is a great result for the team.",
            output: "I mean, this is a great result for the team."))
    }

    func testEditThatKeepsTheRetractedWordIsRejected() {
        XCTAssertFalse(LLMPostProcessor.spokenEditIsSafe(
            input: "Invite Priya, I mean Maya, to the kickoff.", output: "Invite Priya to the kickoff."))
        XCTAssertFalse(LLMPostProcessor.spokenEditIsSafe(
            input: "We land at nine, no wait, ten thirty, so plan dinner late.",
            output: "We land at nine, so plan dinner late."))
    }

    func testHalfAppliedEditIsRejected() {
        XCTAssertFalse(LLMPostProcessor.spokenEditIsSafe(
            input: "Order twenty shirts, actually make that thirty, in navy.",
            output: "Order thirty shirts, actually make that in navy."))
        XCTAssertFalse(LLMPostProcessor.spokenEditIsSafe(
            input: "Forget it ever happened, the new version is much better.",
            output: "Forget it happened, the new version is much better."))
    }

    func testEditThatAddsWordsIsRejected() {
        XCTAssertFalse(LLMPostProcessor.spokenEditIsSafe(
            input: "Move the launch to Friday. Wait, no, Thursday.",
            output: "Move the launch to Thursday morning."))
    }

    // From code review (2026-11-11).

    func testSharedWordDoesNotVouchForAMissingCorrection() {
        XCTAssertFalse(LLMPostProcessor.spokenEditIsSafe(
            input: "The call is with Dana. Scratch that, it's with Omar.", output: "The call is with Dana."))
        XCTAssertFalse(LLMPostProcessor.spokenEditIsSafe(
            input: "Put it on Monday, I mean on Tuesday.", output: "Put it on Monday."))
    }

    func testMergedRetractionIsRejected() {
        XCTAssertFalse(LLMPostProcessor.spokenEditIsSafe(
            input: "We land at nine, no wait, ten thirty, so plan dinner late.",
            output: "We land at nine thirty, so plan dinner late."))
    }

    func testEveryCorrectionIsChecked() {
        let input = "Invite Priya, I mean Maya, and book the room for Monday, actually no, Tuesday."
        XCTAssertFalse(LLMPostProcessor.spokenEditIsSafe(
            input: input, output: "Invite Priya and book the room for Tuesday."))
        XCTAssertTrue(LLMPostProcessor.spokenEditIsSafe(
            input: input, output: "Invite Maya and book the room for Tuesday."))
    }

    func testLiteralCuePhraseMayStay() {
        XCTAssertTrue(LLMPostProcessor.spokenEditIsSafe(
            input: "I mean, the price is fifty, actually make that forty five.",
            output: "I mean, the price is forty five."))
    }

    func testCurlyApostropheIsTheSameWord() {
        XCTAssertTrue(LLMPostProcessor.spokenEditIsSafe(
            input: "Let's meet at the office at three, actually no, make that four o'clock",
            output: "Let\u{2019}s meet at the office at four o\u{2019}clock"))
    }
}
