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
}
