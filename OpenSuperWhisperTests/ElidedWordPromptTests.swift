import XCTest

@testable import OpenSuperWhisper

/// Elided-word reconstruction lives in the cleanup prompt (corpus h01: the engine drops
/// "the" from "Schedule the review" — context-dependent, so it can't be a deterministic
/// pass like NumberCompaction). These tests pin the two halves of that contract in the
/// shipped default prompt, and the migration that keeps old installs on the current
/// wording. The model's actual compliance is measured in bench/ — a prompt clause that
/// silently disappears here would fail there only on Noah's machine, weeks later.
final class ElidedWordPromptTests: XCTestCase {

    private var defaultPrompt: String {
        // Read through a scratch suite so we get the code default, never a stored value.
        AppPreferences.shared.migrateCleanupPromptToDefault()
        return AppPreferences.shared.aiPostProcessingPrompt
    }

    func testDefaultPromptAsksForDroppedFunctionWordsBack() {
        // The restoration clause: without it the model obeys "never add" and leaves
        // "Schedule review" broken.
        XCTAssertTrue(defaultPrompt.contains("dropped a short function word"))
        XCTAssertTrue(defaultPrompt.contains("Schedule the review for Tuesday"),
                      "the worked example is what a 1.5B model actually follows")
    }

    func testDefaultPromptStillForbidsInventingContent() {
        // The restoration clause must not have loosened the transform-only contract.
        XCTAssertTrue(defaultPrompt.contains("Never add names, facts, or any other words"))
        XCTAssertTrue(defaultPrompt.contains("never add or remove information beyond these rules"))
    }

    func testStaleStoredPromptIsDroppedByMigration() {
        // Installs from the editable-prompt era persisted the then-current default; the
        // migration must clear it so prompt tuning reaches them.
        DefaultsStore.current.set("old wording without the restoration clause",
                                  forKey: "aiPostProcessingPrompt")
        AppPreferences.shared.migrateCleanupPromptToDefault()
        XCTAssertTrue(AppPreferences.shared.aiPostProcessingPrompt
            .contains("dropped a short function word"))
    }

    func testRestoredArticleGrowthPassesTheLengthGuard() {
        // Adding "the" grows output slightly; the guard's 3x ceiling must not eat it.
        let input = "Schedule review for March 3rd at 10:30 with Priya"
        let output = "Schedule the review for March 3rd at 10:30 with Priya."
        XCTAssertTrue(LLMPostProcessor.passesLengthGuard(input: input, output: output))
    }
}
