import Foundation

/// Decides whether an edit the user made to a fresh dictation is a spelling Rhino should learn.
///
/// The user dictates "we use Apsumo daily", then fixes it to "we use AppSumo daily" in the
/// app. That one-word swap is a dictionary rule they would otherwise have to add by hand.
/// Most edits are not that: rewording, a different word, a typo of their own. So a swap
/// is learned only when all of these hold:
///   - it is one word for one word, or two spoken words joined into one ("Tidy Cal" → "TidyCal");
///     any other change to the words is a rewrite, not a spelling fix
///   - the new spelling is a name or brand (has a capital letter) — "their" → "there" must never
///     become a rule that rewrites every "their"
///   - for a one-for-one swap, the word Rhino typed is not a real word and the two are close
///     in spelling (sound-alike letters free, as in `SoundAlike`)
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
    static func correction(inserted: [String], edited: [String], trailingOpen: Bool,
                           isRealWord: (String) -> Bool = SystemWordList.contains) -> Correction? {
        let spoken = inserted.map(clean).filter { !$0.isEmpty }
        let written = edited.map(clean).filter { !$0.isEmpty }
        guard !spoken.isEmpty else { return nil }
        if trailingOpen {
            // Try the stretch as long as the dictation (a swap), then one word shorter (a join).
            for length in [spoken.count, spoken.count - 1] where length > 0 && written.count >= length {
                if let found = aligned(spoken, Array(written.prefix(length)), isRealWord) { return found }
            }
            return nil
        }
        return aligned(spoken, written, isRealWord)
    }

    private static func aligned(_ spoken: [String], _ written: [String],
                                _ isRealWord: (String) -> Bool) -> Correction? {
        var head = 0
        while head < min(spoken.count, written.count), same(spoken[head], written[head]) { head += 1 }
        var tail = 0
        while tail < min(spoken.count, written.count) - head,
              same(spoken[spoken.count - 1 - tail], written[written.count - 1 - tail]) { tail += 1 }
        let heard = Array(spoken[head..<(spoken.count - tail)])
        let typed = Array(written[head..<(written.count - tail)])
        guard typed.count == 1, let correct = typed.first,
              correct.count >= minimumLength, correct.contains(where: \.isUppercase) else { return nil }

        switch heard.count {
        case 1:
            let wrong = heard[0]
            guard !isRealWord(wrong) else { return nil }
            let a = wrong.lowercased(), b = correct.lowercased()
            guard a != b || wrong != correct else { return nil }
            guard SoundAlike.editDistance(a, b) <= max(2, b.count / 3) else { return nil }
            return Correction(heard: wrong, correct: correct)
        case 2:
            // A join: the two spoken words spell the new one.
            guard (heard[0] + heard[1]).lowercased() == correct.lowercased() else { return nil }
            return Correction(heard: heard.joined(separator: " "), correct: correct)
        default:
            return nil
        }
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
