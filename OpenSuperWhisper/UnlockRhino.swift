import AppKit
import SwiftUI

/// Free-tier paywall: shown when the weekly free words run out, or from the menu bar.
@MainActor
final class UnlockRhino {
    static let shared = UnlockRhino()
    static let buyURL = URL(string: "https://rhinovoice.app/#buy")!
    static let panelSize = NSSize(width: 420, height: 380)
    static let promptSize = NSSize(width: 420, height: 210)

    private var panel: NSPanel?
    private lazy var appSumoHashes = UsageGate.loadAppSumoHashes()
    var gate: UsageGate { UsageGate(defaults: DefaultsStore.current) }

    func bootstrap() {
        gate.bootstrap(hasCompletedOnboarding: AppPreferences.shared.hasCompletedOnboarding)
    }

    /// Called on the trigger key. Returns false (and shows the paywall) when the
    /// free words for this week are used up.
    var recordingBlocked: Bool { gate.isBlocked }

    /// The cursor bubble is the proven way to reach a user over any app; the panel
    /// carries the buy button and code field.
    func showRecordingBlocked() {
        IndicatorWindowManager.shared.flash(.info("Free words used up this week. Rhino menu → Get Rhino Unlimited"))
        show(limitReached: true)
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
        gate.markCodePromptShown()
        IndicatorWindowManager.shared.flash(gate.isUnlocked
            ? .info("Rhino is unlimited 🦏")
            : .error("That unlock code didn't work. Rhino menu → Get Rhino Unlimited"))
        show()
    }

    /// One-time "Have an unlock code?" ask: a moment after launch (so a rhinovoice://unlock
    /// link that opened the app is handled first) or right after onboarding finishes. Never during
    /// onboarding, never for unlocked or grandfathered installs.
    ///
    /// Launches are often in the background (login item, update relaunch) while the user types
    /// elsewhere, so this panel never takes key focus on its own: clicking the field makes it key.
    func showCodePromptIfNeeded() {
        guard !DefaultsStore.isRunningTests,
              ProcessInfo.processInfo.environment["RHINO_PREFS_SUITE"] == nil,
              gate.shouldOfferCodePrompt(hasCompletedOnboarding: AppPreferences.shared.hasCompletedOnboarding),
              panel?.isVisible != true else { return }
        gate.markCodePromptShown()
        present(title: "Rhino", size: Self.promptSize, takeFocus: false, rootView: AppSumoCodePromptView(
            unlock: { [weak self] code in self?.unlock(code: code) ?? false },
            dismiss: { [weak self] in self?.panel?.orderOut(nil) }))
    }

    /// `focusCode`: opened from "Enter unlock code…", so the cursor starts in the code field.
    func show(limitReached: Bool = false, focusCode: Bool = false) {
        present(title: "Rhino Unlimited", size: Self.panelSize, takeFocus: true, rootView: UnlockRhinoView(
            limitReached: limitReached,
            wordsThisWeek: gate.wordsThisWeek,
            isUnlocked: gate.isUnlocked,
            focusCode: focusCode,
            unlock: { [weak self] code in self?.unlock(code: code) ?? false },
            invite: { [weak self] in
                self?.panel?.orderOut(nil)
                ShareRhino.shared.show()
            },
            dismiss: { [weak self] in self?.panel?.orderOut(nil) }))
    }

    /// `takeFocus`: only for panels the user just asked for (menu, paywall, unlock link).
    private func present<V: View>(title: String, size: NSSize, takeFocus: Bool, rootView: V) {
        if panel == nil {
            // Same recipe as the Share panel, which is proven to appear over whatever app
            // is frontmost: a non-activating floating panel that never hides on deactivate.
            // macOS 14+ often refuses to activate a background app, so nothing here may
            // depend on Rhino becoming active. A non-activating panel can still take key
            // focus, so the code field remains typeable.
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            self.panel = panel
        }
        guard let panel else { return }
        panel.title = title
        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = []
        panel.contentViewController = hosting
        panel.setContentSize(size)
        panel.center()
        panel.orderFrontRegardless()
        if takeFocus { panel.makeKey() }
    }
}

extension Notification.Name {
    static let rhinoUnlockChanged = Notification.Name("rhinoUnlockChanged")
}

struct UnlockRhinoView: View {
    let limitReached: Bool
    let wordsThisWeek: Int
    let isUnlocked: Bool
    var focusCode = false
    let unlock: (String) -> Bool
    let invite: () -> Void
    let dismiss: () -> Void

    @State private var unlocked = false

    /// Typing at ~40 words a minute.
    private var minutesSaved: Int { max(1, wordsThisWeek / 40) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if unlocked || isUnlocked {
                Text("Rhino is unlimited 🦏").font(.title2.bold())
                Text("Thank you. Dictate as much as you like, forever.")
                Spacer(minLength: 0)
                HStack { Spacer(); Button("Done", action: dismiss).buttonStyle(PrimaryPillStyle()) }
            } else {
                Text(limitReached ? "You've used this week's free words" : "Rhino Unlimited")
                    .font(.title2.bold())
                Text(limitReached
                     ? "You dictated \(wordsThisWeek.formatted()) words this week, about \(minutesSaved) minutes of typing saved."
                     : "Rhino is free for \(UsageGate.weeklyFreeWords.formatted()) words a week. You've used \(wordsThisWeek.formatted()) this week.")
                    .fixedSize(horizontal: false, vertical: true)

                // First, so AppSumo buyers who already paid see their way in before any price.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Already bought it, or have an AppSumo code?")
                        .font(.subheadline.weight(.semibold))
                    UnlockCodeField(focusOnAppear: focusCode, unlock: unlock) { unlocked = true }
                }

                Divider()

                Text("Unlimited forever: $20 once, or free when \(ReferralLink.friendsNeeded) friends join. Otherwise your free words reset Monday.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    NSWorkspace.shared.open(UnlockRhino.buyURL)
                } label: {
                    Text("Get Unlimited for $20")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(PrimaryPillStyle())
                Button(action: invite) {
                    Text("Or invite \(ReferralLink.friendsNeeded) friends and get it free")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                Spacer(minLength: 0)
                HStack { Spacer(); Button("Not now", action: dismiss) }
            }
        }
        .padding(24)
        .frame(width: UnlockRhino.panelSize.width, height: UnlockRhino.panelSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// One-time first-launch ask for AppSumo buyers who redeemed on the site but never typed the code.
struct AppSumoCodePromptView: View {
    let unlock: (String) -> Bool
    let dismiss: () -> Void

    @State private var unlocked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if unlocked {
                Text("Rhino is unlimited 🦏").font(.title3.bold())
                Text("Thank you. Dictate as much as you like, forever.")
                Spacer(minLength: 0)
                HStack { Spacer(); Button("Done", action: dismiss).buttonStyle(PrimaryPillStyle()) }
            } else {
                Text("Have an unlock code?").font(.title3.bold())
                Text("From AppSumo or your $20 purchase. Enter it to unlock Rhino for good.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                // No auto-focus: the prompt can appear while the user types in another app.
                UnlockCodeField(focusOnAppear: false, unlock: unlock) { unlocked = true }
                Spacer(minLength: 0)
                HStack { Spacer(); Button("Not now", action: dismiss) }
            }
        }
        .padding(20)
        .frame(width: UnlockRhino.promptSize.width, height: UnlockRhino.promptSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Code field + Unlock, shared by the paywall and the first-launch prompt.
private struct UnlockCodeField: View {
    let focusOnAppear: Bool
    let unlock: (String) -> Bool
    let onUnlocked: () -> Void

    @State private var code = ""
    @State private var status: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(UsageGate.codePlaceholder, text: $code)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(tryUnlock)
                Button("Unlock", action: tryUnlock)
            }
            if let status {
                Text(status).font(.caption).foregroundStyle(.red)
            }
        }
        .onAppear {
            // The panel becomes key right after it is shown; focus on the next turn so it sticks.
            guard focusOnAppear else { return }
            DispatchQueue.main.async { focused = true }
        }
    }

    private func tryUnlock() {
        if unlock(code) {
            status = nil
            onUnlocked()
        } else {
            status = "That code didn't work. Check it and try again."
        }
    }
}

/// Always drawn in the accent color. `.borderedProminent` turns grey whenever Rhino isn't the
/// active app, which is always the case here: the panel is non-activating by design.
private struct PrimaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1)))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
