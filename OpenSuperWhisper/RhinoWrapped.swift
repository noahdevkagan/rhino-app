import Foundation
import NaturalLanguage

/// "Your Rhino Wrapped": eight playful stats about how this person talks, computed from the
/// local history DB. Pure functions here (unit-tested in RhinoWrappedTests); loading,
/// caching and the card live in RhinoWrappedCard.swift. Nothing leaves the Mac unless the
/// user clicks Share, and the shared image carries only these stats: no transcript text
/// beyond the single top word and phrase.
struct RhinoWrapped: Equatable, Sendable {
    /// One completed dictation, reduced to the columns Wrapped reads.
    struct Dictation: Sendable {
        let text: String
        let timestamp: Date
        let sourceAppName: String?
    }

    /// Below this the stats are noise ("your word: hello"), so the card stays hidden.
    static let minimumDictations = 10

    /// "just" is left out: it is nearly always a real word, so it won every time.
    static let fillers = ["like", "actually", "basically", "literally", "um", "uh"]

    /// "like" after these is the verb or a comparison ("I like", "would like", "looks like"),
    /// not a filler. Cheap, and good enough for a fun stat.
    static let likeNotFillerAfter: Set<String> = [
        "i", "you", "we", "they", "he", "she", "would", "don't", "didn't", "doesn't", "really",
        "i'd", "you'd", "we'd", "they'd", "i'll", "we'll", "you'll", "to", "look", "looks",
        "looked", "feel", "feels", "felt", "sound", "sounds", "seem", "seems", "something",
        "much", "more", "also", "not", "who", "people",
    ]

    /// Longest token shown on the card. Scripts written without spaces can still hand
    /// the tokenizer a long run; this keeps a clause from ever reaching the shared image.
    static let maxDisplayedWordLength = 20

    var firstDate: Date
    var dictations: Int

    var topWord: String?
    var topWordCount = 0
    var topPhrase: String?
    var topPhraseCount = 0

    var topApp: String?
    var topAppWords = 0

    var topFiller: String?
    var topFillerCount = 0
    /// Count of the runner-up filler named in the note: "um", or "uh" when "um" itself won.
    var fillerFootnoteWord = "um"
    var fillerFootnoteCount = 0

    var bestStreakDays = 0
    var activeDays = 0

    /// Start hour (0–23) of the busiest 2-hour window.
    var peakHourStart = 0
    /// Calendar weekday (1 = Sunday … 7 = Saturday) with the most dictations.
    var peakWeekday = 1

    var biggestRambleWords = 0
    var questions = 0
    var pleaseCount = 0
    var weekendDictations = 0
}

// MARK: - Computation

extension RhinoWrapped {
    /// nil until there are `minimumDictations` dictations with any words in them.
    /// One pass over the text; thousands of dictations take well under a second, and the
    /// caller runs it off the main thread.
    static func compute(_ rows: [Dictation], calendar: Calendar = .current) -> RhinoWrapped? {
        let rows = rows.filter { !$0.text.isEmpty }
        guard rows.count >= minimumDictations,
              let first = rows.map(\.timestamp).min() else { return nil }

        var wrapped = RhinoWrapped(firstDate: first, dictations: rows.count)

        var wordCounts: [String: Int] = [:]
        var phraseCounts: [String: Int] = [:]
        var fillerCounts: [String: Int] = [:]
        var appWords: [String: Int] = [:]
        var hourCounts = [Int](repeating: 0, count: 24)
        var weekdayCounts = [Int](repeating: 0, count: 8)
        var days = Set<Date>()

        let tokenizer = NLTokenizer(unit: .word)
        for row in rows {
            var words = 0
            for sentence in sentences(row.text, tokenizer: tokenizer) {
                var previous: String?
                for token in sentence {
                    words += 1
                    if isFiller(token, after: previous) { fillerCounts[token, default: 0] += 1 }
                    if token == "please" { wrapped.pleaseCount += 1 }
                    if isContentWord(token) { wordCounts[token, default: 0] += 1 }
                    if let previous, previous.count <= maxDisplayedWordLength,
                       token.count <= maxDisplayedWordLength {
                        phraseCounts[previous + " " + token, default: 0] += 1
                    }
                    previous = token
                }
            }
            wrapped.questions += row.text.reduce(0) { $1 == "?" || $1 == "？" ? $0 + 1 : $0 }
            wrapped.biggestRambleWords = max(wrapped.biggestRambleWords, words)

            if let app = row.sourceAppName?.trimmingCharacters(in: .whitespaces), !app.isEmpty {
                appWords[app, default: 0] += words
            }
            let parts = calendar.dateComponents([.hour, .weekday], from: row.timestamp)
            hourCounts[parts.hour ?? 0] += 1
            weekdayCounts[parts.weekday ?? 1] += 1
            if calendar.isDateInWeekend(row.timestamp) { wrapped.weekendDictations += 1 }
            days.insert(calendar.startOfDay(for: row.timestamp))
        }

        if let (word, count) = top(wordCounts) {
            wrapped.topWord = word
            wrapped.topWordCount = count
            // The phrase rides on the word ("think" → "I think"), the way people hear it.
            let withWord = phraseCounts.filter { key, _ in
                key.split(separator: " ").contains { $0 == word }
            }
            if let (phrase, phraseCount) = top(withWord), phraseCount > 1 {
                wrapped.topPhrase = phrase
                wrapped.topPhraseCount = phraseCount
            }
        }
        if let (app, count) = top(appWords) {
            wrapped.topApp = app
            wrapped.topAppWords = count
        }
        if let (filler, count) = top(fillerCounts) {
            wrapped.topFiller = filler
            wrapped.topFillerCount = count
        }
        wrapped.fillerFootnoteWord = wrapped.topFiller == "um" ? "uh" : "um"
        wrapped.fillerFootnoteCount = fillerCounts[wrapped.fillerFootnoteWord] ?? 0

        wrapped.activeDays = days.count
        wrapped.bestStreakDays = longestStreak(days, calendar: calendar)

        // Busiest 2-hour window, sliding by one hour and wrapping past midnight.
        var bestHour = 0, bestCount = -1
        for hour in 0..<24 {
            let count = hourCounts[hour] + hourCounts[(hour + 1) % 24]
            if count > bestCount { bestHour = hour; bestCount = count }
        }
        wrapped.peakHourStart = bestHour
        wrapped.peakWeekday = (1...7).max { a, b in
            weekdayCounts[a] != weekdayCounts[b] ? weekdayCounts[a] < weekdayCounts[b] : a > b
        } ?? 1
        return wrapped
    }

    /// Lowercased words, grouped by sentence so a phrase never spans "…done. Think…".
    /// NLTokenizer finds the words, so Chinese, Japanese and Thai (written without spaces)
    /// split into words instead of whole clauses. Straight and curly apostrophes match.
    static func sentences(_ text: String, tokenizer: NLTokenizer = NLTokenizer(unit: .word)) -> [[String]] {
        let lower = text.lowercased()
        var result: [[String]] = []
        var current: [String] = []
        var lastEnd = lower.startIndex
        tokenizer.string = lower
        tokenizer.enumerateTokens(in: lower.startIndex..<lower.endIndex) { range, _ in
            if !current.isEmpty, lower[lastEnd..<range.lowerBound].contains(where: sentenceEnds.contains) {
                result.append(current)
                current = []
            }
            lastEnd = range.upperBound
            let token = lower[range].replacingOccurrences(of: "’", with: "'")
                .trimmingCharacters(in: apostrophes)
            if token.contains(where: { $0.isLetter || $0.isNumber }) { current.append(token) }
            return true
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// A filler use of `token`, given the word before it in the same sentence.
    static func isFiller(_ token: String, after previous: String?) -> Bool {
        guard fillerSet.contains(token) else { return false }
        if token == "like", let previous, likeNotFillerAfter.contains(previous) { return false }
        return true
    }

    /// Counts toward "Your word": 3–20 letters, not a stopword or filler, not a number.
    static func isContentWord(_ token: String) -> Bool {
        token.count > 2 && token.count <= maxDisplayedWordLength && !stopwords.contains(token) && !fillerSet.contains(token)
            && !token.allSatisfy(\.isNumber)
    }

    /// Longest run of consecutive calendar days in `days` (each a start-of-day).
    static func longestStreak(_ days: Set<Date>, calendar: Calendar) -> Int {
        let sorted = days.sorted()
        guard var previous = sorted.first else { return 0 }
        var best = 1, run = 1
        for day in sorted.dropFirst() {
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            run = gap == 1 ? run + 1 : 1
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// Highest count; ties go to the alphabetically first key so results are stable.
    private static func top(_ counts: [String: Int]) -> (String, Int)? {
        counts.max { a, b in a.value != b.value ? a.value < b.value : a.key > b.key }
            .map { ($0.key, $0.value) }
    }

    private static let apostrophes = CharacterSet(charactersIn: "'")
    private static let sentenceEnds: Set<Character> = [".", "!", "?", "\n", ";", "。", "！", "？", "…"]
    private static let fillerSet = Set(fillers)

    /// Common English function words plus dictation glue ("yeah", "okay", "gonna").
    /// Built from an array: a Set literal traps on the repeats this list carries.
    static let stopwords = Set<String>([
        "the", "and", "for", "are", "but", "not", "you", "all", "any", "can", "had", "her",
        "was", "one", "our", "out", "has", "him", "his", "how", "its", "may", "new", "now",
        "old", "see", "two", "way", "who", "did", "get", "got", "let", "say", "she", "too",
        "use", "yes", "yeah", "yep", "okay", "also", "that", "this", "with", "have", "from",
        "they", "will", "would", "there", "their", "what", "about", "which", "when", "make",
        "can't", "don't", "i'm", "it's", "that's", "there's", "i've", "i'll", "i'd", "you're",
        "we're", "they're", "let's", "what's", "doesn't", "didn't", "isn't", "won't", "wasn't",
        "aren't", "couldn't", "wouldn't", "shouldn't", "haven't", "you've", "we'll", "he's",
        "she's", "here's", "where's", "who's", "how's", "you'll", "we've", "they've",
        "were", "been", "being", "than", "then", "them", "these", "those", "some", "such",
        "into", "over", "only", "very", "more", "most", "much", "many", "other", "each",
        "both", "few", "own", "same", "just", "should", "could", "does", "doing", "done",
        "here", "where", "why", "because", "while", "after", "before", "again", "once",
        "your", "yours", "mine", "ours", "theirs", "myself", "yourself", "itself", "his",
        "hers", "what", "whom", "whose", "any", "every", "either", "neither", "through",
        "during", "under", "above", "below", "between", "against", "into", "onto", "upon",
        "off", "per", "via", "yet", "still", "even", "ever", "never", "always", "really",
        "gonna", "wanna", "gotta", "kind", "sort", "thing", "things", "stuff", "lot",
        "like", "well", "going", "want", "need", "know", "something", "anything", "nothing",
        "everything", "someone", "anyone", "everyone", "maybe", "sure", "right", "whether",
        "since", "until", "though", "although", "unless", "else", "able", "put", "take",
        "can", "will", "shall", "might", "must", "ought", "hey", "please", "thanks",
    ])
}

// MARK: - Locked (under `minimumDictations`)

extension RhinoWrapped {
    /// Dictations that count toward unlocking: completed and not empty, same as `compute`.
    static func countedDictations(_ rows: [Dictation]) -> Int {
        rows.reduce(0) { $1.text.isEmpty ? $0 : $0 + 1 }
    }

    /// Short, realistic things to try saying. Rotates with each new dictation.
    static let samplePhrases = [
        "Reply to Sam: sounds good, see you at 3.",
        "Can we move tomorrow's call to Thursday?",
        "Thanks for the update, I'll take a look tonight.",
        "Remind me to send the invoice on Friday.",
        "Running five minutes late, start without me.",
        "Love this idea, let's try it next week.",
    ]

    static func samplePhrase(for count: Int) -> String {
        samplePhrases[abs(count) % samplePhrases.count]
    }

    /// "3 of 10" on the locked card's header.
    static func progressText(_ count: Int) -> String {
        "\(min(max(count, 0), minimumDictations)) of \(minimumDictations)"
    }

    /// "7 more to unlock" under each greyed tile.
    static func lockedNote(_ count: Int) -> String {
        "\(max(minimumDictations - count, 1)) more to unlock"
    }

    /// Tile labels in card order, for the locked state.
    static let tileLabels = [
        "Your word", "Where you talk most", "Filler of choice", "Best streak",
        "Peak hour", "Biggest ramble", "Questions asked", "Weekend talk",
    ]
}

// MARK: - Display

extension RhinoWrapped {
    struct Tile: Equatable, Identifiable {
        let label: String
        let value: String
        let note: String
        var id: String { label }
    }

    /// The eight tiles in card order (4 × 2), as on the approved mockup.
    func tiles(calendar: Calendar = .current, locale: Locale = .current) -> [Tile] {
        let number = NumberFormatter()
        number.numberStyle = .decimal
        number.locale = locale
        func n(_ value: Int) -> String { number.string(from: NSNumber(value: value)) ?? "\(value)" }
        func times(_ count: Int) -> String { count == 1 ? "once" : "\(n(count)) times" }

        var wordNote = topWord == nil ? "say more and it shows up" : times(topWordCount)
        if let topPhrase {
            wordNote += " · “\(Self.displayPhrase(topPhrase))” ×\(n(topPhraseCount))"
        }

        var fillerNote = "clean talker"
        if topFiller != nil {
            fillerNote = "\(times(topFillerCount)) · “\(fillerFootnoteWord)” "
                + (fillerFootnoteCount == 0 ? "never" : "just \(n(fillerFootnoteCount))")
        }

        let pleaseNote: String
        switch pleaseCount {
        case 0: pleaseNote = "“please” never said"
        case 1: pleaseNote = "“please” said once"
        default: pleaseNote = "“please” said \(n(pleaseCount)) times"
        }

        let weekendShare = Double(weekendDictations) / Double(max(dictations, 1))
        let weekendNote = weekendDictations == 0 ? "weekdays only"
            : weekendShare < 0.1 ? "you rest on weekends"
            : "\(Int((weekendShare * 100).rounded()))% of your talking"

        let weekday = calendar.weekdaySymbols[safe: peakWeekday - 1] ?? ""

        return [
            Tile(label: "Your word",
                 value: topWord.map { "“\($0)”" } ?? "—", note: wordNote),
            Tile(label: "Where you talk most",
                 value: topApp ?? "—",
                 note: topApp == nil ? "no app info yet" : "\(Self.compact(topAppWords)) words"),
            Tile(label: "Filler of choice",
                 value: topFiller.map { "“\($0)”" } ?? "none", note: fillerNote),
            Tile(label: "Best streak",
                 value: bestStreakDays == 1 ? "1 day" : "\(n(bestStreakDays)) days",
                 note: bestStreakDays <= 1 ? "come back tomorrow" : "\(n(activeDays)) days talking"),
            Tile(label: "Peak hour",
                 value: Self.hourWindow(peakHourStart), note: "\(weekday)s most"),
            Tile(label: "Biggest ramble",
                 value: "\(n(biggestRambleWords)) words", note: "in one go"),
            Tile(label: "Questions asked",
                 value: n(questions), note: pleaseNote),
            Tile(label: "Weekend talk",
                 value: weekendDictations == 0 ? "0 times" : times(weekendDictations), note: weekendNote),
        ]
    }

    /// "Aug 11", or "Aug 11, 2025" when it isn't this year.
    func sinceText(now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        let sameYear = calendar.component(.year, from: firstDate) == calendar.component(.year, from: now)
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMMd" : "MMMdyyyy")
        return "since " + formatter.string(from: firstDate)
    }

    /// 17 → "5–7 PM"; 11 → "11 AM–1 PM"; 23 → "11 PM–1 AM".
    static func hourWindow(_ start: Int) -> String {
        let end = (start + 2) % 24
        func h12(_ h: Int) -> Int { h % 12 == 0 ? 12 : h % 12 }
        func period(_ h: Int) -> String { h < 12 ? "AM" : "PM" }
        if period(start) == period(end) && end > start {
            return "\(h12(start))–\(h12(end)) \(period(end))"
        }
        return "\(h12(start)) \(period(start))–\(h12(end)) \(period(end))"
    }

    /// 6_312 → "6.3K"; 950 → "950"; 1_260_000 → "1.3M".
    static func compact(_ n: Int) -> String {
        // Round first so 999_960 reads "1.0M", not "1000.0K".
        if n >= 999_950 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    /// Restores the capital on "I" and its contractions: "i think" → "I think".
    static func displayPhrase(_ phrase: String) -> String {
        phrase.split(separator: " ").map { word in
            word == "i" || word.hasPrefix("i'") ? "I" + word.dropFirst() : String(word)
        }.joined(separator: " ")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
