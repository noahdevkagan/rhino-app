import SwiftUI

/// "How much should Rhino tidy?" — the three cleanup levels as one choice, at the top of the
/// Output tab. Plain state in, so the snapshot test can render it without a view model.
/// When the chosen level needs the cleanup model and it isn't on disk yet, one line says so
/// with the download right there.
struct CleanupLevelPicker: View {
    @Binding var level: CleanupLevel
    let modelDownloaded: Bool
    let downloadProgress: Double?
    let downloadError: String?
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(CleanupLevel.allCases) { option in
                optionRow(option)
            }
            if level.usesModel && !modelDownloaded {
                modelNeeded.padding(.top, 4)
            }
            if let downloadError {
                Text("✕ \(downloadError)")
                    .scaledFont(size: 11)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func optionRow(_ option: CleanupLevel) -> some View {
        let selected = option == level
        return Button { level = option } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle().stroke(selected ? STheme.accent : STheme.controlBorder, lineWidth: 1.5)
                    if selected { Circle().fill(STheme.accent).padding(3.5) }
                }
                .frame(width: 15, height: 15)
                .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .scaledFont(size: 13, weight: selected ? .semibold : .regular)
                        .foregroundColor(STheme.text)
                    Text(option.hint)
                        .scaledFont(size: 11)
                        .foregroundColor(STheme.hint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? STheme.accentSoft : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var modelNeeded: some View {
        HStack(spacing: 8) {
            if let progress = downloadProgress {
                ProgressView(value: progress).frame(width: 160).controlSize(.small)
                Text("Downloading the cleanup model… \(Int(progress * 100))%")
                    .scaledFont(size: 11).foregroundColor(STheme.hint)
            } else {
                Text("\(level.title) needs the cleanup model: about 1 GB, downloaded once, runs only on your Mac.")
                    .scaledFont(size: 11).foregroundColor(STheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Download", action: onDownload).controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
    }
}
