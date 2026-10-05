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

    func show(limitReached: Bool = false) {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: Self.panelSize),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            panel.title = "Rhino Unlimited"
            panel.isReleasedWhenClosed = false
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
        // The code field needs keyboard focus, so this panel does activate Rhino.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
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
