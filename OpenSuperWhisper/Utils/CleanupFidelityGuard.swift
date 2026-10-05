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

        if added >= max(addedFloor, Int((Double(spoken.count) * addedFraction).rounded(.up))) {
            return false
        }
        if isList(output) {
            return Double(dropped) <= Double(spoken.count) * listDroppedFraction
        }
        if longestRun(removedOffsets.sorted()) >= longestDroppedRun { return false }
        return dropped < droppedFloor || Double(dropped) <= Double(spoken.count) * droppedFraction
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
