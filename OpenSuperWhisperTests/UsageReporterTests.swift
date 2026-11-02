import XCTest
@testable import OpenSuperWhisper

/// Opt-in usage counts (default-off is checked statically by tests/hygiene): nothing counted while off, opt-out forgets everything.
@MainActor
final class UsageReporterTests: XCTestCase {
    private var savedEnabled = false

    override func setUp() async throws {
        savedEnabled = AppPreferences.shared.shareUsageStats
    }

    override func tearDown() async throws {
        AppPreferences.shared.shareUsageStats = savedEnabled
        UsageReporter.shared.setEnabled(savedEnabled)
    }

    func testNothingCountedWhileOff() {
        AppPreferences.shared.shareUsageStats = false
        UsageReporter.shared.setEnabled(false)
        UsageReporter.shared.record(words: 12, seconds: 4)
        XCTAssertTrue(UsageReporter.shared.loadPending().isEmpty)
    }

    func testCountsAccumulateWhileOnAndOptOutForgetsThem() {
        AppPreferences.shared.shareUsageStats = true
        UsageReporter.shared.setEnabled(true)
        UsageReporter.shared.record(words: 10, seconds: 3.4)
        UsageReporter.shared.record(words: 5, seconds: 2)
        let today = UsageReporter.dayString(Date())
        let counts = UsageReporter.shared.loadPending()[today]
        XCTAssertGreaterThanOrEqual(counts?.words ?? 0, 15)
        XCTAssertGreaterThanOrEqual(counts?.dictations ?? 0, 2)

        AppPreferences.shared.shareUsageStats = false
        UsageReporter.shared.setEnabled(false)
        XCTAssertTrue(UsageReporter.shared.loadPending().isEmpty)
    }

    func testPendingKeepsOnlyTheNewestDays() {
        var pending: [String: UsageReporter.DayCounts] = [:]
        for i in 1...40 { pending[String(format: "2026-01-%02d", i)] = .init(words: i) }
        let trimmed = UsageReporter.trimmed(pending)
        XCTAssertEqual(trimmed.count, UsageReporter.maxPendingDays)
        XCTAssertNil(trimmed["2026-01-01"])
        XCTAssertNotNil(trimmed["2026-01-40"])
    }

    func testDayStringIsISO() {
        XCTAssertEqual(UsageReporter.dayString(Date()).count, 10)
        XCTAssertNotNil(UsageReporter.dayString(Date()).range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression))
    }
}
