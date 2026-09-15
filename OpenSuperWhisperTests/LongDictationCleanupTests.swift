import XCTest

@testable import OpenSuperWhisper

/// Guards from the 2026-09-14 report: a 6m36s dictation into Cursor saved only part of
/// the transcript. Recording and the Parakeet file pass were complete — the LLM cleanup
/// pass truncated. Its fixed 512-token response cap cut the re-emitted transcript
/// mid-sentence, and at that clip length the cut output (≈0.37× the input) still passed
/// the 0.3× length-ratio guard, so the truncated text reached the clipboard and history.
/// These pin the pure decisions of the fix: transcripts too long for the model context
/// skip the LLM passes entirely, and the response token budget scales with the input
/// instead of a fixed cap. (LlamaContext's truncated-generation flag needs a loaded
/// model, so it's exercised by the CLI cleanup probes, not here.)
final class LongDictationCleanupTests: XCTestCase {

    // MARK: - LLM input gate

    func testOrdinaryDictationStaysWithinLLMBudget() {
        let oneMinute = String(repeating: "we shipped the update and it looks good ", count: 20)
        XCTAssertTrue(LLMPostProcessor.withinLLMInputBudget(oneMinute),
                      "normal dictations must keep getting cleanup")
    }

    func testSixAndAHalfMinuteDictationSkipsLLM() {
        // ~990 words ≈ the reported 6m36s clip: far beyond what the 4096-token context
        // can hold twice (input + re-emitted output) next to the prompt.
        let longClip = String(repeating: "and we were pushing content ", count: 200)
        XCTAssertFalse(LLMPostProcessor.withinLLMInputBudget(longClip),
                       "a transcript the model cannot re-emit in full must stay verbatim")
    }

    func testInputBudgetBoundary() {
        let atLimit = String(repeating: "a", count: LLMPostProcessor.maxLLMInputChars)
        XCTAssertTrue(LLMPostProcessor.withinLLMInputBudget(atLimit))
        XCTAssertFalse(LLMPostProcessor.withinLLMInputBudget(atLimit + "a"))
    }

    func testInputGateStaysUnderLongClipHold() {
        // The gate's comfort zone (~4 min of speech) must sit below the 5-minute
        // long-clip hold: every dictation short enough to be auto-pasted should still
        // be eligible for cleanup. ~150 wpm ≈ 6.2 chars/word incl. space ≈ 930 chars/min.
        let charsPerMinute = 930.0
        let gateMinutes = Double(LLMPostProcessor.maxLLMInputChars) / charsPerMinute
        XCTAssertLessThan(gateMinutes * 60, DictationPipeline.longClipHoldThreshold)
    }

    // MARK: - Response token budget

    func testShortInputKeepsOldFloor() {
        XCTAssertEqual(BuiltInLlamaBackend.responseTokenBudget(forInputBytes: 0), 512)
        XCTAssertEqual(BuiltInLlamaBackend.responseTokenBudget(forInputBytes: 400), 512)
        XCTAssertEqual(BuiltInLlamaBackend.responseTokenBudget(forInputBytes: 1_024), 512)
    }

    func testBudgetScalesWithInput() {
        // bytes/2 ≈ 2× the tokens English text needs, so a pass the input gate admits
        // can always re-emit its transcript with room for formatting additions.
        XCTAssertEqual(BuiltInLlamaBackend.responseTokenBudget(forInputBytes: 3_000), 1_500)
        XCTAssertEqual(BuiltInLlamaBackend.responseTokenBudget(forInputBytes: 4_000), 2_000)
    }

    func testBudgetCapStaysUnderContext() {
        XCTAssertEqual(BuiltInLlamaBackend.responseTokenBudget(forInputBytes: 1_000_000), 3_072,
                       "the response budget must never claim the whole 4096-token context")
    }

    func testGateAdmitsOnlyInputsTheBudgetCanReEmit() {
        // Cross-check the two constants: the largest transcript the input gate admits
        // gets a response budget of at least one token per ~3.5 chars — above the ~4
        // chars/token English averages, so admitted inputs can't hit the cap.
        let maxAdmitted = LLMPostProcessor.maxLLMInputChars
        let budget = BuiltInLlamaBackend.responseTokenBudget(forInputBytes: maxAdmitted)
        XCTAssertGreaterThanOrEqual(Double(budget), Double(maxAdmitted) / 3.5)
    }
}
