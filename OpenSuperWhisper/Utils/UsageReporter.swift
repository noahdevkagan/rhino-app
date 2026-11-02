import Foundation

/// Opt-in anonymous usage counts ("Share anonymous usage stats", Settings → History & Privacy).
///
/// OFF by default. While off, nothing is counted and nothing is sent. While on, Rhino keeps
/// per-day totals on this Mac — words, dictations, seconds dictated — and at most once a
/// day posts the finished days to rhinovoice.app/api/usage with a random install ID that is
/// created on opt-in and deleted on opt-out. Never the words themselves, audio, app names,
/// or anything else. See decisions.md 2026-11-02 and tests/hygiene (the only sanctioned
/// non-download network call, and only when the user turned it on).
@MainActor
final class UsageReporter {
    static let shared = UsageReporter()
    static let endpoint = URL(string: "https://rhinovoice.app/api/usage")!
    /// Keep at most this many unsent days (a Mac offline for a month doesn't grow forever).
    static let maxPendingDays = 30
    static let minInterval: TimeInterval = 24 * 3600

    struct DayCounts: Codable, Equatable {
        var words = 0
        var dictations = 0
        var secondsDictated = 0
    }

    private enum Key {
        static let installId = "usageStats.installId"
        static let pending = "usageStats.pending"
        static let lastAttemptAt = "usageStats.lastAttemptAt"
    }

    private var defaults: UserDefaults { DefaultsStore.current }
    private var inFlight = false

    var isEnabled: Bool { AppPreferences.shared.shareUsageStats }

    /// Settings toggle. On mints a fresh random install ID; off forgets it and every unsent count.
    func setEnabled(_ enabled: Bool) {
        if enabled {
            if defaults.string(forKey: Key.installId) == nil {
                defaults.set(UUID().uuidString.lowercased(), forKey: Key.installId)
            }
        } else {
            defaults.removeObject(forKey: Key.installId)
            defaults.removeObject(forKey: Key.pending)
            defaults.removeObject(forKey: Key.lastAttemptAt)
        }
    }

    /// One finished dictation. No-op while the user hasn't opted in.
    func record(words: Int, seconds: TimeInterval) {
        guard isEnabled, words > 0 else { return }
        var pending = loadPending()
        let day = Self.dayString(Date())
        var counts = pending[day] ?? DayCounts()
        counts.words += words
        counts.dictations += 1
        counts.secondsDictated += max(0, Int(seconds.rounded()))
        pending[day] = counts
        savePending(Self.trimmed(pending))
        sendIfDue()
    }

    /// Sends the finished days (never today, which is still counting) at most once per 24 h,
    /// whatever the outcome — a failed send waits for tomorrow, no retry loop.
    func sendIfDue(now: Date = Date()) {
        guard isEnabled, Self.sendingAllowed, !inFlight,
              let installId = defaults.string(forKey: Key.installId) else { return }
        if let last = defaults.object(forKey: Key.lastAttemptAt) as? Date,
           now.timeIntervalSince(last) < Self.minInterval { return }

        let today = Self.dayString(now)
        let finished = loadPending().filter { $0.key < today }
        guard !finished.isEmpty else { return }

        let payload = Payload(
            installId: installId,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            days: finished.keys.sorted().map { day in
                let c = finished[day]!
                return Payload.Day(day: day, words: c.words, dictations: c.dictations,
                                   secondsDictated: c.secondsDictated)
            })
        guard let body = try? JSONEncoder().encode(payload) else { return }

        defaults.set(now, forKey: Key.lastAttemptAt)
        inFlight = true
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let sentDays = Set(finished.keys)

        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCache = nil
        URLSession(configuration: config).dataTask(with: request) { _, response, _ in
            let ok = ((response as? HTTPURLResponse)?.statusCode ?? 0) / 100 == 2
            Task { @MainActor in
                let reporter = UsageReporter.shared
                reporter.inFlight = false
                // The user may have opted out mid-flight: setEnabled(false) already wiped everything.
                guard ok, reporter.isEnabled else { return }
                var pending = reporter.loadPending()
                for day in sentDays { pending.removeValue(forKey: day) }
                reporter.savePending(pending)
            }
        }.resume()
    }

    // MARK: - Payload & storage

    struct Payload: Encodable {
        struct Day: Encodable {
            let day: String
            let words: Int
            let dictations: Int
            let secondsDictated: Int
        }
        let installId: String
        let appVersion: String
        let osMajor: Int
        let days: [Day]
    }

    /// Dev builds never send unless RHINO_USAGE_STATS_DEV=1 (so they can't pollute the totals).
    static var sendingAllowed: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["RHINO_USAGE_STATS_DEV"] == "1"
        #else
        return true
        #endif
    }

    func loadPending() -> [String: DayCounts] {
        guard let data = defaults.data(forKey: Key.pending),
              let decoded = try? JSONDecoder().decode([String: DayCounts].self, from: data) else { return [:] }
        return decoded
    }

    private func savePending(_ pending: [String: DayCounts]) {
        if pending.isEmpty {
            defaults.removeObject(forKey: Key.pending)
        } else if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: Key.pending)
        }
    }

    nonisolated static func trimmed(_ pending: [String: DayCounts]) -> [String: DayCounts] {
        guard pending.count > maxPendingDays else { return pending }
        let keep = Set(pending.keys.sorted().suffix(maxPendingDays))
        return pending.filter { keep.contains($0.key) }
    }

    /// Local calendar day, "YYYY-MM-DD".
    nonisolated static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
