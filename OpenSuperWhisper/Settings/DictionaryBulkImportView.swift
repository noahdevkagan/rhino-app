import SwiftUI

struct DictionaryBulkImportView: View {
    @Binding var entries: [CustomDictionaryEntry]
    let onSaved: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var rows: [CustomDictionaryEntry] = []
    @State private var reviewing = false
    @State private var error: String?
    @FocusState private var pasteFocused: Bool

    private var soundAlikes: Bool { AppPreferences.shared.customDictionarySoundAlikesEnabled }
    private var problems: [UUID: String] {
        Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            DictionaryBulkImport.problem(for: row, rows: rows, existing: entries,
                                         soundAlikes: soundAlikes).map { (row.id, $0) }
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Add multiple words")
                    .scaledFont(size: 22, weight: .semibold)
                    .foregroundColor(STheme.textBright)
                HStack(spacing: 12) {
                    Text("1  Paste").foregroundColor(reviewing ? STheme.hint : STheme.textBright)
                    Image(systemName: "chevron.right").scaledFont(size: 9)
                    Text("2  Review corrections").foregroundColor(reviewing ? STheme.textBright : STheme.hint)
                }
                .scaledFont(size: 11, weight: .medium)
                .foregroundColor(STheme.hint)
            }
            .padding(22)
            Divider().overlay(STheme.border)
            if reviewing { review } else { paste }
            Divider().overlay(STheme.border)
            footer.padding(18)
        }
        .frame(width: 580, height: 570)
        .background(STheme.windowBg)
        .onAppear { pasteFocused = true }
    }

    private var paste: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste words or phrases, one per line.")
                .scaledFont(size: 14, weight: .medium)
                .foregroundColor(STheme.textBright)
            Text("You can also copy two columns from a spreadsheet: correct spelling, then how Rhino hears it. Leave out the column headings.")
                .scaledFont(size: 12)
                .foregroundColor(STheme.hint)
                .fixedSize(horizontal: false, vertical: true)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .scaledFont(size: 14)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .focused($pasteFocused)
                    .accessibilityLabel("Words to add")
                    // The error names a line number, which the next keystroke can invalidate.
                    .onChange(of: text) { _, _ in error = nil }
                if text.isEmpty {
                    Text("Klaviyo\nAcme Labs\nJo")
                        .scaledFont(size: 14)
                        .foregroundColor(STheme.hint.opacity(0.7))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .background(STheme.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(STheme.controlBorder))
            Text("You’ll review how each word is corrected before saving.")
                .scaledFont(size: 11)
                .foregroundColor(STheme.hint)
            if let error {
                Text(error).scaledFont(size: 12).foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Paste error: \(error)")
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity)
    }

    private var review: some View {
        let issues = problems
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add the spelling Rhino gets wrong if you know it. Otherwise, Rhino can try close sound-alikes for longer, single words.")
                    .scaledFont(size: 12)
                    .foregroundColor(STheme.hint)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text("Correct spelling").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Rhino hears it as (optional)").frame(maxWidth: .infinity, alignment: .leading)
                }
                .scaledFont(size: 11, weight: .medium)
                .foregroundColor(STheme.hint)
                ForEach(rows) { row in
                    reviewRow(stableDictionaryEntryBinding(entries: $rows, fallback: row), issue: issues[row.id])
                }
                Text(soundAlikes
                     ? "Short names and phrases need a “hears it as” entry. Duplicates are skipped; existing corrections are kept."
                     : "Sound-alike fixing is off. Add how Rhino spells each new word now, or enable it in Settings → Output.")
                    .scaledFont(size: 11)
                    .foregroundColor(STheme.hint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .frame(maxHeight: .infinity)
    }

    private func reviewRow(_ row: Binding<CustomDictionaryEntry>, issue: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("Correct spelling", text: row.replacement)
                    .accessibilityLabel("Correct spelling")
                TextField("Optional mishearing", text: row.original)
                    .accessibilityLabel("Rhino hears \(row.wrappedValue.replacement) as")
            }
            .textFieldStyle(.roundedBorder)
            .scaledFont(size: 13)
            Text(issue ?? explanation(for: row.wrappedValue))
                .scaledFont(size: 11)
                .foregroundColor(issue == nil ? STheme.hint : .orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(STheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(STheme.border))
    }

    private func explanation(for row: CustomDictionaryEntry) -> String {
        let heard = row.original.trimmingCharacters(in: .whitespacesAndNewlines)
        if !heard.isEmpty { return "Replaces “\(heard)” with “\(row.replacement.trimmingCharacters(in: .whitespacesAndNewlines))”." }
        if DictionaryBulkImport.merge([row], into: entries).added == 0 {
            return "Already in your dictionary — existing corrections are kept."
        }
        return "Tries close sound-alikes. Add a mishearing if Rhino still gets it wrong."
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            if reviewing {
                Button("Back") {
                    text = rows.map { $0.replacement + ($0.original.isEmpty ? "" : "\t" + $0.original) }
                        .joined(separator: "\n")
                    reviewing = false
                    pasteFocused = true
                }
            }
            Spacer()
            if reviewing {
                let issues = problems
                let result = DictionaryBulkImport.merge(rows, into: entries)
                Text(issues.isEmpty
                     ? "\(rows.count) ready"
                     : "\(issues.count) \(issues.count == 1 ? "needs" : "need") a correction")
                    .scaledFont(size: 11).foregroundColor(STheme.hint)
                Button(result.added == 0 ? "Save words" : "Add \(result.added) \(result.added == 1 ? "word" : "words")") {
                    guard problems.isEmpty else { return }
                    let saved = DictionaryBulkImport.merge(rows, into: entries)
                    entries = saved.entries
                    // Some owners save through onChange on the next view update.
                    // Persist before notifying other open dictionary editors.
                    AppPreferences.shared.customDictionaryEntries = saved.entries
                    NotificationCenter.default.post(name: .customDictionaryDidChange, object: nil)
                    onSaved(saved.summary)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(rows.isEmpty || !issues.isEmpty)
            } else {
                Button("Review words") {
                    do {
                        rows = try DictionaryBulkImport.parse(text)
                        error = nil
                        pasteFocused = false
                        reviewing = true
                    } catch { self.error = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
