import SwiftUI
import XCTest

@testable import OpenSuperWhisper

/// Rhino Wrapped's stats (RhinoWrapped.swift). Fixed calendar so streaks, hours and
/// weekends don't depend on the machine running the tests.
final class RhinoWrappedTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.locale = Locale(identifier: "en_US")
        return c
    }()

    /// 2026-11-02 is a Monday.
    private func date(day: Int, hour: Int = 10, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func dictation(_ text: String, day: Int, hour: Int = 10, app: String? = "Slack") -> RhinoWrapped.Dictation {
        .init(text: text, timestamp: date(day: day, hour: hour), sourceAppName: app)
    }

    private func filler(_ n: Int, startDay: Int = 2) -> [RhinoWrapped.Dictation] {
        (0..<n).map { dictation("Okay yeah sure.", day: startDay + $0) }
    }

    func testHiddenUntilTenDictations() {
        XCTAssertNil(RhinoWrapped.compute(filler(9), calendar: calendar))
        XCTAssertNotNil(RhinoWrapped.compute(filler(10), calendar: calendar))
        // Empty transcripts don't count toward the threshold.
        let withBlanks = filler(9) + [dictation("", day: 20)]
        XCTAssertNil(RhinoWrapped.compute(withBlanks, calendar: calendar))
    }

    func testTopWordSkipsStopwordsShortWordsAndFillersAndPicksItsPhrase() {
        var rows = filler(8)
        rows.append(dictation("I think we should ship it. I think so. Um, I like the API.", day: 20))
        rows.append(dictation("Do you think the the the doc is ready? I think yes, think.", day: 21))
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.topWord, "think")
        XCTAssertEqual(w.topWordCount, 5)
        XCTAssertEqual(w.topPhrase, "i think")
        XCTAssertEqual(w.topPhraseCount, 3)
        XCTAssertEqual(w.tiles(calendar: calendar)[0].value, "“think”")
        XCTAssertEqual(w.tiles(calendar: calendar)[0].note, "5 times · “I think” ×3")
    }

    func testPhraseNeverSpansSentences() {
        XCTAssertEqual(RhinoWrapped.sentences("Done. Think about it? Don't stop"),
                       [["done"], ["think", "about", "it"], ["don't", "stop"]])
        XCTAssertEqual(RhinoWrapped.sentences("it’s fine"), [["it's", "fine"]])
    }

    /// Chinese/Japanese/Thai have no spaces; whole clauses must never become a "word"
    /// (they'd land in the shared image).
    func testUnspacedScriptsSplitIntoWordsNotClauses() {
        let zh = "我今天下午要和客户开会讨论新产品的发布计划。然后我们一起吃晚饭！"
        let sentences = RhinoWrapped.sentences(zh)
        XCTAssertEqual(sentences.count, 2)
        XCTAssertGreaterThan(sentences[0].count, 5)
        for token in sentences.flatMap({ $0 }) { XCTAssertLessThanOrEqual(token.count, 6, token) }

        let rows = filler(8) + [dictation(zh, day: 20), dictation("ประชุมกับลูกค้าตอนบ่ายเรื่องแผนเปิดตัวสินค้าใหม่", day: 21)]
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertGreaterThan(w.biggestRambleWords, 5)
        for tile in w.tiles(calendar: calendar) {
            XCTAssertFalse(tile.value.contains("客户开会讨论"), tile.value)
            XCTAssertFalse(tile.note.contains("客户开会讨论"), tile.note)
        }
    }

    func testOverlongTokensNeverShowAsYourWord() {
        let long = "supercalifragilisticexpialidocious" // 34 letters
        let rows = filler(8) + [dictation("\(long) \(long) \(long) rhino", day: 20), dictation("rhino", day: 21)]
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.topWord, "rhino")
        XCTAssertNil(w.topPhrase.flatMap { $0.contains(long) ? $0 : nil })
    }

    func testLikeAsVerbIsNotAFillerAndJustIsNeverOne() {
        XCTAssertFalse(RhinoWrapped.isFiller("like", after: "i"))
        XCTAssertFalse(RhinoWrapped.isFiller("like", after: "would"))
        XCTAssertFalse(RhinoWrapped.isFiller("like", after: "looks"))
        XCTAssertTrue(RhinoWrapped.isFiller("like", after: "was"))
        XCTAssertTrue(RhinoWrapped.isFiller("like", after: nil))
        XCTAssertFalse(RhinoWrapped.isFiller("just", after: nil))

        var rows = filler(8)
        rows.append(dictation("I like it. We would like more. It looks like rain. I just really like that.", day: 20))
        rows.append(dictation("Um, it was like, actually fine. Uh.", day: 21))
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.topFiller, "actually") // like ×1, actually ×1, um ×1, uh ×1: alphabetical tie-break
        XCTAssertEqual(w.topFillerCount, 1)
    }

    func testContentWordRules() {
        XCTAssertFalse(RhinoWrapped.isContentWord("ok"))     // ≤ 2 letters
        XCTAssertFalse(RhinoWrapped.isContentWord("the"))    // stopword
        XCTAssertFalse(RhinoWrapped.isContentWord("literally")) // filler
        XCTAssertFalse(RhinoWrapped.isContentWord("2026"))   // number
        XCTAssertTrue(RhinoWrapped.isContentWord("rhino"))
    }

    func testTopAppByWords() {
        var rows = filler(8) // 3 words each in Slack = 24
        rows.append(dictation(String(repeating: "word ", count: 40), day: 20, app: "Claude"))
        rows.append(dictation("one two", day: 21, app: nil))
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.topApp, "Claude")
        XCTAssertEqual(w.topAppWords, 40)
        XCTAssertEqual(w.tiles(calendar: calendar)[1].note, "40 words")
    }

    func testFillerOfChoiceAndUmFootnote() {
        var rows = filler(8)
        rows.append(dictation("Like, I just like it. Like literally. Um.", day: 20))
        rows.append(dictation("Basically like that. Um, uh.", day: 21))
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.topFiller, "like")
        XCTAssertEqual(w.topFillerCount, 4)
        XCTAssertEqual(w.fillerFootnoteWord, "um")
        XCTAssertEqual(w.fillerFootnoteCount, 2)
        XCTAssertEqual(w.tiles(calendar: calendar)[2].note, "4 times · “um” just 2")
    }

    func testStreakAndActiveDays() {
        // Days 2–6 (5 in a row), then 10–12 (3), with two dictations on day 3.
        let days = [2, 3, 3, 4, 5, 6, 10, 11, 12, 20]
        let rows = days.map { dictation("Okay yeah sure.", day: $0) }
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.bestStreakDays, 5)
        XCTAssertEqual(w.activeDays, 9)
        XCTAssertEqual(w.tiles(calendar: calendar)[3].value, "5 days")
        XCTAssertEqual(w.tiles(calendar: calendar)[3].note, "9 days talking")
    }

    func testStreakCrossesMonthEndAndDaylightSavingChange() {
        // Oct 28 → Nov 2 is 6 days in a row; US clocks fall back on Nov 1, 2026.
        let october = [28, 29, 30, 31].map {
            RhinoWrapped.Dictation(text: "hi", timestamp: date(day: $0, month: 10), sourceAppName: nil)
        }
        let rows = october + [1, 2, 10, 12, 14, 16].map { dictation("hi", day: $0) }
        XCTAssertEqual(RhinoWrapped.compute(rows, calendar: calendar)!.bestStreakDays, 6)
    }

    func testPeakHourWindowAndWeekday() {
        // Fridays (Nov 6, 13, 20) at 5 and 6 PM; a few mornings elsewhere.
        var rows: [RhinoWrapped.Dictation] = []
        for day in [6, 13, 20] {
            rows.append(dictation("hello there", day: day, hour: 17))
            rows.append(dictation("hello again", day: day, hour: 18))
        }
        for day in [2, 3, 4, 9] { rows.append(dictation("morning", day: day, hour: 9)) }
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.peakHourStart, 17)
        XCTAssertEqual(w.peakWeekday, 6)
        let tile = w.tiles(calendar: calendar)[4]
        XCTAssertEqual(tile.value, "5–7 PM")
        XCTAssertEqual(tile.note, "Fridays most")
    }

    func testHourWindowLabels() {
        XCTAssertEqual(RhinoWrapped.hourWindow(17), "5–7 PM")
        XCTAssertEqual(RhinoWrapped.hourWindow(9), "9–11 AM")
        XCTAssertEqual(RhinoWrapped.hourWindow(11), "11 AM–1 PM")
        XCTAssertEqual(RhinoWrapped.hourWindow(23), "11 PM–1 AM")
        XCTAssertEqual(RhinoWrapped.hourWindow(0), "12–2 AM")
        XCTAssertEqual(RhinoWrapped.hourWindow(22), "10 PM–12 AM")
    }

    func testRambleQuestionsPleaseAndWeekend() {
        var rows = filler(8) // Nov 2–9: includes Sat 7 and Sun 8
        rows.append(dictation("Can you help? Please? What now? " + String(repeating: "go ", count: 100), day: 14)) // Sat
        rows.append(dictation("please send it, PLEASE.", day: 16))
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.biggestRambleWords, 106)
        XCTAssertEqual(w.questions, 3)
        XCTAssertEqual(w.pleaseCount, 3)
        XCTAssertEqual(w.weekendDictations, 3)
        let tiles = w.tiles(calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(tiles[5].value, "106 words")
        XCTAssertEqual(tiles[6].value, "3")
        XCTAssertEqual(tiles[6].note, "“please” said 3 times")
        XCTAssertEqual(tiles[7].value, "3 times")
        XCTAssertEqual(tiles[7].note, "30% of your talking")
    }

    func testWeekendRestNote() {
        let rows = (2...6).flatMap { day in [dictation("hi there", day: day), dictation("bye now", day: day)] }
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.weekendDictations, 0)
        XCTAssertEqual(w.tiles(calendar: calendar)[7].note, "you rest on weekends")
    }

    func testSinceTextAndFirstDate() {
        var rows = filler(10, startDay: 5)
        rows.append(dictation("earliest", day: 3))
        let w = RhinoWrapped.compute(rows, calendar: calendar)!
        XCTAssertEqual(w.firstDate, date(day: 3))
        XCTAssertEqual(w.sinceText(now: date(day: 20), calendar: calendar), "since Nov 3")
        let nextYear = calendar.date(byAdding: .year, value: 1, to: date(day: 20))!
        XCTAssertEqual(w.sinceText(now: nextYear, calendar: calendar), "since Nov 3, 2026")
    }

    func testCompactNumbers() {
        XCTAssertEqual(RhinoWrapped.compact(950), "950")
        XCTAssertEqual(RhinoWrapped.compact(6_312), "6.3K")
        XCTAssertEqual(RhinoWrapped.compact(1_260_000), "1.3M")
        XCTAssertEqual(RhinoWrapped.compact(999_949), "999.9K")
        XCTAssertEqual(RhinoWrapped.compact(999_960), "1.0M")
    }

    /// The share image renders in both modes (ImageRenderer has no window to lean on).
    /// Copies land in the temp folder for eyeballing: rhino-wrapped-light.png / -dark.png.
    @MainActor
    func testShareImageRendersInBothModes() throws {
        var rows = filler(8)
        rows.append(dictation("I think we should ship it. I think so. Like, um, really?", day: 20, app: "Claude"))
        rows.append(dictation("Do you think it's ready? Please check.", day: 21, app: "Claude"))
        let w = try XCTUnwrap(RhinoWrapped.compute(rows, calendar: calendar))
        for (scheme, name) in [(ColorScheme.light, "light"), (.dark, "dark")] {
            let image = try XCTUnwrap(RhinoWrappedSharer.image(w, scheme: scheme))
            XCTAssertGreaterThan(image.size.width, 700)
            XCTAssertGreaterThan(image.size.height, 150)
            let png = try XCTUnwrap(RhinoWrappedSharer.pngData(image))
            try png.write(to: FileManager.default.temporaryDirectory
                .appendingPathComponent("rhino-wrapped-\(name).png"))
        }
    }

    /// Thousands of dictations must stay fast: the card computes on every new recording.
    func testComputeIsFastForLargeHistory() {
        let sentence = "I think the new onboarding flow is like really close, can we ship it on Friday? "
        let rows = (0..<5_000).map { i in
            RhinoWrapped.Dictation(text: String(repeating: sentence, count: 4),
                                   timestamp: date(day: 1).addingTimeInterval(Double(i) * 3_600),
                                   sourceAppName: i % 3 == 0 ? "Claude" : "Slack")
        }
        let start = Date()
        let w = RhinoWrapped.compute(rows, calendar: calendar)
        XCTAssertNotNil(w)
        XCTAssertLessThan(Date().timeIntervalSince(start), 3.0)
    }
}
