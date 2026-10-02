import XCTest
@testable import OpenSuperWhisper

final class NumberFormattingPreferenceTests: XCTestCase {
    func testDefaultAndPersistedNumberPreferences() {
        let prefs = AppPreferences.shared
        let defaults = DefaultsStore.current
        let previous = defaults.object(forKey: "numberFormattingStyle")
        defer { defaults.set(previous, forKey: "numberFormattingStyle") }
        defaults.removeObject(forKey: "numberFormattingStyle")
        XCTAssertEqual(prefs.numberFormattingStyle, .smart)
        for style in NumberFormattingStyle.allCases {
            prefs.numberFormattingStyle = style
            XCTAssertEqual(defaults.string(forKey: "numberFormattingStyle"), style.rawValue)
            XCTAssertEqual(prefs.numberFormattingStyle, style)
        }
        defaults.set("unknown-future-style", forKey: "numberFormattingStyle")
        XCTAssertEqual(prefs.numberFormattingStyle, .smart)
    }

    func testCleanupPromptPreservesAlreadyFormattedNumbers() {
        AppPreferences.shared.migrateCleanupPromptToDefault()
        let prompt = AppPreferences.shared.aiPostProcessingPrompt
        XCTAssertTrue(prompt.contains("keep digits as digits and spelled-out numbers as words"))
        XCTAssertFalse(prompt.contains("Write numbers, times, and amounts as compact digits"))
    }

    func testDecimalsAreFormattedBeforeCleanupLengthGuard() {
        let raw = "zero point seven two five"
        let formatted = NumberCompaction.apply(raw)
        XCTAssertEqual(formatted, "0.725")
        // The old LLM-only conversion is rejected as apparent loss of words.
        XCTAssertFalse(LLMPostProcessor.passesLengthGuard(input: raw, output: formatted))
        XCTAssertTrue(LLMPostProcessor.passesLengthGuard(input: formatted, output: formatted))
    }
}
