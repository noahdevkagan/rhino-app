import XCTest
@testable import OpenSuperWhisper

/// "Hi, Steve" → "Hi Steve" (Steve, 2026-10-28). Pure text logic in `GreetingComma.apply`.
final class GreetingCommaTests: XCTestCase {

    func testGreetingAndThanksBeforeANameLoseTheComma() {
        XCTAssertEqual(GreetingComma.apply("Hi, Steve."), "Hi Steve.")
        XCTAssertEqual(GreetingComma.apply("Thanks, Steve."), "Thanks Steve.")
        XCTAssertEqual(GreetingComma.apply("Thank you so much, Anna!"), "Thank you so much Anna!")
        XCTAssertEqual(GreetingComma.apply("hey, O'Brien"), "hey O'Brien")
    }

    func testEveryGreetingInAMessage() {
        XCTAssertEqual(GreetingComma.apply("Hi, Steve,\n\nThe deck is ready. Thanks, Sam"),
                       "Hi Steve,\n\nThe deck is ready. Thanks Sam")
    }

    func testGroupWords() {
        XCTAssertEqual(GreetingComma.apply("Hi, everyone."), "Hi everyone.")
        XCTAssertEqual(GreetingComma.apply("Thanks, all."), "Thanks all.")
    }

    func testCommaBeforeANewClauseStays() {
        XCTAssertEqual(GreetingComma.apply("Thanks, I'll check."), "Thanks, I'll check.")
        XCTAssertEqual(GreetingComma.apply("Hi, how are you?"), "Hi, how are you?")
        XCTAssertEqual(GreetingComma.apply("Thanks, That helps."), "Thanks, That helps.")
    }

    func testOnlyAtTheStartOfASentenceOrLine() {
        XCTAssertEqual(GreetingComma.apply("I said hi, Steve."), "I said hi, Steve.")
        XCTAssertEqual(GreetingComma.apply("Chi, Steve"), "Chi, Steve")
    }

    func testNoCommaNoChange() {
        XCTAssertEqual(GreetingComma.apply("Hi Steve"), "Hi Steve")
        XCTAssertEqual(GreetingComma.apply(""), "")
    }
}
