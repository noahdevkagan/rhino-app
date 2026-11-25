import Foundation

/// The deterministic half of the "Polished" cleanup level: hesitation sounds, comma-bracketed
/// verbal fillers and stammered repeats are removed in code, before the model sees the text.
/// Code is fast, runs without the model downloaded, and can only ever delete the exact words
/// listed here, so it can't reword or invent anything. Everything that needs judgement (false
/// starts, lists, which "like" is a filler) is left to the model pass and its guard.
///
/// English only: the filler words are English. Callers skip it for other languages.
enum Disfluency {
    static func apply(_ text: String) -> String {
        var out = text
        out = removeHesitations(out)
        out = removeBracketedFillers(out)
        out = removeRepeats(out)
        return tidy(out, original: text)
    }

    // MARK: - Hesitations: um, uh, er, hmm…

    /// Sounds that are never words. "uh huh" (yes) and "mhm" are answers, so they stay.
    private static let hesitation = try! NSRegularExpression(
        pattern: #"(?<![\w'’-])(?:u+m+|u+h+(?! huh\b)|erm+|er|a+h+|h+m+|m{2,})(?![\w'’-])[,.…]*\s*"#,
        options: [.caseInsensitive])

    private static func removeHesitations(_ text: String) -> String {
        replace(hesitation, in: text) { _, _ in "" }
    }

    // MARK: - Verbal fillers, only where commas mark them as asides

    /// "It was, like, huge" / "We should, you know, ship it" / "You know, I think…".
    /// Without the commas "like" and "you know" are usually real words ("I like it", "you know
    /// the answer"), so those stay for the model to judge.
    private static let bracketedFiller = try! NSRegularExpression(
        pattern: #",\s*(?:you know|like|I guess|basically)\s*(?:,|(?=[.?!]))"#
            + #"|(?:^|(?<=[.?!]\s))(?:you know|like|basically|so,? um|okay so),\s+"#,
        options: [.caseInsensitive])

    private static func removeBracketedFillers(_ text: String) -> String {
        replace(bracketedFiller, in: text) { _, _ in "" }
    }

    // MARK: - Stammered repeats: "I I think", "we should we should go"

    /// One to three words said twice in a row ("the the", "I think, I think"), never across a
    /// sentence end. The first saying is kept.
    private static let repeated = try! NSRegularExpression(
        pattern: #"(?<![\w'’])((?:[\w'’]+\s+){0,2}[\w'’]+)(?:,?\s+\1)+(?![\w'’])"#,
        options: [.caseInsensitive])

    /// Words people repeat on purpose: emphasis ("very very", "no no no"), grammar ("that that",
    /// "had had", "what it is is"), and set phrases ("bye bye", "knock knock").
    private static let deliberateRepeats: Set<String> = [
        "that", "had", "is", "very", "really", "no", "yes", "yeah", "so", "bye", "ha", "haha",
        "well", "too", "many", "much", "more", "go", "knock", "please", "now", "ok", "okay",
        "again", "far", "long", "over", "round", "on", "out", "by", "through", "together", "hey",
        "hi", "wow", "oh", "boo", "ta", "tsk", "chop", "choo", "dum", "la", "na", "blah", "ho",
        "hip", "bang", "tick", "tock", "mm", "do", "can", "will",
    ]

    /// Digits and number words are data ("five five five", "one one two"), never a stammer.
    private static let numberWords: Set<String> = [
        "zero", "oh", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
        "eighty", "ninety", "hundred", "thousand", "million", "billion", "double", "triple",
    ]

    private static func removeRepeats(_ text: String) -> String {
        replace(repeated, in: text) { whole, groups in
            guard let phrase = groups.first ?? nil else { return whole }
            let words = phrase.lowercased().replacingOccurrences(of: "’", with: "'")
                .split(whereSeparator: \.isWhitespace).map(String.init)
            if words.contains(where: { numberWords.contains($0) || $0.contains(where: \.isNumber) }) {
                return whole
            }
            if words.count == 1, deliberateRepeats.contains(words[0]) { return whole }
            // A two- or three-word repeat made only of deliberate words ("so so", "no no")
            // is emphasis too.
            if words.allSatisfy(deliberateRepeats.contains) { return whole }
            return phrase
        }
    }

    // MARK: - Helpers

    /// Replaces every match (last to first, so ranges stay valid) with `transform(whole, groups)`.
    private static func replace(_ regex: NSRegularExpression, in text: String,
                                transform: (String, [String?]) -> String) -> String {
        let ns = text as NSString
        var result = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches.reversed() {
            let whole = ns.substring(with: match.range)
            let groups: [String?] = (1..<max(1, match.numberOfRanges)).map { i in
                let r = match.range(at: i)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            let replacement = transform(whole, groups)
            guard replacement != whole, let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    /// Mends the punctuation and capitals a removal leaves behind: ", ," → ",", "word ." →
    /// "word.", a sentence that now starts lowercase gets its capital back.
    private static func tidy(_ text: String, original: String) -> String {
        guard text != original else { return text }
        var out = text
        let fixes: [(String, String)] = [
            (#"[ \t]{2,}"#, " "),
            (#"\s+([,.?!;:])"#, "$1"),
            (#",(?:\s*,)+"#, ","),
            (#",\s*([.?!])"#, "$1"),
            (#"^[\s,;:.]+"#, ""),
            (#"([.?!])\s*[,;:]+"#, "$1"),
        ]
        for (pattern, template) in fixes {
            out = out.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        out = out.trimmingCharacters(in: .whitespaces)
        // Capitalize a sentence start that a removal exposed, but only where the original text
        // used sentence case at all (a lowercase-only transcript stays lowercase).
        let originalStartsUpper = original.trimmingCharacters(in: .whitespacesAndNewlines)
            .first.map { $0.isUppercase } ?? false
        guard originalStartsUpper else { return out }
        let starts = try! NSRegularExpression(pattern: #"(?:^|[.?!]\s+)([a-z])"#)
        let ns = out as NSString
        var result = out
        for match in starts.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed() {
            let r = match.range(at: 1)
            guard let range = Range(r, in: result) else { continue }
            result.replaceSubrange(range, with: ns.substring(with: r).uppercased())
        }
        return result
    }
}
