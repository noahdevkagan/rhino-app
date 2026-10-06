import XCTest
@testable import OpenSuperWhisper

final class ReferralLinkTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "ReferralLinkTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testCodeIsGeneratedOnceAndKept() {
        let defaults = freshDefaults()
        let first = ReferralLink(defaults: defaults).code
        XCTAssertTrue(ReferralLink.isValid(first))
        XCTAssertEqual(ReferralLink(defaults: defaults).code, first)
    }

    func testInvalidStoredCodeIsReplaced() {
        let defaults = freshDefaults()
        defaults.set("NOT-VALID", forKey: "referral.code")
        XCTAssertTrue(ReferralLink.isValid(ReferralLink(defaults: defaults).code))
    }

    func testURLsPointAtTheWebsite() {
        let link = ReferralLink(defaults: freshDefaults())
        XCTAssertEqual(link.inviteURL.absoluteString, "https://rhinovoice.app/r/\(link.code)")
        XCTAssertEqual(link.statusURL.absoluteString, "https://rhinovoice.app/r/\(link.code)/status")
    }

    func testValidation() {
        XCTAssertTrue(ReferralLink.isValid("abcd2345"))
        XCTAssertFalse(ReferralLink.isValid("abcd234"))     // too short
        XCTAssertFalse(ReferralLink.isValid("ABCD2345"))    // uppercase
        XCTAssertFalse(ReferralLink.isValid("abcd2341"))    // 1 is not base32
    }

    func testCodesDiffer() {
        XCTAssertNotEqual(ReferralLink.makeCode(), ReferralLink.makeCode())
    }
}
