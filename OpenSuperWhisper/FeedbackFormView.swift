import AppKit
import SwiftUI

/// Tiny feedback form reachable from the menu bar. No backend and no telemetry:
/// Send opens the user's mail client pre-addressed to Noah with the typed text
/// and Rhino version filled in.
struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    static let address = "noahkagan@gmail.com"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Send Feedback")
                    .font(.title3.bold())
                Text("Goes straight to Noah — what's working, what's annoying, what's missing?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 140)
                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.2))
                )

            HStack {
                Text(Self.address)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                Spacer()
                Button("Cancel") { dismiss() }
                Button {
                    send()
                } label: {
                    Label("Send via Email", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 440)
    }

    static func emailURL(feedback: String, version: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            .init(name: "subject", value: "Rhino feedback (v\(version))"),
            .init(name: "body", value: feedback),
        ]
        return components.url
    }

    private func send() {
        if let url = Self.emailURL(feedback: text, version: UpdatesView.currentVersion) {
            NSWorkspace.shared.open(url)
        }
        dismiss()
    }
}
