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
        FlowLayout(spacing: 6) {
            ForEach(entries) { entry in
                badge(for: entry)
            }
            addBadge
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).fill(STheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(STheme.border, lineWidth: 1))
    }

    private func badge(for value: CustomDictionaryEntry) -> some View {
        let entry = stableDictionaryEntryBinding(entries: $entries, fallback: value)
        let label = value.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        let count = value.triggers.count

        return Button { editing = value.id } label: {
            HStack(spacing: 5) {
                Text(label.isEmpty ? "empty" : label)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(label.isEmpty ? STheme.hint : STheme.textBright)
                // Only worth showing when there is more than the obvious one behind it.
                if count > 1 {
                    Text("\(count)")
                        .scaledFont(size: 9, weight: .semibold)
                        .foregroundColor(STheme.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(STheme.accentSoft))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(STheme.controlBg))
            .overlay(Capsule().stroke(STheme.controlBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(value.triggers.joined(separator: ", "))
        .popover(isPresented: Binding(get: { editing == value.id },
                                      set: { if !$0 { editing = nil } }),
                 arrowEdge: .bottom) {
            DictionaryRuleEditor(entry: entry) {
                entries.removeAll { $0.id == value.id }
                editing = nil
            }
        }
    }

    private var addBadge: some View {
        Button {
            let entry = CustomDictionaryEntry()
            entries.append(entry)
            editing = entry.id
        } label: {
            Image(systemName: "plus")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundColor(STheme.hint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().strokeBorder(STheme.controlBorder,
                                                   style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        }
        .buttonStyle(.plain)
        .help("Add a rule")
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

/// What sits behind one badge: the result on top, everything that reaches it underneath.
private struct DictionaryRuleEditor: View {
    @Binding var entry: CustomDictionaryEntry
    let onDelete: () -> Void

    @FocusState private var focused: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Writes")
                    .scaledFont(size: 9, weight: .bold)
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(STheme.sectionTitle)

                TextField("", text: $entry.replacement, prompt: Text("GitHub"))
                    .textFieldStyle(.plain)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(STheme.textBright)
            }

            Divider().overlay(STheme.border)

            VStack(alignment: .leading, spacing: 5) {
                Text("When it hears")
                    .scaledFont(size: 9, weight: .bold)
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(STheme.sectionTitle)

                ForEach(Array(triggerBindings().enumerated()), id: \.offset) { position, binding in
                    HStack(spacing: 6) {
                        TextField("", text: binding, prompt: Text("git hub"))
                            .textFieldStyle(.plain)
                            .scaledFont(size: 12)
                            .focused($focused, equals: position)

                        Button { entry.removeTrigger(at: position) } label: {
                            Image(systemName: "minus.circle")
                                .scaledFont(size: 10)
                                .foregroundColor(STheme.hint)
                        }
                        .buttonStyle(.plain)
                        .disabled(position == 0 && entry.alternates.isEmpty)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(STheme.inputBg))
                }

                Button {
                    entry.alternates.append("")
                    focused = entry.triggers.count
                } label: {
                    Label("Another way of saying it", systemImage: "plus")
                        .scaledFont(size: 11)
                        .foregroundColor(STheme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            Divider().overlay(STheme.border)

            VStack(alignment: .leading, spacing: 5) {
                Text("Spacing")
                    .scaledFont(size: 9, weight: .bold)
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(STheme.sectionTitle)

                Picker("", selection: $entry.spacing) {
                    Text("Keep spaces").tag(CustomDictionaryEntry.Spacing.standalone)
                    Text("Opens").tag(CustomDictionaryEntry.Spacing.attachesRight)
                    Text("Closes").tag(CustomDictionaryEntry.Spacing.attachesLeft)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // The rule doing its job beats a description of what it does.
                Text(preview)
                    .scaledFont(size: 11, design: .monospaced)
                    .foregroundColor(STheme.hint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Divider().overlay(STheme.border)

            Button(role: .destructive, action: onDelete) {
                Label("Delete this rule", systemImage: "trash")
                    .scaledFont(size: 11)
            }
            .buttonStyle(.plain)
            .foregroundColor(STheme.hint)
        }
        .padding(14)
        .frame(width: 280)
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
