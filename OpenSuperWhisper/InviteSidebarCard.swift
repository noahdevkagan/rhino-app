import SwiftUI

/// Free users only: a standing "invite friends, get Unlimited" offer in the main window's
/// sidebar, so the referral reward is visible without a popup. Hidden once unlocked.
struct InviteSidebarCard: View {
    @State private var isUnlocked = UnlockRhino.shared.gate.isUnlocked
    @State private var hovered = false

    var body: some View {
        if !isUnlocked {
            Button { ShareRhino.shared.show() } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🦏 Get Unlimited free")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundColor(STheme.textBright)
                    Text("Invite \(ReferralLink.friendsNeeded) friends")
                        .scaledFont(size: 11)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(STheme.accentSoft.opacity(hovered ? 1 : 0.7)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(STheme.accent.opacity(0.35), lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Share your link. When \(ReferralLink.friendsNeeded) friends get Rhino, Unlimited is yours.")
            .onHover { hovered = $0 }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .onReceive(NotificationCenter.default.publisher(for: .rhinoUnlockChanged)) { _ in
                isUnlocked = UnlockRhino.shared.gate.isUnlocked
            }
        }
    }
}
