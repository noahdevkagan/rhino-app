import XCTest
@testable import OpenSuperWhisper

final class DictionaryBulkImportTests: XCTestCase {
    func testPastesMixedColumnsAndWindowsLineEndingsWithoutSplittingPhrasesOrCommas() throws {
        let rows = try DictionaryBulkImport.parse("  Klaviyo  \r\n\r\n Acme Labs\takme labs \rJo\tJoe\nACME, Inc.\tacme incorporated\n")
        XCTAssertEqual(rows.map(\.replacement), ["Klaviyo", "Acme Labs", "Jo", "ACME, Inc."])
        XCTAssertEqual(rows.map(\.original), ["", "akme labs", "Joe", "acme incorporated"])
    }

    func testMalformedPasteFailsAsAWholeInsteadOfLosingColumnsOrMissingSpelling() {
        for text in [" \n\t", "Klaviyo\nAcme\twrong\textra", "Klaviyo\n\tmisheard"] {
            XCTAssertThrowsError(try DictionaryBulkImport.parse(text))
        }
    }

    func testWordsWithoutMishearingsRespectActualSoundAlikeEligibilityAndSetting() {
        let eligible = CustomDictionaryEntry(replacement: "Klaviyo")
        XCTAssertNil(DictionaryBulkImport.problem(for: eligible, rows: [eligible], existing: [], soundAlikes: true))
        XCTAssertNotNil(DictionaryBulkImport.problem(for: eligible, rows: [eligible], existing: [], soundAlikes: false))
        for spelling in ["Jo", "Acme Labs", "ACME, Inc.", ""] {
            let row = CustomDictionaryEntry(replacement: spelling)
            XCTAssertNotNil(DictionaryBulkImport.problem(for: row, rows: [row], existing: [], soundAlikes: true))
        }
        let exact = CustomDictionaryEntry(original: "Joe", replacement: "Jo")
        XCTAssertNil(DictionaryBulkImport.problem(for: exact, rows: [exact], existing: [], soundAlikes: false))
    }

    func testExistingShortWordCanBeRepastedWithoutLosingItsCorrection() {
        let existing = CustomDictionaryEntry(original: "Joe", replacement: "Jo")
        let row = CustomDictionaryEntry(replacement: "Jo")
        XCTAssertNil(DictionaryBulkImport.problem(for: row, rows: [row], existing: [existing], soundAlikes: false))
        let result = DictionaryBulkImport.merge([row], into: [existing])
        XCTAssertEqual(result.entries, [existing])
        XCTAssertEqual(result.skipped, 1)
    }

    func testShortWordPastedTwiceTakesItsCorrectionFromTheOtherLine() throws {
        let rows = try DictionaryBulkImport.parse("Jo\tJoe\nJo\nAcme Labs\nAcme Labs\takme labs")
        for row in rows {
            XCTAssertNil(DictionaryBulkImport.problem(for: row, rows: rows, existing: [],
                                                      soundAlikes: true))
        }
        let result = DictionaryBulkImport.merge(rows, into: [])
        XCTAssertEqual(result.entries.map(\.replacement), ["Jo", "Acme Labs"])
        XCTAssertEqual(result.entries.map(\.triggers), [["Joe"], ["akme labs"]])
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.skipped, 1)
    }

    func testImportPreservesIdentityAlternatesAndUnrelatedPunctuationRules() throws {
        let existing = CustomDictionaryEntry(original: "clavio", replacement: "Klaviyo", alternates: ["claviyo"])
        let punctuation = CustomDictionaryEntry(original: "open quote", replacement: "\"", spacing: .attachesRight)
        let rows = try DictionaryBulkImport.parse("Klaviyo\tCLAVIO\nKlaviyo\tklavio\nJo\tJoe\nJo\tjoe")
        let result = DictionaryBulkImport.merge(rows, into: [existing, punctuation])
        XCTAssertEqual(result.entries[0].id, existing.id)
        XCTAssertEqual(result.entries[0].triggers, ["clavio", "claviyo", "klavio"])
        XCTAssertEqual(result.entries[1], punctuation)
        XCTAssertEqual(result.entries.count, 3)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(result.skipped, 2)
        XCTAssertEqual(CustomDictionary.apply("clavio and Joe", entries: result.entries), "Klaviyo and Jo")
    }

    func testImportedRulesForOneWordKeepAllMishearingsAndStayIdempotent() throws {
        let rows = try DictionaryBulkImport.parse("Klaviyo\tclavio\nKlaviyo\tklavio\nKlaviyo")
        let result = DictionaryBulkImport.merge(rows, into: [])
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(result.entries[0].triggers, ["clavio", "klavio"])
        let again = DictionaryBulkImport.merge(rows, into: result.entries)
        XCTAssertEqual(again.entries, result.entries)
        XCTAssertEqual(again.skipped, 3)
    }

    func testConflictingMishearingsAcrossExistingAndImportedRulesAreRejected() {
        let existing = CustomDictionaryEntry(original: "joe", replacement: "Joseph")
        let row = CustomDictionaryEntry(original: "JOE", replacement: "Jo")
        XCTAssertNotNil(DictionaryBulkImport.problem(for: row, rows: [row], existing: [existing], soundAlikes: true))
        XCTAssertNotNil(DictionaryBulkImport.problem(for: row, rows: [row, existing], existing: [], soundAlikes: true))
        let duplicate = CustomDictionaryEntry(original: "joe", replacement: "Jo")
        XCTAssertNil(DictionaryBulkImport.problem(for: row, rows: [row, duplicate], existing: [], soundAlikes: true))
    }

    func testDesiredCapitalizationRemainsMeaningfulAsInExistingDictionaryMerge() {
        let existing = CustomDictionaryEntry(original: "git hub", replacement: "GitHub")
        let row = CustomDictionaryEntry(original: "git hub", replacement: "github")
        XCTAssertNotNil(DictionaryBulkImport.problem(for: row, rows: [row], existing: [existing], soundAlikes: true))
        let different = CustomDictionaryEntry(original: "my github", replacement: "github")
        let result = DictionaryBulkImport.merge([different], into: [existing])
        XCTAssertEqual(result.entries.map(\.replacement), ["GitHub", "github"])
        XCTAssertEqual(result.entries[0], existing)
    }
}
