import CryptoKit
import Foundation

/// Free tier: unlimited for the first week, then 2,000 dictated words per week
/// (resets Monday). A purchase or AppSumo code unlocks it for good.
///
/// Local-only and honor-based on purpose: counts live in preferences, codes are
/// checked against bundled SHA-256 hashes, nothing is sent anywhere. Installs
/// that finished onboarding before the free tier shipped are grandfathered.
struct UsageGate {
    static let weeklyFreeWords = 2_000
    static let trialDays = 7
    /// SHA-256 of the normalized code shown on rhinovoice.app/thanks after purchase.
    static let purchaseCodeHash = "4b1d3fee45d3af53cb92b7fd6784206da8b48fde6570c58c4225ab157fdcb4b9"

    let defaults: UserDefaults
    var now: () -> Date = Date.init

    private enum Key {
        static let installedAt = "usage.installedAt"
        static let unlocked = "usage.unlocked"
        static let weekStart = "usage.weekStart"
        static let weekWords = "usage.weekWords"
    }

    /// Runs once per install, at launch. An install that already completed
    /// onboarding predates the free tier, so it was paid for: unlock it.
    func bootstrap(hasCompletedOnboarding: Bool) {
        guard defaults.object(forKey: Key.installedAt) == nil else { return }
        defaults.set(now(), forKey: Key.installedAt)
        if hasCompletedOnboarding { defaults.set(true, forKey: Key.unlocked) }
    }

    var isUnlocked: Bool { defaults.bool(forKey: Key.unlocked) }

    var isInTrial: Bool {
        guard let installedAt = defaults.object(forKey: Key.installedAt) as? Date else { return true }
        return now().timeIntervalSince(installedAt) < Double(Self.trialDays) * 86_400
    }

    var wordsThisWeek: Int {
        guard let start = defaults.object(forKey: Key.weekStart) as? Date,
              start == Self.weekStart(for: now()) else { return 0 }
        return defaults.integer(forKey: Key.weekWords)
    }

    /// True when a new dictation should be refused. A dictation already in
    /// progress always finishes; only the next one is blocked.
    var isBlocked: Bool {
        !isUnlocked && !isInTrial && wordsThisWeek >= Self.weeklyFreeWords
    }

    func record(words: Int) {
        guard words > 0 else { return }
        let total = wordsThisWeek + words
        defaults.set(Self.weekStart(for: now()), forKey: Key.weekStart)
        defaults.set(total, forKey: Key.weekWords)
    }

    /// Returns true and unlocks when the code is the purchase code or an AppSumo code.
    @discardableResult
    func unlock(code: String, appSumoHashes: Set<String>) -> Bool {
        let normalized = Self.normalize(code)
        guard !normalized.isEmpty else { return false }
        let digest = Self.sha256(normalized)
        guard digest == Self.purchaseCodeHash || appSumoHashes.contains(digest) else { return false }
        defaults.set(true, forKey: Key.unlocked)
        return true
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Same normalization as the website's AppSumo redeem form.
    static func normalize(_ code: String) -> String {
        code.uppercased().filter { !$0.isWhitespace }
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Monday 00:00 local time of the week containing `date`.
    static func weekStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    /// Bundled AppSumo code hashes (the same list the website's redeem form uses).
    static func loadAppSumoHashes(bundle: Bundle = .main) -> Set<String> {
        guard let url = bundle.url(forResource: "appsumo-hashes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let hashes = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(hashes)
    }
}
