import AppKit
import SwiftUI

/// Free-tier paywall: shown when the weekly free words run out, or from the menu bar.
@MainActor
final class UnlockRhino {
    static let shared = UnlockRhino()
    static let buyURL = URL(string: "https://rhinovoice.app/#buy")!
    static let panelSize = NSSize(width: 420, height: 380)

    private var panel: NSPanel?
    private lazy var appSumoHashes = UsageGate.loadAppSumoHashes()
    var gate: UsageGate { UsageGate(defaults: DefaultsStore.current) }

    func bootstrap() {
        gate.bootstrap(hasCompletedOnboarding: AppPreferences.shared.hasCompletedOnboarding)
    }

    /// Called on the trigger key. Returns false (and shows the paywall) when the
    /// free words for this week are used up.
    func allowRecording() -> Bool {
        guard gate.isBlocked else { return true }
        // The cursor bubble is the proven way to reach a user over any app; the panel
        // carries the buy button and code field.
        IndicatorWindowManager.shared.flash(.info("Free words used up this week. Rhino menu → Get Rhino Unlimited"))
        show(limitReached: true)
        return false
    }

    func record(text: String) {
        gate.record(words: UsageGate.wordCount(text))
    }

    func unlock(code: String) -> Bool {
        let ok = gate.unlock(code: code, appSumoHashes: appSumoHashes)
        if ok { NotificationCenter.default.post(name: .rhinoUnlockChanged, object: nil) }
        return ok
    }

    /// rhinovoice://unlock?code=RH-XXXX-XXXX-XXXX. The code is checked locally like a typed one;
    /// a bad or missing code just opens the panel so the user can type it.
    func handle(url: URL) {
        guard url.host == "unlock" else { return }
        let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value ?? ""
        if !gate.isUnlocked { _ = unlock(code: code) }
        IndicatorWindowManager.shared.flash(gate.isUnlocked
            ? .info("Rhino is unlimited 🦏")
            : .error("That unlock code didn't work. Rhino menu → Get Rhino Unlimited"))
        show()
    }

    func show(limitReached: Bool = false) {
        if panel == nil {
            // Same recipe as the Share panel, which is proven to appear over whatever app
            // is frontmost: a non-activating floating panel that never hides on deactivate.
            // macOS 14+ often refuses to activate a background app, so nothing here may
            // depend on Rhino becoming active. A non-activating panel can still take key
            // focus, so the code field remains typeable.
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: Self.panelSize),
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered, defer: false)
            panel.title = "Rhino Unlimited"
            panel.isReleasedWhenClosed = false
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            self.panel = panel
        }
        guard let panel else { return }
        let hosting = NSHostingController(rootView: UnlockRhinoView(
            limitReached: limitReached,
            wordsThisWeek: gate.wordsThisWeek,
            isUnlocked: gate.isUnlocked,
            unlock: { [weak self] code in self?.unlock(code: code) ?? false },
            dismiss: { [weak panel] in panel?.orderOut(nil) }))
        hosting.sizingOptions = []
        panel.contentViewController = hosting
        panel.setContentSize(Self.panelSize)
        panel.center()
        panel.orderFrontRegardless()
        panel.makeKey()
    }
}

extension Notification.Name {
    static let rhinoUnlockChanged = Notification.Name("rhinoUnlockChanged")
}

private struct UnlockRhinoView: View {
    let limitReached: Bool
    let wordsThisWeek: Int
    let isUnlocked: Bool
    let unlock: (String) -> Bool
    let dismiss: () -> Void

    @State private var code = ""
    @State private var status: String?
    @State private var unlocked = false

    /// Typing at ~40 words a minute.
    private var minutesSaved: Int { max(1, wordsThisWeek / 40) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if unlocked || isUnlocked {
                Text("Rhino is unlimited 🦏").font(.title2.bold())
                Text("Thank you. Dictate as much as you like, forever.")
                Spacer(minLength: 0)
                HStack { Spacer(); Button("Done", action: dismiss).buttonStyle(.borderedProminent) }
            } else {
                Text(limitReached ? "You've used this week's free words" : "Rhino Unlimited")
                    .font(.title2.bold())
                Text(limitReached
                     ? "You dictated \(wordsThisWeek.formatted()) words this week, about \(minutesSaved) minutes of typing saved."
                     : "Rhino is free for \(UsageGate.weeklyFreeWords.formatted()) words a week. You've used \(wordsThisWeek.formatted()) this week.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Unlimited forever: $20 once. Otherwise your free words reset Monday.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    NSWorkspace.shared.open(UnlockRhino.buyURL)
                } label: {
                    Text("Get Unlimited for $20").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Already bought it, or have an AppSumo code?")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("RHINO-XXXX-XXXX", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(tryUnlock)
                        Button("Unlock", action: tryUnlock)
                    }
                    if let status {
                        Text(status).font(.caption).foregroundStyle(.red)
                    }
                }
                Spacer(minLength: 0)
                HStack { Spacer(); Button("Not now", action: dismiss) }
            }
        }
        .padding(24)
        .frame(width: UnlockRhino.panelSize.width, height: UnlockRhino.panelSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func tryUnlock() {
        if unlock(code) {
            unlocked = true
            status = nil
        } else {
            status = "That code didn't work. Check it and try again."
        }
    }
}
