import XCTest
@testable import OpenSuperWhisper

/// The bundled CommonCorrections.json (maintained by the weekly improvement PR) must load, every
/// pair in it must actually fix its own example, and the user's dictionary must always win.
final class CommonCorrectionsTests: XCTestCase {
    private struct File: Decodable {
        struct Pair: Decodable { let heard: String; let corrected: String }
        let version: Int
        let entries: [Pair]
    }

    private func bundledFile() throws -> (Data, File) {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "CommonCorrections", withExtension: "json"),
                                "CommonCorrections.json is missing from the app bundle")
        let data = try Data(contentsOf: url)
        return (data, try JSONDecoder().decode(File.self, from: data))
    }

    /// Regression replay: each learned pair, said in a sentence, comes out corrected.
    func testEveryBundledPairFixesItsOwnExample() throws {
        let (data, file) = try bundledFile()
        let rules = CommonCorrections.entries(fromJSON: data)
        for pair in file.entries {
            let fixed = CommonCorrections.apply("we use \(pair.heard) daily", userEntries: [], bundled: rules)
            XCTAssertEqual(fixed, "we use \(pair.corrected) daily", "\(pair.heard) → \(pair.corrected)")
        }
    }

    func testBundledPairsAreShareableShaped() throws {
        let (_, file) = try bundledFile()
        for pair in file.entries {
            XCTAssertNotNil(CorrectionScrub.scrubbed(heard: pair.heard, corrected: pair.corrected),
                            "bundled pair \(pair.heard) → \(pair.corrected) fails the share scrub")
        }
    }

    func testAppliesAndUserRuleWins() {
        let json = #"{"version":1,"entries":[{"heard":"Clavio","corrected":"Klaviyo"},{"heard":"git hub","corrected":"GitHub"}]}"#
        let rules = CommonCorrections.entries(fromJSON: Data(json.utf8))
        XCTAssertEqual(CommonCorrections.apply("Clavio and git hub", userEntries: [], bundled: rules),
                       "Klaviyo and GitHub")

        let mine = [CustomDictionaryEntry(original: "Clavio", replacement: "Claudio")]
        XCTAssertEqual(CommonCorrections.apply("Clavio and git hub", userEntries: mine, bundled: rules),
                       "Clavio and GitHub", "a bundled rule must step aside for the user's own phrasing")
    }

    func testBadJSONIsEmpty() {
        XCTAssertTrue(CommonCorrections.entries(fromJSON: Data("nope".utf8)).isEmpty)
        let selfGrowing = #"{"version":1,"entries":[{"heard":"noah","corrected":"noah kagan"}]}"#
        XCTAssertTrue(CommonCorrections.entries(fromJSON: Data(selfGrowing.utf8)).isEmpty,
                      "rules that grow on a second pass are not safe to bundle")
    }
}
