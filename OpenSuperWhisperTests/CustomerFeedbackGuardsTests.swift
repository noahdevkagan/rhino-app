import XCTest

@testable import OpenSuperWhisper

/// Guards added from the 2026-09-11 customer report: dictations aimed at an AI
/// assistant or a terminal skip LLM cleanup (so meta-instructions meant for THAT
/// AI aren't executed by Rhino's cleanup model), and a very long clip — far more
/// likely a mic left running than a deliberate dictation — is held on the
/// clipboard instead of pasted. These pin the pure decision logic; the pipeline
/// wiring is exercised by DictationPipelineTests and manual runs.
final class CustomerFeedbackGuardsTests: XCTestCase {

    // MARK: - Verbatim targets (LLM cleanup bypass)

    func testVerbatimDefaultsOn() {
        DefaultsStore.current.removeObject(forKey: "verbatimInAIApps")
        XCTAssertTrue(AppPreferences.shared.verbatimInAIApps,
                      "verbatim-in-AI-apps is a safety net and must default on")
    }

    func testAIAssistantsAndTerminalsAreVerbatimTargets() {
        XCTAssertTrue(LLMPostProcessor.isVerbatimTarget("com.anthropic.claudefordesktop"))
        XCTAssertTrue(LLMPostProcessor.isVerbatimTarget("com.openai.chat"))
        XCTAssertTrue(LLMPostProcessor.isVerbatimTarget("com.apple.Terminal"))
        XCTAssertTrue(LLMPostProcessor.isVerbatimTarget("com.googlecode.iterm2"))
    }

    func testWarpChannelsMatchByPrefix() {
        XCTAssertTrue(LLMPostProcessor.isVerbatimTarget("dev.warp.Warp-Stable"))
        XCTAssertTrue(LLMPostProcessor.isVerbatimTarget("dev.warp.Warp-Preview"))
    }

    func testOrdinaryAppsAreNotVerbatimTargets() {
        XCTAssertFalse(LLMPostProcessor.isVerbatimTarget("com.apple.mail"))
        XCTAssertFalse(LLMPostProcessor.isVerbatimTarget("com.google.Chrome"))
        // IDEs are deliberately NOT verbatim: prose dictated into an editor
        // (comments, commit messages) still benefits from cleanup.
        XCTAssertFalse(LLMPostProcessor.isVerbatimTarget("com.microsoft.VSCode"))
    }

    func testMissingBundleIDNeverMatches() {
        XCTAssertFalse(LLMPostProcessor.isVerbatimTarget(nil))
        XCTAssertFalse(LLMPostProcessor.isVerbatimTarget(""))
    }

    // MARK: - Long-clip hold

    func testLongClipHoldDefaultsOn() {
        DefaultsStore.current.removeObject(forKey: "reviewLongRecordings")
        XCTAssertTrue(AppPreferences.shared.reviewLongRecordings,
                      "the long-recording hold is a safety net and must default on")
    }

    func testLongClipBoundary() {
        XCTAssertFalse(DictationPipeline.isLongClip(duration: 0))
        XCTAssertFalse(DictationPipeline.isLongClip(
            duration: DictationPipeline.longClipHoldThreshold - 1),
            "an ordinary dictation just under the threshold pastes normally")
        XCTAssertTrue(DictationPipeline.isLongClip(
            duration: DictationPipeline.longClipHoldThreshold))
        XCTAssertTrue(DictationPipeline.isLongClip(duration: 90 * 60),
                      "a movie-length recording is always held")
    }
}
