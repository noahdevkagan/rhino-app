import SwiftUI

/// Teaches the dictionary from a transcript: pick the word Rhino got wrong, type what it should
/// be. This is the "train it on my word" people ask for — they already see the mistake in their
/// history, so nobody has to guess in Settings what the model mishears.
struct FixSpellingSheet: View {
    let recording: Recording

    @Environment(\.dismiss) private var dismiss
    @State private var heard = ""
    @State private var correct = ""
    @State private var fixThisTranscript = true
    @FocusState private var correctFocused: Bool

    private var words: [String] { CustomDictionary.pickableWords(in: recording.transcription) }

    private var canSave: Bool {
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let correct = correct.trimmingCharacters(in: .whitespacesAndNewlines)
        return !heard.isEmpty && !correct.isEmpty && heard != correct
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fix a word")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Click the word Rhino got wrong")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ScrollView {
                    FlowLayout(spacing: 5) {
                        ForEach(words, id: \.self) { word in
                            Button {
                                heard = word
                                correctFocused = true
                            } label: {
                                Text(word)
                                    .font(.callout)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(heard == word
                                        ? Color.accentColor.opacity(0.18)
                                        : Color.secondary.opacity(0.1)))
                                    .overlay(Capsule().stroke(heard == word
                                        ? Color.accentColor : Color.clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Rhino wrote")
                        .foregroundColor(.secondary)
                    TextField("", text: $heard, prompt: Text("e.g. Clavio"))
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Should be")
                        .foregroundColor(.secondary)
                    TextField("", text: $correct, prompt: Text("e.g. Klaviyo"))
                        .textFieldStyle(.roundedBorder)
                        .focused($correctFocused)
                }
            }

            Toggle("Also fix it in this transcript", isOn: $fixThisTranscript)

            if !AppPreferences.shared.customDictionaryEnabled {
                Text("Your dictionary is off — saving turns it back on.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add to dictionary", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save() {
        let prefs = AppPreferences.shared
        prefs.customDictionaryEntries = CustomDictionary.teaching(
            heard: heard, correct: correct, to: prefs.customDictionaryEntries)
        prefs.customDictionaryEnabled = true
        NotificationCenter.default.post(name: .customDictionaryDidChange, object: nil)

        if fixThisTranscript {
            let rule = CustomDictionaryEntry(original: heard, replacement: correct)
            var updated = recording
            updated.transcription = CustomDictionary.apply(recording.transcription, entries: [rule])
            if updated.transcription != recording.transcription {
                RecordingStore.shared.updateRecording(updated)
            }
        }
        dismiss()
    }
}
