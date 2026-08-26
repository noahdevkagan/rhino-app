import XCTest

@testable import OpenSuperWhisper

/// The LLM cleanup prompt and all its worked examples are English, which biased the small
/// built-in model into intermittently *translating* non-English dictations into English
/// (reported with German: roughly every third dictation came back in English). The fix pins
/// the output language in two places — a named language rule appended to the system prompt,
/// and a same-language reminder in the per-request wrapper next to the text. These tests pin
/// that both appear for non-English languages, that auto-detect gets the language-agnostic
/// wording, and that the English prompt stays byte-identical to the tuned original. The
/// model's actual compliance is measured in bench/, not here.
final class CleanupLanguageRuleTests: XCTestCase {

    func testSystemPromptPinsNamedLanguage() {
        let system = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            languageCode: "de")
        XCTAssertNotNil(system)
        XCTAssertTrue(system!.contains("the transcription is in German"))
        XCTAssertTrue(system!.contains("keeping every word in German"))
        XCTAssertTrue(system!.hasSuffix("in German."),
                      "the language rule must be the last instruction before the text")
    }

    func testSystemPromptPinsSameLanguageForAutoDetect() {
        let system = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            languageCode: "auto")
        XCTAssertNotNil(system)
        XCTAssertTrue(system!.contains("in the exact language it was dictated in"))
        XCTAssertTrue(system!.contains("never translate the text"))
    }

    func testEnglishSystemPromptIsUnchanged() {
        // "en" (and the legacy no-argument call) must produce the exact prompt the English
        // cleanup behavior was tuned on — no language rule appended.
        let baseline = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt)
        let english = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            languageCode: "en")
        XCTAssertEqual(baseline, english)
        XCTAssertFalse(english!.contains("Language rule"))
    }

    func testLanguageRuleComposesWithSmartFormatting() {
        let system = LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: AppPreferences.shared.aiPostProcessingPrompt,
            smartFormatting: true,
            languageCode: "de")
        XCTAssertNotNil(system)
        XCTAssertTrue(system!.contains("Formatting rule"))
        XCTAssertTrue(system!.contains("the transcription is in German"))
        XCTAssertLessThan(system!.range(of: "Formatting rule")!.lowerBound,
                          system!.range(of: "Language rule")!.lowerBound,
                          "the language pin must come after the formatting examples")
    }

    func testUserWrapperRestatesLanguageNextToTheText() {
        let german = LLMPostProcessor.wrapUserText("hallo welt", languageCode: "de")
        XCTAssertTrue(german.contains("Keep the text in German — do not translate it."))

        let auto = LLMPostProcessor.wrapUserText("hallo welt", languageCode: "auto")
        XCTAssertTrue(auto.contains(
            "Keep the text in the language it was dictated in — do not translate it."))

        // English (and the legacy no-argument call) stays word-for-word what cleanup was
        // tuned on.
        XCTAssertEqual(LLMPostProcessor.wrapUserText("hello"),
                       LLMPostProcessor.wrapUserText("hello", languageCode: "en"))
        XCTAssertFalse(LLMPostProcessor.wrapUserText("hello").contains("translate"))
    }

    func testLanguageRuleUsesCuratedDisplayNames() {
        XCTAssertTrue(LLMPostProcessor.languageRule(for: "nl")!.contains("in Dutch"))
        XCTAssertTrue(LLMPostProcessor.languageRule(for: "fr")!.contains("in French"))
        XCTAssertNil(LLMPostProcessor.languageRule(for: "en"))
    }
}
