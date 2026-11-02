import Combine
import Foundation

/// Opt-in correction sharing ("Help improve accuracy", Settings → History & Privacy).
///
/// OFF by default, and separate from the usage-stats opt-in (UsageReporter) because this one
/// carries words, not counts. The only signal is the "Fix a word" sheet: the word Rhino wrote and
/// what the user said it should be. Nothing else is watched — no keystrokes in other apps, no
/// diffing of history edits, never audio, never the rest of the dictation, never app names.
///
/// Each pair is capped at 5 words a side and dropped entirely if either side looks like
/// an email, a URL, a number of 4+ digits or a key/token (`CorrectionScrub`). Pairs wait on this Mac
/// where Settings lists them (delete one or all), and go to rhinovoice.app/api/corrections at most
/// once a week with a random install ID of their own. Turning the toggle off deletes the queue,
/// asks the server to delete what this ID already shared, and forgets the ID.
///
/// Pairs taught on 3+ different Macs flow back into the bundled CommonCorrections.json via the
/// weekly improvement PR (Scripts/improve). See decisions.md 2026-11-02 and tests/hygiene.
@MainActor
final class CorrectionReporter: ObservableObject {
    static let shared = CorrectionReporter()
    static let endpoint = URL(string: "https://rhinovoice.app/api/corrections")!
    static let maxQueued = 200
    static let minInterval: TimeInterval = 7 * 24 * 3600

    struct Item: Codable, Identifiable, Equatable {
        var id = UUID()
        let heard: String
        let corrected: String
        let engine: String
        let model: String
        let language: String
        var addedAt = Date()
    }

    private enum Key {
        static let installId = "corrections.installId"
        static let queue = "corrections.queue"
        static let lastAttemptAt = "corrections.lastAttemptAt"
    }

    @Published private(set) var queue: [Item] = []

    private var defaults: UserDefaults { DefaultsStore.current }
    private var inFlight = false

    private init() {
        queue = loadQueue()
    }

    var isEnabled: Bool { AppPreferences.shared.shareCorrections }

    /// Settings toggle. On mints a fresh random install ID (not the usage-stats one). Off deletes
    /// the queue, asks the server to delete this ID's pairs, and forgets the ID.
    func setEnabled(_ enabled: Bool) {
        if enabled {
            if defaults.string(forKey: Key.installId) == nil {
                defaults.set(UUID().uuidString.lowercased(), forKey: Key.installId)
            }
            return
        }
        if let installId = defaults.string(forKey: Key.installId), Self.sendingAllowed {
            requestServerDeletion(installId: installId)
        }
        defaults.removeObject(forKey: Key.installId)
        defaults.removeObject(forKey: Key.lastAttemptAt)
        deleteAll()
    }

    /// One "Fix a word" correction. No-op while the user hasn't opted in or the pair is unsafe.
    func record(heard: String, corrected: String, model: String?) {
        guard isEnabled,
              let pair = CorrectionScrub.scrubbed(heard: heard, corrected: corrected) else { return }
        let prefs = AppPreferences.shared
        let item = Item(heard: pair.heard, corrected: pair.corrected,
                        engine: CorrectionScrub.label(prefs.selectedEngine),
                        model: CorrectionScrub.label(model ?? ""),
                        language: CorrectionScrub.languageCode(prefs.whisperLanguage))
        // The same fix taught twice is still one fix.
        guard !queue.contains(where: {
            $0.heard.caseInsensitiveCompare(item.heard) == .orderedSame && $0.corrected == item.corrected
        }) else { return }
        queue.append(item)
        if queue.count > Self.maxQueued { queue.removeFirst(queue.count - Self.maxQueued) }
        saveQueue()
        sendIfDue()
    }

    func delete(_ id: Item.ID) {
        queue.removeAll { $0.id == id }
        saveQueue()
    }

    func deleteAll() {
        queue = []
        saveQueue()
    }

    /// Sends the queue at most once a week, whatever the outcome — a failed send waits for next
    /// week, no retry loop.
    func sendIfDue(now: Date = Date()) {
        guard isEnabled, Self.sendingAllowed, !inFlight, !queue.isEmpty,
              let installId = defaults.string(forKey: Key.installId) else { return }
        if let last = defaults.object(forKey: Key.lastAttemptAt) as? Date,
           now.timeIntervalSince(last) < Self.minInterval { return }

        let batch = Array(queue.prefix(100))
        let payload = Payload(
            installId: installId,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            items: batch.map {
                Payload.Pair(heard: $0.heard, corrected: $0.corrected,
                             engine: $0.engine, model: $0.model, language: $0.language)
            })
        guard let body = try? JSONEncoder().encode(payload) else { return }

        defaults.set(now, forKey: Key.lastAttemptAt)
        inFlight = true
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let sentIds = Set(batch.map(\.id))

        Self.session().dataTask(with: request) { _, response, _ in
            let ok = ((response as? HTTPURLResponse)?.statusCode ?? 0) / 100 == 2
            Task { @MainActor in
                let reporter = CorrectionReporter.shared
                reporter.inFlight = false
                // The user may have opted out mid-flight: setEnabled(false) already wiped the queue.
                guard ok, reporter.isEnabled else { return }
                reporter.queue.removeAll { sentIds.contains($0.id) }
                reporter.saveQueue()
            }
        }.resume()
    }

    private func requestServerDeletion(installId: String) {
        var components = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "installId", value: installId)]
        guard let url = components.url else { return }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "DELETE"
        Self.session().dataTask(with: request) { _, _, _ in }.resume()
    }

    // MARK: - Payload

    struct Payload: Encodable {
        struct Pair: Encodable {
            let heard: String
            let corrected: String
            let engine: String
            let model: String
            let language: String
        }
        let installId: String
        let appVersion: String
        let items: [Pair]
    }

    /// Dev builds never send unless RHINO_CORRECTIONS_DEV=1 (so they can't pollute the data).
    static var sendingAllowed: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["RHINO_CORRECTIONS_DEV"] == "1"
        #else
        return true
        #endif
    }

    private static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCache = nil
        return URLSession(configuration: config)
    }

    // MARK: - Storage

    private func loadQueue() -> [Item] {
        guard let data = defaults.data(forKey: Key.queue),
              let decoded = try? JSONDecoder().decode([Item].self, from: data) else { return [] }
        return decoded
    }

    private func saveQueue() {
        if queue.isEmpty {
            defaults.removeObject(forKey: Key.queue)
        } else if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: Key.queue)
        }
    }
}

/// What may leave this Mac from a "Fix a word" pair. Pure, so tests and the server mirror
/// (website/app/_lib/corrections.ts) can hold it to the same rules.
enum CorrectionScrub {
    static let maxWords = 5
    static let maxChars = 60

    /// A pair that is safe to share, or nil. Whitespace is collapsed; each side must hold a
    /// letter, stay within `maxWords` words and `maxChars` characters, and look like nothing
    /// personal. Unsafe pairs are dropped whole rather than redacted: half a pair teaches nothing.
    static func scrubbed(heard: String, corrected: String) -> (heard: String, corrected: String)? {
        let heard = collapse(heard)
        let corrected = collapse(corrected)
        guard heard != corrected, isShareable(heard), isShareable(corrected) else { return nil }
        return (heard, corrected)
    }

    static func isShareable(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= maxChars,
              text.rangeOfCharacter(from: .letters) != nil,
              text.split(separator: " ").count <= maxWords else { return false }
        return !looksPersonal(text)
    }

    static let personalPatterns: [NSRegularExpression] = [
        #"[^\s@]+@[^\s@]+\.[^\s@]+"#,                        // email
        #"(?i)\b(https?://|www\.)"#,                         // URL
        #"(?i)\b[a-z0-9-]+\.(com|net|org|io|app|ai|co|dev|me|us|uk|de)\b"#, // bare domain
        #"\d[\d\s.,-]{2,}\d"#,                               // 4+ digits, even with separators
        #"\d{4,}"#,                                          // 4+ digits
        #"(?i)\b(sk|pk|rk|ghp|gho|xox[abp]|akia)[-_][A-Za-z0-9]"#,  // well-known key prefixes
        #"[A-Za-z0-9_\-]{24,}"#,                             // long token (24+: real words stop sooner)
        #"\b(?=[A-Za-z0-9]*\d)(?=[A-Za-z0-9]*[A-Za-z])[A-Za-z0-9]{12,}\b"#, // mixed letters+digits ≥12
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    static func looksPersonal(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return personalPatterns.contains { $0.firstMatch(in: text, range: range) != nil }
    }

    static func collapse(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Engine/model labels: a short slug or empty — never a file path or a user-typed name.
    static func label(_ raw: String) -> String {
        let name = (raw as NSString).lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        guard !name.isEmpty, name.count <= 40,
              name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return "" }
        return name
    }

    /// "en", "pt-BR", "auto" — anything else becomes empty.
    static func languageCode(_ raw: String) -> String {
        raw.range(of: #"^([a-z]{2,3}(-[A-Za-z]{2,4})?|auto)$"#, options: .regularExpression) != nil ? raw : ""
    }
}
