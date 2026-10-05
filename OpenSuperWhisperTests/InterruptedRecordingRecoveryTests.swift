import GRDB
import XCTest
@testable import OpenSuperWhisper

final class InterruptedRecordingRecoveryTests: XCTestCase {
    func testRestartQuarantinesOnlyInterruptedJobsAndPreservesTheirData() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer {
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path.path + suffix) }
        }
        let database = try DatabaseQueue(path: path.path)
        try database.write { db in
            try db.execute(sql: """
                CREATE TABLE recordings (
                    id TEXT PRIMARY KEY, status TEXT, progress DOUBLE,
                    transcription TEXT, sourceFileURL TEXT, failureDetail TEXT
                )
                """)
            for status in ["pending", "converting", "transcribing", "completed", "failed"] {
                try db.execute(sql: "INSERT INTO recordings VALUES (?, ?, ?, ?, ?, ?)",
                               arguments: [status, status, 0.5, "existing transcript", "/audio/original.m4a", "original detail"])
            }
        }
        try database.close()
        let reopened = try DatabaseQueue(path: path.path)
        try RecordingStore.recoverInterruptedRecordings(in: reopened)
        // Repeated launches must not retry or rewrite failed rows.
        try RecordingStore.recoverInterruptedRecordings(in: reopened)
        try reopened.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM recordings")
            XCTAssertEqual(rows.count, 5)
            for row in rows {
                let original: String = row["id"]
                let interrupted = ["converting", "transcribing"].contains(original)
                XCTAssertEqual(row["status"] as String, interrupted ? "failed" : original)
                XCTAssertEqual(row["progress"] as Double, interrupted ? 0 : 0.5)
                XCTAssertEqual(row["transcription"] as String, "existing transcript")
                XCTAssertEqual(row["sourceFileURL"] as String, "/audio/original.m4a")
                let detail: String = row["failureDetail"]
                if interrupted { XCTAssertTrue(detail.contains("Retry")) }
                else { XCTAssertEqual(detail, "original detail") }
            }
        }
        try reopened.close()
    }
}
