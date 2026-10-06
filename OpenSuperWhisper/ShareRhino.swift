import AppKit
import SwiftUI

@MainActor
final class ShareRhino {
    static let shared = ShareRhino()

    /// The invite goes to rhinovoice.app/r/<code>, which offers friends Rhino free on
    /// AppSumo (coupon rhinofree) or the free download, and counts them toward this
    /// user's 3-friend unlock. Copying never opens a connection.
    static var link: ReferralLink { ReferralLink(defaults: DefaultsStore.current) }
    static func invitation(_ url: URL) -> String {
        """
        I've been using Rhino Voice to dictate on my Mac and I can give it to you free.
        Hold a key, talk, and it types for you in any app. Everything runs on your Mac.

        Get it here: \(url.absoluteString)

        Needs an Apple silicon Mac with macOS 14 or later.
        """
    }

    private var panel: NSPanel?

    func dismissForRecording() {
        panel?.orderOut(nil)
    }

    func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 350),
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered, defer: false)
            panel.title = "Share Rhino"
            panel.isReleasedWhenClosed = false
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            self.panel = panel
        }
        guard let panel else { return }
        // Reset the copied state every time the menu item opens this panel.
        let hosting = NSHostingController(rootView: ShareRhinoView(
            link: Self.link,
            isUnlocked: UnlockRhino.shared.gate.isUnlocked,
            dismiss: { [weak panel] in panel?.orderOut(nil) }))
        hosting.sizingOptions = []
        panel.contentViewController = hosting
        panel.setContentSize(NSSize(width: 420, height: 350))
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: frame.maxX - panel.frame.width - 20,
                                               y: frame.maxY - 20))
        }
        // Never activate Rhino or take keyboard focus from the dictation target.
        panel.orderFrontRegardless()
    }
}

private struct ShareRhinoView: View {
    let link: ReferralLink
    let isUnlocked: Bool
    let dismiss: () -> Void
    @State private var copied = false
    @State private var linkCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isUnlocked ? "Share Rhino 🦏" : "Get Rhino Unlimited free 🦏")
                .font(.title2.bold())
            Text(isUnlocked
                 ? "Send friends your link. They can get Rhino free."
                 : "Invite \(ReferralLink.friendsNeeded) friends. When \(ReferralLink.friendsNeeded) get Rhino through your link, Unlimited is yours, free.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                Text("Your link")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(link.inviteURL.absoluteString)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button(linkCopied ? "Copied!" : "Copy link") {
                        ClipboardUtil.copyToClipboard(link.inviteURL.absoluteString)
                        linkCopied = true
                        copied = false
                    }
                }
                Text("Friends get Rhino free on AppSumo, or the free download.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.2)))
            if !isUnlocked {
                Button("See how many friends joined") { NSWorkspace.shared.open(link.statusURL) }
                    .buttonStyle(.link)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Close", action: dismiss)
                Spacer()
                Button(copied ? "Invitation copied" : "Copy invitation") {
                    ClipboardUtil.copyToClipboard(ShareRhino.invitation(link.inviteURL))
                    copied = true
                    linkCopied = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420, height: 350)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
