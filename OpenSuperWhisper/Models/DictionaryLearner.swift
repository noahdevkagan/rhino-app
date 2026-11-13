import Foundation

/// Decides whether an edit the user made to a fresh dictation is a spelling Rhino should learn.
///
/// The user dictates "we use Apsumo daily", then fixes it to "we use AppSumo daily" in the
/// app. That one-word swap is a dictionary rule they would otherwise have to add by hand. Any
/// word the user corrects is learned (names, lowercase words like "kubernets" → "kubernetes",
/// and real words the recognizer swapped like "shatter" → "chatter"), as long as the edit looks
/// like fixing a word rather than rewriting the sentence:
///   - it is one word for one word, or two spoken words joined into one ("Tidy Cal" → "TidyCal",
///     "any way" → "anyway"); any other change to the words is a rewrite, not a spelling fix
///   - the new word has at least `minimumLength` letters
///   - for a one-for-one swap, the two are close in spelling (sound-alike letters free, as in
///     `SoundAlike`), and the new one isn't just the old one plus a plural or possessive
///     ("Klaviyo" → "Klaviyo's" is grammar, not spelling)
///   - when both words are real words, they also sound alike (same `SoundAlike.skeleton`) and
///     the heard one isn't a short grammar word (`neverRewritten`): "shatter" → "chatter" is a
///     mishearing, "fast" → "last" or "the" → "they" is the user changing what they said, and a
///     rule would rewrite every future "the"
///   - changing only sentence-position capitals ("Hello" → "hello") is not a correction
/// A capital that is only there because the word starts a sentence is not kept in the rule
/// when the new word is a real word ("Shatter" → "Chatter" teaches "shatter" → "chatter"), so it
/// stays lowercase mid-sentence; `CustomDictionary.fittingCase` capitalizes it at a sentence start.
/// Pure logic; `DictionaryAutoLearn` reads the field and calls this.
enum DictionaryLearner {
    struct Correction: Equatable {
        let heard: String
        let correct: String
    }

    /// The new word must have at least this many letters.
    static let minimumLength = 3

    /// - Parameters:
    ///   - inserted: the words Rhino typed.
    ///   - edited: the same stretch of the field now. When `trailingOpen`, the field had nothing
    ///     after the dictation, so the user may have kept typing; extra trailing words are ignored.
    ///   - isRealWord: the word list check (injected for tests).
    ///   - atSentenceStart: the stretch begins a sentence (start of field or after . ! ?).
    static func correction(inserted: [String], edited: [String], trailingOpen: Bool,
                           atSentenceStart: Bool = false,
                           isRealWord: (String) -> Bool = SystemWordList.contains) -> Correction? {
        let spoken = inserted.map(clean).filter { !$0.isEmpty }
        let raw = edited.filter { !clean($0).isEmpty }
        guard !spoken.isEmpty else { return nil }
        if trailingOpen {
            // Try the stretch as long as the dictation (a swap), then one word shorter (a join).
            for length in [spoken.count, spoken.count - 1] where length > 0 && raw.count >= length {
                if let found = aligned(spoken, Array(raw.prefix(length)), atSentenceStart, isRealWord) {
                    return found
                }
            }
            return nil
        }
        return aligned(spoken, raw, atSentenceStart, isRealWord)
    }

    private static func aligned(_ spoken: [String], _ raw: [String], _ atSentenceStart: Bool,
                                _ isRealWord: (String) -> Bool) -> Correction? {
        let written = raw.map(clean)
        var head = 0
        while head < min(spoken.count, written.count), same(spoken[head], written[head]) { head += 1 }
        var tail = 0
        while tail < min(spoken.count, written.count) - head,
              same(spoken[spoken.count - 1 - tail], written[written.count - 1 - tail]) { tail += 1 }
        let heard = Array(spoken[head..<(spoken.count - tail)])
        let typed = Array(written[head..<(written.count - tail)])
        guard typed.count == 1, var correct = typed.first, correct.count >= minimumLength else { return nil }
        let startsSentence = head == 0
            ? atSentenceStart
            : raw[head - 1].last.map { ".!?".contains($0) } ?? false

        var wrong: String
        switch heard.count {
        case 1:
            wrong = heard[0]
            let a = wrong.lowercased(), b = correct.lowercased()
            guard !isPluralOrPossessive(a, of: b), !isPluralOrPossessive(b, of: a) else { return nil }
            guard SoundAlike.editDistance(a, b) <= max(2, b.count / 3) else { return nil }
            if isRealWord(a), isRealWord(b) {
                guard a.count >= minimumLength, !neverRewritten.contains(a),
                      SoundAlike.skeleton(a) == SoundAlike.skeleton(b) else { return nil }
            }
        case 2:
            // A join: the two spoken words spell the new one.
            guard (heard[0] + heard[1]).lowercased() == correct.lowercased() else { return nil }
            wrong = heard.joined(separator: " ")
        default:
            return nil
        }
        // A sentence-start capital on a real word belongs to the sentence, not the word.
        if startsSentence, innerCapitals(correct).isEmpty, isRealWord(correct) {
            correct = correct.lowercased()
            if innerCapitals(wrong).isEmpty {
                wrong = wrong.lowercased()
            }
        }
        guard wrong != correct else { return nil }
        return Correction(heard: wrong, correct: correct)
    }

    /// Short grammar words a recognizer confuses with each other. The right one depends on the
    /// sentence, so a rule always rewriting one into another would be wrong as often as right.
    static let neverRewritten: Set<String> = [
        "the", "they", "then", "than", "that", "this", "these", "those", "there", "their",
        "they're", "theyre", "your", "you're", "youre", "its", "it's", "were", "where", "we're",
        "wear", "whether", "weather", "to", "too", "two", "of", "off", "our", "are",
        "hour", "and", "an", "in", "on", "a", "is", "as", "at", "it", "be", "been", "being",
        "have", "has", "had", "was", "will", "would", "could", "should", "can", "can't", "cant",
        "don't", "dont", "won't", "wont", "here", "hear", "know", "no", "now", "new", "knew",
        "who's", "whose", "lose", "loose", "accept", "except", "affect", "effect",
    ]

    private static func isPluralOrPossessive(_ word: String, of base: String) -> Bool {
        ["s", "es", "'s"].contains { word == base + $0 }
    }

    /// Words match ignoring case, unless the user added capitals inside the word ("Appsumo" →
    /// "AppSumo" is a fix; "Hello" → "hello" is only the sentence position changing).
    private static func same(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        return a.lowercased() == b.lowercased() && innerCapitals(a) == innerCapitals(b)
    }

    private static func innerCapitals(_ word: String) -> String {
        String(word.dropFirst().filter(\.isUppercase))
    }

    /// Strips punctuation at the edges ("AppSumo." → "AppSumo"), keeps inner apostrophes.
    static func clean(_ word: String) -> String {
        word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }

    /// Splits field text into words the same way for the dictation and the field.
    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
}
