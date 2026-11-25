import Foundation

/// The deterministic half of the "Polished" cleanup level: hesitation sounds, comma-bracketed
/// verbal fillers and stammered repeats are removed in code, before the model sees the text.
/// Code is fast, runs without the model downloaded, and can only ever delete the exact words
/// listed here, so it can't reword or invent anything. Everything that needs judgement (false
/// starts, lists, which "like" is a filler) is left to the model pass and its guard.
///
/// The rule throughout: remove only what is unambiguously a disfluency. A missed "um" costs
/// nothing; a deleted real word ("the ER", "log in in", "Walla Walla") changes what was said.
///
/// English only: the filler words are English. Callers skip it for other languages.
enum Disfluency {
    static func apply(_ text: String) -> String {
        var out = removeHesitations(text)
        out = removeBracketedFillers(out)
        out = mendRemovals(out, original: text)
        return removeRepeats(out)
    }

    /// Stands in for a removed span until `mendRemovals` fixes the spacing, punctuation and
    /// capital around it, so those fixes touch only the places something was removed.
    private static let mark = "\u{E000}"

    // MARK: - Hesitations: um, uh, er, hmm…

    /// Candidate sounds. Which matches are removed is decided in `isHesitation`: lowercase
    /// only (so "ER", "HMM", "UM" the acronyms stay), plus a capitalised sentence-initial "Um"
    /// or "Uh" before a comma or a lowercase word. "uh huh" and "mhm" are answers and stay.
    private static let hesitationCandidate = try! NSRegularExpression(
        pattern: #"(?<![\w'’-])(u+m+|u+h+|erm+|er|a+h+|h+m+|m{2,})(?![\w'’-])"#,
        options: [.caseInsensitive])

    private static func removeHesitations(_ text: String) -> String {
        let ns = text as NSString
        var result = text
        for match in hesitationCandidate.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let token = ns.substring(with: match.range)
            let before = ns.substring(to: match.range.location)
            let after = ns.substring(from: NSMaxRange(match.range))
            guard isHesitation(token, before: before, after: after) else { continue }
            // Take a comma that belongs to it ("um, so"), or an ellipsis when the sentence goes
            // on ("um... so"). Never a ".", "?" or "!": "That's all, um." keeps its full stop.
            var length = match.range.length
            if after.hasPrefix(",") {
                length += 1
            } else if let dots = after.range(of: #"^(?:…|\.{3})(?=\s+[a-z])"#, options: .regularExpression) {
                length += NSRange(dots, in: after).length
            }
            var location = match.range.location
            // Bracketed by commas (", um,") the commas were the hesitation's: both go, as for
            // ", you know,".
            if after.hasPrefix(","),
               let lead = before.range(of: #"(?<=[\p{L}\d'’])[ \t]*,[ \t]*$"#, options: .regularExpression) {
                let leadLength = NSRange(lead, in: before).length
                location -= leadLength
                length += leadLength
            }
            let range = NSRange(location: location, length: length)
            guard let swiftRange = Range(range, in: result) else { continue }
            result.replaceSubrange(swiftRange, with: mark)
        }
        return result
    }

    private static func isHesitation(_ token: String, before: String, after: String) -> Bool {
        let lower = token.lowercased()
        // "uh huh" / "uh-huh" means yes.
        if lower.hasPrefix("u"), lower.contains("h"),
           after.range(of: #"^[ \t]+huh\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return false
        }
        // "4 mm", "12mm": a unit after a number.
        if lower.allSatisfy({ $0 == "m" }),
           before.range(of: #"\d[ \t]*$"#, options: .regularExpression) != nil {
            return false
        }
        if token == lower {
            // Bare "er" is a German and French word, and in English transcripts the hesitation
            // is written as an aside ("I, er, need"); only that form goes.
            if lower == "er" {
                return before.range(of: #",[ \t]*$"#, options: .regularExpression) != nil
                    || after.range(of: #"^(?:,|…|\.\.\.)"#, options: .regularExpression) != nil
            }
            return true
        }
        // Capitalised: only "Um"/"Uh" (and their stretched forms, "Hmm", "Erm") at a sentence
        // start, followed by a comma or a lowercase word. "Um Kulthum", "Er ist", "UM" stay.
        let capitalised = token.prefix(1).uppercased() + token.dropFirst().lowercased()
        guard token == capitalised,
              lower.range(of: #"^(?:u+m+|u+h+|h+m+|erm+)$"#, options: .regularExpression) != nil,
              isSentenceStart(before) else { return false }
        return after.hasPrefix(",") || after.range(of: #"^[ \t]+[a-z]"#, options: .regularExpression) != nil
    }

    /// Whether `before` (the text preceding a position) ends at a sentence or line start.
    private static func isSentenceStart(_ before: String) -> Bool {
        let trimmed = before.replacingOccurrences(of: mark, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        guard let last = trimmed.last else { return true }
        return ".?!\n".contains(last)
    }

    // MARK: - Verbal fillers, only where commas mark them as asides mid-sentence

    /// "It was, like, huge" / "We should, you know, move it" / "It's, I mean, fine". Only
    /// between two commas with words on both sides: without the commas "like" and "you know"
    /// are usually real words ("I like it", "you know the answer"), and at the end of a
    /// sentence they are part of how it was said ("We ship Friday, you know?", "…, I guess.").
    private static let bracketedFiller = try! NSRegularExpression(
        pattern: #"(?<=[\p{L}\d'’])[ \t]*,[ \t]*(?:you know|like|I mean)[ \t]*,(?=[ \t]*[\p{L}\d\#(mark)])"#)

    private static func removeBracketedFillers(_ text: String) -> String {
        bracketedFiller.stringByReplacingMatches(
            in: text, range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: mark)
    }

    // MARK: - Mending what a removal leaves behind

    /// Fixes spacing, a stranded comma and a lost capital, only next to a removal mark:
    /// "That's all, ⌫." → "That's all." / "it ⌫. Thanks" → "it. Thanks" / "⌫ so I" → "So I".
    /// Text elsewhere ("3 p.m. and", "e.g. vim", "iPhone") is never touched.
    private static func mendRemovals(_ text: String, original: String) -> String {
        guard text.contains(mark) else { return text }
        let m = mark
        let fixes: [(String, String)] = [
            // Collapse a run of marks and the spaces around them to " ⌫ ".
            ("[ \\t]*(?:\(m)[ \\t]*)+", " \(m) "),
            // At a line start: no space before the next word.
            ("(?m)^ \(m) ", m),
            // Before punctuation: a comma left in front goes too ("all, ⌫." → "all⌫.").
            ("[,;:]? \(m) ([.?!,;:…])", "\(m)$1"),
            // At a line end: a stranded comma goes ("That's all, ⌫" → "That's all⌫").
            ("(?m)[,;:]? \(m) ?$", m),
            // Between words: one space.
            (" \(m) ", " \(m)"),
        ]
        var out = text
        for (pattern, template) in fixes {
            out = out.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        // A removal at a sentence start exposes the next word: give it back its capital, but
        // only where the original used sentence case at all (a lowercase transcript stays so).
        let originalStartsUpper = original.trimmingCharacters(in: .whitespacesAndNewlines)
            .first.map { $0.isUppercase } ?? false
        if originalStartsUpper {
            var result = ""
            var pendingCapital = false
            for ch in out {
                if String(ch) == m {
                    pendingCapital = isSentenceStart(result)
                    continue
                }
                if pendingCapital, ch.isLetter {
                    result.append(contentsOf: ch.isLowercase ? String(ch).uppercased() : String(ch))
                    pendingCapital = false
                    continue
                }
                if !ch.isWhitespace { pendingCapital = false }
                result.append(ch)
            }
            out = result
        }
        return out.replacingOccurrences(of: m, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
    }

    // MARK: - Stammered repeats: "I I think", "we should we should go"

    /// One to three words said twice or more in a row, separated by spaces only: never across
    /// a comma ("Turn right, right at the light", "New York, New York") or a sentence end.
    /// Which matches collapse is decided in `isStammer`.
    private static let repeated = try! NSRegularExpression(
        pattern: #"(?<![\w'’-])((?:[\w'’]+[ \t]+){0,2}[\w'’]+)(?:[ \t]+\1)+(?![\w'’-])"#,
        options: [.caseInsensitive])

    /// The only single words collapsed when doubled: function words that don't legitimately
    /// say twice in a row. "in in" (log in in the morning), "her her", "was was", "that that",
    /// "had had", "so so" and every content word can, so they're not here.
    private static let stammerWords: Set<String> = [
        "i", "i'm", "i've", "i'll", "i'd", "the", "a", "an", "we", "we're", "we've", "we'll",
        "and", "to", "it's", "but", "my", "our", "if", "or", "they're", "you're",
    ]

    /// A two- or three-word repeat collapses only when it starts like a sentence restart:
    /// a pronoun, article or one of the words above ("we should we should", "it was it was").
    private static let stammerStarts: Set<String> = stammerWords.union([
        "you", "he", "she", "they", "it", "this", "there", "what", "so",
    ])

    /// Repeats made only of these are meant: emphasis ("no no", "very very") and set phrases.
    private static let deliberateWords: Set<String> = [
        "that", "had", "is", "very", "really", "no", "yes", "yeah", "so", "bye", "ha", "haha",
        "well", "too", "please", "now", "ok", "okay", "go", "hey", "hi", "oh", "wow",
    ]

    /// Digits and number words are data ("five five five", "one one two"), never a stammer.
    private static let numberWords: Set<String> = [
        "zero", "oh", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
        "eighty", "ninety", "hundred", "thousand", "million", "billion", "double", "triple",
    ]

    private static func removeRepeats(_ text: String) -> String {
        let ns = text as NSString
        var result = text
        for match in repeated.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let whole = ns.substring(with: match.range)
            let phrase = ns.substring(with: match.range(at: 1))
            let before = ns.substring(to: match.range.location)
            guard isStammer(whole: whole, phrase: phrase, atSentenceStart: isSentenceStart(before)),
                  let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: phrase)
        }
        return result
    }

    private static func isStammer(whole: String, phrase: String, atSentenceStart: Bool) -> Bool {
        let words = phrase.lowercased().replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first else { return false }
        if words.contains(where: { numberWords.contains($0) || $0.contains(where: \.isNumber) }) {
            return false
        }
        // A capital anywhere but the sentence's first word means a name or a title: "The The",
        // "Bora Bora", "Duran Duran", "Plan A a…". "I" and its contractions are always capital.
        let tokens = whole.split(whereSeparator: \.isWhitespace)
        for (index, token) in tokens.enumerated() {
            guard let initial = token.first, initial.isUppercase else { continue }
            let lower = token.lowercased().replacingOccurrences(of: "’", with: "'")
            if lower == "i" || lower.hasPrefix("i'") { continue }
            if index == 0, atSentenceStart { continue }
            return false
        }
        if words.count == 1 { return stammerWords.contains(first) }
        guard stammerStarts.contains(first) else { return false }
        return !words.allSatisfy(deliberateWords.contains)
    }
}
