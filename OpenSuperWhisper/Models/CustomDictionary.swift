import Foundation

/// A single custom-dictionary rule: whenever `original` is recognized in a
/// transcription it is rewritten to `replacement`. Useful for fixing proper
/// nouns, brand names and domain jargon that the speech models consistently
/// mis-transcribe (e.g. "git hub" -> "GitHub").
struct CustomDictionaryEntry: Codable, Identifiable, Equatable, Hashable {

    /// What the replacement does to the spaces around it.
    ///
    /// Dictating punctuation needs this. A rule turning the spoken "open quote" into `"` leaves
    /// `he said " hello "` if it only swaps the words, because the spaces that separated them
    /// are still there. Punctuation has to glue to the word it belongs to.
    enum Spacing: String, Codable {
        /// Replace the words and nothing else. Right for names and jargon.
        case standalone
        /// Also eat the space that follows, for an opening mark: `open quote hello` → `"hello`.
        case attachesRight
        /// Also eat the space before, for a closing mark: `hello close quote` → `hello"`.
        case attachesLeft
    }

    var id: UUID
    var original: String
    var replacement: String

    /// Other things the user might say for the same result. Whisper is not consistent about
    /// "open quote" versus "opening quote" versus "quote", and making someone add a whole row
    /// per phrasing means retyping the replacement every time.
    var alternates: [String]
    var spacing: Spacing

    init(id: UUID = UUID(), original: String = "", replacement: String = "",
         alternates: [String] = [], spacing: Spacing = .standalone) {
        self.id = id
        self.original = original
        self.replacement = replacement
        self.alternates = alternates
        self.spacing = spacing
    }

    /// Hand-written so dictionaries saved before `alternates` and `spacing` existed still load;
    /// the synthesised decoder would throw on the missing keys and drop every entry.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        original = try container.decode(String.self, forKey: .original)
        replacement = try container.decode(String.self, forKey: .replacement)
        alternates = try container.decodeIfPresent([String].self, forKey: .alternates) ?? []
        spacing = try container.decodeIfPresent(Spacing.self, forKey: .spacing) ?? .standalone
    }

    /// Every phrasing this rule matches, the primary one first.
    var triggers: [String] {
        ([original] + alternates)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Drops one phrasing, counting from the primary at 0.
    ///
    /// Removing the primary promotes the next one instead of blanking it: an entry with no
    /// primary but surviving alternates matches nothing, so the rule would look present in the
    /// editor while having quietly stopped working.
    mutating func removeTrigger(at position: Int) {
        if position == 0 {
            original = alternates.first ?? ""
            if !alternates.isEmpty { alternates.removeFirst() }
        } else if alternates.indices.contains(position - 1) {
            alternates.remove(at: position - 1)
        }
    }
}

enum CustomDictionary {

    /// Applies the user's dictionary replacements to a transcription.
    ///
    /// Matching is case-insensitive and constrained to word boundaries so that
    /// substrings inside larger words are left untouched (e.g. a rule for "cat"
    /// will not touch "category"). The replacement string is inserted verbatim,
    /// preserving the casing the user typed.
    static func apply(_ text: String, entries: [CustomDictionaryEntry]) -> String {
        guard !text.isEmpty, !entries.isEmpty else { return text }

        var result = text
        for entry in entries {
            let replacement = entry.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip incomplete rows. A row with no trigger has nothing to match; an empty
            // `replacement` would silently DELETE every occurrence from the output — a natural
            // intermediate state when the user has filled "Heard" but not yet "Replace with".
            // Both are treated as no-ops rather than data loss.
            guard !replacement.isEmpty else { continue }

            // Longest first, so "opening quote" isn't half-eaten by a "quote" alternate on the
            // same rule.
            for trigger in entry.triggers.sorted(by: { $0.count > $1.count }) {
                let escaped = NSRegularExpression.escapedPattern(for: trigger)
                // Only add a \b assertion where the adjacent character of the search
                // term is itself a word character — otherwise the boundary never
                // matches for terms that start/end with punctuation (e.g. "C++").
                let leadingBoundary = isWordCharacter(trigger.first) ? "\\b" : ""
                let trailingBoundary = isWordCharacter(trigger.last) ? "\\b" : ""

                // Punctuation has to swallow the space on the side it belongs to, or an opening
                // quote lands as `he said " hello`. Only horizontal space is eaten: a rule must
                // not silently pull two paragraphs together.
                let eatBefore = entry.spacing == .attachesLeft ? "[ \\t]*" : ""
                let eatAfter = entry.spacing == .attachesRight ? "[ \\t]*" : ""
                let pattern = eatBefore + leadingBoundary + escaped + trailingBoundary + eatAfter

                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                else { continue }

                let range = NSRange(result.startIndex..., in: result)
                // Use the trimmed replacement (consistent with promptBoost) so a stray leading/
                // trailing space in the rule doesn't produce double spaces in the output.
                let template = NSRegularExpression.escapedTemplate(for: replacement)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range,
                                                        withTemplate: template)
            }
        }
        return result
    }

    /// Everything the dictionary does to finished text: the user's exact phrasings, then the
    /// sound-alike pass for words nobody listed a phrasing for (`SoundAlike`).
    static func correct(_ text: String, entries: [CustomDictionaryEntry],
                        soundAlikes: Bool) -> String {
        let exact = apply(text, entries: entries)
        return soundAlikes ? SoundAlike.apply(exact, entries: entries) : exact
    }

    /// The rules that can run a second time without changing their own output.
    ///
    /// The dictionary runs again after LLM cleanup, because the cleanup model can put back a
    /// spelling the dictionary already fixed. A rule whose result contains its own trigger
    /// ("noah" → "Noah Kagan") would grow on every pass, so it only ever runs once.
    static func reapplicable(_ entries: [CustomDictionaryEntry]) -> [CustomDictionaryEntry] {
        entries.filter { entry in
            let replacement = entry.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            return apply(replacement, entries: [entry]) == replacement
        }
    }

    /// Adds a correction taught from a transcript ("Clavio" should be "Klaviyo"), folded into
    /// the rule that already writes that spelling if there is one.
    static func teaching(heard: String, correct: String,
                         to entries: [CustomDictionaryEntry]) -> [CustomDictionaryEntry] {
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let correct = correct.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty, !correct.isEmpty, heard != correct else { return entries }
        return merged(entries + [CustomDictionaryEntry(original: heard, replacement: correct)])
    }

    /// The distinct words of a transcript, in order, for picking the one that came out wrong.
    static func pickableWords(in text: String, limit: Int = 80) -> [String] {
        var seen = Set<String>()
        var words: [String] = []
        for raw in text.split(whereSeparator: { $0.isWhitespace }) {
            // Keep inner apostrophes and hyphens ("Klaviyo's", "e-mail"), drop the punctuation
            // a sentence puts around a word.
            let word = raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            guard word.rangeOfCharacter(from: .letters) != nil,
                  seen.insert(word.lowercased()).inserted else { continue }
            words.append(word)
            if words.count == limit { break }
        }
        return words
    }

    /// Folds rules that write the same thing into one.
    ///
    /// Before a rule could hold several phrasings, saying a thing three ways meant three rows
    /// all writing "My Monkey". The badge editor then showed three identical badges, which is
    /// the same information presented as clutter. Merging is lossless: every phrasing survives
    /// as an alternate of the rule that keeps them.
    ///
    /// Spacing is part of the key, since an opening and a closing quote write the same character
    /// while pulling opposite ways. Rules with no replacement yet are left alone: they are rows
    /// someone is still filling in, and collapsing them would delete work in progress.
    static func merged(_ entries: [CustomDictionaryEntry]) -> [CustomDictionaryEntry] {
        struct Key: Hashable {
            let replacement: String
            let spacing: CustomDictionaryEntry.Spacing
        }

        var result: [CustomDictionaryEntry] = []
        var positionByKey: [Key: Int] = [:]

        for entry in entries {
            let replacement = entry.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !replacement.isEmpty else {
                result.append(entry)
                continue
            }

            let key = Key(replacement: replacement, spacing: entry.spacing)
            guard let position = positionByKey[key] else {
                positionByKey[key] = result.count
                result.append(entry)
                continue
            }

            for trigger in entry.triggers
            where !result[position].triggers.contains(where: {
                $0.caseInsensitiveCompare(trigger) == .orderedSame
            }) {
                result[position].alternates.append(trigger)
            }
        }

        return result
    }

    /// The de-duplicated list of replacement terms (the "correct" forms). This is
    /// the single source of the words we boost on both engines: Whisper via the
    /// initial prompt (`promptBoost`) and Parakeet via custom-vocabulary boosting
    /// (`FluidAudioEngine`). Order is preserved; de-duplication is case-insensitive.
    static func boostTerms(entries: [CustomDictionaryEntry]) -> [String] {
        var seen = Set<String>()
        return entries
            .map { $0.replacement.trimmingCharacters(in: .whitespacesAndNewlines) }
            // Punctuation rules ("open quote" → `"`) have nothing to teach a model about
            // spelling, and boosting a bare quote mark would just litter the prompt.
            .filter { $0.rangeOfCharacter(from: .alphanumerics) != nil }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    /// Builds an initial-prompt fragment from the dictionary's replacement terms
    /// so a prompt-conditioned model (Whisper) is biased toward producing the
    /// correct spelling in the first place.
    static func promptBoost(entries: [CustomDictionaryEntry]) -> String {
        boostTerms(entries: entries).joined(separator: ", ")
    }

    private static func isWordCharacter(_ character: Character?) -> Bool {
        guard let character = character else { return false }
        return character.isLetter || character.isNumber || character == "_"
    }
}
