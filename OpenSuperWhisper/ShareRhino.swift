import AppKit
import SwiftUI

@MainActor
final class ShareRhino {
    static let shared = ShareRhino()

    // User-provided AppSumo offer. Copying never opens a connection; recipients
    // apply the coupon at checkout in their browser.
    static let downloadLink = "https://appsumo.com/products/rhino/"
    static let couponCode = "rhinofree"
    static let linkAndCode = "\(downloadLink)\nUse coupon \(couponCode) at checkout to get Rhino for free."
    static let invitation = """
    I've been using Rhino Voice to dictate on my Mac, and I can share it with you for free.
    It turns speech into text and processes everything on your Mac.

    Get Rhino free on AppSumo:
    \(linkAndCode)

    Requires an Apple silicon Mac with macOS 14 or later. After checkout, follow the redemption instructions in your AppSumo account.
    """

    private var panel: NSPanel?
    private var pendingPrompt: Task<Void, Never>?
    private var policy: SharePromptPolicy { SharePromptPolicy(defaults: DefaultsStore.current) }

    func recordSuccessfulDictation() {
        guard AppPreferences.shared.hasCompletedOnboarding else { return }
        policy.recordSuccessfulDictation()
        guard policy.isEligible else { return }
        pendingPrompt?.cancel()
        pendingPrompt = Task { [weak self] in
            // Give insertion/clipboard restoration time to settle. If the user
            // starts another take, retry after a later successful dictation.
            do { try await Task.sleep(nanoseconds: 3_000_000_000) }
            catch { return }
            guard let self, self.policy.isEligible,
                  !DictationPipeline.shared.isProcessing,
                  IndicatorWindowManager.shared.viewModel == nil else { return }
            self.show()
        }
    }

    func dismissForRecording() {
        pendingPrompt?.cancel()
        panel?.orderOut(nil)
    }

    func show() {
        pendingPrompt?.cancel()
        policy.markPresented()
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
        let hosting = NSHostingController(rootView: ShareRhinoView { [weak panel] in
            panel?.orderOut(nil)
        })
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
    let dismiss: () -> Void
    @State private var copied = false
    @State private var linkCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Happy Rhino Day! 🦏")
                .font(.title2.bold())
            Text("Give 3 friends Rhino Voice for free.")
                .font(.headline)
            Text("Send them this AppSumo link and coupon.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                Text("AppSumo link")
                    .font(.caption).foregroundStyle(.secondary)
                Text(ShareRhino.downloadLink)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("Coupon: \(ShareRhino.couponCode)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button(linkCopied ? "Copied!" : "Copy link + code") {
                        ClipboardUtil.copyToClipboard(ShareRhino.linkAndCode)
                        linkCopied = true
                        copied = false
                    }
                }
                Text("Apply the coupon at checkout.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.2)))
            Spacer(minLength: 0)
            HStack {
                Button("Close", action: dismiss)
                Spacer()
                Button(copied ? "Invitation copied" : "Copy invitation") {
                    ClipboardUtil.copyToClipboard(ShareRhino.invitation)
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
