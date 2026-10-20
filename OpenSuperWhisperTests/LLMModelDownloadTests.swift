import XCTest

@testable import OpenSuperWhisper

/// The cleanup model can be downloaded from Home's offer and from Settings, and Home is
/// rebuilt mid-download on every tab switch. These pin that a second request joins the
/// transfer already running instead of starting another ~1 GB one, and that progress
/// lives on the manager where any rebuilt view can find it.
@MainActor
final class LLMModelDownloadTests: XCTestCase {
    private var originalTransfer: (@MainActor (@escaping (Double) -> Void) async throws -> Void)!

    override func setUp() async throws {
        try await super.setUp()
        originalTransfer = LLMModelManager.shared.defaultModelTransfer
    }

    override func tearDown() async throws {
        LLMModelManager.shared.defaultModelTransfer = originalTransfer
        try await super.tearDown()
    }

    func testSecondDownloadJoinsTheOneRunning() async throws {
        let manager = LLMModelManager.shared
        var transfers = 0
        var release: CheckedContinuation<Void, Never>?
        manager.defaultModelTransfer = { progress in
            transfers += 1
            progress(0.5)
            await withCheckedContinuation { release = $0 }
        }

        async let first: Void = manager.downloadDefaultModel()
        async let second: Void = manager.downloadDefaultModel()
        while release == nil { await Task.yield() }
        // Let the second request reach the manager before the transfer ends.
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(manager.defaultModelProgress, 0.5, "a rebuilt view reads progress here")
        release?.resume()
        try await first
        try await second

        XCTAssertEqual(transfers, 1, "the second request joined the running download")
        XCTAssertNil(manager.defaultModelProgress)
    }

    func testANewDownloadCanStartAfterOneFails() async throws {
        let manager = LLMModelManager.shared
        var transfers = 0
        manager.defaultModelTransfer = { _ in
            transfers += 1
            throw URLError(.notConnectedToInternet)
        }

        do {
            try await manager.downloadDefaultModel()
            XCTFail("the failure reaches the caller")
        } catch {}
        XCTAssertNil(manager.defaultModelProgress)

        manager.defaultModelTransfer = { _ in transfers += 1 }
        try await manager.downloadDefaultModel()
        XCTAssertEqual(transfers, 2, "a failed download doesn't block the retry")
    }
}
