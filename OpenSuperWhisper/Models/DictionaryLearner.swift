import Foundation

/// Decides whether an edit the user made to a fresh dictation is a spelling Rhino should learn.
///
/// The user dictates "we use Apsumo daily", then fixes it to "we use AppSumo daily" in the
/// app. That one-word swap is a dictionary rule they would otherwise have to add by hand. Any
/// misspelling the user corrects is learned (names, and lowercase words like "kubernets" →
/// "kubernetes"), as long as the edit looks like fixing a mishearing rather than rewriting:
///   - it is one word for one word, or two spoken words joined into one that isn't an ordinary
///     word ("Tidy Cal" → "TidyCal"; never "any way" → "anyway"); anything else is a rewrite
///   - the new word has at least `minimumLength` letters
///   - for a one-for-one swap, the two are close in spelling (sound-alike letters free, as in
///     `SoundAlike`), and the new one isn't just the old one plus a plural or possessive
///   - a real word is never changed into a non-word ("going" → "goin" is slang or a typo), and an
///     ordinary word never into a name ("mark" → "Marc" would rewrite every "mark")
///   - real word → real word only when they differ in the opening consonants alone
///     (`onlyOnsetDiffers`: "shatter" → "chatter", not "ran" → "run" or "form" → "from"), and
///     never for short grammar words (`neverRewritten`)
///   - changing only sentence-position capitals ("Hello" → "hello") is not a correction
/// An ordinary word fixed at a sentence start is saved lowercase ("Shatter" → "Chatter" teaches
/// "shatter" → "chatter"); `CustomDictionary.fittingCase` capitalizes it at a sentence start.
/// Names keep the case typed.
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
    ///   - isRealWord: the word list check, any case (injected for tests).
    ///   - isCommonWord: in the word list as an ordinary lowercase word, not only as a name.
    ///   - atSentenceStart: the stretch begins a sentence (start of field or after . ! ?).
    static func correction(inserted: [String], edited: [String], trailingOpen: Bool,
                           atSentenceStart: Bool = false,
                           isRealWord: (String) -> Bool = SystemWordList.contains,
                           isCommonWord: (String) -> Bool = SystemWordList.isCommonWord) -> Correction? {
        let spoken = inserted.map(clean).filter { !$0.isEmpty }
        let raw = edited.filter { !clean($0).isEmpty }
        guard !spoken.isEmpty else { return nil }
        if trailingOpen {
            // Try the stretch as long as the dictation (a swap), then one word shorter (a join).
            for length in [spoken.count, spoken.count - 1] where length > 0 && raw.count >= length {
                if let found = aligned(spoken, Array(raw.prefix(length)), atSentenceStart, isRealWord, isCommonWord) {
                    return found
                }
            }
            return nil
        }
        return aligned(spoken, raw, atSentenceStart, isRealWord, isCommonWord)
    }

    private static func aligned(_ spoken: [String], _ raw: [String], _ atSentenceStart: Bool,
                                _ isRealWord: (String) -> Bool,
                                _ isCommonWord: (String) -> Bool) -> Correction? {
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
            let realA = isRealWord(a), realB = isRealWord(b)
            // A real word changed into a non-word is the user's own typo or slang ("going" → "goin").
            if realA, !realB { return nil }
            // An ordinary word turned into a name ("mark" → "Marc") would rewrite the ordinary
            // word everywhere.
            if realA, isCommonWord(a), correct.contains(where: \.isUppercase), !isCommonWord(b) {
                return nil
            }
            if realA, realB {
                guard !neverRewritten.contains(a), onlyOnsetDiffers(a, b) else { return nil }
            }
        case 2:
            // A join: the two spoken words spell the new one, and it isn't an ordinary word.
            // "any way" → "anyway" or "may be" → "maybe" is right in one sentence and wrong in
            // the next ("is there any way").
            guard (heard[0] + heard[1]).lowercased() == correct.lowercased(),
                  !isRealWord(correct) else { return nil }
            wrong = heard.joined(separator: " ")
        default:
            return nil
        }
        // A sentence-start capital on an ordinary word belongs to the sentence, not the word.
        // Names keep their capital ("John" is in the list only as a name).
        if startsSentence, innerCapitals(correct).isEmpty, isCommonWord(correct) {
            correct = correct.lowercased()
            if innerCapitals(wrong).isEmpty, isCommonWord(wrong) || !isRealWord(wrong) {
                wrong = wrong.lowercased()
            }
        }
        guard wrong != correct else { return nil }
        return Correction(heard: wrong, correct: correct)
    }

    /// Two real words that differ only in the consonants before the first vowel, same length,
    /// and sound alike there: "shatter" → "chatter" is a mishearing; "fast" → "last" is not. A different vowel ("ran" → "run", "man" → "men"),
    /// moved letters ("form" → "from"), a changed ending ("advice" → "advise") or an added
    /// letter ("three" → "tree") is a different word the user chose.
    static func onlyOnsetDiffers(_ a: String, _ b: String) -> Bool {
        let a = Array(a.lowercased()), b = Array(b.lowercased())
        guard a.count == b.count, a != b else { return false }
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        guard let firstVowel = a.firstIndex(where: vowels.contains),
              b.firstIndex(where: vowels.contains) == firstVowel else { return false }
        return a[firstVowel...] == b[firstVowel...]
            && SoundAlike.skeleton(String(a)) == SoundAlike.skeleton(String(b))
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

    /// Counts how many polls in a row read the same correction. A word the user paused on
    /// mid-typing changes between polls, so it never reaches the count.
    struct Stability {
        private(set) var pending: Correction?
        private(set) var count = 0

        /// Records one poll; true once `found` has read the same `required` polls in a row.
        mutating func observe(_ found: Correction?, required: Int) -> Bool {
            guard let found else {
                pending = nil
                count = 0
                return false
            }
            if found == pending {
                count += 1
            } else {
                pending = found
                count = 1
            }
            return count >= required
        }
    }
}
