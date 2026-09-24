import XCTest

@testable import OpenSuperWhisper

final class LlamaSpeculativeDecodingTests: XCTestCase {
    typealias T = LlamaContext.LlamaToken

    // MARK: - Draft selection (pure)

    func testStrongMatchDraftsLongRunFromLatestOccurrence() {
        // "1 2 3 4" appears twice; the later one (the transcript sits last) wins.
        let source: [T] = [1, 2, 3, 4, 90, 91, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        XCTAssertEqual(LlamaContext.draftTokens(source: source, output: [1, 2, 3, 4], limit: 31),
                       [5, 6, 7, 8, 9])
        XCTAssertEqual(LlamaContext.draftTokens(source: source, output: [1, 2, 3, 4], limit: 2),
                       [5, 6], "The remaining token budget caps the draft")
    }

    func testLongRunIsCappedAtMaxDraftTokens() {
        let source: [T] = [1, 2, 3, 4] + (100..<200).map { T($0) }
        let draft = LlamaContext.draftTokens(source: source, output: [1, 2, 3, 4], limit: 1_000)
        XCTAssertEqual(draft.count, LlamaContext.maxDraftTokens)
        XCTAssertEqual(draft.first, 100)
    }

    func testWeakMatchProbesOneToken() {
        let source: [T] = [7, 8, 9, 10, 11]
        // Only the last output token matches the source: probe a single token.
        XCTAssertEqual(LlamaContext.draftTokens(source: source, output: [50, 51, 8], limit: 31), [9])
        // A 4-token match with fewer than 4 tokens after it is not worth a long batch.
        XCTAssertEqual(LlamaContext.draftTokens(source: [1, 2, 3, 4, 5, 6], output: [1, 2, 3, 4], limit: 31),
                       [5])
    }

    func testNoMatchOrNoRoomDraftsNothing() {
        XCTAssertEqual(LlamaContext.draftTokens(source: [1, 2, 3], output: [9], limit: 31), [])
        XCTAssertEqual(LlamaContext.draftTokens(source: [1, 2, 3], output: [1], limit: 0), [])
        XCTAssertEqual(LlamaContext.draftTokens(source: [1, 2, 3], output: [], limit: 31), [])
        // A match on the source's final token has no continuation.
        XCTAssertEqual(LlamaContext.draftTokens(source: [1, 2, 3], output: [3], limit: 31), [])
    }

    // MARK: - Real model: speculative output must equal plain greedy decoding

    func testRealModelWarmupFailureCanRetryWithoutChangingOutput() throws {
        let manager = LLMModelManager.shared
        let url = manager.localURL(for: LLMModelManager.defaultModel.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Local cleanup model not installed")
        }
        let system = "Correct punctuation and capitalization. Preserve the speaker's words."
        let user = "sounds good see you tomorrow"
        func run(speculative: Bool, failWarmup: Bool) throws -> String {
            let context = try XCTUnwrap(LlamaContext(modelPath: url.path, contextLength: 256,
                                                    speculativeDecoding: speculative))
            if failWarmup {
                // Qwen's prefix fits, but leaves fewer than 32 KV slots for the verify batch.
                // The single-token-only control below confirms prefill actually reached warm-up.
                context.prefill(system: String(repeating: " word", count: 225),
                                userVariantA: "a", userVariantB: "b")
                XCTAssertEqual(context.decodeShapesWarm, !speculative,
                               "A failed verify must leave warm-up eligible for retry")
            }
            context.prefill(system: system, userVariantA: "a", userVariantB: "b")
            XCTAssertTrue(context.decodeShapesWarm, "Warm-up must succeed with room to decode")
            let output = context.generate(system: system, user: user, maxTokens: 64)
            XCTAssertFalse(context.lastGenerationTruncated)
            return output
        }
        let plain = try run(speculative: false, failWarmup: true)
        let fresh = try run(speculative: true, failWarmup: false)
        let recovered = try run(speculative: true, failWarmup: true)
        XCTAssertEqual(recovered, fresh)
        XCTAssertEqual(recovered, plain)
    }

    /// Same requests through a plain-decoding context and a speculative one, in app order
    /// (recording-time prefill, then generate). Every text and truncation flag must match.
    /// CI without the optional local model skips; this test never initiates a download.
    func testRealModelSpeculativeDecodingMatchesPlainGreedy() throws {
        let manager = LLMModelManager.shared
        let url = manager.localURL(for: LLMModelManager.defaultModel.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Local cleanup model not installed")
        }
        let prompt = "Correct punctuation and capitalization. Preserve the speaker's words."
        let formatting = try XCTUnwrap(LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true, generalPrompt: prompt, smartFormatting: true, languageCode: "en"))
        let german = try XCTUnwrap(LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true, generalPrompt: prompt, smartFormatting: true, languageCode: "de"))
        let edits = LLMPostProcessor.spokenEditsPassPrompt
        let longText = """
            Okay so here's my thinking on the launch plan for next month. First, I want to make \
            sure we don't repeat what happened last time, where the landing page went live before \
            the checkout flow was tested end to end. Second, the email sequence. I think we should \
            cut it from seven emails down to four, because the last three barely got opened. \
            Third, pricing. I'm leaning toward keeping the single tier at forty nine dollars.
            """
        let requests: [(system: String, user: String, maxTokens: Int)] = [
            (formatting, LLMPostProcessor.wrapUserText("Sounds good.", smartFormatting: true), 128),
            (formatting, LLMPostProcessor.wrapUserText(longText, smartFormatting: true), 512),
            (edits, LLMPostProcessor.wrapSpokenEditsUserText(
                "Send the proposal on Tuesday, actually make that Thursday, and copy Sarah."), 256),
            (formatting, LLMPostProcessor.wrapUserText(
                "Grocery list, um, avocados, sourdough, oat milk, two lemons.", smartFormatting: true), 256),
            (german, LLMPostProcessor.wrapUserText("Bitte schick mir morgen die Unterlagen für das Treffen.",
                                                  smartFormatting: true, languageCode: "de"), 256),
            // Budget runs out mid-output (and mid-draft): same cut text, both flagged truncated.
            (formatting, LLMPostProcessor.wrapUserText(longText, smartFormatting: true), 23),
            (formatting, LLMPostProcessor.wrapUserText(longText, smartFormatting: true), 1),
            // Must recover cleanly after a truncated generation cleared the cache.
            (formatting, LLMPostProcessor.wrapUserText(
                "The MRR went from forty two k to fifty eight k.", smartFormatting: true), 256),
        ]

        // One context resident at a time.
        func run(speculative: Bool) throws -> [String] {
            let context = try XCTUnwrap(LlamaContext(modelPath: url.path, speculativeDecoding: speculative))
            var results: [String] = []
            for request in requests {
                context.prefill(system: formatting,
                    userVariantA: LLMPostProcessor.wrapUserText("a", smartFormatting: true),
                    userVariantB: LLMPostProcessor.wrapUserText("b", smartFormatting: true))
                let text = context.generate(system: request.system, user: request.user,
                                            maxTokens: request.maxTokens)
                results.append("\(context.lastGenerationTruncated ? "TRUNCATED" : "ok")|\(text)")
            }
            return results
        }

        let plain = try run(speculative: false)
        let speculative = try run(speculative: true)
        XCTAssertEqual(speculative, plain)
        XCTAssertTrue(plain[5].hasPrefix("TRUNCATED|"), "The small-budget case must actually truncate")
        XCTAssertTrue(plain[6].hasPrefix("TRUNCATED|"))
        XCTAssertTrue(plain[1].hasPrefix("ok|"), "The long request must complete within its budget")
    }
}
