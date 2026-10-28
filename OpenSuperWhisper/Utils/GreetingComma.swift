import Foundation

/// Removes the comma the speech engines put between a greeting and a name: "Hi, Steve" →
/// "Hi Steve", "Thanks, Steve." → "Thanks Steve.". Parakeet and Whisper punctuate the
/// vocative by the book; people writing messages mostly don't, and the cleanup model's own
/// examples already lay greetings out as "Hi Sarah," (Steve, 2026-10-28: "drives me mad").
/// Runs on every dictation unless `greetingCommaEnabled` is on.
///
/// Only a greeting that opens a sentence or line counts, and only a comma followed by a name
/// (a capitalized word that isn't a common sentence opener) or a group word ("everyone").
/// "Thanks, I'll check" and "Hi, how are you" keep their commas.
enum GreetingComma {

    /// Greetings and thanks, longest first so "thank you so much" wins over "thank you".
    static let greetings: [String] = [
        "thank you so much", "thanks so much", "thanks again", "thank you", "many thanks",
        "good morning", "good afternoon", "good evening", "congratulations", "goodbye",
        "morning", "evening", "hello", "hiya", "thanks", "cheers", "congrats", "dear",
        "hey", "bye", "hi",
    ]

    /// Lowercase words after a greeting that address people, like a name does.
    private static let groupWords: Set<String> = [
        "everyone", "everybody", "all", "team", "guys", "folks", "both", "there",
    ]

    /// Capitalized words that start a new clause rather than name someone: "Thanks, I'll
    /// check", "Hi, The file is attached". Compared lowercased.
    private static let clauseOpeners: Set<String> = [
        "i", "i'm", "i'll", "i've", "i'd", "a", "an", "the", "this", "that", "these", "those",
        "it", "it's", "its", "we", "we're", "we'll", "we've", "you", "you're", "you'll",
        "you've", "your", "my", "our", "he", "she", "they", "they're", "there", "here", "what",
        "who", "why", "where", "when", "how", "will", "would", "can", "could", "should",
        "shall", "may", "might", "must", "just", "so", "and", "but", "or", "please", "let",
        "let's", "yes", "no", "not", "have", "has", "had", "is", "are", "was", "were", "do",
        "does", "did", "don't", "sorry", "hope", "got", "really", "great", "good", "see",
        "talk", "speak", "much", "again", "for", "in", "on", "at", "to", "as", "if", "very",
        "also", "thanks", "thank", "hi", "hello", "hey", "love", "looking", "appreciate",
        "catch", "enjoy", "take", "best", "kind", "warm", "regards", "okay", "ok", "well",
        "oh", "now", "then", "today", "tomorrow", "tonight", "nice", "glad", "happy",
    ]

    /// `text` with the greeting commas removed.
    static func apply(_ text: String) -> String {
        guard text.contains(",") else { return text }
        let alternation = greetings
            .map { phrase in
                phrase.split(separator: " ")
                    .map { NSRegularExpression.escapedPattern(for: String($0)) }
                    .joined(separator: "\\s+")
            }
            .joined(separator: "|")
        // 1: the greeting, at the start of the text, a line, or a sentence. 2: the comma and
        // the space after it. 3: the next word.
        let pattern = "(?:^|(?<=[.!?]\\s)|(?<=\\n))[ \\t]*((?i:\(alternation)))(,[ \\t]+)([\\p{L}][\\p{L}'’-]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return text
        }
        let ns = text as NSString
        var result = text as NSString
        // Back to front, so earlier ranges stay valid while later ones are edited.
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let word = ns.substring(with: match.range(at: 3))
            guard addressesSomeone(word) else { continue }
            result = result.replacingCharacters(in: match.range(at: 2), with: " ") as NSString
        }
        return result as String
    }

    /// A name ("Steve", "O'Brien") or a group ("everyone"), not the start of a new clause.
    static func addressesSomeone(_ word: String) -> Bool {
        if groupWords.contains(word) { return true }
        guard let first = word.first, first.isUppercase else { return false }
        return !clauseOpeners.contains(word.lowercased().replacingOccurrences(of: "’", with: "'"))
    }
}
