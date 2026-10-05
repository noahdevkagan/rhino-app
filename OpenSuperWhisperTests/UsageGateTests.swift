import XCTest
@testable import OpenSuperWhisper

final class UsageGateTests: XCTestCase {
    // Wednesday 2026-10-07 12:00 UTC.
    private let wednesday = Date(timeIntervalSince1970: 1_791_374_400)

    func testOnboardedInstallIsGrandfathered() {
        withGate { gate in
            gate.bootstrap(hasCompletedOnboarding: true)
            XCTAssertTrue(gate.isUnlocked)
        }
    }

    func testBootstrapOnlyRunsOnceSoLaterOnboardingDoesNotUnlock() {
        withGate { gate in
            gate.bootstrap(hasCompletedOnboarding: false)
            gate.bootstrap(hasCompletedOnboarding: true)
            XCTAssertFalse(gate.isUnlocked)
        }
    }

    func testFirstWeekIsUnlimited() {
        withGate { gate in
            gate.bootstrap(hasCompletedOnboarding: false)
            gate.record(words: 10_000)
            XCTAssertTrue(gate.isInTrial)
            XCTAssertFalse(gate.isBlocked)
        }
    }

    func testBlocksAtWeeklyLimitAfterTrialAndResetsMonday() {
        withGate { gate in
            var gate = gate
            gate.bootstrap(hasCompletedOnboarding: false)
            gate.now = { self.wednesday.addingTimeInterval(8 * 86_400) }
            gate.record(words: 1_999)
            XCTAssertFalse(gate.isBlocked)
            gate.record(words: 1)
            XCTAssertTrue(gate.isBlocked)
            gate.now = { self.wednesday.addingTimeInterval(13 * 86_400) }
            XCTAssertEqual(gate.wordsThisWeek, 0)
            XCTAssertFalse(gate.isBlocked)
        }
    }

    func testPurchaseAndAppSumoCodesUnlock() {
        withGate { gate in
            XCTAssertFalse(gate.unlock(code: "RHINO-NOPE-NOPE", appSumoHashes: []))
            XCTAssertFalse(gate.isUnlocked)
            let appSumo = UsageGate.sha256("RH-AAAA-BBBB-CCCC")
            XCTAssertTrue(gate.unlock(code: " rh-aaaa-bbbb-cccc ", appSumoHashes: [appSumo]))
            XCTAssertTrue(gate.isUnlocked)
        }
    }

    func testBundledPurchaseHashIsWellFormed() {
        XCTAssertEqual(UsageGate.purchaseCodeHash.count, 64)
    }

    func testWordCount() {
        XCTAssertEqual(UsageGate.wordCount("  Hey team,\nquick update. "), 4)
        XCTAssertEqual(UsageGate.wordCount(""), 0)
    }

    private func withGate(_ body: (UsageGate) -> Void) {
        let suite = "UsageGateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(UsageGate(defaults: defaults, now: { self.wednesday }))
    }
}
