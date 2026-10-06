import Foundation
import Security

/// "Invite 2 friends, get Unlimited free." Each install gets a random code; friends who
/// click through rhinovoice.app/r/<code> are counted by the website, and the status page
/// shows the unlock link once two have. The app itself never contacts the site: it
/// only builds the URLs, and the user opens them in their browser.
struct ReferralLink {
    static let friendsNeeded = 2
    static let alphabet = Array("abcdefghijklmnopqrstuvwxyz234567")
    private static let key = "referral.code"

    let defaults: UserDefaults

    /// Stable per install: generated on first use, then kept.
    var code: String {
        if let existing = defaults.string(forKey: Self.key), Self.isValid(existing) { return existing }
        let fresh = Self.makeCode()
        defaults.set(fresh, forKey: Self.key)
        return fresh
    }

    var inviteURL: URL { URL(string: "https://rhinovoice.app/r/\(code)")! }
    var statusURL: URL { URL(string: "https://rhinovoice.app/r/\(code)/status")! }

    /// Must match isReferralCode in website/app/_lib/referrals.ts.
    static func isValid(_ code: String) -> Bool {
        code.count == 8 && code.allSatisfy { alphabet.contains($0) }
    }

    static func makeCode() -> String {
        var bytes = [UInt8](repeating: 0, count: 8)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<8).map { _ in UInt8.random(in: 0...255) }
        }
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }
}
