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
    /// Counted dictations, for the locked card's "N of 10". nil until the first load.
    @Published private(set) var dictationCount: Int?

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
        let (result, count) = await Task.detached(priority: .utility) {
            (RhinoWrapped.compute(rows), RhinoWrapped.countedDictations(rows))
        }.value
        wrapped = result
        dictationCount = count
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

    // Locked state (newuser-after mockup).
    var accent: Color {
        dark ? Color(red: 0.62, green: 0.55, blue: 0.95) : Color(red: 0.431, green: 0.337, blue: 0.812)
    }
    var track: Color { dark ? Color.white.opacity(0.10) : Color(red: 0.902, green: 0.902, blue: 0.937) }
    var dashed: Color { dark ? accent.opacity(0.45) : Color(red: 0.812, green: 0.776, blue: 0.933) }
    var placeholder: Color { dark ? Color(white: 0.38) : Color(red: 0.780, green: 0.780, blue: 0.800) }
    var keyFill: Color { dark ? Color.white.opacity(0.08) : Color(red: 0.965, green: 0.965, blue: 0.973) }
    var keyBorder: Color { dark ? Color.white.opacity(0.16) : Color(red: 0.863, green: 0.867, blue: 0.890) }
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

/// Before `minimumDictations`: the same card, locked. Progress toward 10, a phrase to
/// try with the user's own dictation key, and the eight tiles greyed out. No Share.
struct RhinoWrappedLockedView: View {
    let count: Int
    let shortcut: String
    let scheme: ColorScheme

    private var palette: WrappedPalette { WrappedPalette(scheme: scheme) }
    private var progress: Double {
        min(max(Double(count) / Double(RhinoWrapped.minimumDictations), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Your Rhino Wrapped")
                    .scaledFont(size: 15, weight: .bold)
                    .foregroundColor(palette.text)
                Text("unlocks at \(RhinoWrapped.minimumDictations) dictations")
                    .scaledFont(size: 11.5)
                    .foregroundColor(palette.secondary)
                Spacer()
                Text(RhinoWrapped.progressText(count))
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundColor(palette.accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.track)
                    Capsule().fill(palette.accent)
                        .frame(width: max(progress > 0 ? 5 : 0, geo.size.width * progress))
                }
            }
            .frame(height: 5)
            .accessibilityLabel("\(RhinoWrapped.progressText(count)) dictations")

            HStack(spacing: 6) {
                Text("🎙️")
                if shortcut == "—" {
                    // No dictation key set: no key chip to point at.
                    Text("Try saying")
                } else {
                    // Tap-to-toggle users would hold, release, and keep recording.
                    Text("Try one now: \(AppPreferences.shared.holdToRecord ? "hold" : "press")")
                    Text(shortcut)
                        .scaledFont(size: 12, weight: .semibold)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 5).fill(palette.keyFill))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(palette.keyBorder, lineWidth: 1))
                    Text("and say")
                }
                Text("\"\(RhinoWrapped.samplePhrase(for: count))\"")
                    .italic()
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .scaledFont(size: 12.5)
            .foregroundColor(palette.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.tile))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(palette.dashed, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))

            let note = RhinoWrapped.lockedNote(count)
            VStack(spacing: 10) {
                ForEach([0, 4], id: \.self) { start in
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(RhinoWrapped.tileLabels[start..<start + 4], id: \.self) { label in
                            lockedTile(label, note: note)
                        }
                    }
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

    private func lockedTile(_ label: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .scaledFont(size: 11)
                .foregroundColor(palette.secondary)
            Text("?")
                .scaledFont(size: 16, weight: .bold)
                .foregroundColor(palette.placeholder)
            Text(note)
                .scaledFont(size: 11)
                .foregroundColor(palette.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.tile))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(palette.tileBorder, lineWidth: 1))
    }
}

/// Home's slot, directly above History: the locked card under 10 dictations, the real one after.
struct RhinoWrappedSection: View {
    /// The user's dictation key as Home shows it ("fn", "⌥ Space").
    let shortcut: String
    @ObservedObject private var model = RhinoWrappedModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // No modifiers here: HomeHeaderView drives refresh().
        if let wrapped = model.wrapped {
            RhinoWrappedCardView(wrapped: wrapped, scheme: colorScheme) { anchorView in
                RhinoWrappedSharer.share(wrapped, scheme: colorScheme, from: anchorView)
            }
        } else if let count = model.dictationCount {
            RhinoWrappedLockedView(count: count, shortcut: shortcut, scheme: colorScheme)
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
