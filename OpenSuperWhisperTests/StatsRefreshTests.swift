import GRDB
import XCTest
@testable import OpenSuperWhisper

/// Stats cache signature, the midnight rollover signal, and History's in-place refresh.
@MainActor
final class StatsRefreshTests: XCTestCase {
    // MARK: Cache signature

    private func makeDatabase() throws -> DatabaseQueue {
        var config = Configuration()
        config.prepareDatabase { db in db.add(function: RecordingStore.rowHashFunction) }
        let database = try DatabaseQueue(configuration: config)
        try database.write { db in
            try db.execute(sql: """
                CREATE TABLE recordings (
                    id TEXT PRIMARY KEY, timestamp DATETIME, transcription TEXT, status TEXT,
                    sourceAppName TEXT, duration DOUBLE
                )
                """)
            try db.execute(sql: "INSERT INTO recordings VALUES ('a', '2026-11-23 10:00:00', 'hello world', 'completed', 'Slack', 3)")
            try db.execute(sql: "INSERT INTO recordings VALUES ('b', '2026-11-24 09:00:00', 'second one', 'completed', NULL, 2)")
            try db.execute(sql: "INSERT INTO recordings VALUES ('c', '2026-11-24 09:30:00', 'pending text', 'pending', NULL, 1)")
        }
        return database
    }

    private func signature(_ database: DatabaseQueue) throws -> String {
        try database.read { try RecordingStore.historySignature($0) }
    }

    func testSignatureCatchesSameLengthEdit() throws {
        let database = try makeDatabase()
        let before = try signature(database)
        try database.write { try $0.execute(sql: "UPDATE recordings SET transcription = 'hello wordl' WHERE id = 'a'") }
        XCTAssertNotEqual(before, try signature(database))
    }

    func testSignatureCatchesAppAndDurationEdits() throws {
        let database = try makeDatabase()
        let before = try signature(database)
        try database.write { try $0.execute(sql: "UPDATE recordings SET sourceAppName = 'Mail' WHERE id = 'a'") }
        let afterApp = try signature(database)
        XCTAssertNotEqual(before, afterApp)
        try database.write { try $0.execute(sql: "UPDATE recordings SET duration = 4 WHERE id = 'a'") }
        XCTAssertNotEqual(afterApp, try signature(database))
    }

    func testSignatureIgnoresUnfinishedRowsAndIsStable() throws {
        let database = try makeDatabase()
        let before = try signature(database)
        XCTAssertEqual(before, try signature(database))
        try database.write { try $0.execute(sql: "UPDATE recordings SET transcription = 'pending texT' WHERE id = 'c'") }
        XCTAssertEqual(before, try signature(database))
    }

    func testRowHashSeparatesFields() {
        XCTAssertNotEqual(RecordingStore.rowHash(["ab", "c"]), RecordingStore.rowHash(["a", "bc"]))
        XCTAssertEqual(RecordingStore.rowHash(["x", "y"]), RecordingStore.rowHash(["x", "y"]))
    }

    // MARK: Day rollover

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testDayClockPublishesOnlyWhenTheDayChanges() {
        let calendar = utc
        var now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 23, minute: 59))!
        let clock = DayClock(now: { now }, calendar: { calendar }, observe: false)
        let start = clock.today
        var published = 0
        let sink = clock.$today.dropFirst().sink { _ in published += 1 }
        defer { sink.cancel() }

        now = now.addingTimeInterval(30)  // still Nov 24
        XCTAssertFalse(clock.check())
        XCTAssertEqual(clock.today, start)

        now = now.addingTimeInterval(60)  // past midnight
        XCTAssertTrue(clock.check())
        XCTAssertEqual(clock.today, calendar.date(from: DateComponents(year: 2026, month: 11, day: 25)))
        XCTAssertFalse(clock.check())
        XCTAssertEqual(published, 1)
    }

    func testDayClockPublishesOnTimeZoneChange() {
        var calendar = utc
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
        let clock = DayClock(now: { now }, calendar: { calendar }, observe: false)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!  // same day, other zone
        XCTAssertTrue(clock.check())
    }

    func testHistoryDayHeaderRollsOver() {
        let calendar = utc
        let dictated = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 22))!
        let sameDay = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24))!
        let nextDay = calendar.date(from: DateComponents(year: 2026, month: 11, day: 25))!
        XCTAssertEqual(ContentView.dayHeader(dictated, now: sameDay, calendar: calendar), "Today")
        XCTAssertEqual(ContentView.dayHeader(dictated, now: nextDay, calendar: calendar), "Yesterday")
    }

    // MARK: History refresh

    func testRefreshLimitCoversLoadedRowsInWholePages() {
        XCTAssertEqual(ContentViewModel.refreshLimit(loaded: 0, pageSize: 100), 100)
        XCTAssertEqual(ContentViewModel.refreshLimit(loaded: 100, pageSize: 100), 100)
        XCTAssertEqual(ContentViewModel.refreshLimit(loaded: 101, pageSize: 100), 200)
        XCTAssertEqual(ContentViewModel.refreshLimit(loaded: 250, pageSize: 100), 300)
    }
}
