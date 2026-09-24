import Foundation

/// Local milestones only: no transcript, recipient list, or referral tracking.
struct SharePromptPolicy {
    static let threshold = 5
    let defaults: UserDefaults

    var isEligible: Bool {
        defaults.integer(forKey: "sharing.successfulDictations") >= Self.threshold
            && !defaults.bool(forKey: "sharing.didPresent")
    }

    func recordSuccessfulDictation() {
        let count = defaults.integer(forKey: "sharing.successfulDictations")
        defaults.set(min(Self.threshold, max(0, count) + 1),
                     forKey: "sharing.successfulDictations")
    }

    func markPresented() {
        defaults.set(true, forKey: "sharing.didPresent")
    }
}
