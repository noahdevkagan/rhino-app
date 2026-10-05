import XCTest

@testable import OpenSuperWhisper

/// The recordings database and audio must not be shared between parallel test hosts or with the
/// developer's real history. Every worker used to open and migrate the same recordings.sqlite at
/// launch, and the loser of the lock race crashed in RecordingStore.init's fatalError.
final class RecordingStorageTests: XCTestCase {

    func testTestsUseAPrivateStorageDirectory() {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let real = applicationSupport.appendingPathComponent(Bundle.main.bundleIdentifier!)

        XCTAssertNotEqual(Recording.storageDirectory.standardizedFileURL, real.standardizedFileURL,
                          "tests must not open the app's real recordings database")
        XCTAssertFalse(Recording.recordingsDirectory.path.hasPrefix(real.path),
                       "tests must not write audio into the app's real recordings folder")
        XCTAssertTrue(Recording.storageDirectory.lastPathComponent
                        .contains("\(ProcessInfo.processInfo.processIdentifier)"),
                      "each test process needs its own directory")
    }

    /// The store opening at all is what crashed before; touching `shared` exercises init + migrations.
    @MainActor
    func testStoreOpensInPrivateDirectory() async throws {
        _ = try await RecordingStore.shared.fetchRecordings(limit: 1, offset: 0)
        let db = Recording.storageDirectory.appendingPathComponent("recordings.sqlite")
        XCTAssertTrue(FileManager.default.fileExists(atPath: db.path))
    }
}
