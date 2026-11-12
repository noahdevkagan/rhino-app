import Foundation

/// Checks that LLM cleanup output still says what the speaker said.
///
/// The length-ratio guard only catches gross failures. Replaying real dictations through
/// the 1.5B model (docs/performance-audit-2026-10-05.md) found outputs that pass it while
/// being wrong: a 24-word sentence deleted from the middle of a 71-word dictation, and a
/// dictated request ("write a message to them asking for…") answered with the drafted
/// message. Both show up as words: many spoken words missing, or several words nobody
/// said. A rejected cleanup falls back to the transcript, which is complete.
enum CleanupFidelityGuard {
    /// Shorter texts are left to the length guard: a legitimate fix to a few words is a
    /// large fraction of them.
    static let minimumWords = 12
    /// A deleted clause. Cleanup drops a stray "and" or a repeated word, never this many in a row.
    static let longestDroppedRun = 8
    /// Dropped words scattered through the text: at least `droppedFloor` of them and more
    /// than `droppedFraction` of the dictation.
    static let droppedFloor = 4
    static let droppedFraction = 0.08
    /// A dictated list loses its cue words and often its lead-in ("okay, make a list"),
    /// so list output is only held to this looser bound.
    static let listDroppedFraction = 0.4
    /// Words that were never spoken: at least `addedFloor`, or `addedFraction` of a long dictation.
    static let addedFloor = 3
    static let addedFraction = 0.02
    /// Under this many words the floors above are too loose: replaying real dictations, a short
    /// one never legitimately loses two content words or gains one nobody said, while the bad
    /// rewrites did exactly that ("Draft Matt a message to see if he…" → "Draft Matt: see if
    /// you…"; "really liked your place" → "really looking forward to your place").
    /// A join ("post hog" → "posthog"), a word-form change or a completed fragment
    /// ("as f as" → "as far as") is explained by the spoken words and doesn't count.
    static let shortDictationWords = 40
    static let shortDroppedLimit = 2

    static func preservesSpokenWords(input: String, output: String) -> Bool {
        let spoken = words(input)
        // Scripts written without spaces come through as a few very long "words";
        // counting them says nothing about what was kept.
        guard spoken.count >= minimumWords,
              spoken.reduce(0, { $0 + $1.count }) / spoken.count <= 12 else { return true }
        let written = words(output)

        var removedOffsets: [Int] = []
        var removed: [String: Int] = [:], inserted: [String: Int] = [:]
        var removals: [Change] = [], insertions: [Change] = []
        for change in written.difference(from: spoken) {
            switch change {
            case .remove(let offset, let word, _):
                removedOffsets.append(offset)
                removed[word, default: 0] += 1
                removals.append(Change(word: word, offset: offset))
            case .insert(let offset, let word, _):
                inserted[word, default: 0] += 1
                insertions.append(Change(word: word, offset: offset))
            }
        }
        // A word that moved is neither lost nor invented.
        for (word, count) in removed {
            let moved = min(count, inserted[word] ?? 0)
            removed[word] = count - moved
            inserted[word] = (inserted[word] ?? 0) - moved
        }
        let dropped = removed.reduce(0) { $0 + (isContent($1.key) ? $1.value : 0) }
        let added = inserted.reduce(0) { $0 + (isContent($1.key) ? $1.value : 0) }
        let short = spoken.count < shortDictationWords
        let unexplained = short
            ? unexplainedChanges(removals: removals, insertions: insertions,
                                 heading: isList(output) ? headingWords(output) : [])
            : nil

        // Short text: one unexplained word is enough, and joins don't count against it.
        if let unexplained {
            if unexplained.invented > 0 { return false }
        } else if added >= max(addedFloor, Int((Double(spoken.count) * addedFraction).rounded(.up))) {
            return false
        }
        if isList(output) {
            return Double(dropped) <= Double(spoken.count) * listDroppedFraction
        }
        if longestRun(removedOffsets.sorted()) >= longestDroppedRun { return false }
        if let unexplained { return unexplained.dropped < shortDroppedLimit }
        return dropped < droppedFloor || Double(dropped) <= Double(spoken.count) * droppedFraction
    }

    private struct Change { let word: String; let offset: Int }

    /// Content words lost and gained once moves, joins, word-form changes and completed
    /// fragments are paired off. Works on the diff's ordered changes, never on dictionary
    /// iteration order, so the same text always gets the same answer.
    private static func unexplainedChanges(removals: [Change], insertions: [Change],
                                           heading: [String]) -> (dropped: Int, invented: Int) {
        var lost = removals.sorted { $0.offset < $1.offset }
        var added = insertions.sorted { $0.offset < $1.offset }
        // A word that moved is neither lost nor invented.
        added = added.filter { change in
            guard let i = lost.firstIndex(where: { $0.word == change.word }) else { return true }
            lost.remove(at: i)
            return false
        }
        var headingAllowance = Array(heading.prefix(2))
        var invented = 0
        for change in added where isShortContent(change.word) {
            let word = change.word
            if let i = lost.indices.dropLast().first(where: {
                lost[$0 + 1].offset == lost[$0].offset + 1 && lost[$0].word + lost[$0 + 1].word == word
            }) {
                // "post hog" → "posthog": two spoken words, side by side.
                lost.removeSubrange(i...(i + 1))
            } else if let i = lost.firstIndex(where: { isWordForm($0.word, word) || completes($0.word, word) }) {
                lost.remove(at: i)
            } else if let i = headingAllowance.firstIndex(of: word) {
                // A list heading the model added ("Shopping list:").
                headingAllowance.remove(at: i)
            } else {
                invented += 1
            }
        }
        return (lost.filter { isShortContent($0.word) }.count, invented)
    }

    /// The same word in another form: "seatbelt's"/"seatbelt", "organizing"/"organize",
    /// "launch"/"launches". Only these endings: "should"/"shouldn't" is the opposite meaning,
    /// and "approve"/"approach" a different word.
    private static func isWordForm(_ a: String, _ b: String) -> Bool {
        let (short, long) = a.count <= b.count ? (a, b) : (b, a)
        guard short.count >= 3, short != long else { return false }
        if long.hasPrefix(short), wordFormEndings.contains(String(long.dropFirst(short.count))) {
            return true
        }
        if short.hasSuffix("e") {
            let stem = short.dropLast()
            return long.hasPrefix(stem) && ["ing", "ed", "er"].contains(String(long.dropFirst(stem.count)))
        }
        return false
    }

    private static let wordFormEndings: Set<String> = ["s", "es", "'s", "ed", "d", "ing", "er", "ers", "ly"]

    /// A cut-off single letter the model finished: "as f as" → "as far as".
    private static func completes(_ fragment: String, _ word: String) -> Bool {
        fragment.count == 1 && word.count <= 4 && word.hasPrefix(fragment)
    }

    /// Words on a list's heading line (a non-item line ending in a colon).
    private static func headingWords(_ text: String) -> [String] {
        text.split(separator: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasSuffix(":") && !isList(String($0)) }
            .flatMap { words(String($0)) }
    }

    /// Short dictations also let "as" and "are" come and go ("as f as long as" → "as far as").
    private static func isShortContent(_ word: String) -> Bool {
        isContent(word) && word != "as" && word != "are"
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            .filter { !$0.isEmpty }
    }

    /// Function words, fillers, layout cues and numbers come and go in a faithful cleanup
    /// ("three hundred" → "300", "number one" → "1."), so they don't count as lost or invented.
    private static func isContent(_ word: String) -> Bool {
        !ignorable.contains(word) && !word.allSatisfy(\.isNumber)
    }

    private static let ignorable: Set<String> = [
        "a", "an", "the", "and", "or", "but", "so", "to", "of", "in", "on", "at", "for", "with",
        "that", "this", "it", "is", "was", "be", "i", "you", "we", "he", "she", "they", "them",
        "just", "like", "really", "well", "okay", "ok", "alright", "all", "right", "um", "uh",
        "yeah", "know", "mean",
        "number", "item", "step", "bullet", "point", "next", "new", "line", "paragraph",
        "first", "second", "third", "fourth", "fifth",
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
        "eighty", "ninety", "hundred", "thousand", "million", "billion",
        "percent", "dollar", "dollars",
    ]

    private static func isList(_ text: String) -> Bool {
        text.range(of: #"(?m)^\s*(?:[-*•] |\d+[.)] )"#, options: .regularExpression) != nil
    }

    private static func longestRun(_ sortedOffsets: [Int]) -> Int {
        var longest = 0, current = 0
        var previous: Int?
        for offset in sortedOffsets {
            current = (previous.map { offset == $0 + 1 } ?? false) ? current + 1 : 1
            longest = max(longest, current)
            previous = offset
        }
        return longest
    }
}
