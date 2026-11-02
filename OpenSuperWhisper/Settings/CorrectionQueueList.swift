import SwiftUI

/// The pairs "Help improve accuracy" will send next, so the user sees exactly what leaves the Mac
/// and can take any of it back before it does. (CorrectionReporter)
struct CorrectionQueueList: View {
    @ObservedObject private var reporter = CorrectionReporter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(reporter.queue.isEmpty
                     ? "Nothing waiting to send. Fixes you make with \"Fix a word\" show up here first."
                     : "Waiting to send (\(reporter.queue.count))")
                    .scaledFont(size: 11)
                    .foregroundColor(STheme.hint)
                Spacer()
                if !reporter.queue.isEmpty {
                    Button("Delete all") { reporter.deleteAll() }
                        .controlSize(.small)
                }
            }
            ForEach(reporter.queue) { item in
                HStack(spacing: 8) {
                    Text(item.heard)
                        .scaledFont(size: 12, design: .monospaced)
                        .foregroundColor(STheme.hint)
                    Image(systemName: "arrow.right")
                        .scaledFont(size: 10)
                        .foregroundColor(STheme.hint)
                    Text(item.corrected)
                        .scaledFont(size: 12, design: .monospaced)
                        .foregroundColor(STheme.text)
                    Spacer()
                    Button {
                        reporter.delete(item.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(STheme.hint)
                    }
                    .buttonStyle(.plain)
                    .help("Don't send this one")
                }
            }
        }
        .padding(.leading, 18)
    }
}
