import Foundation

/// The Stats tab's ranges. Week is the last 7 days ending today (a rolling week, so its
/// comparison with the 7 days before is always like for like); Month and Year are the
/// calendar month and year so far.
enum StatsRange: String, CaseIterable, Identifiable, Sendable {
    case week, month, year, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .all: return "All time"
        }
    }
}

/// Everything the Stats tab (and Home's "This week" card) shows for one range, computed
/// from the local history only (RecordingStore.fetchWrappedDictations). Pure: tested in
/// RhinoStatsTests; RhinoStatsModel loads, caches and runs it off the main thread.
struct RhinoStats: Equatable, Sendable {
    /// Typing speed the time-saved and "× your typing" lines compare against. Same 40 WPM
    /// Home's stats strip has always used (DictationStats.secondsSaved).
    static let typingWPM = 40.0
    /// Weeks in the streak heatmap.
    static let heatmapWeeks = 20

    struct Totals: Equatable, Sendable {
        var words = 0
        var seconds: Double = 0
        var dictations = 0
        var activeDays = 0

        /// Words per minute while speaking. Same rule as Home's strip: 0 under 5 seconds.
        var wpm: Int { seconds > 5 ? Int((Double(words) / (seconds / 60)).rounded()) : 0 }
        /// Typing the same words at `typingWPM`, minus the time spent dictating.
        var secondsSaved: Double { max(0, Double(words) / RhinoStats.typingWPM * 60 - seconds) }
    }

    struct Bar: Equatable, Sendable, Identifiable {
        let start: Date
        let words: Int
        var id: Date { start }
    }

    struct AppShare: Equatable, Sendable, Identifiable {
        let name: String
        let words: Int
        var id: String { name }
    }

    struct KPI: Equatable, Identifiable {
        enum Trend: Equatable { case up, down, flat, context }
        let label: String
        let value: String
        let unit: String
        let note: String
        let trend: Trend
        var id: String { label }
    }

    let range: StatsRange
    let now: Date
    let interval: DateInterval
    /// The equal earlier period the change lines compare against (nil for Year / All time).
    let previous: DateInterval?
    let totals: Totals
    let previousTotals: Totals?
    /// First dictation inside the range.
    let firstDate: Date?
    /// Words per day (Week, Month) or per month (Year, All time).
    let bars: [Bar]
    let apps: [AppShare]
    /// Streaks and the heatmap are about habits, so they read the whole history.
    let currentStreak: Int
    let bestStreak: Int
    /// `heatmapWeeks` columns of 7 days, oldest first; 0–4 intensity, -1 for days after today.
    let heatmap: [[Int]]
    /// Wrapped for this range only (needs one dictation in it, not ten).
    let wrapped: RhinoWrapped?
    /// Completed, non-empty dictations all time: under 10, Wrapped stays locked everywhere.
    let countedDictations: Int

    var barsByMonth: Bool { range == .year || range == .all }
}

// MARK: - Computation

extension RhinoStats {
    /// The range's own interval and the equal earlier one it's compared with.
    /// Intervals are half-open and end at the start of tomorrow.
    static func period(_ range: StatsRange, now: Date, firstDate: Date?,
                       calendar: Calendar) -> (current: DateInterval, previous: DateInterval?) {
        // Every boundary goes through startOfDay: where DST starts at midnight (Chile,
        // Paraguay…) that day begins at 01:00, and adding days to it keeps the 01:00.
        let today = calendar.startOfDay(for: now)
        let end = calendar.dateInterval(of: .day, for: now)!.end
        switch range {
        case .week:
            let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: today)!)
            let previousStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: start)!)
            return (DateInterval(start: start, end: end), DateInterval(start: previousStart, end: start))
        case .month:
            let start = calendar.dateInterval(of: .month, for: now)!.start
            // Last month's same days so far (Oct 1–24 against Nov 1–24), never past its end.
            let elapsed = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            let previousStart = calendar.date(byAdding: .month, value: -1, to: start)!
            let previousEnd = min(calendar.startOfDay(for: calendar.date(byAdding: .day, value: elapsed,
                                                                         to: previousStart)!), start)
            return (DateInterval(start: start, end: end), DateInterval(start: previousStart, end: previousEnd))
        case .year:
            let start = calendar.dateInterval(of: .year, for: now)!.start
            return (DateInterval(start: start, end: end), nil)
        case .all:
            let start = min(calendar.startOfDay(for: firstDate ?? now), today)
            return (DateInterval(start: start, end: end), nil)
        }
    }

    /// Words as Home's stats strip counts them: whitespace-separated runs.
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    static func totals(_ rows: [RhinoWrapped.Dictation], in interval: DateInterval,
                       calendar: Calendar) -> Totals {
        var totals = Totals()
        var days = Set<Date>()
        for row in rows where RhinoWrapped.contains(interval, row.timestamp) {
            totals.words += wordCount(row.text)
            totals.seconds += max(row.duration, 0)
            totals.dictations += 1
            days.insert(calendar.startOfDay(for: row.timestamp))
        }
        totals.activeDays = days.count
        return totals
    }

    static func compute(_ allRows: [RhinoWrapped.Dictation], range: StatsRange, now: Date = Date(),
                        calendar: Calendar = .current) -> RhinoStats {
        let rows = allRows.filter { !$0.text.isEmpty }
        let (interval, previous) = period(range, now: now, firstDate: rows.map(\.timestamp).min(),
                                          calendar: calendar)
        let inRange = rows.filter { RhinoWrapped.contains(interval, $0.timestamp) }

        // Bars: one per day, or one per month, from the range's start through today.
        let unit: Calendar.Component = range == .year || range == .all ? .month : .day
        var bucketStarts: [Date] = []
        var cursor = calendar.dateInterval(of: unit, for: interval.start)!.start
        while cursor < interval.end {
            bucketStarts.append(cursor)
            // The bucket's own end, not cursor + 1: keeps every start on a true day start.
            cursor = calendar.dateInterval(of: unit, for: cursor)!.end
        }
        var bucketWords: [Date: Int] = [:]
        var appWords: [String: Int] = [:]
        for row in inRange {
            let words = wordCount(row.text)
            if let bucket = calendar.dateInterval(of: unit, for: row.timestamp)?.start {
                bucketWords[bucket, default: 0] += words
            }
            if let app = row.sourceAppName?.trimmingCharacters(in: .whitespaces), !app.isEmpty {
                appWords[app, default: 0] += words
            }
        }
        let apps = appWords
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(5)
            .map { AppShare(name: $0.key, words: $0.value) }

        // Streaks and heatmap: the whole history.
        var dayWords: [Date: Int] = [:]
        for row in rows { dayWords[calendar.startOfDay(for: row.timestamp), default: 0] += wordCount(row.text) }
        let days = Set(dayWords.keys)

        return RhinoStats(
            range: range,
            now: now,
            interval: interval,
            previous: previous,
            totals: totals(rows, in: interval, calendar: calendar),
            previousTotals: previous.map { totals(rows, in: $0, calendar: calendar) },
            firstDate: inRange.map(\.timestamp).min(),
            bars: bucketStarts.map { Bar(start: $0, words: bucketWords[$0] ?? 0) },
            apps: Array(apps),
            currentStreak: currentStreak(days, now: now, calendar: calendar),
            bestStreak: RhinoWrapped.longestStreak(days, calendar: calendar),
            heatmap: heatmap(dayWords, now: now, calendar: calendar),
            wrapped: RhinoWrapped.compute(inRange, minimum: 1, calendar: calendar),
            countedDictations: rows.count)
    }

    /// Consecutive days with a dictation, ending today, or yesterday when today has none
    /// yet (so the morning doesn't read "0-day streak").
    static func currentStreak(_ days: Set<Date>, now: Date, calendar: Calendar) -> Int {
        var day = calendar.startOfDay(for: now)
        let dayBefore = { (day: Date) in
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: day)!)
        }
        if !days.contains(day) { day = dayBefore(day) }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = dayBefore(day)
        }
        return streak
    }

    /// GitHub-style: `heatmapWeeks` week columns ending with this week, each Sunday (or the
    /// locale's first weekday) first. Levels are quarters of the busiest day in view.
    static func heatmap(_ dayWords: [Date: Int], now: Date, calendar: Calendar) -> [[Int]] {
        let today = calendar.startOfDay(for: now)
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let first = calendar.date(byAdding: .weekOfYear, value: -(heatmapWeeks - 1), to: thisWeek)!
        let columns: [[Date]] = (0..<heatmapWeeks).map { week in
            (0..<7).map { calendar.startOfDay(for: calendar.date(byAdding: .day, value: week * 7 + $0, to: first)!) }
        }
        let busiest = columns.joined().filter { $0 <= today }.map { dayWords[$0] ?? 0 }.max() ?? 0
        return columns.map { column in
            column.map { day in
                if day > today { return -1 }
                let words = dayWords[day] ?? 0
                guard words > 0, busiest > 0 else { return 0 }
                return min(4, max(1, Int((Double(words) / Double(busiest) * 4).rounded(.up))))
            }
        }
    }

    /// Percent change, rounded; nil when there's nothing to compare with.
    static func percentChange(_ current: Int, _ previous: Int) -> Int? {
        guard previous > 0 else { return nil }
        return Int((Double(current - previous) / Double(previous) * 100).rounded())
    }
}

// MARK: - Display

extension RhinoStats {
    private static func formatter(_ template: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static func decimal(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// "3,410", or "11.2K" from ten thousand up.
    static func wordsText(_ n: Int) -> String {
        n >= 10_000 ? RhinoWrapped.compact(n) : decimal(n)
    }

    /// The last day inside the range (its end is the start of tomorrow).
    private var lastDay: Date { interval.end.addingTimeInterval(-1) }

    /// "Nov 18–24"; across a month boundary "Oct 28–Nov 3".
    static func dayRange(_ start: Date, _ last: Date, calendar: Calendar) -> String {
        let md = formatter("MMMd", calendar: calendar)
        if calendar.isDate(start, equalTo: last, toGranularity: .month) {
            return md.string(from: start) + "–" + formatter("d", calendar: calendar).string(from: last)
        }
        return md.string(from: start) + "–" + md.string(from: last)
    }

    /// Who the change lines compare with: "last week", "October".
    func comparedWith(calendar: Calendar = .current) -> String {
        switch range {
        case .week: return "last week"
        case .month:
            guard let previous else { return "last month" }
            return Self.formatter("MMMM", calendar: calendar).string(from: previous.start)
        case .year, .all: return ""
        }
    }

    /// Share button: "Share this week" / "Share November" / "Share 2026" / "Share all time".
    func shareLabel(calendar: Calendar = .current) -> String {
        switch range {
        case .week: return "this week"
        case .month: return Self.formatter("MMMM", calendar: calendar).string(from: interval.start)
        case .year: return Self.formatter("yyyy", calendar: calendar).string(from: interval.start)
        case .all: return "all time"
        }
    }

    /// "Your week Wrapped" / "Your November Wrapped" / "Your 2026 Wrapped" / "Your all-time Wrapped".
    func wrappedTitle(calendar: Calendar = .current) -> String {
        switch range {
        case .week: return "Your week Wrapped"
        case .all: return "Your all-time Wrapped"
        default: return "Your \(shareLabel(calendar: calendar)) Wrapped"
        }
    }

    /// Next to the chart title and on the shared image: "Nov 18–24", "Nov 1–24", "by month".
    func chartNote(calendar: Calendar = .current) -> String {
        barsByMonth ? "by month" : Self.dayRange(interval.start, lastDay, calendar: calendar)
    }

    /// Under the title on a shared image: which days the stats cover.
    func shareSubtitle(calendar: Calendar = .current) -> String {
        switch range {
        case .week, .month: return Self.dayRange(interval.start, lastDay, calendar: calendar)
        case .year: return shareLabel(calendar: calendar) + " so far"
        case .all: return wrapped?.sinceText(now: now, calendar: calendar) ?? "all time"
        }
    }

    /// Up to four labels spread under the bars: first, last and two between.
    func axisLabels(calendar: Calendar = .current) -> [String] {
        guard !bars.isEmpty else { return [] }
        let spansYears = !calendar.isDate(bars.first!.start, equalTo: bars.last!.start, toGranularity: .year)
        let template: String
        switch range {
        case .week: template = "EEE"
        case .month: template = "MMMd"
        case .year: template = "MMM"
        case .all: template = spansYears ? "MMMyy" : "MMM"
        }
        let f = Self.formatter(template, calendar: calendar)
        let last = bars.count - 1
        let picks = last < 3 ? Array(0...last) : [0, last / 3, (2 * last) / 3, last]
        var seen = Set<Int>()
        return picks.filter { seen.insert($0).inserted }.map { f.string(from: bars[$0].start) }
    }

    /// The four KPI cards. Week and Month compare with the equal earlier period; Year and
    /// All time have nothing equal to compare with, so they get a context line instead.
    func kpis(calendar: Calendar = .current) -> [KPI] {
        let saved = totals.secondsSaved
        let savedValue: (String, String) = saved < 3600
            ? ("\(Int((saved / 60).rounded()))", "min")
            : (String(format: "%.1f", saved / 3600), "hrs")
        let wpm = totals.wpm

        let values: [(String, String, String)] = [
            ("Words", Self.wordsText(totals.words), "words"),
            ("Time saved", savedValue.0, savedValue.1),
            ("Dictations", Self.decimal(totals.dictations), ""),
            ("Speed", wpm > 0 ? "\(wpm)" : "—", "wpm"),
        ]

        let notes: [(String, KPI.Trend)]
        if let previousTotals {
            let vs = "vs " + comparedWith(calendar: calendar)
            notes = [
                Self.percentNote(totals.words, previousTotals.words, vs: vs),
                Self.percentNote(Int(saved.rounded()), Int(previousTotals.secondsSaved.rounded()), vs: vs),
                Self.countNote(totals.dictations, previousTotals.dictations, vs: vs,
                               hasPrevious: previousTotals.dictations > 0),
                wpm > 0 && previousTotals.wpm > 0
                    ? Self.countNote(wpm, previousTotals.wpm, vs: vs, hasPrevious: true)
                    : ("none " + comparedWith(calendar: calendar), .context),
            ]
        } else {
            let since = firstDate.map {
                "since " + Self.formatter(
                    calendar.isDate($0, equalTo: now, toGranularity: .year) ? "MMMd" : "MMMdyyyy",
                    calendar: calendar).string(from: $0)
            } ?? "no dictations yet"
            let workdays = saved / (8 * 3600)
            let workdayText = workdays >= 9.95 ? "\(Int(workdays.rounded()))"
                : String(format: "%.1f", workdays).replacingOccurrences(of: ".0", with: "")
            let typing = Double(wpm) / Self.typingWPM
            notes = [
                (since, .context),
                (saved > 0 ? "≈ \(workdayText) workday\(workdayText == "1" ? "" : "s")" : "keep talking", .context),
                (totals.activeDays == 1 ? "on 1 day" : "on \(Self.decimal(totals.activeDays)) days", .context),
                (wpm > 0 ? String(format: "%.1f× your typing", typing) : "—", .context),
            ]
        }

        return zip(values, notes).map { value, note in
            KPI(label: value.0, value: value.1, unit: value.2, note: note.0, trend: note.1)
        }
    }

    /// "↑ 22% vs last week".
    static func percentNote(_ current: Int, _ previous: Int, vs: String) -> (String, KPI.Trend) {
        guard let change = percentChange(current, previous) else {
            return (current > 0 ? "new " + vs : "—", .context)
        }
        if change == 0 { return ("same as " + vs.dropFirst(3), .flat) }
        return ("\(change > 0 ? "↑" : "↓") \(abs(change))% \(vs)", change > 0 ? .up : .down)
    }

    /// "↑ 9 vs last week".
    static func countNote(_ current: Int, _ previous: Int, vs: String, hasPrevious: Bool) -> (String, KPI.Trend) {
        guard hasPrevious else { return (current > 0 ? "new " + vs : "—", .context) }
        let change = current - previous
        if change == 0 { return ("same as " + vs.dropFirst(3), .flat) }
        return ("\(change > 0 ? "↑" : "↓") \(decimal(abs(change))) \(vs)", change > 0 ? .up : .down)
    }

    // MARK: Home's "This week" card (Week range)

    /// "This week: 3,410 words, up 22%".
    var weekHeadline: String {
        var line = "This week: \(Self.decimal(totals.words)) word\(totals.words == 1 ? "" : "s")"
        if let previousTotals, let change = Self.percentChange(totals.words, previousTotals.words) {
            line += change == 0 ? ", same as last week" : ", \(change > 0 ? "up" : "down") \(abs(change))%"
        }
        return line
    }

    /// "6-day streak · most in Slack · your word this week: “honestly”". Parts with no
    /// data are left out.
    var weekSubline: String {
        var parts: [String] = []
        if currentStreak > 0 { parts.append("\(currentStreak)-day streak") }
        if let app = wrapped?.topApp { parts.append("most in \(app)") }
        if let word = wrapped?.topWord { parts.append("your word this week: “\(word)”") }
        return parts.isEmpty ? "No dictations in the last 7 days yet" : parts.joined(separator: " · ")
    }
}
