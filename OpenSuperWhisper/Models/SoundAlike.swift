import Foundation

/// Catches the spellings a speech model invents for a word it has never seen.
///
/// An exact rule only works once the user knows what the model mishears, and people don't:
/// they know "Klaviyo" is right, not that it lands as "Clavio" one day and "Claviyo" the next.
/// So a rule's word also fixes anything that sounds the same and is spelled nearly the same,
/// as long as the stray spelling isn't a real English word. The real-word guard is what makes
/// this safe to run on every dictation: "Stripe" sounds like "strip", but "strip" is a word and
/// is left alone; "Clavio" is not a word, so it can only have been a mishearing.
///
/// Two adjacent words are also tried as one, since that is how compound brand names break:
/// "git hub", "hub spot", "air table". A pair has to spell the word exactly — close was far too
/// loose over real text ("as an" → "Asana", "you type" → "YouTube").
///
/// Links, addresses and paths are left alone: "github.com/me" is not a mishearing.
enum SoundAlike {

    /// Shorter words collide with too much ordinary speech to be worth guessing at. Short names
    /// still work through an exact "heard as" phrasing.
    static let minimumTermLength = 5

    /// Rewrites every near-miss of an eligible rule's word in `text`.
    ///
    /// `isRealWord` is injectable so tests don't depend on the system word list.
    static func apply(_ text: String, entries: [CustomDictionaryEntry],
                      isRealWord: (String) -> Bool = SystemWordList.contains) -> String {
        let terms = eligibleTerms(entries)
        guard !terms.isEmpty, !text.isEmpty else { return text }

        // Another rule's own words are never someone's mishearing of this one.
        var protected = Set<String>()
        for entry in entries {
            protected.insert(fold(entry.replacement))
            for trigger in entry.triggers { protected.insert(fold(trigger)) }
        }

        let tokens = wordTokens(in: text).filter { !isInsideLinkOrPath($0, of: text) }
        var edits: [(range: Range<String.Index>, term: String)] = []
        var index = 0
        while index < tokens.count {
            // Two words first: "git hub" should become one "GitHub", not stay two misses.
            if index + 1 < tokens.count,
               text[tokens[index].upperBound..<tokens[index + 1].lowerBound] == " " {
                let pair = tokens[index].lowerBound..<tokens[index + 1].upperBound
                let joined = String(text[tokens[index]]) + String(text[tokens[index + 1]])
                if let term = match(joined, terms: terms, protected: protected, exactOnly: true,
                                    isRealWord: isRealWord) {
                    edits.append((pair, term))
                    index += 2
                    continue
                }
            }
            if let term = match(String(text[tokens[index]]), terms: terms, protected: protected,
                                exactOnly: false, isRealWord: isRealWord) {
                edits.append((tokens[index], term))
            }
            index += 1
        }

        var result = text
        for edit in edits.reversed() {
            result.replaceSubrange(edit.range, with: edit.term)
        }
        return result
    }

    /// The rule words distinctive enough to guess at: one word, mostly letters, long enough.
    static func eligibleTerms(_ entries: [CustomDictionaryEntry]) -> [String] {
        var seen = Set<String>()
        return entries
            .map { $0.replacement.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { term in
                term.allSatisfy { $0.isLetter || $0.isNumber }
                    && term.filter(\.isLetter).count >= minimumTermLength
                    && seen.insert(fold(term)).inserted
            }
    }

    /// What a word sounds like, reduced to its consonants.
    ///
    /// Letters a model swaps for each other when guessing at an unfamiliar word collapse to one
    /// symbol: hard c/k/q/g, soft c/s/z, v/f/ph, b/p, d/t. Vowels, h, w and y carry too little to
    /// compare — "Klaviyo" and "Clavio" both reduce to `klf` — except a leading vowel, which
    /// keeps "Asana" apart from "Sana".
    static func skeleton(_ word: String) -> String {
        let letters = Array(fold(word))
        var out: [Character] = []
        var index = 0
        while index < letters.count {
            let letter = letters[index]
            let next: Character? = index + 1 < letters.count ? letters[index + 1] : nil
            var symbol: Character?
            switch letter {
            case "a", "e", "i", "o", "u", "y":
                symbol = index == 0 ? "a" : nil
            case "h", "w":
                symbol = nil
            case "c":
                if next == "h" {
                    symbol = "x"
                    index += 1
                } else if let next, "eiy".contains(next) {
                    symbol = "s"
                } else {
                    symbol = "k"
                }
            case "s":
                if next == "h" {
                    symbol = "x"
                    index += 1
                } else {
                    symbol = "s"
                }
            case "p":
                if next == "h" {
                    symbol = "f"
                    index += 1
                } else {
                    symbol = "p"
                }
            case "k", "q", "g": symbol = "k"
            case "z": symbol = "s"
            case "v", "f": symbol = "f"
            case "b": symbol = "p"
            case "d": symbol = "t"
            case "x":
                out.append("k")
                symbol = "s"
            default: symbol = letter
            }
            if let symbol, out.last != symbol { out.append(symbol) }
            index += 1
        }
        return String(out)
    }

    /// How many letters a candidate may be off by. Scaled to the word: one for a 5–6 letter
    /// word, two from 7 ("Clavio" for "Klaviyo" needs two raw edits, one once c/k is free).
    static func allowedDistance(for term: String) -> Int {
        max(1, (term.count - 1) / 3)
    }

    /// Levenshtein distance, where swapping letters that sound alike (c/k, v/f, s/z, b/p, d/t)
    /// is free: those are the guesses a model makes, not a different word. Vowels still count,
    /// or every consonant frame would match every other.
    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a).map(soundClass), b = Array(b).map(soundClass)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    // MARK: - Private

    private static func soundClass(_ letter: Character) -> Character {
        switch letter {
        case "c", "k", "q", "g": return "k"
        case "s", "z": return "s"
        case "v", "f": return "f"
        case "b", "p": return "p"
        case "d", "t": return "t"
        default: return letter
        }
    }

    private static func match(_ candidate: String, terms: [String], protected: Set<String>,
                              exactOnly: Bool, isRealWord: (String) -> Bool) -> String? {
        let folded = fold(candidate)
        guard folded.count >= minimumTermLength - 1 else { return nil }

        var best: (term: String, distance: Int)?
        var tied = false
        for term in terms {
            let foldedTerm = fold(term)
            if folded == foldedTerm {
                // Only the casing or a split is off ("klaviyo", "git hub"). Fixing it is the
                // point, unless the brand is also an ordinary word ("notion"): that stays as
                // spoken, since nothing says the user meant the brand.
                if candidate == term || isRealWord(folded) { return nil }
                return term
            }
            guard !exactOnly, abs(folded.count - foldedTerm.count) <= 2,
                  skeleton(folded) == skeleton(foldedTerm) else { continue }
            let distance = editDistance(folded, foldedTerm)
            guard distance <= allowedDistance(for: foldedTerm) else { continue }
            if let current = best {
                if distance < current.distance {
                    best = (term, distance)
                    tied = false
                } else if distance == current.distance {
                    tied = true
                }
            } else {
                best = (term, distance)
            }
        }
        guard let best, !tied else { return nil }
        // A real word was said on purpose. For a pair it is the two together that must not be
        // a word: "air table" is two ordinary words, but only the brand spells "airtable".
        if protected.contains(folded) || isRealWord(folded) { return nil }
        return best.term
    }

    private static func wordTokens(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start: String.Index?
        for index in text.indices {
            let character = text[index]
            if character.isLetter || character.isNumber {
                if start == nil { start = index }
            } else if let open = start {
                ranges.append(open..<index)
                start = nil
            }
        }
        if let open = start { ranges.append(open..<text.endIndex) }
        return ranges
    }

    /// Whether the run of non-space text around a word is a link, address or path.
    private static func isInsideLinkOrPath(_ token: Range<String.Index>, of text: String) -> Bool {
        var start = token.lowerBound
        while start > text.startIndex, !text[text.index(before: start)].isWhitespace {
            start = text.index(before: start)
        }
        var end = token.upperBound
        while end < text.endIndex, !text[end].isWhitespace { end = text.index(after: end) }
        let chunk = text[start..<end]
        if chunk.contains(where: { "/@\\_".contains($0) }) { return true }
        // A dot between letters ("github.com"), not one ending a sentence.
        let characters = Array(chunk)
        return characters.indices.dropFirst().dropLast().contains {
            characters[$0] == "." && characters[$0 - 1].isLetter && characters[$0 + 1].isLetter
        }
    }

    private static func fold(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }
}

/// The macOS system word list (/usr/share/dict/words), used to tell a real word from a
/// mishearing. Loaded once, off the dictation path where possible (`prewarm`): ~100 ms and
/// ~10 MB, paid only by people whose dictionary has a word long enough to guess at.
enum SystemWordList {
    private static let words: Set<String>? = {
        guard let text = try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8)
        else { return nil }
        var set = Set<String>(minimumCapacity: 240_000)
        text.enumerateLines { line, _ in set.insert(line.lowercased()) }
        return set
    }()

    /// Without the list nothing can be told apart, so every word counts as real and sound-alike
    /// matching stands down.
    static func contains(_ word: String) -> Bool {
        guard let words else { return true }
        return words.contains(word.lowercased())
    }

    static func prewarm() {
        DispatchQueue.global(qos: .utility).async { _ = words }
    }
}
