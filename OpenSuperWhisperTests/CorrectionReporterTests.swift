import XCTest
@testable import OpenSuperWhisper

/// Opt-in correction sharing (default-off is checked statically by tests/hygiene): nothing queued
/// while off, personal-looking pairs never queued, opt-out forgets the queue.
@MainActor
final class CorrectionReporterTests: XCTestCase {
    private var savedEnabled = false

    override func setUp() async throws {
        savedEnabled = AppPreferences.shared.shareCorrections
    }

    override func tearDown() async throws {
        AppPreferences.shared.shareCorrections = savedEnabled
        CorrectionReporter.shared.setEnabled(savedEnabled)
        CorrectionReporter.shared.deleteAll()
    }

    func testNothingQueuedWhileOff() {
        AppPreferences.shared.shareCorrections = false
        CorrectionReporter.shared.setEnabled(false)
        CorrectionReporter.shared.record(heard: "Clavio", corrected: "Klaviyo", model: "ggml-base.en")
        XCTAssertTrue(CorrectionReporter.shared.queue.isEmpty)
    }

    func testQueuesWhileOnDedupesAndOptOutForgets() {
        AppPreferences.shared.shareCorrections = true
        CorrectionReporter.shared.setEnabled(true)
        CorrectionReporter.shared.record(heard: "Clavio", corrected: "Klaviyo", model: "ggml-base.en")
        CorrectionReporter.shared.record(heard: "clavio", corrected: "Klaviyo", model: "ggml-base.en")
        XCTAssertEqual(CorrectionReporter.shared.queue.count, 1)
        XCTAssertEqual(CorrectionReporter.shared.queue.first?.model, "ggml-base.en")

        CorrectionReporter.shared.delete(CorrectionReporter.shared.queue[0].id)
        XCTAssertTrue(CorrectionReporter.shared.queue.isEmpty)

        CorrectionReporter.shared.record(heard: "git hub", corrected: "GitHub", model: nil)
        AppPreferences.shared.shareCorrections = false
        CorrectionReporter.shared.setEnabled(false)
        XCTAssertTrue(CorrectionReporter.shared.queue.isEmpty)
    }

    func testOrdinaryFixesAreShareable() {
        XCTAssertNotNil(CorrectionScrub.scrubbed(heard: "Clavio", corrected: "Klaviyo"))
        XCTAssertNotNil(CorrectionScrub.scrubbed(heard: "git  hub", corrected: "GitHub"))
        XCTAssertEqual(CorrectionScrub.scrubbed(heard: " git  hub ", corrected: "GitHub")?.heard, "git hub")
        XCTAssertNotNil(CorrectionScrub.scrubbed(heard: "open AI", corrected: "OpenAI"))
    }

    func testPersonalLookingPairsAreDropped() {
        let unsafe = [
            ("noah at gmail", "noah@gmail.com"),
            ("my site", "https://example.org"),
            ("my site", "www.example"),
            ("rhino voice dot app", "rhinovoice.app"),
            ("pin", "4321"),
            ("card", "4111 1111"),
            ("phone", "555-1234"),
            ("key", "sk-abc123"),
            ("token", "ghp_abcdef"),
            ("id", "a1b2c3d4e5f6g7h8"),
            ("blob", "abcdefghijklmnopqrstuvwxyz"),
        ]
        for (heard, corrected) in unsafe {
            XCTAssertNil(CorrectionScrub.scrubbed(heard: heard, corrected: corrected),
                         "\(heard) → \(corrected) should never be queued")
        }
    }

    func testLongOrEmptyOrIdenticalPairsAreDropped() {
        XCTAssertNil(CorrectionScrub.scrubbed(heard: "one two three four five six", corrected: "x"))
        XCTAssertNil(CorrectionScrub.scrubbed(heard: "", corrected: "Klaviyo"))
        XCTAssertNil(CorrectionScrub.scrubbed(heard: "Klaviyo", corrected: "Klaviyo"))
        XCTAssertNil(CorrectionScrub.scrubbed(heard: "!!", corrected: "?"))
        XCTAssertNil(CorrectionScrub.scrubbed(heard: String(repeating: "a", count: 61), corrected: "b"))
    }

    func testLabelsNeverCarryPathsOrFreeText() {
        XCTAssertEqual(CorrectionScrub.label("/Users/noah/Models/ggml-base.en.bin"), "ggml-base.en.bin")
        XCTAssertEqual(CorrectionScrub.label("whisper"), "whisper")
        XCTAssertEqual(CorrectionScrub.label("My Secret Model"), "")
        XCTAssertEqual(CorrectionScrub.languageCode("en"), "en")
        XCTAssertEqual(CorrectionScrub.languageCode("pt-BR"), "pt-BR")
        XCTAssertEqual(CorrectionScrub.languageCode("auto"), "auto")
        XCTAssertEqual(CorrectionScrub.languageCode("english please"), "")
    }
}
