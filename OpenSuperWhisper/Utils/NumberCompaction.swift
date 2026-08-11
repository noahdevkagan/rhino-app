import Foundation

/// Deterministic spoken-number compaction: "forty-two thousand" → "42,000",
/// "thirty-eight percent" → "38%", "four p. m." → "4pm". Runs on every
/// transcription BEFORE the optional LLM cleanup — formatting people expect
/// from dictation should never depend on a 1.5B model's mood (corpus item
/// h02 proved it doesn't comply reliably).
///
/// Deliberately conservative: a bare small number word ("the one thing I'm
/// watching", "one-on-one") is prose and is left alone. Conversion only
/// triggers when the phrase is unambiguously numeric:
///   - a compound ("forty-two", "twenty five") or a magnitude ("… thousand")
///   - or a single number word directly followed by percent / am / pm
enum NumberCompaction {
    private static let units: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
        "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    ]
    private static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]
    private static let magnitudes: [String: Int] = [
        "hundred": 100, "thousand": 1_000, "million": 1_000_000, "billion": 1_000_000_000,
    ]

    private static let numberWord = "(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|billion|and)"
    /// A run of number words separated by spaces or hyphens.
    private static let phraseRegex = try! NSRegularExpression(
        pattern: "(?i)\\b\(numberWord)(?:[ -]\(numberWord))*\\b")
    /// Digits followed by a spoken/spaced meridiem: "4 p. m.", "10 pm", "7 a.m."
    private static let meridiemRegex = try! NSRegularExpression(
        pattern: "(?i)\\b(\\d{1,2}(?::\\d{2})?)\\s*([ap])\\.?\\s?m\\.?(?=[^\\w]|$)")
    /// "X percent" (digits) → "X%"
    private static let percentRegex = try! NSRegularExpression(
        pattern: "(?i)\\b(\\d+(?:\\.\\d+)?)\\s+percent\\b")

    static func apply(_ text: String) -> String {
        var result = compactSpelledNumbers(in: text)
        result = replace(percentRegex, in: result) { m in "\(m[1])%" }
        result = replace(meridiemRegex, in: result) { m in "\(m[1])\(m[2].lowercased())m" }
        return result
    }

    /// Replace spelled-number phrases with digits, when they qualify (see rules
    /// in the type comment). Grouped with thousands separators from 10,000 up —
    /// "42,000" reads like a person typed it; "1200" stays compact.
    private static func compactSpelledNumbers(in text: String) -> String {
        replace(phraseRegex, in: text) { m, range in
            let phrase = m[0]
            let words = phrase.lowercased()
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ").map(String.init)
                .filter { $0 != "and" }
            guard qualifies(words, in: text, matchRange: range) else { return phrase }
            guard let value = parse(words) else { return phrase }
            return format(value)
        }
    }

    private static func qualifies(_ words: [String], in text: String, matchRange: NSRange) -> Bool {
        guard !words.isEmpty else { return false }
        // Hyphenated idioms like "one-on-one" never reach here (the "on" breaks
        // the run), but a single unit word is prose unless a percent/meridiem
        // follows it directly.
        if words.contains(where: { magnitudes[$0] != nil }) { return true }
        if words.count >= 2 { return true }
        let after = (text as NSString).substring(from: matchRange.location + matchRange.length)
        return after.range(of: "^\\s*(percent\\b|[ap]\\.?\\s?m\\.?([^\\w]|$))",
                           options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Standard spelled-number parser: units accumulate, "hundred" scales the
    /// current group, thousand/million/billion close a group. Returns nil for
    /// sequences that aren't a single well-formed number ("one two",
    /// "ten thirty") so prose lists — and spoken clock times — are left alone.
    private static func parse(_ words: [String]) -> Int? {
        enum Slot { case open, afterTens, closed }
        var total = 0, group = 0
        var slot = Slot.open
        for word in words {
            if let u = units[word] {
                switch slot {
                case .open: group += u; slot = u < 10 ? .afterTens : .closed
                case .afterTens where u < 10 && group % 10 == 0 && group % 100 >= 20:
                    group += u; slot = .closed
                default: return nil
                }
            } else if let t = tens[word] {
                guard slot == .open else { return nil }
                group += t
                slot = .afterTens
            } else if word == "hundred" {
                guard group > 0 else { return nil }
                group *= 100
                slot = .open
            } else if let mag = magnitudes[word], mag >= 1000 {
                total += (group == 0 ? 1 : group) * mag
                group = 0
                slot = .open
            } else {
                return nil
            }
        }
        let value = total + group
        return value > 0 || words == ["zero"] ? value : nil
    }

    private static func format(_ value: Int) -> String {
        if value >= 10_000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
        return String(value)
    }

    private static func replace(_ regex: NSRegularExpression, in text: String,
                                _ transform: ([String], NSRange) -> String) -> String {
        var result = text
        // Iterate matches back-to-front so earlier ranges stay valid.
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                let r = match.range(at: i)
                groups.append(r.location == NSNotFound ? "" : (text as NSString).substring(with: r))
            }
            let replacement = transform(groups, match.range)
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }

    private static func replace(_ regex: NSRegularExpression, in text: String,
                                _ transform: ([String]) -> String) -> String {
        replace(regex, in: text) { groups, _ in transform(groups) }
    }
}
