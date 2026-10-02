import Foundation

/// Output preferences are strings on disk so unknown future values fall back to Smart.
enum NumberFormattingStyle: String, CaseIterable, Identifiable {
    case smart, digits, spoken

    var id: String { rawValue }
    var title: String {
        switch self {
        case .smart: return "Smart"
        case .digits: return "Prefer digits"
        case .spoken: return "Keep as spoken"
        }
    }
    var hint: String {
        switch self {
        case .smart: return "English numbers: point seven → 0.7; seven items → 7 items. Common idioms stay words."
        case .digits: return "English number words use digits, including seven → 7. Common idioms stay words."
        case .spoken: return "Keep numbers as the speech recognizer writes them. It may already use digits."
        }
    }
}

/// Local English number formatting, independent of the optional cleanup model.
/// Ambiguous sequences, idioms and identifiers are left untouched.
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

    private static let numberWord = "(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|billion)"
    /// A run of number words separated by spaces or hyphens.
    private static let phraseRegex = try! NSRegularExpression(
        pattern: "(?i)\\b\(numberWord)(?:[ \t-]+(?:and[ \t-]+)?\(numberWord))*\\b")
    /// Digits followed by a spoken/spaced meridiem: "4 p. m.", "10 pm", "7 a.m."
    private static let meridiemRegex = try! NSRegularExpression(
        pattern: "(?i)\\b(\\d{1,2}(?::\\d{2})?)\\s*([ap])\\.?\\s?m\\.?(?=[^\\w]|$)")
    /// "X percent" (digits) → "X%"
    private static let percentRegex = try! NSRegularExpression(
        pattern: "(?i)\\b(\\d+(?:\\.\\d+)?)\\s+percent\\b")

    static func apply(_ text: String, style: NumberFormattingStyle = .smart) -> String {
        guard style != .spoken else { return text }
        var result = compactDecimals(in: text)
        result = compactSpelledNumbers(in: result, style: style)
        result = replace(percentRegex, in: result) { m in "\(m[1])%" }
        result = replace(meridiemRegex, in: result) { m in "\(m[1])\(m[2].lowercased())m" }
        return result
    }

    private static let digitWord = "(?:zero|one|two|three|four|five|six|seven|eight|nine|[0-9]+)"
    private static let decimalRegex = try! NSRegularExpression(pattern:
        "(?i)\\b(?:(minus|negative)[ \\t]+)?"
        + "(?:((?:" + numberWord + "(?:[ \\t-]+(?:and[ \\t-]+)?" + numberWord + ")*)|[0-9]+)[ \\t]+)?"
        + "point[ \\t]+(" + digitWord + "(?:[ \\t-]+" + digitWord + ")*)\\b")

    /// Preserve each fractional digit as text, including zeros and long sequences;
    /// floating-point arithmetic would round exactly the numbers users are dictating.
    private static func compactDecimals(in text: String) -> String {
        replace(decimalRegex, in: text) { groups, range in
            guard !isProtected(in: text, range: range) else { return groups[0] }
            let before = (text as NSString).substring(to: range.location)
            let after = (text as NSString).substring(from: NSMaxRange(range))
            // A regex may find a second, overlapping decimal after rejecting the
            // first. Never convert the tail of a dotted/version-like sequence.
            guard before.range(of: "(?:" + numberWord + "|[0-9])[ \\t-]+$",
                               options: [.regularExpression, .caseInsensitive]) == nil else { return groups[0] }
            // An unsupported continuation is not a smaller valid decimal.
            guard after.range(of: "^[ \\t-]+(?:" + numberWord + "|point)\\b",
                              options: [.regularExpression, .caseInsensitive]) == nil else { return groups[0] }
            // Without a leading number, "point" is usually the noun: "at that point two
            // people left", "my point two". Only a bare "point" in number position decimalizes.
            if groups[2].isEmpty, groups[1].isEmpty, isNounPoint(before: before, fraction: groups[3], after: after) {
                return groups[0]
            }
            let integer: String
            if groups[2].isEmpty {
                integer = "0"
            } else if groups[2].allSatisfy({ $0.isASCII && $0.isNumber }) {
                integer = groups[2]
            } else if let value = parsePhrase(groups[2]) {
                integer = String(value)
            } else {
                return groups[0]
            }
            let fractional = groups[3].lowercased()
                .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
                .map { units[String($0)].map(String.init) ?? String($0) }.joined()
            return (groups[1].isEmpty ? "" : "-") + integer + "." + fractional
        }
    }

    private static let nounPointModifiers = "the|that|this|which|what|whose|a|an|some|any|every|each|no|my|your|his|her|its|our|their|good|great|fair|valid|main|key|turning|breaking|boiling|starting|sore|high|low|end|same|different|other|another|whole|focal|vantage|entry|exit|data|talking|selling|pressure|pain|price|bullet|match|set|game|power|one"
    private static let countNounsAfterPoint = "people|persons|things|items|ways|reasons|options|questions|ideas|guys|kids|men|women|teams|customers|users"

    private static func isNounPoint(before: String, fraction: String, after: String) -> Bool {
        if before.range(of: "\\b(?:" + nounPointModifiers + ")[ \\t]+$",
                        options: [.regularExpression, .caseInsensitive]) != nil { return true }
        // "point two people": a single digit followed by a count noun is a count, not 0.2.
        let digits = fraction.split(whereSeparator: { $0.isWhitespace || $0 == "-" })
        return digits.count == 1
            && after.range(of: "^[ \\t]+(?:" + countNounsAfterPoint + ")\\b",
                           options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func parsePhrase(_ phrase: String) -> Int? {
        let tokens = phrase.lowercased().split(whereSeparator: { $0.isWhitespace || $0 == "-" }).map(String.init)
        for (index, token) in tokens.enumerated() where token == "and" {
            guard index > 0, magnitudes[tokens[index - 1]] != nil else { return nil }
        }
        return parse(tokens.filter { $0 != "and" })
    }

    /// A small cleanup model can ignore the preservation instruction. In Keep as
    /// spoken mode, reject that cleanup rather than silently changing number words
    /// to digits (or changing numeric values). Casing and ordinary punctuation may vary.
    static func preservesNumberRepresentation(input: String, output: String) -> Bool {
        func tokens(_ text: String) -> [String] {
            let regex = numberTokenRegex
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                .map { (text as NSString).substring(with: $0.range).lowercased() }
        }
        return tokens(input) == tokens(output)
    }

    private static let numberTokenRegex = try! NSRegularExpression(
        pattern: "(?i)(?<!\\w)(?:-?[0-9]+(?:[.,:/][0-9]+)*%?|" + numberWord + "|minus|negative|point)(?!\\w)")

    /// Replace spelled-number phrases with digits, when they qualify (see rules
    /// in the type comment). Grouped with thousands separators from 10,000 up —
    /// "42,000" reads like a person typed it; "1200" stays compact.
    private static func compactSpelledNumbers(in text: String, style: NumberFormattingStyle) -> String {
        replace(phraseRegex, in: text) { m, range in
            let phrase = m[0]
            let tokens = phrase.lowercased()
                .replacingOccurrences(of: "-", with: " ")
                .split(whereSeparator: { $0.isWhitespace }).map(String.init)
            let words = tokens.filter { $0 != "and" }
            guard !isProtected(in: text, range: range),
                  qualifies(words, in: text, matchRange: range, style: style) else { return phrase }
            guard let value = parsePhrase(phrase) else { return phrase }
            return format(value)
        }
    }

    // Explicit quantity vocabulary keeps Smart predictable: an unfamiliar context
    // stays as recognized. This is deliberately English-only, not a language model.
    private static let quantities = "items?|people|persons?|lemons?|apples?|tickets?|times|days?|weeks?|months?|years?|hours?|minutes?|seconds?|dollars?|cents?|euros?|pounds?|kilograms?|grams?|miles?|kilometers?|metres?|meters?|feet|foot|inches|litres?|liters?|percent|emails?|messages?|calls?|meetings?|files?|pages?|slides?|words?|characters?|customers?|users?|orders?|copies|seats?|bottles?|cups?|tablespoons?|teaspoons?|units?|points?|degrees?"

    private static func qualifies(_ words: [String], in text: String,
                                  matchRange: NSRange, style: NumberFormattingStyle) -> Bool {
        guard !words.isEmpty else { return false }
        if words.contains(where: { magnitudes[$0] != nil }) || words.count >= 2 { return true }
        let source = text as NSString
        let before = source.substring(to: matchRange.location)
        let after = source.substring(from: NSMaxRange(matchRange))
        // A number alone is usually a form-field answer: "Seven." → "7."
        let padding = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let isLoneAnswer = before.trimmingCharacters(in: padding).isEmpty
            && after.trimmingCharacters(in: padding).isEmpty
        if words == ["one"], !isLoneAnswer, isIndefiniteOne(before: before, after: after) { return false }
        if style == .digits || isLoneAnswer { return true }
        if after.range(of: "^\\s+(?:" + quantities + ")\\b|^\\s*[ap]\\.?\\s?m\\.?(?=[^\\w]|$)",
                       options: [.regularExpression, .caseInsensitive]) != nil { return true }
        return before.range(of: "\\b(?:number|item|step|room|chapter|page|version)\\s+$",
                            options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// "One" opening a sentence ("One thing I learned") or meaning "a/some"
    /// ("one day we'll", "one time I", "give me one second") reads as prose, not a count.
    private static func isIndefiniteOne(before: String, after: String) -> Bool {
        if before.range(of: "(?:^|[.!?…][\"')\\]]*)[ \\t\\n]*$", options: .regularExpression) != nil { return true }
        if before.range(of: "\\b(?:the|that|this|which|any|every|some|no|each|someone's|the only)[ \\t]+$",
                        options: [.regularExpression, .caseInsensitive]) != nil { return true }
        return after.range(of: "^[ \\t]+(?:day|days|time|times|week|month|year|minute|second|sec|hour|point|points|more|last|another)\\b",
                           options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isProtected(in text: String, range: NSRange) -> Bool {
        let source = text as NSString
        let before = source.substring(to: range.location)
        let after = source.substring(from: NSMaxRange(range))
        // Don't rewrite pieces of hyphenated idioms, URLs, addresses or identifiers.
        let attached = CharacterSet(charactersIn: "-/@_.")
        if let last = before.unicodeScalars.last, attached.contains(last) { return true }
        if let first = after.unicodeScalars.first,
           CharacterSet(charactersIn: "-/@_").contains(first) { return true }
        if after.range(of: "^\\.[a-z]", options: .regularExpression) != nil { return true }
        // A decimal needs a decimal parser; never partially turn "point seven" into 7.
        if before.range(of: "\\bpoint\\s+$", options: [.regularExpression, .caseInsensitive]) != nil
            || after.range(of: "^\\s+point\\b", options: [.regularExpression, .caseInsensitive]) != nil { return true }
        return idiomRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .contains { NSIntersectionRange($0.range, range) == range }
    }

    private static let idiomRegex = try! NSRegularExpression(pattern:
        "(?i)\\b(?:one of|one another|one at a time|one by one|two by two|one and (?:all|only)|one or two|two or three|one more thing|the one thing|one way or another|(?:no|some|any|every) one|all in one|at one with|my two cents|in two minds|on the one hand|(?:one|two|three|four|five|six|seven|eight|nine|ten) times (?:as|the))\\b")

    /// Standard spelled-number parser: units accumulate, "hundred" scales the
    /// current group, thousand/million/billion close a group. Returns nil for
    /// sequences that aren't a single well-formed number ("one two",
    /// "ten thirty") so prose lists — and spoken clock times — are left alone.
    private static func parse(_ words: [String]) -> Int? {
        enum Slot { case open, afterTens, closed }
        var total = 0, group = 0
        var lastMagnitude = Int.max
        var hadHundred = false
        var slot = Slot.open
        for word in words {
            if let u = units[word] {
                guard u != 0 || words.count == 1 else { return nil }
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
                guard (1...9).contains(group), !hadHundred else { return nil }
                hadHundred = true
                group *= 100
                slot = .open
            } else if let mag = magnitudes[word], mag >= 1000 {
                guard mag < lastMagnitude, group > 0 || words.count == 1 else { return nil }
                total += (group == 0 ? 1 : group) * mag
                lastMagnitude = mag
                group = 0
                hadHundred = false
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
