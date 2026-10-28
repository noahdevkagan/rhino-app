import XCTest
@testable import OpenSuperWhisper

/// Context-aware casing at insertion time (customer reports 2026-10-21 to 10-27: phrases
/// dictated mid-sentence came out capitalized with a stray period, and single values typed
/// into a spreadsheet got a period each). The AX read is environment-dependent and verified by
/// hand; this covers the pure decision in `ContextCasing.apply`.
final class ContextCasingTests: XCTestCase {

    private func fit(_ text: String, before: String?, after: String? = "",
                     spoken: Bool = false,
                     properNouns: Set<String> = []) -> String {
        ContextCasing.apply(text: text, before: before, after: after,
                            spokenTrailingMark: spoken,
                            isProperNoun: { properNouns.contains($0) })
    }

    // MARK: - Mid-sentence casing

    func testMidSentenceLowercasesAndDropsPeriod() {
        // "The quick | jumps" + "Brown fox." → "The quick brown fox jumps"
        XCTAssertEqual(fit("Brown fox. ", before: "The quick ", after: " j"), "brown fox")
    }

    func testMidSentenceAddsLeadingSpaceWhenCaretTouchesWord() {
        XCTAssertEqual(fit("Brown fox.", before: "The quick", after: " j"), " brown fox")
    }

    func testMidSentenceAddsTrailingSpaceWhenWordFollowsDirectly() {
        XCTAssertEqual(fit("Brown fox.", before: "The quick ", after: "ju"), "brown fox ")
    }

    func testMidSentenceDropsStrayComma() {
        XCTAssertEqual(fit("Brown fox,", before: "The quick ", after: " j"), "brown fox")
    }

    func testMidSentenceAtEndOfTextKeepsPeriodOfLongDictation() {
        // Finishing a sentence: lowercase, but the period of a real sentence stays.
        XCTAssertEqual(fit("Went to the store today.", before: "Yesterday I ", after: ""),
                       "went to the store today.")
    }

    func testPronounIUntouched() {
        XCTAssertEqual(fit("I think so.", before: "and then ", after: " b"), "I think so")
        XCTAssertEqual(fit("I'm not sure", before: "and then ", after: ""), "I'm not sure")
        XCTAssertEqual(fit("I'll check", before: "and then ", after: ""), "I'll check")
    }

    func testAcronymUntouched() {
        XCTAssertEqual(fit("NASA launched it", before: "and ", after: ""), "NASA launched it")
        XCTAssertEqual(fit("iPhone users", before: "for ", after: ""), "iPhone users")
        XCTAssertEqual(fit("McDonald said", before: "and ", after: ""), "McDonald said")
    }

    func testProperNounUntouched() {
        XCTAssertEqual(fit("Steve said hi", before: "and ", after: "", properNouns: ["Steve"]),
                       "Steve said hi")
        XCTAssertEqual(fit("Monday works", before: "maybe ", after: ""), "Monday works")
    }

    func testArticleALowercased() {
        XCTAssertEqual(fit("A big dog", before: "there was ", after: ""), "a big dog")
    }

    // MARK: - Sentence starts stay capitalized

    func testStartOfFieldUntouched() {
        XCTAssertEqual(fit("Hello there, how are you.", before: "", after: ""),
                       "Hello there, how are you.")
    }

    func testAfterSentenceEndUntouched() {
        XCTAssertEqual(fit("Next we ship it. ", before: "That works. ", after: ""), "Next we ship it. ")
        XCTAssertEqual(fit("Really we should go.", before: "Are you sure? ", after: ""),
                       "Really we should go.")
    }

    func testAfterSentenceEndWithoutSpaceGetsOne() {
        XCTAssertEqual(fit("Next we ship it.", before: "That works.", after: ""), " Next we ship it.")
    }

    func testAfterQuotedSentenceEndUntouched() {
        XCTAssertEqual(fit("Then she left early.", before: "He said \"Bye.\" ", after: ""),
                       "Then she left early.")
    }

    func testNewLineAndListMarkerUntouched() {
        XCTAssertEqual(fit("Buy milk today", before: "Notes:\n", after: ""), "Buy milk today")
        XCTAssertEqual(fit("Buy milk today", before: "- ", after: ""), "Buy milk today")
        XCTAssertEqual(fit("Buy milk today", before: "Todo\n2. ", after: ""), "Buy milk today")
    }

    // MARK: - Short dictations (field values)

    func testSingleWordDropsPeriod() {
        XCTAssertEqual(fit("Approved.", before: "", after: ""), "Approved")
    }

    func testNumberDropsPeriodAndTrailingSpace() {
        XCTAssertEqual(fit("42. ", before: "", after: ""), "42")
        XCTAssertEqual(fit("October 21st.", before: "", after: ""), "October 21st")
    }

    func testShortSentenceBeforeMoreTextKeepsPeriod() {
        // "Done. | More" is between two sentences, not a field value.
        XCTAssertEqual(fit("Next one.", before: "Done. ", after: " M"), "Next one.")
    }

    func testFourWordsKeepPeriodAtStart() {
        XCTAssertEqual(fit("This is a sentence.", before: "", after: ""), "This is a sentence.")
    }

    func testSpokenPeriodKept() {
        XCTAssertEqual(fit("Approved.", before: "", after: "", spoken: true), "Approved.")
        XCTAssertEqual(fit("Brown fox.", before: "The quick ", after: " j", spoken: true), "brown fox.")
    }

    func testQuestionAndExclamationKept() {
        XCTAssertEqual(fit("Really?", before: "", after: ""), "Really?")
        XCTAssertEqual(fit("Done!", before: "", after: ""), "Done!")
        XCTAssertEqual(fit("Wait...", before: "", after: ""), "Wait...")
    }

    func testDecimalsAndAbbreviationsKept() {
        XCTAssertEqual(fit("3.5", before: "", after: ""), "3.5")
        XCTAssertEqual(fit("3.5.", before: "", after: ""), "3.5")
        XCTAssertEqual(fit("The U.S.", before: "", after: ""), "The U.S.")
        XCTAssertEqual(fit("Dr.", before: "", after: ""), "Dr.")
        XCTAssertEqual(fit("John F.", before: "", after: ""), "John F.")
    }

    // MARK: - No context

    func testAXUnavailableLeavesTextUnchanged() {
        XCTAssertEqual(fit("Brown fox. ", before: nil, after: nil), "Brown fox. ")
        XCTAssertEqual(fit("42.", before: nil, after: nil), "42.")
    }

    func testUnknownAfterNeverDropsPeriodMidSentenceForLongText() {
        XCTAssertEqual(fit("Went to the store today.", before: "so I ", after: nil),
                       "went to the store today.")
    }

    // MARK: - Spacing

    func testNoDoubleSpace() {
        XCTAssertEqual(fit(" Brown fox", before: "The quick ", after: ""), "brown fox")
        XCTAssertEqual(fit("Next one. ", before: "Done. ", after: " More"), "Next one.")
    }

    func testNoSpaceAfterOpeningParenOrForCJK() {
        XCTAssertEqual(fit("Brown fox", before: "the (", after: ")"), "brown fox")
        XCTAssertEqual(fit("你好", before: "我说", after: ""), "你好")
    }

    // MARK: - Spoken mark detection

    func testEndsWithSpokenMark() {
        XCTAssertTrue(ContextCasing.endsWithSpokenMark("I had salmon for dinner period"))
        XCTAssertTrue(ContextCasing.endsWithSpokenMark("Approved. Period."))
        XCTAssertFalse(ContextCasing.endsWithSpokenMark("Approved."))
        XCTAssertFalse(ContextCasing.endsWithSpokenMark("Check the billing period."))
    }
}
