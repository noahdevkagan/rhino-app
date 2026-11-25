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
    /// Polished asks the model to drop words (false starts, fillers), so a short dictation can
    /// lose a whole clause ("Order two pallets for Dallas, order five pallets for Austin" → the
    /// Austin half): there the word check starts at this many words instead.
    static let polishedMinimumWords = 5
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

    /// `allowFalseStarts` is the Polished level: an abandoned start the speaker restarted
    /// ("I was going to, I think we should…") may go. Nothing else is loosened.
    static func preservesSpokenWords(input: String, output: String,
                                     allowFalseStarts: Bool = false) -> Bool {
        let spoken = words(input)
        // Scripts written without spaces come through as a few very long "words";
        // counting them says nothing about what was kept.
        guard spoken.count >= (allowFalseStarts ? polishedMinimumWords : minimumWords),
              spoken.reduce(0, { $0 + $1.count }) / spoken.count <= 12 else { return true }
        let written = words(output)

        var removedOffsets: [Int] = []
        var removed: [String: Int] = [:], inserted: [String: Int] = [:]
        var removals: [Change] = [], insertions: [Change] = []
        for change in written.difference(from: spoken) {
            switch change {
            case .remove(let offset, let word, _):
                removals.append(Change(word: word, offset: offset))
            case .insert(let offset, let word, _):
                inserted[word, default: 0] += 1
                insertions.append(Change(word: word, offset: offset))
            }
        }
        if allowFalseStarts {
            // If the two tokenisers ever disagree, treat every word as a sentence end: no
            // run then counts as a false start, which is the safe side.
            let ends = sentenceEnds(input)
            let restarts = falseStartOffsets(
                spoken: spoken,
                endsSentence: ends.count == spoken.count ? ends : Array(repeating: true, count: spoken.count),
                removed: removals.map(\.offset))
            removals.removeAll { restarts.contains($0.offset) }
        }
        for change in removals {
            removedOffsets.append(change.offset)
            removed[change.word, default: 0] += 1
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

    /// Longest abandoned start that counts as a false start.
    static let falseStartMaxWords = 6

    /// Offsets of dropped runs that are false starts. Parallel clauses look like restarts
    /// ("tell Sam the budget is approved, tell Maya…", "we will refund the deposit but we will
    /// not…"), so a dropped run only counts when ALL of these hold for the abandoned start F
    /// (up to `falseStartMaxWords` words) and the restart R that follows it:
    ///   - F is a fragment: no word in it ends a sentence (no ".", "?" or "!" inside or after it);
    ///   - R repeats at least F's first two words, or F is one word said twice ("I I think");
    ///   - F holds no negation and no number (losing "can't" or "two" changes the meaning);
    ///   - every content word in F is said again in R's sentence.
    /// When in doubt the run stays a drop and the guard decides as it would at Light tidy.
    private static func falseStartOffsets(spoken: [String], endsSentence: [Bool],
                                          removed: [Int]) -> Set<Int> {
        var result = Set<Int>()
        var runs: [[Int]] = []
        for offset in removed.sorted() {
            if let last = runs.last?.last, last + 1 == offset {
                runs[runs.count - 1].append(offset)
            } else {
                runs.append([offset])
            }
        }
        for run in runs where run.count <= falseStartMaxWords {
            guard let first = run.first, let last = run.last else { continue }
            let n = run.count
            // The diff may keep either saying of the repeated words: "[we should] we should go"
            // and "we [should we] should go" drop the same false start. Shifting the run back by
            // `s` words is the same text when the s words before it equal its last s words.
            for s in 0...n {
                let a = first - s, b = last + 1 - s
                guard a >= 0 else { break }
                guard (0..<s).allSatisfy({ spoken[a + $0] == spoken[b + $0] }) else { continue }
                if isFalseStart(spoken: spoken, endsSentence: endsSentence, start: a, restart: b) {
                    result.formUnion(run)
                    break
                }
            }
        }
        return result
    }

    /// Whether spoken[start..<restart] is an abandoned start that spoken[restart...] restarts.
    private static func isFalseStart(spoken: [String], endsSentence: [Bool],
                                     start: Int, restart: Int) -> Bool {
        let fragment = Array(spoken[start..<restart])
        guard !fragment.isEmpty, fragment.count <= falseStartMaxWords else { return false }
        // A finished sentence is not a false start, however much the next one looks like it.
        if (start..<restart).contains(where: { endsSentence[$0] }) { return false }
        // The restart must say the fragment's first two words again (one for a stammer).
        let repeated = min(2, fragment.count)
        guard restart + repeated <= spoken.count,
              (0..<repeated).allSatisfy({ spoken[restart + $0] == fragment[$0] }) else { return false }
        if fragment.contains(where: { isNegation($0) || isNumber($0) }) { return false }
        // Everything the fragment said that matters is said again before the restart's
        // sentence ends: otherwise dropping it loses information ("refund the deposit").
        var end = restart
        while end < spoken.count {
            end += 1
            if endsSentence[end - 1] { break }
        }
        let restartWords = Set(spoken[restart..<end])
        return fragment.allSatisfy { !isContent($0) || restartWords.contains($0) }
    }

    private static func isNegation(_ word: String) -> Bool {
        negations.contains(word) || word.hasSuffix("n't")
    }

    private static let negations: Set<String> = [
        "not", "no", "never", "nothing", "nobody", "none", "neither", "nor", "cannot", "nowhere",
        "without", "cant", "wont", "dont", "didnt", "doesnt", "isnt", "arent", "wasnt", "werent",
        "shouldnt", "couldnt", "wouldnt", "havent", "hasnt", "hadnt",
    ]

    private static func isNumber(_ word: String) -> Bool {
        word.contains(where: \.isNumber) || numberWords.contains(word)
    }

    private static let numberWords: Set<String> = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
        "eighty", "ninety", "hundred", "thousand", "million", "billion", "half", "dozen",
        "first", "second", "third", "once", "twice",
    ]

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

    /// For each word `words(text)` returns, whether a ".", "?" or "!" follows it before the
    /// next word. Same tokenising as `words`, so the indexes line up.
    private static func sentenceEnds(_ text: String) -> [Bool] {
        let normalized = text.lowercased().replacingOccurrences(of: "’", with: "'")
        let wordChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'"))
        var ends: [Bool] = []
        var token = ""
        var separator = ""
        func finish() {
            if !token.trimmingCharacters(in: CharacterSet(charactersIn: "'")).isEmpty {
                ends.append(false)
            }
            token = ""
        }
        for scalar in normalized.unicodeScalars {
            if wordChars.contains(scalar) {
                if token.isEmpty, !ends.isEmpty, separator.contains(where: { ".?!".contains($0) }) {
                    ends[ends.count - 1] = true
                }
                if token.isEmpty { separator = "" }
                token.unicodeScalars.append(scalar)
            } else {
                finish()
                separator.unicodeScalars.append(scalar)
            }
        }
        finish()
        if !ends.isEmpty, separator.contains(where: { ".?!".contains($0) }) {
            ends[ends.count - 1] = true
        }
        return ends
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
