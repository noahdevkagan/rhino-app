import Foundation

/// Fits a finished dictation to the text around the caret, so a phrase dropped into the middle
/// of a sentence reads like part of it.
///
/// The speech engines (Parakeet, Whisper) format every clip as a whole sentence: capital first
/// letter, closing period. That is right at the start of a field and wrong almost everywhere
/// else. Users correcting a phrase mid-sentence got "the Quick brown fox. jumps"
/// (customer reports 2026-10-21 to 10-27), and single words or numbers typed into a spreadsheet
/// got a period each.
///
/// Pure text logic; `TranscriptInserter` reads the context via Accessibility
/// (`FocusUtils.caretContext()`) and passes `nil` when it can't, which changes nothing.
enum ContextCasing {

    /// How much text to read on each side of the caret. Enough to see past a few spaces or a
    /// list marker before it, and a space plus one letter after it.
    static let beforeWindow = 32
    static let afterWindow = 2

    /// Dictations this short are field values (a name, a number, a date, a cell), not sentences.
    static let shortDictationMaxWords = 3

    /// - Parameters:
    ///   - text: The dictation as it would be inserted (may carry the trailing space
    ///     `applyPostProcessing` adds after a closing period).
    ///   - before: Up to `beforeWindow` characters before the caret (before the selection, if
    ///     text is selected). `""` means the caret is at the start of the field. `nil` means the
    ///     app didn't expose its text: the dictation is returned unchanged.
    ///   - after: Up to `afterWindow` characters after the caret (after the selection). `""` is
    ///     the end of the field, `nil` unknown.
    ///   - spokenTrailingMark: The user said the closing mark ("period", "comma"), so it stays.
    ///   - isProperNoun: Extra protection for the first word (names, the user's dictionary).
    static func apply(text: String, before: String?, after: String?,
                      spokenTrailingMark: Bool = false,
                      isProperNoun: (String) -> Bool = { _ in false }) -> String {
        guard let before else { return text }

        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return text }
        let leadingWS = String(text.prefix { $0.isWhitespace })
        let trailingWS = String(String(text.reversed()).prefix { $0.isWhitespace }.reversed())

        let midSentence = isMidSentence(before: before)
        if midSentence {
            body = lowercasingFirstWord(body, isProperNoun: isProperNoun)
        }

        // Closing mark. Only a lone "." (or a "," mid-sentence) is ever dropped; "?", "!", "..."
        // and abbreviations ("U.S.") stay, and so does anything the user said out loud.
        var dropped = false
        if !spokenTrailingMark {
            let continuesIntoText = midSentence && nextIsWord(after)
            if continuesIntoText, body.hasSuffix(","), body.count > 1 {
                body.removeLast()
                dropped = true
            } else if hasDroppablePeriod(body),
                      continuesIntoText
                        || (wordCount(body) <= shortDictationMaxWords
                            // "Done. | More": a short sentence between sentences keeps its period.
                            && (midSentence || !nextIsWord(after))) {
                body.removeLast()
                dropped = true
            }
        }

        // Spacing on the left: one space between the existing text and the dictation, never two.
        var leading = leadingWS
        if let last = before.last, last.isWhitespace {
            leading = ""
        } else if before.isEmpty {
            leading = ""
        } else if leading.isEmpty, needsSpaceBetween(before.last, body.first) {
            leading = " "
        }

        // Spacing on the right.
        var trailing = trailingWS
        if dropped {
            // The trailing space only followed the period; without it, it would be a stray.
            trailing = ""
        }
        if let next = after?.first {
            if next == " " || next == "\t" {
                trailing = ""
            } else if trailing.isEmpty, needsSpaceBetween(body.last, next) {
                trailing = " "
            }
        }

        return leading + body + trailing
    }

    // MARK: - Context

    /// Sentence-ending marks: the next word starts a sentence.
    private static let sentenceEnders: Set<Character> = [".", "!", "?", "…"]
    /// Skipped when looking for the mark that ends the previous text: `He said "Hi."` ends a
    /// sentence even though the last character is a quote.
    private static let closers: Set<Character> = ["\"", "'", "”", "’", ")", "]", "»"]

    /// True when the caret sits inside a sentence: there is text before it on the same line and
    /// the last real character before it doesn't end a sentence.
    static func isMidSentence(before: String) -> Bool {
        // The current line only; a newline means we're at the start of a line.
        let line: Substring
        if let nl = before.lastIndex(where: { $0.isNewline }) {
            line = before[before.index(after: nl)...]
        } else {
            line = before[...]
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            // Empty field, empty line, or only whitespace in the window: treat as a start.
            return false
        }
        if isListMarker(trimmed) { return false }
        for ch in trimmed.reversed() {
            if closers.contains(ch) { continue }
            return !sentenceEnders.contains(ch)
        }
        return false
    }

    /// "- ", "* ", "• ", "1. ", "2) " on a line of their own: the next word starts a list item.
    private static func isListMarker(_ s: String) -> Bool {
        if ["-", "*", "•", "\u{2013}", "\u{2014}"].contains(s) { return true }
        guard let last = s.last, last == "." || last == ")" else { return false }
        let digits = s.dropLast()
        return !digits.isEmpty && digits.count <= 3 && digits.allSatisfy(\.isNumber)
    }

    /// The text after the caret continues the sentence: a word right there, or after one space.
    private static func nextIsWord(_ after: String?) -> Bool {
        guard let after, let first = after.first else { return false }
        if isWordChar(first) { return true }
        if first == " " || first == "\t" {
            let rest = after.dropFirst()
            if let second = rest.first { return isWordChar(second) }
        }
        return false
    }

    // MARK: - First word

    /// English names that stay capitalized even though they're dictionary words.
    private static let alwaysCapitalized: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "june", "july", "august", "september",
        "october", "november", "december",
    ]

    /// Lowercases the first letter when the first word is an ordinary capitalized word
    /// ("The", "Brown"), not "I"/"I'm", an acronym ("NASA"), a mixed-case name ("iPhone",
    /// "McDonald"), a weekday or month, or something `isProperNoun` recognizes.
    static func lowercasingFirstWord(_ text: String, isProperNoun: (String) -> Bool) -> String {
        guard let first = text.first, first.isLetter, first.isUppercase else { return text }
        let word = String(text.prefix { !$0.isWhitespace })
        // The word without trailing punctuation: "Fox." → "Fox".
        let core = String(word.reversed().drop { !$0.isLetter && !$0.isNumber }.reversed())
        guard !core.isEmpty else { return text }

        if core.count == 1 {
            // "I" stays; "A" is the article.
            guard core == "A" else { return text }
        } else {
            let rest = core.dropFirst()
            // "I'm", "I'll", "O'Brien": second character isn't a lowercase letter.
            guard let second = rest.first, second.isLetter, second.isLowercase else { return text }
            // "McDonald", "YouTube", "NASA": any later capital means a name or acronym.
            guard !rest.contains(where: { $0.isUppercase }) else { return text }
            guard !alwaysCapitalized.contains(core.lowercased()) else { return text }
            guard !isProperNoun(core) else { return text }
        }
        return first.lowercased() + text.dropFirst()
    }

    // MARK: - Closing period

    /// Abbreviations that keep their period even as the last word.
    private static let abbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "st", "jr", "sr", "inc", "ltd", "co", "corp", "etc", "vs",
        "prof", "approx", "dept", "est",
    ]

    /// A single closing "." that isn't part of "...", an abbreviation ("U.S.", "e.g.", "Dr."),
    /// or an initial ("J."). A number keeps its decimal point: "3.5." → "3.5".
    static func hasDroppablePeriod(_ text: String) -> Bool {
        guard text.hasSuffix("."), !text.hasSuffix(".."), text.count > 1 else { return false }
        let lastToken = text.split(whereSeparator: { $0.isWhitespace }).last.map(String.init) ?? text
        let stem = lastToken.dropLast()
        guard let stemLast = stem.last else { return false }
        if stem.contains("."), stemLast.isLetter { return false }
        if stem.count == 1, stemLast.isLetter, stemLast.isUppercase { return false }
        let bare = stem.filter { $0.isLetter }.lowercased()
        if abbreviations.contains(bare), stem.allSatisfy({ $0.isLetter }) { return false }
        return true
    }

    /// Words with at least one letter or digit ("$42" counts, a lone "-" doesn't).
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace })
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .count
    }

    // MARK: - Spacing

    /// Characters that sit flush against the word before them.
    private static let attachLeft: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", "%", "”", "’", "'", "\"", "…"]
    /// Characters that sit flush against the word after them.
    private static let attachRight: Set<Character> = ["(", "[", "{", "“", "‘", "'", "\"", "/", "-", "@", "#", "$"]

    /// Whether two neighbours need a space between them. Word characters on both sides do;
    /// punctuation attaches to its side; scripts written without spaces (Chinese, Japanese,
    /// Thai) never get one.
    static func needsSpaceBetween(_ left: Character?, _ right: Character?) -> Bool {
        guard let left, let right else { return false }
        if left.isWhitespace || right.isWhitespace { return false }
        if isUnspacedScript(left) || isUnspacedScript(right) { return false }
        if attachRight.contains(left) { return false }
        if attachLeft.contains(right) { return false }
        let leftOK = isWordChar(left) || attachLeft.contains(left)
        let rightOK = isWordChar(right) || attachRight.contains(right)
        return leftOK && rightOK
    }

    private static func isWordChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
    }

    private static func isUnspacedScript(_ c: Character) -> Bool {
        guard let v = c.unicodeScalars.first?.value else { return false }
        switch v {
        case 0x0E00...0x0E7F,   // Thai
             0x0E80...0x0EFF,   // Lao
             0x1000...0x109F,   // Myanmar
             0x1780...0x17FF,   // Khmer
             0x3000...0x30FF,   // CJK punctuation, Hiragana, Katakana
             0x3400...0x4DBF,   // CJK Extension A
             0x4E00...0x9FFF,   // CJK Unified Ideographs
             0xF900...0xFAFF,   // CJK Compatibility Ideographs
             0xFF00...0xFFEF,   // Fullwidth forms
             0x20000...0x2FFFF: // CJK Extensions B+
            return true
        default:
            return false
        }
    }

    // MARK: - Spoken marks

    /// Spoken commands for a closing mark that this pass could otherwise drop.
    private static let spokenClosers = ["period", "full stop", "comma"]

    /// True when the dictation ended with a spoken "period" / "full stop" / "comma" that
    /// `SpokenPunctuation` turned into the mark: the user asked for it, so it stays.
    /// `transcript` is the text before spoken punctuation ran.
    static func endsWithSpokenMark(_ transcript: String) -> Bool {
        func tail(_ s: String) -> String {
            String(String(s.lowercased().reversed())
                .drop { $0.isWhitespace || ".,!?;:".contains($0) }
                .reversed())
        }
        let before = tail(transcript)
        guard let word = spokenClosers.first(where: { endsWithWord(before, $0) }) else { return false }
        // Converted only if the command word is gone afterwards ("billing period." keeps it).
        let after = tail(SpokenPunctuation.apply(transcript))
        return !endsWithWord(after, word)
    }

    private static func endsWithWord(_ s: String, _ word: String) -> Bool {
        guard s.hasSuffix(word) else { return false }
        let start = s.index(s.endIndex, offsetBy: -word.count)
        return start == s.startIndex || !s[s.index(before: start)].isLetter
    }
}
