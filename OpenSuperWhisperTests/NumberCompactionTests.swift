import XCTest
@testable import OpenSuperWhisper

/// The deterministic spoken-number pass. Every case here exists because a
/// wrong conversion TYPES ITSELF into the user's document — conservatism
/// cases matter as much as conversion cases. Conversion cases come from the
/// 2026-08-11 corpus run (item h02/h03 failures).
final class NumberCompactionTests: XCTestCase {
    func testCompoundAndMagnitude() {
        XCTAssertEqual(NumberCompaction.apply("went from forty-two thousand to fifty-eight thousand"),
                       "went from 42,000 to 58,000")
        XCTAssertEqual(NumberCompaction.apply("about three hundred people"), "about 300 people")
        XCTAssertEqual(NumberCompaction.apply("two million views"), "2,000,000 views")
    }

    func testPercent() {
        XCTAssertEqual(NumberCompaction.apply("thirty-eight percent growth"), "38% growth")
        XCTAssertEqual(NumberCompaction.apply("eight percent ahead of plan"), "8% ahead of plan")
        XCTAssertEqual(NumberCompaction.apply("tracking 8 percent ahead"), "tracking 8% ahead")
    }

    func testMeridiemGluing() {
        XCTAssertEqual(NumberCompaction.apply("make it four p. m. today"), "make it 4pm today")
        XCTAssertEqual(NumberCompaction.apply("at 10:30 a.m. sharp"), "at 10:30am sharp")
        XCTAssertEqual(NumberCompaction.apply("around 7 pm"), "around 7pm")
    }

    func testProseNumbersAreLeftAlone() {
        // Single small number words are prose, not figures.
        XCTAssertEqual(NumberCompaction.apply("the one thing I'm watching"),
                       "the one thing I'm watching")
        XCTAssertEqual(NumberCompaction.apply("our one-on-one on Tuesday"),
                       "our one-on-one on Tuesday")
        XCTAssertEqual(NumberCompaction.apply("two lemons and whatever cheese looks good"),
                       "two lemons and whatever cheese looks good")
        // A run that isn't one well-formed number (a spoken clock time or a
        // list) is not converted — better untouched than wrong.
        XCTAssertEqual(NumberCompaction.apply("ten thirty works for me"),
                       "ten thirty works for me")
        XCTAssertEqual(NumberCompaction.apply("one two three go"), "one two three go")
    }

    func testCompoundWithoutMagnitudeConverts() {
        XCTAssertEqual(NumberCompaction.apply("twenty five slides"), "25 slides")
        XCTAssertEqual(NumberCompaction.apply("we have ninety-nine problems"),
                       "we have 99 problems")
    }
}
