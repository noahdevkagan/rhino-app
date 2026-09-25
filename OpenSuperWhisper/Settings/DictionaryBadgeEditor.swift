import SwiftUI

/// The custom dictionary as a row of badges, one per result.
///
/// It used to be a two-column table, one line per phrasing. That forced anyone who says a thing
/// three ways to write the result three times, and once rules could hold several phrasings the
/// table had nowhere to put them. What the user cares about is the short list of results they
/// have taught it; the phrasings that reach each one are a detail behind it.
struct DictionaryBadgeEditor: View {
    @Binding var entries: [CustomDictionaryEntry]

    @State private var editing: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 6) {
                ForEach(entries) { entry in
                    badge(for: entry)
                }
                addBadge
            }

            // The rule opens inside the card rather than in a popover. A popover anchored to a
            // badge near the bottom of the Settings sheet opened past the window edge and was
            // cut off, so people couldn't see what they were typing (Steven, 2026-09-25).
            if let id = editing, let value = entries.first(where: { $0.id == id }) {
                Divider().overlay(STheme.border)
                DictionaryRuleEditor(
                    entry: stableDictionaryEntryBinding(entries: $entries, fallback: value),
                    onDone: { close() },
                    onDelete: {
                        entries.removeAll { $0.id == id }
                        editing = nil
                    })
                    .id(id)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).fill(STheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(STheme.border, lineWidth: 1))
        .onDisappear { close() }
    }

    private func badge(for value: CustomDictionaryEntry) -> some View {
        let label = value.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        let triggers = value.triggers
        let selected = editing == value.id

        return Button { open(value.id) } label: {
            HStack(spacing: 5) {
                // With one phrasing the whole rule fits on the badge, so show it: seeing
                // "clavio → Klaviyo" says what the rule does without opening it.
                if triggers.count == 1, !label.isEmpty {
                    Text(triggers[0])
                        .scaledFont(size: 12)
                        .foregroundColor(STheme.hint)
                    Image(systemName: "arrow.right")
                        .scaledFont(size: 8, weight: .semibold)
                        .foregroundColor(STheme.hint)
                }
                Text(label.isEmpty ? "New word" : label)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(label.isEmpty ? STheme.hint : STheme.textBright)
                if triggers.count > 1 {
                    Text("\(triggers.count)")
                        .scaledFont(size: 9, weight: .semibold)
                        .foregroundColor(STheme.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(STheme.accentSoft))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(selected ? STheme.accentSoft : STheme.controlBg))
            .overlay(Capsule().stroke(selected ? STheme.accent : STheme.controlBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(triggers.isEmpty ? label : triggers.joined(separator: ", ") + " → " + label)
    }

    private var addBadge: some View {
        Button {
            let entry = CustomDictionaryEntry()
            entries.append(entry)
            open(entry.id)
        } label: {
            Label("Add word", systemImage: "plus")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundColor(STheme.hint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().strokeBorder(STheme.controlBorder,
                                                   style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        }
        .buttonStyle(.plain)
        .help("Add a word or phrase to spell your way")
    }

    private func open(_ id: UUID) {
        guard editing != id else { return close() }
        close()
        editing = id
    }

    /// Closing a rule nobody filled in drops it, so "Add word" then clicking away doesn't leave
    /// a blank badge behind.
    private func close() {
        if let id = editing,
           let entry = entries.first(where: { $0.id == id }),
           entry.replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           entry.triggers.isEmpty {
            entries.removeAll { $0.id == id }
        }
        editing = nil
    }
}

/// Resolves an editor row by identity every time SwiftUI reads or writes it.
///
/// `ForEach($entries)` creates bindings backed by array positions. Deleting a rule removes its
/// position before the popover's focused text field finishes resigning focus; AppKit then makes
/// one final read through that stale binding and traps in `Array.subscript`. A removed row uses
/// its last rendered value for that teardown read, and any late write is deliberately ignored.
func stableDictionaryEntryBinding(entries: Binding<[CustomDictionaryEntry]>,
                                  fallback: CustomDictionaryEntry) -> Binding<CustomDictionaryEntry> {
    Binding(
        get: {
            entries.wrappedValue.first { $0.id == fallback.id } ?? fallback
        },
        set: { updated in
            guard let index = entries.wrappedValue.firstIndex(where: { $0.id == fallback.id })
            else { return }
            entries.wrappedValue[index] = updated
        }
    )
}

/// What sits behind one badge: the right spelling on top, what the model hears underneath.
private struct DictionaryRuleEditor: View {
    @Binding var entry: CustomDictionaryEntry
    let onDone: () -> Void
    let onDelete: () -> Void

    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case replacement
        case trigger(Int)
    }

    private var replacement: String {
        entry.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Punctuation ("open quote" → `"`) is the only kind of rule where spacing is a question.
    /// Existing rules that already use it keep the control.
    private var showsSpacing: Bool {
        (!replacement.isEmpty && replacement.rangeOfCharacter(from: .alphanumerics) == nil)
            || entry.spacing != .standalone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                sectionTitle("Correct spelling")
                TextField("", text: $entry.replacement, prompt: Text("e.g. Klaviyo"))
                    .textFieldStyle(.plain)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(STheme.textBright)
                    .focused($focused, equals: .replacement)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(STheme.inputBg))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    sectionTitle("Rhino hears it as")
                    Text("optional")
                        .scaledFont(size: 10)
                        .foregroundColor(STheme.hint)
                }

                ForEach(Array(triggerBindings().enumerated()), id: \.offset) { position, binding in
                    HStack(spacing: 6) {
                        TextField("", text: binding, prompt: Text("e.g. clavio"))
                            .textFieldStyle(.plain)
                            .scaledFont(size: 12)
                            .focused($focused, equals: .trigger(position))

                        Button { entry.removeTrigger(at: position) } label: {
                            Image(systemName: "minus.circle")
                                .scaledFont(size: 10)
                                .foregroundColor(STheme.hint)
                        }
                        .buttonStyle(.plain)
                        .disabled(position == 0 && entry.alternates.isEmpty)
                        .help("Remove this spelling")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(STheme.inputBg))
                }

                Button {
                    entry.alternates.append("")
                    focused = .trigger(entry.alternates.count)
                } label: {
                    Label("Another way it's heard", systemImage: "plus")
                        .scaledFont(size: 11)
                        .foregroundColor(STheme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                if let note = matchingNote {
                    Text(note)
                        .scaledFont(size: 11)
                        .foregroundColor(STheme.hint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if showsSpacing {
                VStack(alignment: .leading, spacing: 5) {
                    sectionTitle("Spacing")

                    Picker("", selection: $entry.spacing) {
                        Text("Keep spaces").tag(CustomDictionaryEntry.Spacing.standalone)
                        Text("Opens").tag(CustomDictionaryEntry.Spacing.attachesRight)
                        Text("Closes").tag(CustomDictionaryEntry.Spacing.attachesLeft)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 280)

                    // The rule doing its job beats a description of what it does.
                    Text(preview)
                        .scaledFont(size: 11, design: .monospaced)
                        .foregroundColor(STheme.hint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            HStack {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .scaledFont(size: 11)
                }
                .buttonStyle(.plain)
                .foregroundColor(STheme.hint)

                Spacer()

                Button("Done", action: onDone)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .onAppear {
            if replacement.isEmpty { focused = .replacement }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 9, weight: .bold)
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundColor(STheme.sectionTitle)
    }

    /// What happens when nothing is listed under "hears it as", so the optional field reads as
    /// optional rather than as a step that was skipped.
    private var matchingNote: String? {
        guard !replacement.isEmpty, replacement.rangeOfCharacter(from: .alphanumerics) != nil
        else { return nil }
        let guessable = !SoundAlike.eligibleTerms([entry]).isEmpty
        let soundAlikes = AppPreferences.shared.customDictionarySoundAlikesEnabled
        if guessable && soundAlikes {
            return "Close misspellings are fixed automatically. Add one here only if Rhino keeps getting it wrong."
        }
        if entry.triggers.isEmpty {
            return guessable
                ? "Add how Rhino spells it now — sound-alike fixing is off in Settings → Output."
                : "Add how Rhino spells it now — short words and phrases need an exact match."
        }
        return nil
    }

    private var preview: String {
        let spoken = entry.triggers.first ?? "…"
        let sample: String
        switch entry.spacing {
        case .attachesRight: sample = "he said \(spoken) yes"
        case .attachesLeft: sample = "yes \(spoken) he said"
        case .standalone: sample = "yes \(spoken) no"
        }
        return CustomDictionary.apply(sample, entries: [entry])
    }

    /// The primary phrasing and its alternates edited as one list, since the distinction is an
    /// implementation detail the user has no reason to care about.
    private func triggerBindings() -> [Binding<String>] {
        [Binding(get: { entry.original }, set: { entry.original = $0 })]
            + entry.alternates.indices.map { index in
                Binding(get: { entry.alternates.indices.contains(index) ? entry.alternates[index] : "" },
                        set: { if entry.alternates.indices.contains(index) { entry.alternates[index] = $0 } })
            }
    }

}

/// Wraps its children onto as many lines as it needs. SwiftUI has no flow layout of its own.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
                       cache: inout ()) {
        for row in arrange(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        var x: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !row.indices.isEmpty && x + size.width > width {
                rows.append(row)
                row = Row(y: row.y + row.height + spacing)
                x = 0
            }
            row.indices.append(index)
            row.width = max(row.width, x + size.width)
            row.height = max(row.height, size.height)
            x += size.width + spacing
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
