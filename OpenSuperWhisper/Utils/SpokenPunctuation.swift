import Foundation

/// Deterministic spoken punctuation: "pretty rad. Period. I will" → "pretty rad. I will",
/// "I dictated, comma, so" → "I dictated, so", "as words. New paragraph: I did" → a blank
/// line. Part of smart formatting (no toggle of its own) and applied before any LLM pass —
/// the cleanup contract says "keep every word", so the model kept the command words
/// (customer report, 2026-09-29: "it actually inserts them as words").
///
/// Pause punctuation is the strongest command cue. Colon and layout commands need it
/// on both sides; comma/question mark/etc. need it on either side. Period also accepts
/// a sentence boundary or the end of the dictation with no pause before it ("I had salmon
/// for dinner period"), unless it reads as a noun: "billing period", "the Jurassic period".
/// Without a pause before a command, nearby determiners protect literal mentions such as
/// "the Oxford comma". The period-specific check can recognize "thanks for reporting this
/// period." as a command without treating "during this period." as one.
enum SpokenPunctuation {
    private struct Command {
        let mark: String
        /// Needs pause punctuation on both sides (see the type comment).
        let strict: Bool
        var isBreak: Bool { mark.hasPrefix("\n") }
        var endsSentence: Bool { [".", "?", "!"].contains(mark) }
    }

    private static let commands: [String: Command] = [
        "period": Command(mark: ".", strict: true),
        "full stop": Command(mark: ".", strict: false),
        "comma": Command(mark: ",", strict: false),
        "question mark": Command(mark: "?", strict: false),
        "exclamation point": Command(mark: "!", strict: false),
        "exclamation mark": Command(mark: "!", strict: false),
        "semicolon": Command(mark: ";", strict: false),
        "colon": Command(mark: ":", strict: true),
        "new line": Command(mark: "\n", strict: true),
        "newline": Command(mark: "\n", strict: true),
        "new paragraph": Command(mark: "\n\n", strict: true),
    ]

    private static let mentionWords: Set<String> = [
        "a", "an", "the", "this", "that", "every", "each", "another", "one", "no", "any",
        "word", "my", "your", "his", "her", "its", "our", "their",
    ]

    /// Optional pause punctuation (including spaced/repeated marks), the gap, the command,
    /// optional trailing punctuation. Only a matched command consumes these marks.
    /// The lookbehind keeps a command at the very start of the text (nothing to punctuate)
    /// or of a line from matching.
    private static let regex = try! NSRegularExpression(
        pattern: "(?i)(?<=\\S)((?:[ \\t]*[.,!?;:])*)[ \\t]+"
            + "\\b(period|full stop|comma|question mark|exclamation (?:point|mark)"
            + "|semi-?colon|colon|new ?line|new paragraph)\\b"
            + "((?:[ \\t]*[.,!?;:])+)?")

    static func apply(_ text: String) -> String {
        var result = text
        var searchStart = 0
        while true {
            let ns = result as NSString
            guard searchStart < ns.length,
                  let m = regex.firstMatch(
                      in: result, options: .withTransparentBounds,
                      range: NSRange(location: searchStart, length: ns.length - searchStart))
            else { break }

            let pre = ns.substring(with: m.range(at: 1)).filter { !$0.isWhitespace }
            let word = ns.substring(with: m.range(at: 2))
            let post = m.range(at: 3).location == NSNotFound ? "" : ns.substring(with: m.range(at: 3))
            let prefix = ns.substring(to: m.range.location)
            let rest = ns.substring(from: m.range.location + m.range.length)
            let key = word.lowercased().replacingOccurrences(of: "-", with: "")

            guard let command = commands[key],
                  qualifies(command, key: key, pre: pre, post: post, prefix: prefix, rest: rest) else {
                let wordRange = m.range(at: 2)
                searchStart = wordRange.location + wordRange.length
                continue
            }

            var replacement: String
            var tail = rest
            if command.isBreak {
                // Keep the pause punctuation that ends the line; a break at the very end of
                // the dictation adds nothing.
                replacement = pre
                if !tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    replacement += command.mark
                    tail = String(tail.drop(while: { $0 == " " || $0 == "\t" }))
                }
            } else {
                // The spoken mark overrides the one the speech model guessed for the pause.
                replacement = command.mark
            }
            if command.isBreak || command.endsSentence {
                tail = capitalizingFirstLetter(tail)
            }
            result = prefix + replacement + tail
            // Resume at the replacement: the mark just written is the pause punctuation a
            // following command ("words. Period. New paragraph:") is checked against.
            searchStart = (prefix as NSString).length
        }
        return result
    }

    private static func qualifies(_ command: Command, key: String, pre: String, post: String,
                                  prefix: String, rest: String) -> Bool {
        if key == "period", pre.isEmpty,
           // A comma alone is not a sentence boundary. Keep unpunctuated mid-sentence
           // uses intact too ("period of time", "period I will..."). A "?" or "!" after
           // it means the speech model heard a question or exclamation, not a full stop.
           !post.contains(where: { "?!".contains($0) }),
           post.contains(".") || rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           hasUnpausedPeriodEnding(prefix) || !endsInPeriodNounPhrase(prefix) {
            return true
        }
        if pre.isEmpty, lastWords(of: prefix, count: 2).contains(where: mentionWords.contains) {
            return false
        }
        let before = !pre.isEmpty
        let after = !post.isEmpty || rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return command.strict ? before && after : before || after
    }

    /// Positive evidence, rather than a denylist of period modifiers: an open-ended
    /// modifier list would silently eat unfamiliar noun phrases ("early modern period").
    /// These pronouns/adverbs and complete verb phrases can end the dictated sentence.
    /// This deliberately does not try to recognize every possible unpaused command.
    private static func hasUnpausedPeriodEnding(_ prefix: String) -> Bool {
        let words = lastWords(of: prefix, count: 3)
        guard let last = words.last else { return false }
        if ["here", "there", "now", "today", "tomorrow", "yesterday", "tonight",
            "soon", "again", "it", "them", "me", "us", "you"].contains(last) {
            // Do not reinterpret explicit mentions: "the word it period".
            return !words.dropLast().contains(where: mentionWords.contains)
        }
        if ["this", "that"].contains(last), words.count == 3 {
            // Only thanks ("for reporting this") and requests ("please fix that"): a bare
            // verb + this/that is often a time phrase ("did we fix this period",
            // "we are reporting this period", "during this period").
            let (lead, verb) = (words[0], words[1])
            return lead == "for" && ["reporting", "fixing", "sending", "sharing"].contains(verb)
                || lead == "please" && ["fix", "send", "share"].contains(verb)
        }
        return words.suffix(2).joined(separator: " ") == "i disagree"
            || words.suffix(2).joined(separator: " ") == "i agree"
            || words.suffix(3).joined(separator: " ") == "what you think"
    }

    /// Words that, right before a sentence-final "period", make it the noun: "billing
    /// period", "third period", "Jurassic period". Article-less noun uses are rare, so the
    /// list covers the common ones and a determiner ("the", "our"...) covers the rest.
    private static let periodModifiers: Set<String> = [
        "billing", "reporting", "trial", "grace", "waiting", "cooling", "notice", "recovery",
        "adjustment", "transition", "transitional", "probation", "probationary", "holiday",
        "summer", "winter", "spring", "autumn", "fall", "peak", "rest", "time", "study",
        "free", "class", "first", "second", "third", "fourth", "fifth", "sixth", "seventh",
        "eighth", "last", "next", "same", "short", "long", "brief", "extended", "entire",
        "whole", "modern", "medieval", "colonial", "historical", "jurassic", "cretaceous",
        "triassic", "cambrian", "victorian", "edwardian", "renaissance", "baroque",
        "classical", "romantic", "glacial", "warm", "dry", "rainy", "orbital",
    ]

    /// Whether "period" closing this clause reads as a noun: a modifier right before it or
    /// a determiner/possessive close behind. Otherwise a sentence-final "period" is the
    /// spoken mark (customer report 2026-10-07: "I had salmon for dinner period" → the
    /// word stayed, and cleanup turned it into "dinner, period.").
    private static func endsInPeriodNounPhrase(_ prefix: String) -> Bool {
        let words = lastWords(of: prefix, count: 3)
        guard let last = words.last else { return true }
        return periodModifiers.contains(last) || words.contains(where: mentionWords.contains)
    }

    /// The last `count` words of the clause `text` ends in, lowercased. Stops at punctuation
    /// so a determiner in the previous sentence ("Love that. Sam comma.") isn't counted.
    private static func lastWords(of text: String, count: Int) -> [String] {
        let clause = text.split(omittingEmptySubsequences: false,
                                whereSeparator: { ".,!?;:\n".contains($0) }).last ?? ""
        return clause.split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .suffix(count).map { $0.lowercased() }
    }

    private static func capitalizingFirstLetter(_ text: String) -> String {
        guard let index = text.firstIndex(where: { !$0.isWhitespace }),
              text[index].isLowercase else { return text }
        return text.replacingCharacters(in: index...index, with: text[index].uppercased())
    }
}
