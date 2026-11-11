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
        for change in written.difference(from: spoken) {
            switch change {
            case .remove(let offset, let word, _):
                removedOffsets.append(offset)
                removed[word, default: 0] += 1
            case .insert(_, let word, _):
                inserted[word, default: 0] += 1
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
        let unexplained = short ? unexplainedChanges(removed: removed, inserted: inserted) : nil

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

    /// Content words lost and gained once joins, word-form changes and completed fragments
    /// are paired off against each other.
    private static func unexplainedChanges(removed: [String: Int], inserted: [String: Int])
        -> (dropped: Int, invented: Int) {
        var lost = removed.flatMap { word, count in Array(repeating: word, count: max(count, 0)) }
        var invented = 0
        for (word, count) in inserted where count > 0 && isContent(word) {
            for _ in 0..<count {
                // Joins first: "posthog" also starts with "post", which would leave "hog" lost.
                if let (i, j) = joinParts(of: word, in: lost) {
                    lost.remove(at: max(i, j))
                    lost.remove(at: min(i, j))
                } else if let i = lost.firstIndex(where: { isRelated($0, word) }) {
                    lost.remove(at: i)
                } else {
                    invented += 1
                }
            }
        }
        return (lost.filter(isContent).count, invented)
    }

    /// "organizing"/"organize", "seatbelt's"/"seatbelt", a cut-off "f" completed to "far".
    private static func isRelated(_ spoken: String, _ written: String) -> Bool {
        guard isContent(spoken) else { return false }
        if written.hasPrefix(spoken) || spoken.hasPrefix(written) { return true }
        return spoken.count >= 4 && written.count >= 4 && spoken.prefix(4) == written.prefix(4)
    }

    /// Two spoken words written as one: "post hog" → "posthog", "call outs" → "callouts".
    private static func joinParts(of word: String, in lost: [String]) -> (Int, Int)? {
        for (i, head) in lost.enumerated() where word.hasPrefix(head) && word.count > head.count {
            let tail = String(word.dropFirst(head.count))
            if let j = lost.indices.first(where: { $0 != i && lost[$0] == tail }) { return (i, j) }
        }
        return nil
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
        "that", "this", "it", "is", "are", "was", "be", "as", "i", "you", "we", "he", "she", "they", "them",
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
