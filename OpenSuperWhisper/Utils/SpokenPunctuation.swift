import Foundation

/// Deterministic spoken punctuation: "pretty rad. Period. I will" → "pretty rad. I will",
/// "I dictated, comma, so" → "I dictated, so", "as words. New paragraph: I did" → a blank
/// line. Part of smart formatting (no toggle of its own) and applied before any LLM pass —
/// the cleanup contract says "keep every word", so the model kept the command words
/// (customer report, 2026-09-29: "it actually inserts them as words").
///
/// The speech model marks a command by the pause around it: dictated with a pause, it
/// comes back as "rad. Period. I will"; run on without one it reads "rad period I will",
/// which cannot be told apart from "the trial period ended". So a command converts only
/// next to that pause punctuation:
///   - period, colon, new line, new paragraph collide with prose at a sentence end
///     ("a grace period.", "a new line.") and need punctuation on BOTH sides
///     (end of text counts as the far side)
///   - comma, semicolon, question mark, exclamation point, full stop need it on either side
/// Without a pause before it, a determiner in the two words before ("a period", "the word
/// comma", "the Oxford comma.", "a big question mark.") marks a mention, never a command —
/// at the cost of leaving "the deck comma." as words. Unpunctuated commands are left to
/// the LLM's layout rule.
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

    /// Optional pause punctuation, the gap, the command, optional trailing punctuation.
    /// The lookbehind keeps a command at the very start of the text (nothing to punctuate)
    /// or of a line from matching.
    private static let regex = try! NSRegularExpression(
        pattern: "(?i)(?<=\\S)([.,!?;:]?)[ \\t]+"
            + "\\b(period|full stop|comma|question mark|exclamation (?:point|mark)"
            + "|semi-?colon|colon|new ?line|new paragraph)\\b"
            + "([ \\t]*[.,!?;:]+)?")

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

            let pre = ns.substring(with: m.range(at: 1))
            let word = ns.substring(with: m.range(at: 2))
            let post = m.range(at: 3).location == NSNotFound ? "" : ns.substring(with: m.range(at: 3))
            let prefix = ns.substring(to: m.range.location)
            let rest = ns.substring(from: m.range.location + m.range.length)
            let key = word.lowercased().replacingOccurrences(of: "-", with: "")

            guard let command = commands[key],
                  qualifies(command, pre: pre, post: post, prefix: prefix, rest: rest) else {
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

    private static func qualifies(_ command: Command, pre: String, post: String,
                                  prefix: String, rest: String) -> Bool {
        if pre.isEmpty, lastWords(of: prefix, count: 2).contains(where: mentionWords.contains) {
            return false
        }
        let before = !pre.isEmpty
        let after = !post.isEmpty || rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return command.strict ? before && after : before || after
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
