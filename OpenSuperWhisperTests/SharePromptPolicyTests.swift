import XCTest
@testable import OpenSuperWhisper

final class SharePromptPolicyTests: XCTestCase {
    func testFifthSuccessMakesPromptEligibleAcrossRelaunch() {
        withPolicy { policy in
            for _ in 0..<4 { policy.recordSuccessfulDictation() }
            XCTAssertFalse(policy.isEligible)
            policy.recordSuccessfulDictation()
            XCTAssertTrue(SharePromptPolicy(defaults: policy.defaults).isEligible)
        }
    }

    func testPresentationSuppressesFuturePromptsAcrossRelaunch() {
        withPolicy { policy in
            for _ in 0..<5 { policy.recordSuccessfulDictation() }
            policy.markPresented()
            let relaunched = SharePromptPolicy(defaults: policy.defaults)
            for _ in 0..<10 { relaunched.recordSuccessfulDictation() }
            XCTAssertFalse(relaunched.isEligible)
        }
    }

    func testOpeningFromMenuBeforeMilestoneSuppressesAutomaticPrompt() {
        withPolicy { policy in
            policy.markPresented()
            for _ in 0..<5 { policy.recordSuccessfulDictation() }
            XCTAssertFalse(policy.isEligible)
        }
    }

    private func withPolicy(_ body: (SharePromptPolicy) -> Void) {
        let suite = "SharePromptPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(SharePromptPolicy(defaults: defaults))
    }
}
