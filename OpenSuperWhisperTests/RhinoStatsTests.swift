import XCTest

@testable import OpenSuperWhisper

/// Stats tab ranges, period-over-period changes and range-only Wrapped (RhinoStats.swift).
/// Fixed calendar so day and month boundaries don't depend on the machine.
final class RhinoStatsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.locale = Locale(identifier: "en_US")
        return c
    }()

    /// 2026-11-24 is a Tuesday.
    private func date(_ month: Int, _ day: Int, hour: Int = 10, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private var now: Date { date(11, 24, hour: 15) }

    private func row(_ words: Int, _ month: Int, _ day: Int, hour: Int = 10, year: Int = 2026,
                     app: String? = "Slack", seconds: Double = 0, word: String = "rhino") -> RhinoWrapped.Dictation {
        .init(text: Array(repeating: word, count: words).joined(separator: " "),
              timestamp: date(month, day, hour: hour, year: year), sourceAppName: app, duration: seconds)
    }

    // MARK: Periods

    func testWeekIsLastSevenDaysComparedWithTheSevenBefore() {
        let (current, previous) = RhinoStats.period(.week, now: now, firstDate: nil, calendar: calendar)
        XCTAssertEqual(current.start, date(11, 18, hour: 0))
        XCTAssertEqual(current.end, date(11, 25, hour: 0))
        XCTAssertEqual(previous?.start, date(11, 11, hour: 0))
        XCTAssertEqual(previous?.end, date(11, 18, hour: 0))
    }

    func testMonthIsCalendarMonthSoFarComparedWithTheSameDaysLastMonth() {
        let (current, previous) = RhinoStats.period(.month, now: now, firstDate: nil, calendar: calendar)
        XCTAssertEqual(current.start, date(11, 1, hour: 0))
        XCTAssertEqual(current.end, date(11, 25, hour: 0))
        XCTAssertEqual(previous?.start, date(10, 1, hour: 0))
        XCTAssertEqual(previous?.end, date(10, 25, hour: 0))

        // March 31 against February: clamped to February's end, never into March.
        let (_, fromMarch) = RhinoStats.period(.month, now: date(3, 31), firstDate: nil, calendar: calendar)
        XCTAssertEqual(fromMarch?.start, date(2, 1, hour: 0))
        XCTAssertEqual(fromMarch?.end, date(3, 1, hour: 0))
    }

    func testYearAndAllTimeHaveNothingToCompareWith() {
        let (year, noPrevious) = RhinoStats.period(.year, now: now, firstDate: nil, calendar: calendar)
        XCTAssertEqual(year.start, date(1, 1, hour: 0))
        XCTAssertNil(noPrevious)
        let (all, alsoNone) = RhinoStats.period(.all, now: now, firstDate: date(8, 11, hour: 9), calendar: calendar)
        XCTAssertEqual(all.start, date(8, 11, hour: 0))
        XCTAssertNil(alsoNone)
    }

    // MARK: Totals and changes

    func testWeekTotalsAndChangesAgainstLastWeek() {
        let rows = [
            row(60, 11, 20, seconds: 30), row(60, 11, 24, seconds: 30), // this week: 120 words, 2 dictations
            row(100, 11, 12, seconds: 40),                               // last week: 100 words, 1 dictation
            row(500, 10, 1),                                             // older: in neither
        ]
        let stats = RhinoStats.compute(rows, range: .week, now: now, calendar: calendar)
        XCTAssertEqual(stats.totals.words, 120)
        XCTAssertEqual(stats.totals.dictations, 2)
        XCTAssertEqual(stats.previousTotals?.words, 100)
        XCTAssertEqual(stats.totals.wpm, 120)        // 120 words in 1 minute
        XCTAssertEqual(stats.previousTotals?.wpm, 150)

        let kpis = stats.kpis(calendar: calendar)
        XCTAssertEqual(kpis.map(\.label), ["Words", "Time saved", "Dictations", "Speed"])
        XCTAssertEqual(kpis[0].note, "↑ 20% vs last week")
        XCTAssertEqual(kpis[0].trend, .up)
        XCTAssertEqual(kpis[2].note, "↑ 1 vs last week")
        XCTAssertEqual(kpis[3].note, "↓ 30 vs last week")
        XCTAssertEqual(kpis[3].trend, .down)
        XCTAssertEqual(stats.weekHeadline, "This week: 120 words, up 20%")
    }

    func testMonthChangeLineNamesLastMonth() {
        let rows = [row(50, 11, 3), row(100, 10, 3), row(400, 10, 28)] // Oct 28 is past Oct 1–24
        let stats = RhinoStats.compute(rows, range: .month, now: now, calendar: calendar)
        XCTAssertEqual(stats.previousTotals?.words, 100)
        XCTAssertEqual(stats.kpis(calendar: calendar)[0].note, "↓ 50% vs October")
    }

    func testNothingLastPeriodSaysNewInsteadOfAPercent() {
        let stats = RhinoStats.compute([row(10, 11, 24)], range: .week, now: now, calendar: calendar)
        XCTAssertEqual(stats.kpis(calendar: calendar)[0].note, "new vs last week")
        XCTAssertEqual(stats.weekHeadline, "This week: 10 words")
        XCTAssertNil(RhinoStats.percentChange(10, 0))
    }

    func testRowOnTheBoundaryCountsInOnePeriodOnly() {
        let boundary = RhinoWrapped.Dictation(text: "one two", timestamp: date(11, 18, hour: 0),
                                              sourceAppName: nil)
        let stats = RhinoStats.compute([boundary], range: .week, now: now, calendar: calendar)
        XCTAssertEqual(stats.totals.words, 2)
        XCTAssertEqual(stats.previousTotals?.words, 0)
    }

    func testYearAndAllTimeShowContextLines() {
        let rows = [row(400, 8, 11, seconds: 120), row(400, 9, 2, seconds: 120), row(10, 1, 5, year: 2025)]
        let year = RhinoStats.compute(rows, range: .year, now: now, calendar: calendar)
        let notes = year.kpis(calendar: calendar).map(\.note)
        XCTAssertEqual(notes[0], "since Aug 11")
        XCTAssertEqual(notes[2], "on 2 days")
        XCTAssertEqual(notes[3], "5.0× your typing") // 800 words in 4 min = 200 wpm vs 40
        XCTAssertTrue(year.kpis(calendar: calendar).allSatisfy { $0.trend == .context })

        let all = RhinoStats.compute(rows, range: .all, now: now, calendar: calendar)
        XCTAssertEqual(all.totals.words, 810)
        XCTAssertEqual(all.kpis(calendar: calendar)[0].note, "since Jan 5, 2025")
    }

    // MARK: Bars, apps, streaks

    func testBarsArePerDayForWeekAndMonthAndPerMonthForYearAndAllTime() {
        let rows = [row(30, 11, 24), row(20, 11, 20), row(5, 8, 11)]
        let week = RhinoStats.compute(rows, range: .week, now: now, calendar: calendar)
        XCTAssertEqual(week.bars.count, 7)
        XCTAssertEqual(week.bars.last?.words, 30)
        XCTAssertEqual(week.bars[2].words, 20) // Nov 20
        XCTAssertEqual(RhinoStats.compute(rows, range: .month, now: now, calendar: calendar).bars.count, 24)
        let year = RhinoStats.compute(rows, range: .year, now: now, calendar: calendar)
        XCTAssertEqual(year.bars.count, 11)
        XCTAssertEqual(year.bars[10].words, 50)
        let all = RhinoStats.compute(rows, range: .all, now: now, calendar: calendar)
        XCTAssertEqual(all.bars.map(\.words), [5, 0, 0, 50]) // Aug … Nov
        XCTAssertEqual(all.axisLabels(calendar: calendar), ["Aug", "Sep", "Oct", "Nov"])
        XCTAssertEqual(week.chartNote(calendar: calendar), "Nov 18–24")
    }

    func testTopAppsAreByWordsInTheRange() {
        let rows = [row(10, 11, 24, app: "Gmail"), row(30, 11, 23, app: "Slack"), row(500, 10, 2, app: "Notes"),
                    row(5, 11, 22, app: nil)]
        let stats = RhinoStats.compute(rows, range: .week, now: now, calendar: calendar)
        XCTAssertEqual(stats.apps.map(\.name), ["Slack", "Gmail"])
    }

    func testCurrentStreakEndsTodayOrYesterday() {
        let days: Set<Date> = Set([21, 22, 23].map { date(11, $0, hour: 0) })
        XCTAssertEqual(RhinoStats.currentStreak(days, now: now, calendar: calendar), 3)
        XCTAssertEqual(RhinoStats.currentStreak(days.union([date(11, 24, hour: 0)]), now: now, calendar: calendar), 4)
        XCTAssertEqual(RhinoStats.currentStreak(days, now: date(11, 26), calendar: calendar), 0)
    }

    func testHeatmapIsTwentyWeeksWithFutureDaysBlank() {
        let stats = RhinoStats.compute([row(40, 11, 24), row(10, 11, 23)], range: .week, now: now, calendar: calendar)
        XCTAssertEqual(stats.heatmap.count, RhinoStats.heatmapWeeks)
        XCTAssertTrue(stats.heatmap.allSatisfy { $0.count == 7 })
        let thisWeek = stats.heatmap.last! // Sun Nov 22 … Sat Nov 28
        XCTAssertEqual(thisWeek, [0, 1, 4, -1, -1, -1, -1])
    }

    // MARK: Wrapped for a range

    func testWrappedCoversOnlyTheRange() {
        var rows = (1...12).map { row(3, 10, $0, word: "invoice") } // October: "invoice"
        rows.append(row(3, 11, 23, word: "honestly"))
        rows.append(row(2, 11, 24, app: "Gmail", word: "honestly"))

        let week = RhinoStats.compute(rows, range: .week, now: now, calendar: calendar)
        XCTAssertEqual(week.wrapped?.dictations, 2)
        XCTAssertEqual(week.wrapped?.topWord, "honestly")
        XCTAssertEqual(week.countedDictations, 14) // the unlock still counts all time
        XCTAssertTrue(week.weekSubline.contains("your word this week: “honestly”"))

        let all = RhinoStats.compute(rows, range: .all, now: now, calendar: calendar)
        XCTAssertEqual(all.wrapped?.topWord, "invoice")
        XCTAssertEqual(all.wrapped?.dictations, 14)

        // A range with no dictations has no Wrapped.
        let quiet = RhinoStats.compute(rows, range: .week, now: date(11, 24, year: 2027), calendar: calendar)
        XCTAssertNil(quiet.wrapped)
    }
}
