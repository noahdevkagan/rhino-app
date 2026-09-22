import XCTest

@testable import OpenSuperWhisper

final class LlamaPromptCacheTests: XCTestCase {
    /// Real KV save/restore must preserve sequential outputs, not just cache bookkeeping.
    /// CI without the optional local model skips; this test never initiates a download.
    func testRealModelSwitchesBudgetMissesAndTruncationPreserveOutput() throws {
        let manager = LLMModelManager.shared
        let url = manager.localURL(for: LLMModelManager.defaultModel.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Local cleanup model not installed")
        }
        let formatting = try XCTUnwrap(LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: "Correct punctuation and capitalization. Preserve the speaker's words.",
            smartFormatting: true, languageCode: "en"))
        let german = try XCTUnwrap(LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: "Correct punctuation and capitalization. Preserve the speaker's words.",
            smartFormatting: true, languageCode: "de"))
        let edits = LLMPostProcessor.spokenEditsPassPrompt
        let requests = [
            (formatting, LLMPostProcessor.wrapUserText("please send the proposal to Sarah", smartFormatting: true)),
            (edits, LLMPostProcessor.wrapSpokenEditsUserText("send it Tuesday actually make that Thursday")),
            (formatting, LLMPostProcessor.wrapUserText("send it Thursday", smartFormatting: true)),
            (edits, LLMPostProcessor.wrapSpokenEditsUserText("invite Sarah I mean Michael to the meeting")),
            (formatting, LLMPostProcessor.wrapUserText("invite Michael to the meeting", smartFormatting: true)),
            (german, LLMPostProcessor.wrapUserText("Bitte schick mir morgen die Unterlagen.",
                                                  smartFormatting: true, languageCode: "de")),
            (formatting, LLMPostProcessor.wrapUserText("the green bicycle is outside", smartFormatting: true)),
        ]

        // Keep one model/context resident at a time even when comparing three policies.
        func run(limit: Int) throws -> (texts: [String], hits: Int) {
            let context = try XCTUnwrap(LlamaContext(modelPath: url.path, promptCacheByteLimit: limit))
            XCTAssertEqual(context.cachedPromptBytes, 0, "A new context must not inherit idle-unloaded state")
            var texts: [String] = []
            for (system, user) in requests {
                // Simulate recording-time formatting prefill, including before the edit pass.
                context.prefill(system: formatting,
                    userVariantA: LLMPostProcessor.wrapUserText("a", smartFormatting: true),
                    userVariantB: LLMPostProcessor.wrapUserText("b", smartFormatting: true))
                texts.append(context.generate(system: system, user: user, maxTokens: 128))
                XCTAssertFalse(context.lastGenerationTruncated)
                XCTAssertLessThanOrEqual(context.cachedPromptBytes, limit)
            }

            // A cut generation must still fail closed and leave later cache restores safe.
            _ = context.generate(system: edits, user: "Repeat exactly: one two three four five six seven eight nine ten",
                                 maxTokens: 0)
            XCTAssertTrue(context.lastGenerationTruncated)
            texts.append(context.generate(system: formatting, user: requests[0].1, maxTokens: 128))
            XCTAssertFalse(context.lastGenerationTruncated)

            // Context-overflow prompt truncation must not poison a saved valid prefix either.
            _ = context.generate(system: edits, user: String(repeating: "overflow ", count: 5_000), maxTokens: 0)
            XCTAssertTrue(context.lastGenerationTruncated)
            texts.append(context.generate(system: formatting, user: requests[0].1, maxTokens: 128))
            XCTAssertFalse(context.lastGenerationTruncated)
            XCTAssertLessThanOrEqual(context.cachedPromptBytes, limit)
            return (texts, context.promptCacheHits)
        }

        let uncached = try run(limit: 0)
        let cached = try run(limit: 64 * 1024 * 1024)
        let tooSmall = try run(limit: 1)
        XCTAssertGreaterThan(cached.hits, 0, "Parity must actually exercise restored snapshots")
        XCTAssertEqual(uncached.hits, 0)
        XCTAssertEqual(tooSmall.hits, 0, "An oversized prefix must degrade to ordinary decoding")
        XCTAssertEqual(cached.texts, uncached.texts)
        XCTAssertEqual(tooSmall.texts, uncached.texts)
    }
}
