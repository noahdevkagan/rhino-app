import Darwin
import XCTest

@testable import OpenSuperWhisper

/// The idle release frees the inference state and keeps the model mapped. A rebuilt context must
/// give byte-identical output, and rebuilding must be much cheaper than a fresh model load.
/// Prints the measured costs (decisions.md 2026-11-11). Skips without the local model.
final class LlamaIdleReleaseTests: XCTestCase {
    private func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }

    private func ms(since start: CFAbsoluteTime) -> Int { Int((CFAbsoluteTimeGetCurrent() - start) * 1000) }

    func testRealModelReleasedStateRebuildsWithIdenticalOutput() throws {
        let url = LLMModelManager.shared.localURL(for: LLMModelManager.defaultModel.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Local cleanup model not installed")
        }
        let system = try XCTUnwrap(LLMPostProcessor.assembleSystemPrompt(
            generalCleanup: true,
            generalPrompt: "Correct punctuation and capitalization. Preserve the speaker's words.",
            smartFormatting: true, languageCode: "en"))
        let a = LLMPostProcessor.wrapUserText("a", smartFormatting: true)
        let b = LLMPostProcessor.wrapUserText("b", smartFormatting: true)
        let user = LLMPostProcessor.wrapUserText(
            "okay three things for the launch one update the pricing page two email the beta users",
            smartFormatting: true)

        let before = footprintMB()
        var start = CFAbsoluteTimeGetCurrent()
        let context = try XCTUnwrap(LlamaContext(modelPath: url.path))
        context.prefill(system: system, userVariantA: a, userVariantB: b)
        let coldLoadMs = ms(since: start)
        let fresh = context.generate(system: system, user: user, maxTokens: 128)
        let loaded = footprintMB()

        context.releaseInferenceState()
        XCTAssertFalse(context.hasInferenceState)
        XCTAssertEqual(context.cachedPromptBytes, 0, "snapshots must go with the context")
        XCTAssertFalse(context.decodeShapesWarm)
        let released = footprintMB()

        start = CFAbsoluteTimeGetCurrent()
        context.prefill(system: system, userVariantA: a, userVariantB: b)
        let rebuildMs = ms(since: start)
        XCTAssertTrue(context.hasInferenceState)
        XCTAssertTrue(context.decodeShapesWarm)
        let rebuilt = context.generate(system: system, user: user, maxTokens: 128)

        XCTAssertFalse(context.lastGenerationTruncated)
        XCTAssertEqual(rebuilt, fresh, "a rebuilt context must not change cleanup output")
        // Generate on a released context must also rebuild, without a prefill first.
        context.releaseInferenceState()
        XCTAssertEqual(context.generate(system: system, user: user, maxTokens: 128), fresh)

        let report = String(format: "IDLE-RELEASE cold load+prefill %d ms, rebuild+prefill %d ms; "
            + "footprint MB: before %.0f, loaded %.0f, after release %.0f",
            coldLoadMs, rebuildMs, before, loaded, released)
        print(report)
        try? report.write(to: FileManager.default.temporaryDirectory
            .appendingPathComponent("rhino-idle-release.txt"), atomically: true, encoding: .utf8)
        XCTAssertLessThan(released, loaded, "releasing the context must free memory")
    }
}
