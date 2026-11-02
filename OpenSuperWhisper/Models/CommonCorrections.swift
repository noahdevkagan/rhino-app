import Foundation

/// Fixes many people taught Rhino, shipped in the app bundle (`CommonCorrections.json`).
///
/// The weekly improvement loop (`.github/workflows/improve-weekly.yml`) merges "Fix a word" pairs
/// that people on at least three different Macs shared through the opt-in "Help improve accuracy"
/// (CorrectionReporter), so the next release mishears them less for everyone. Applying them is
/// purely local: the list is read from the bundle, never fetched.
///
/// Runs before the user's own dictionary, and drops any bundled rule whose phrasing the user
/// already has a rule for — someone who taught "Clavio" → "Claudio" must never get "Klaviyo".
enum CommonCorrections {
    struct File: Decodable {
        let version: Int
        let entries: [Pair]
    }

    struct Pair: Decodable, Equatable {
        let heard: String
        let corrected: String
    }

    /// The bundled list as dictionary rules. Loaded once.
    static let entries: [CustomDictionaryEntry] = load()

    static func load(bundle: Bundle = .main) -> [CustomDictionaryEntry] {
        guard let url = bundle.url(forResource: "CommonCorrections", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return entries(fromJSON: data)
    }

    static func entries(fromJSON data: Data) -> [CustomDictionaryEntry] {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        let rules = file.entries.compactMap { pair -> CustomDictionaryEntry? in
            let heard = pair.heard.trimmingCharacters(in: .whitespacesAndNewlines)
            let corrected = pair.corrected.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !heard.isEmpty, !corrected.isEmpty, heard != corrected else { return nil }
            return CustomDictionaryEntry(original: heard, replacement: corrected)
        }
        // Only rules that are safe to run twice: the dictionary pass runs again after cleanup.
        return CustomDictionary.reapplicable(CustomDictionary.merged(rules))
    }

    /// The bundled rules minus any whose phrasing the user's own dictionary already covers.
    static func applicable(_ bundled: [CustomDictionaryEntry],
                           excluding user: [CustomDictionaryEntry]) -> [CustomDictionaryEntry] {
        guard !user.isEmpty else { return bundled }
        let taken = Set(user.flatMap { $0.triggers.map { $0.lowercased() } })
        return bundled.compactMap { entry in
            var entry = entry
            let kept = entry.triggers.filter { !taken.contains($0.lowercased()) }
            guard let first = kept.first else { return nil }
            entry.original = first
            entry.alternates = Array(kept.dropFirst())
            return entry
        }
    }

    static func apply(_ text: String, userEntries: [CustomDictionaryEntry],
                      bundled: [CustomDictionaryEntry] = entries) -> String {
        guard !bundled.isEmpty else { return text }
        return CustomDictionary.apply(text, entries: applicable(bundled, excluding: userEntries))
    }
}
