import XCTest
@testable import OpenSuperWhisper

/// US → British spelling (Steve, 2026-10-21: "capitalize" with a Z next to "colour").
/// Pure text logic in `BritishSpelling.apply`.
final class BritishSpellingTests: XCTestCase {

    func testCommonWords() {
        XCTAssertEqual(BritishSpelling.apply("I realized the color of the center was gray."),
                       "I realised the colour of the centre was grey.")
        XCTAssertEqual(BritishSpelling.apply("We traveled to organize a catalog of our favorite flavors."),
                       "We travelled to organise a catalogue of our favourite flavours.")
        XCTAssertEqual(BritishSpelling.apply("capitalize, capitalizing, capitalization"),
                       "capitalise, capitalising, capitalisation")
        XCTAssertEqual(BritishSpelling.apply("The analyzer analyzed the defense."),
                       "The analyser analysed the defence.")
        XCTAssertEqual(BritishSpelling.apply("It was centered and canceled."),
                       "It was centred and cancelled.")
    }

    func testCapitalAtSentenceStartFollowsTheWord() {
        XCTAssertEqual(BritishSpelling.apply("Color matters. Organize it!\nHonor them."),
                       "Colour matters. Organise it!\nHonour them.")
    }

    func testLookalikesStay() {
        // Same in both, or "-our" words that drop the "u" before -ous.
        XCTAssertEqual(BritishSpelling.apply("Resize the prize to size; seize the doctor's humorous error."),
                       "Resize the prize to size; seize the doctor's humorous error.")
        // Meaning-dependent splits are left alone.
        XCTAssertEqual(BritishSpelling.apply("Check the program license."),
                       "Check the program license.")
    }

    func testNamesMidSentenceStay() {
        XCTAssertEqual(BritishSpelling.apply("We visited Pearl Harbor and the Lincoln Center."),
                       "We visited Pearl Harbor and the Lincoln Center.")
        XCTAssertEqual(BritishSpelling.apply("Ask the World Health Organization."),
                       "Ask the World Health Organization.")
        XCTAssertEqual(BritishSpelling.apply("The COLOR code"), "The COLOR code")
    }

    func testDictionaryWordsStay() {
        XCTAssertEqual(BritishSpelling.apply("color and labor", keep: ["color"]), "color and labour")
    }

    func testPunctuationAndSpacingUntouched() {
        XCTAssertEqual(BritishSpelling.apply("  color-coded (favorite's)  "), "  colour-coded (favourite's)  ")
        XCTAssertEqual(BritishSpelling.apply(""), "")
    }
}
