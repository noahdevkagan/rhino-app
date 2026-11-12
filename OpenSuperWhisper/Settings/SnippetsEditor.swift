import SwiftUI

// MARK: - Snippets tab

/// Main-window tab next to Dictionary: phrases the user says to get a block of text.
struct SnippetsTabView: View {
    @State private var snippets: [Snippet] = AppPreferences.shared.snippets
    @State private var enabled = AppPreferences.shared.snippetsEnabled
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Snippets")
                        .scaledFont(size: 34, weight: .bold)
                    Spacer()
                    Toggle("", isOn: $enabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: enabled) { _, on in
                            AppPreferences.shared.snippetsEnabled = on
                        }
                }
                .padding(.top, 26)

                Text("Say a short phrase, get the full text. Dictate just \"my calendar link\" and Rhino types your link, exactly as you saved it here. Stored only on this Mac.")
                    .scaledFont(size: 12.5)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SnippetsEditor(snippets: $snippets)
                    .onChange(of: snippets) { _, new in
                        AppPreferences.shared.snippets = Snippets.pruned(new)
                    }
                    .opacity(enabled ? 1 : 0.4)
                    .disabled(!enabled)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemePalette.windowBackground(colorScheme))
    }
}

// MARK: - Editor

/// The saved snippets as a list, one row per trigger, with the open one edited inline (like
/// the dictionary's rule editor, which also avoids popovers clipping at the window edge).
struct SnippetsEditor: View {
    @Binding var snippets: [Snippet]
    @State private var editing: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snippets.isEmpty {
                Text("No snippets yet.")
                    .scaledFont(size: 12)
                    .foregroundColor(STheme.hint)
                    .padding(.vertical, 6)
            }
            ForEach(snippets) { snippet in
                if editing == snippet.id {
                    SnippetRowEditor(
                        snippet: stableSnippetBinding(snippets: $snippets, fallback: snippet),
                        duplicate: isDuplicate(snippet),
                        onDone: { close() },
                        onDelete: {
                            snippets.removeAll { $0.id == snippet.id }
                            editing = nil
                        })
                        .id(snippet.id)
                        .padding(.vertical, 8)
                } else {
                    row(for: snippet)
                }
                Divider().overlay(STheme.border)
            }

            Button {
                close()
                let snippet = Snippet()
                snippets.append(snippet)
                editing = snippet.id
            } label: {
                Label("Add snippet", systemImage: "plus")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundColor(STheme.hint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().strokeBorder(STheme.controlBorder,
                                                       style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).fill(STheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(STheme.border, lineWidth: 1))
        .onDisappear { close() }
    }

    private func row(for snippet: Snippet) -> some View {
        let trigger = snippet.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = snippet.expansion
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).first ?? ""
        return Button {
            if editing == snippet.id { close() } else { close(); editing = snippet.id }
        } label: {
            HStack(spacing: 8) {
                Text(trigger.isEmpty ? "New snippet" : trigger)
                    .scaledFont(size: 12.5, weight: .medium)
                    .foregroundColor(trigger.isEmpty ? STheme.hint : STheme.textBright)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .scaledFont(size: 8, weight: .semibold)
                    .foregroundColor(STheme.hint)
                Text(firstLine)
                    .scaledFont(size: 12)
                    .foregroundColor(STheme.hint)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(snippet.expansion)
    }

    /// Same rule as matching: only an earlier snippet that can fire takes the phrase.
    private func isDuplicate(_ snippet: Snippet) -> Bool {
        Snippets.shadowing(snippet, in: snippets) != nil
    }

    /// Closing a snippet nobody filled in drops it, so "Add snippet" then clicking away doesn't
    /// leave a blank row behind.
    private func close() {
        if let id = editing, let snippet = snippets.first(where: { $0.id == id }),
           Snippets.pruned([snippet]).isEmpty {
            snippets.removeAll { $0.id == id }
        }
        editing = nil
    }
}

/// Resolves the edited row by identity on every read and write. Same reason as
/// `stableDictionaryEntryBinding`: a deleted row's text field can make one last read through a
/// position-backed binding and trap.
private func stableSnippetBinding(snippets: Binding<[Snippet]>, fallback: Snippet) -> Binding<Snippet> {
    Binding(
        get: { snippets.wrappedValue.first { $0.id == fallback.id } ?? fallback },
        set: { updated in
            guard let index = snippets.wrappedValue.firstIndex(where: { $0.id == fallback.id })
            else { return }
            snippets.wrappedValue[index] = updated
        })
}

private struct SnippetRowEditor: View {
    @Binding var snippet: Snippet
    let duplicate: Bool
    let onDone: () -> Void
    let onDelete: () -> Void

    @FocusState private var focused: Field?
    private enum Field: Hashable { case trigger, expansion }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                sectionTitle("When you say")
                TextField("", text: $snippet.trigger, prompt: Text("e.g. my calendar link"))
                    .textFieldStyle(.plain)
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(STheme.textBright)
                    .focused($focused, equals: .trigger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(STheme.inputBg))
                Text(duplicate
                     ? "A snippet higher in the list already uses this phrase, so Rhino types that one instead."
                     : "Works when this phrase is the whole dictation. Capitals and punctuation don't matter.")
                    .scaledFont(size: 11)
                    .foregroundColor(duplicate ? STheme.warn : STheme.hint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 5) {
                sectionTitle("Rhino types")
                TextEditor(text: $snippet.expansion)
                    .scrollContentBackground(.hidden)
                    .scaledFont(size: 12.5)
                    .foregroundColor(STheme.text)
                    .focused($focused, equals: .expansion)
                    .frame(minHeight: 70, maxHeight: 160)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(STheme.inputBg))
            }

            HStack {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .scaledFont(size: 11)
                }
                .buttonStyle(.plain)
                .foregroundColor(STheme.hint)

                Spacer()

                // No default-action shortcut: Return in the text box adds a line.
                Button("Done", action: onDone)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: 480, alignment: .leading)
        .onAppear {
            if snippet.trigger.isEmpty { focused = .trigger }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 9, weight: .bold)
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundColor(STheme.sectionTitle)
    }
}
