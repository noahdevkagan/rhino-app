import AppKit
import SwiftUI

// MARK: - Loading + cache

/// Holds the current Wrapped stats for Home. Shared so the result survives tab switches
/// (Home is rebuilt on each), and keyed on a cheap SQL fingerprint of the history so the
/// many recordingsDidUpdate posts during a dictation don't each re-read every transcript.
@MainActor
final class RhinoWrappedModel: ObservableObject {
    static let shared = RhinoWrappedModel()

    @Published private(set) var wrapped: RhinoWrapped?

    private var signature: String?
    private var running = false
    private var rerun = false

    func refresh() {
        guard !running else { rerun = true; return }
        running = true
        Task { [weak self] in
            await self?.load()
            guard let self else { return }
            self.running = false
            if self.rerun { self.rerun = false; self.refresh() }
        }
    }

    private func load() async {
        let store = RecordingStore.shared
        // The time zone is part of the key: days, hours and weekends move with it.
        guard let history = try? await store.completedHistorySignature(),
              case let current = history + "|" + TimeZone.current.identifier,
              current != signature,
              let rows = try? await store.fetchWrappedDictations() else { return }
        let result = await Task.detached(priority: .utility) { RhinoWrapped.compute(rows) }.value
        wrapped = result
        signature = current
    }
}

// MARK: - Card

/// Colors are picked from an explicit scheme (not dynamic NSColors) so ImageRenderer
/// draws the shared PNG in the same mode the user is looking at.
private struct WrappedPalette {
    let scheme: ColorScheme
    var dark: Bool { scheme == .dark }

    var gradient: [Color] {
        dark ? [Color(red: 0.12, green: 0.11, blue: 0.16), Color(red: 0.10, green: 0.11, blue: 0.15)]
             : [Color(red: 0.980, green: 0.969, blue: 1.0), Color(red: 0.953, green: 0.969, blue: 1.0)]
    }
    var border: Color {
        dark ? Color(red: 0.22, green: 0.20, blue: 0.30) : Color(red: 0.890, green: 0.863, blue: 0.961)
    }
    var tile: Color { dark ? Color(red: 0.13, green: 0.13, blue: 0.15) : .white }
    var tileBorder: Color {
        dark ? Color.white.opacity(0.08) : Color(red: 0.902, green: 0.902, blue: 0.925)
    }
    var text: Color { dark ? Color(white: 0.94) : Color(red: 0.114, green: 0.114, blue: 0.122) }
    var secondary: Color { dark ? Color(white: 0.62) : Color(red: 0.431, green: 0.431, blue: 0.451) }
    var buttonFill: Color { dark ? Color(white: 0.94) : Color(red: 0.114, green: 0.114, blue: 0.122) }
    var buttonText: Color { dark ? .black : .white }
}

/// "Your Rhino Wrapped": header + 4 × 2 tiles. `onShare` nil hides the button
/// (the shared image); `footer` adds the "Made with Rhino" line under the tiles.
struct RhinoWrappedCardView: View {
    let wrapped: RhinoWrapped
    let scheme: ColorScheme
    var onShare: ((NSView?) -> Void)?
    var footer: String?

    @State private var anchor = ViewAnchor()

    private var palette: WrappedPalette { WrappedPalette(scheme: scheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Your Rhino Wrapped")
                    .scaledFont(size: 15, weight: .bold)
                    .foregroundColor(palette.text)
                Text(wrapped.sinceText())
                    .scaledFont(size: 11.5)
                    .foregroundColor(palette.secondary)
                Spacer()
                if let onShare {
                    Button { onShare(anchor.view) } label: {
                        Text("Share ↗")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundColor(palette.buttonText)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(palette.buttonFill))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .background(AnchorView(anchor: anchor))
                    .help("Share your Wrapped as an image (stats only, no transcripts)")
                }
            }

            // Plain stacks, not LazyVGrid: ImageRenderer can skip lazy content.
            let tiles = wrapped.tiles()
            VStack(spacing: 10) {
                ForEach([0, 4], id: \.self) { start in
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(tiles[start..<min(start + 4, tiles.count)]) { tileView($0) }
                    }
                }
            }

            if let footer {
                HStack {
                    Spacer()
                    Text(footer)
                        .scaledFont(size: 11, weight: .medium)
                        .foregroundColor(palette.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: palette.gradient,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }

    private func tileView(_ tile: RhinoWrapped.Tile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tile.label)
                .scaledFont(size: 11)
                .foregroundColor(palette.secondary)
            Text(tile.value)
                .scaledFont(size: 16, weight: .bold)
                .foregroundColor(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(tile.note)
                .scaledFont(size: 11)
                .foregroundColor(palette.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.tile))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(palette.tileBorder, lineWidth: 1))
    }
}

/// Home's slot: renders nothing until there are enough dictations.
struct RhinoWrappedSection: View {
    @ObservedObject private var model = RhinoWrappedModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // No modifiers here: an empty view never appears, so HomeHeaderView drives refresh().
        if let wrapped = model.wrapped {
            RhinoWrappedCardView(wrapped: wrapped, scheme: colorScheme) { anchorView in
                RhinoWrappedSharer.share(wrapped, scheme: colorScheme, from: anchorView)
            }
        }
    }
}

// MARK: - Share

/// Renders the card to a PNG and opens the system share menu, with "Copy Image" first.
/// Only the stats are in the image; the link is the user's referral invite.
@MainActor
enum RhinoWrappedSharer {
    private static var delegate: PickerDelegate?

    /// "rhinovoice.app/r/<code>": the same invite link as Share Rhino, so friends who
    /// come from a shared Wrapped count toward the 2-friend unlock.
    static var footerLink: String {
        let url = ShareRhino.link.inviteURL
        return (url.host ?? "rhinovoice.app") + url.path
    }

    static func image(_ wrapped: RhinoWrapped, scheme: ColorScheme) -> NSImage? {
        let card = RhinoWrappedCardView(wrapped: wrapped, scheme: scheme,
                                        footer: "Made with Rhino · \(footerLink)")
            .frame(width: 760)
            .padding(20)
            .background(scheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white)
            .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        return renderer.nsImage
    }

    static func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    static func share(_ wrapped: RhinoWrapped, scheme: ColorScheme, from view: NSView?) {
        guard let image = image(wrapped, scheme: scheme), let png = pngData(image) else { return }
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("Rhino Wrapped.png")
        try? png.write(to: file, options: .atomic)

        let copy = NSSharingService(
            title: "Copy Image",
            image: NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil) ?? NSImage(),
            alternateImage: nil) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                // One item only: two (PNG + NSImage) made some apps paste the image twice.
                pasteboard.setData(png, forType: .png)
            }

        guard let view, view.window != nil else {
            copy.perform(withItems: [])
            return
        }
        let delegate = PickerDelegate(copy: copy)
        self.delegate = delegate
        let picker = NSSharingServicePicker(items: [file])
        picker.delegate = delegate
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    private final class PickerDelegate: NSObject, NSSharingServicePickerDelegate {
        let copy: NSSharingService
        init(copy: NSSharingService) { self.copy = copy }

        func sharingServicePicker(_ picker: NSSharingServicePicker,
                                  sharingServicesForItems items: [Any],
                                  proposedSharingServices proposed: [NSSharingService]) -> [NSSharingService] {
            [copy] + proposed
        }
    }
}

/// Lets a SwiftUI button hand its backing NSView to NSSharingServicePicker.
final class ViewAnchor {
    weak var view: NSView?
}

private struct AnchorView: NSViewRepresentable {
    let anchor: ViewAnchor
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { anchor.view = nsView }
}
