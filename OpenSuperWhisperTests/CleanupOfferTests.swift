import XCTest

@testable import OpenSuperWhisper

/// AI cleanup is on by default but its model downloads only on a click, offered from Home
/// once earned. These pin when the offer is earned and that "Not now" sticks.
final class CleanupOfferTests: XCTestCase {
    private let keys = ["aiPostProcessingEnabled", "cleanupOfferDictations",
                        "cleanupOfferEarned", "cleanupOfferDismissed"]

    override func setUp() {
        super.setUp()
        keys.forEach { DefaultsStore.current.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { DefaultsStore.current.removeObject(forKey: $0) }
        super.tearDown()
    }

    func testCleanupIsOnByDefault() {
        XCTAssertTrue(AppPreferences.shared.aiPostProcessingEnabled)
    }

    func testOfferIsEarnedAfterAHandfulOfPlainDictations() {
        for _ in 1..<CleanupOffer.dictationsBeforeOffer {
            CleanupOffer.noteDictation("Let's meet at the usual place.")
        }
        XCTAssertFalse(AppPreferences.shared.cleanupOfferEarned)
        CleanupOffer.noteDictation("Let's meet at the usual place.")
        XCTAssertTrue(AppPreferences.shared.cleanupOfferEarned)
    }

    func testFirstListOrEmailEarnsTheOfferAtOnce() {
        CleanupOffer.noteDictation("Hi Sam, the deck is ready. Thanks, Noah")
        XCTAssertTrue(AppPreferences.shared.cleanupOfferEarned)
    }

    func testOfferStaysHiddenUntilEarned() {
        XCTAssertFalse(CleanupOffer.shouldShow)
    }

    func testNotNowAndCleanupOffBothHideTheOffer() throws {
        try XCTSkipIf(LLMModelManager.shared.isDefaultModelDownloaded(),
                      "the model is on disk here, so the offer never shows")
        AppPreferences.shared.cleanupOfferEarned = true
        XCTAssertTrue(CleanupOffer.shouldShow)

        AppPreferences.shared.aiPostProcessingEnabled = false
        XCTAssertFalse(CleanupOffer.shouldShow, "someone who turned cleanup off is not asked")

        AppPreferences.shared.aiPostProcessingEnabled = true
        AppPreferences.shared.cleanupOfferDismissed = true
        XCTAssertFalse(CleanupOffer.shouldShow, "Not now hides it for good")
    }
}
