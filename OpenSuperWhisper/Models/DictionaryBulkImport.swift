import Foundation

/// A local paste importer. One column is the desired spelling; an optional second
/// tab-separated column is the current mishearing, as copied from a spreadsheet.
enum DictionaryBulkImport {
    enum ParseError: LocalizedError {
        case empty
        case columns(Int)
        case missingSpelling(Int)

        var errorDescription: String? {
            switch self {
            case .empty: return "Paste at least one word."
            case .columns(let line):
                return "Line \(line) has more than two columns. Paste the correct spelling, then how Rhino hears it."
            case .missingSpelling(let line):
                return "Line \(line) needs a correct spelling in the first column."
            }
        }
    }

    static func parse(_ text: String) throws -> [CustomDictionaryEntry] {
        let text = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var rows: [CustomDictionaryEntry] = []
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let columns = line.components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard columns.count <= 2 else { throw ParseError.columns(index + 1) }
            guard !columns[0].isEmpty else { throw ParseError.missingSpelling(index + 1) }
            rows.append(CustomDictionaryEntry(original: columns.count == 2 ? columns[1] : "",
                                              replacement: columns[0]))
        }
        guard !rows.isEmpty else { throw ParseError.empty }
        return rows
    }

    static func problem(for row: CustomDictionaryEntry, rows: [CustomDictionaryEntry],
                        existing: [CustomDictionaryEntry], soundAlikes: Bool) -> String? {
        let correct = row.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !correct.isEmpty else { return "Enter the correct spelling." }
        let heard = row.original.trimmingCharacters(in: .whitespacesAndNewlines)
        if !heard.isEmpty {
            if let conflict = (existing + rows).first(where: {
                $0.replacement.trimmingCharacters(in: .whitespacesAndNewlines) != correct
                    && $0.triggers.contains { $0.caseInsensitiveCompare(heard) == .orderedSame }
            }) {
                return "“\(heard)” already corrects to “\(conflict.replacement)”. Use a different mishearing."
            }
            return nil
        }
        // Re-pasting a word must not require re-entering its corrections, whether it is
        // already saved or another line of the same paste already carries the mishearing.
        if (existing + rows).contains(where: { $0.id != row.id && sameWord($0, row) }) { return nil }
        if SoundAlike.eligibleTerms([row]).isEmpty {
            return "Add how Rhino spells this now — short words and phrases need an exact match."
        }
        return soundAlikes ? nil : "Add how Rhino spells this now — sound-alike fixing is off in Settings → Output."
    }

    struct Result {
        let entries: [CustomDictionaryEntry]
        let added: Int
        let updated: Int
        let skipped: Int

        var summary: String {
            var parts: [String] = []
            if added > 0 { parts.append("Added \(added) \(added == 1 ? "word" : "words")") }
            if updated > 0 { parts.append("Updated \(updated) \(updated == 1 ? "word" : "words")") }
            if skipped > 0 { parts.append("Skipped \(skipped) \(skipped == 1 ? "duplicate" : "duplicates")") }
            return parts.joined(separator: " · ")
        }
    }

    static func merge(_ rows: [CustomDictionaryEntry], into existing: [CustomDictionaryEntry]) -> Result {
        var result = existing
        let existingIDs = Set(existing.map(\.id))
        var updatedIDs = Set<UUID>()
        var skipped = 0
        for row in rows {
            var row = row
            row.replacement = row.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            row.original = row.original.trimmingCharacters(in: .whitespacesAndNewlines)
            if let index = result.firstIndex(where: { sameWord($0, row) }) {
                let combined = CustomDictionary.merged([result[index], row])[0]
                if combined == result[index] {
                    skipped += 1
                } else {
                    result[index] = combined
                    if existingIDs.contains(combined.id) { updatedIDs.insert(combined.id) }
                }
            } else {
                result.append(row)
            }
        }
        return Result(entries: result, added: result.count - existing.count,
                      updated: updatedIDs.count, skipped: skipped)
    }

    private static func sameWord(_ lhs: CustomDictionaryEntry, _ rhs: CustomDictionaryEntry) -> Bool {
        lhs.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            == rhs.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            && lhs.spacing == rhs.spacing
    }
}
