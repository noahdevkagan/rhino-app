import Foundation

/// A saved phrase the user can dictate to get a block of text: "my calendar link" →
/// `https://cal.com/noah/30min`, "my address" → a multi-line address.
struct Snippet: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    /// What the user says. Matched loosely (see `Snippets.normalize`).
    var trigger: String = ""
    /// What lands in the document, exactly as typed, newlines included.
    var expansion: String = ""
}

/// Matching for snippets.
///
/// v1 only expands a dictation that is the trigger and nothing else. The speech engine
/// decorates even a short phrase ("My calendar link."), so both sides are compared after
/// `normalize`. Inline expansion inside a longer sentence is deliberately not done; see
/// decisions.md (2026-11-11).
enum Snippets {

    /// Case-, punctuation- and spacing-insensitive form of a phrase: lowercased, diacritics
    /// folded, every run of non-letter/non-digit characters collapsed to one space, trimmed.
    /// "  My calendar-link. " and "my calendar link" both become "my calendar link".
    /// Straight and curly apostrophes alike split a word ("noah's" → "noah s") on both sides,
    /// so they still match each other.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX")).lowercased()
        var words: [String] = []
        var current = ""
        for ch in folded {
            if ch.isLetter || ch.isNumber {
                current.append(ch)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        return words.joined(separator: " ")
    }

    /// The snippet whose trigger the whole `text` is, or nil. Snippets with an empty trigger
    /// or an empty expansion never match. With duplicate triggers the first one wins.
    static func match(_ text: String, in snippets: [Snippet]) -> Snippet? {
        let spoken = normalize(text)
        guard !spoken.isEmpty else { return nil }
        return snippets.first { snippet in
            !snippet.expansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && normalize(snippet.trigger) == spoken
        }
    }

    /// Snippets worth keeping on disk: drops rows where both fields are blank, so "Add
    /// snippet" then clicking away leaves nothing behind.
    static func pruned(_ snippets: [Snippet]) -> [Snippet] {
        snippets.filter {
            !$0.trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !$0.expansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
