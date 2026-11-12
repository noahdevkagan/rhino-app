import Foundation

/// A saved phrase the user can dictate to get a block of text: "my calendar link" →
/// `https://cal.com/noah/30min`, "my address" → a multi-line address.
struct Snippet: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    /// What the user says. Matched loosely (see `Snippets.normalize`).
    var trigger: String = ""
    /// What lands in the document, exactly as typed, newlines included.
    var expansion: String = ""

    init(id: UUID = UUID(), trigger: String = "", expansion: String = "") {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
    }

    /// Tolerant: a missing or malformed field gets its default instead of failing the row,
    /// so a hand-edited or older/newer stored list still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        trigger = (try? c.decodeIfPresent(String.self, forKey: .trigger)) ?? ""
        expansion = (try? c.decodeIfPresent(String.self, forKey: .expansion)) ?? ""
    }

    /// Has both a trigger and an expansion, so it can fire.
    var isUsable: Bool {
        !Snippets.normalize(trigger).isEmpty
            && !expansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
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

    /// The snippet whose trigger the whole `text` is, or nil. Only usable snippets (trigger
    /// and expansion both filled in) match; among those the first in the list wins.
    ///
    /// `transcriptForm` turns a typed trigger into what the transcript would look like by the
    /// time it gets here (the dictionary, number formatting, British spelling all ran on the
    /// transcript), so "room two" still matches a transcript of "room 2". The trigger matches
    /// in either its typed or its transformed form.
    static func match(_ text: String, in snippets: [Snippet],
                      transcriptForm: (String) -> String = { $0 }) -> Snippet? {
        let spoken = normalize(text)
        guard !spoken.isEmpty else { return nil }
        return snippets.first { snippet in
            snippet.isUsable
                && (normalize(snippet.trigger) == spoken
                    || normalize(transcriptForm(snippet.trigger)) == spoken)
        }
    }

    /// The earlier usable snippet with the same trigger that takes precedence over `snippet`,
    /// or nil when `snippet` itself would be the one used. The editor's duplicate warning uses
    /// this, so it states the same rule `match` applies.
    static func shadowing(_ snippet: Snippet, in snippets: [Snippet]) -> Snippet? {
        let key = normalize(snippet.trigger)
        guard !key.isEmpty else { return nil }
        for other in snippets {
            if other.id == snippet.id { return nil }
            if other.isUsable && normalize(other.trigger) == key { return other }
        }
        return nil
    }

    /// Snippets worth keeping on disk: drops rows where both fields are blank, so "Add
    /// snippet" then clicking away leaves nothing behind.
    static func pruned(_ snippets: [Snippet]) -> [Snippet] {
        snippets.filter {
            !$0.trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !$0.expansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Storage

    /// Result of reading the stored list. `lossless` is false when the data was there but
    /// some or all of it could not be read; the caller must then not overwrite it blindly.
    struct Decoded: Equatable {
        var snippets: [Snippet]
        var lossless: Bool
    }

    /// Decodes each row on its own, so one bad row costs that row, not the whole list.
    static func decode(_ data: Data?) -> Decoded {
        guard let data else { return Decoded(snippets: [], lossless: true) }
        guard let rows = try? JSONDecoder().decode([LossyRow].self, from: data) else {
            return Decoded(snippets: [], lossless: false)
        }
        let snippets = rows.compactMap(\.snippet)
        return Decoded(snippets: snippets, lossless: snippets.count == rows.count)
    }

    private struct LossyRow: Decodable {
        let snippet: Snippet?
        init(from decoder: Decoder) throws {
            snippet = try? Snippet(from: decoder)
        }
    }
}
