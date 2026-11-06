import Foundation
import NaturalLanguage

/// Deterministic layout for long dictated messages: greeting on its own line, sentences
/// grouped into short paragraphs, sign-off block at the end. Part of smart formatting (no
/// toggle of its own). The 1.5B cleanup model only lays out short messages: past roughly
/// 500-900 characters it returns the text as one block however the prompt asks
/// (decisions.md, 2026-11-05). Only whitespace, the greeting's and sign-off's punctuation
/// and one capital change here, so the spoken words cannot be lost.
///
/// English only: the greeting, sign-off and topic cues are English words.
enum MessageLayout {
    /// A line shorter than this is left alone. The model still handles short messages.
    static let minChars = 400

    private static let softSentenceLimit = 3
    private static let hardSentenceLimit = 4
    private static let softCharLimit = 320

    /// Whether `text` is a message with a line long enough to need paragraphs.
    static func qualifies(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: "\n")
        guard lines.contains(where: isLongProse) else { return false }
        let opensWithGreeting = trimmed.range(
            of: #"^\W*(?:hi|hey|hello|dear|good (?:morning|afternoon|evening))\b"#,
            options: [.regularExpression, .caseInsensitive]) != nil
        return opensWithGreeting
            || sentences(in: lines[lines.count - 1]).last.flatMap(signOffBlock) != nil
    }

    /// Lays `text` out as a message, or returns it unchanged when it does not qualify.
    /// Line breaks already there (spoken "new paragraph", the model's layout) are kept.
    static func apply(_ text: String) -> String {
        guard qualifies(text) else { return text }
        var lines = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")

        var greeting: String?
        if let split = splitGreeting(lines[0]) {
            greeting = split.greeting
            lines[0] = split.rest
        }

        // "Thanks so much. Best wishes, Noah." closes with two blocks, so peel up to two.
        var closing = sentences(in: lines[lines.count - 1])
        var signOffs: [String] = []
        while signOffs.count < 2, let last = closing.last, let block = signOffBlock(last) {
            signOffs.insert(block, at: 0)
            closing.removeLast()
        }
        if !signOffs.isEmpty {
            lines[lines.count - 1] = closing.joined(separator: " ")
        }

        let body = lines
            .map { isLongProse($0) ? paragraphs(in: $0).joined(separator: "\n\n") : $0 }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ([greeting, body].compactMap { $0 } + signOffs)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// Prose line long enough to break up. List items are never split.
    private static func isLongProse(_ line: String) -> Bool {
        line.count >= minChars
            && line.range(of: #"^\s*(?:[-*•]|\d+\.)\s"#, options: .regularExpression) == nil
    }

    /// "Hey Sam, hope you're well." → ("Hey Sam,", "Hope you're well."). Only capitalized
    /// words count as the name, so "Hey I think, maybe" and "Hey there's a problem, and" have
    /// no greeting line. Those still get paragraphs.
    private static func splitGreeting(_ line: String) -> (greeting: String, rest: String)? {
        let name = #"(?:(?i:there|team|all|everyone|everybody|guys|folks)|(?:Dr|Mr|Mrs|Ms|Prof)\.?"#
            + #"|(?!I\b|I['’])[A-Z][\w'’-]*)"#
        // A comma only after the bare greeting ("Hey, Sam,"): in "Hi Sam, Dr. Patel said" the
        // greeting ends at the first comma.
        let pattern = #"^\W*((?i:hi|hey|hello|dear|good (?:morning|afternoon|evening))"#
            + #"(?:,? "# + name + #"(?: "# + name + #"){0,2})?)([,.!:])\s+(\S.*)$"#
        guard let groups = captures(of: pattern, in: line),
              let greeting = groups[0], let mark = groups[1], let rest = groups[2] else {
            return nil
        }
        return (greeting + (mark == "!" ? "!" : ","), rest.prefix(1).uppercased() + rest.dropFirst())
    }

    /// The layout for a closing sentence, or nil when it isn't one. "Best wishes, Noah." →
    /// "Best wishes,\nNoah"; "Thanks so much." stays as spoken. Must be a whole sentence
    /// of its own, so "This option is the best." and "Best of luck." stay in the body.
    private static func signOffBlock(_ sentence: String) -> String? {
        let phrase = #"(?i:thanks(?: so much| a lot| again)?|thank you(?: so much)?"#
            + #"|best(?: wishes| regards)?|(?:kind |warm )?regards|cheers|sincerely|talk soon)"#
        let pattern = "^(" + phrase + #")[,.!]?(?:\s+([A-Z][\w'’-]*(?:\s+[A-Z][\w'’-]*)?))?\W*$"#
        guard let groups = captures(of: pattern, in: sentence), let spoken = groups[0] else {
            return nil
        }
        if let name = groups[1] { return "\(spoken),\n\(name)" }
        return sentence
    }

    /// Groups a line's sentences into paragraphs: a topic cue opens a new one, and a
    /// paragraph ends at the soft limits unless the next sentence leans on the one before.
    private static func paragraphs(in line: String) -> [String] {
        let topicCue = #"^(?:(?:the )?(?:first|second|third|next|other|another|last|final|one more)"#
            + #" (?:thing|point|item|question)|(?:first|second|third|next|also|finally|lastly|separately)\b,?"#
            + #"|same thing\b|in terms of\b|as for\b|and then\b|on that note\b|by the way\b|anyway\b"#
            + #"|let me know\b)"#
        let continuation = #"^(?:and|that|this|these|those|it|they|so|but|which|because)\b"#

        var result: [String] = []
        var current: [String] = []
        for sentence in sentences(in: line) {
            let startsTopic = matches(topicCue, sentence)
            let chars = current.reduce(0) { $0 + $1.count }
            let full = current.count >= softSentenceLimit || chars >= softCharLimit
            let breakHere = !current.isEmpty
                && (startsTopic
                    || current.count >= hardSentenceLimit
                    || (full && !matches(continuation, sentence)))
            if breakHere {
                result.append(current.joined(separator: " "))
                current = []
            }
            current.append(sentence)
        }
        if !current.isEmpty { result.append(current.joined(separator: " ")) }
        return result
    }

    private static func sentences(in line: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.setLanguage(.english)
        tokenizer.string = line
        return tokenizer.tokens(for: line.startIndex..<line.endIndex)
            .map { line[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// The pattern's capture groups, nil for each that took no part in the match.
    private static func captures(of pattern: String, in text: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
    }
}
