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
        // Idioms stay prose, while clear quantities use digits.
        XCTAssertEqual(NumberCompaction.apply("the one thing I'm watching"),
                       "the one thing I'm watching")
        XCTAssertEqual(NumberCompaction.apply("our one-on-one on Tuesday"),
                       "our one-on-one on Tuesday")
        XCTAssertEqual(NumberCompaction.apply("two lemons and whatever cheese looks good"),
                       "2 lemons and whatever cheese looks good")
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

    func testSmartQuantitiesAndStandaloneNumbers() {
        let cases = [
            "seven items": "7 items", "Seven.": "7.", "zero": "0",
            "I need seven tickets and five seats.": "I need 7 tickets and 5 seats.",
            "two dollars": "2 dollars", "in eight minutes": "in 8 minutes",
            "room seven": "room 7", "chapter nine": "chapter 9",
            "at four pm": "at 4pm", "🦏 seven items": "🦏 7 items",
            "twenty one of them": "21 of them",
            "seven ideas": "seven ideas" // unknown context is conservative
        ]
        for (input, expected) in cases {
            XCTAssertEqual(NumberCompaction.apply(input), expected, input)
        }
    }

    func testPreferDigitsWorksOutsideQuantityVocabulary() {
        XCTAssertEqual(NumberCompaction.apply("I have seven ideas", style: .digits), "I have 7 ideas")
        XCTAssertEqual(NumberCompaction.apply("I picked seven", style: .digits), "I picked 7")
        XCTAssertEqual(NumberCompaction.apply("ninety", style: .digits), "90")
    }

    func testIdiomsAndIdentifiersInBothFormattingModes() {
        for style in [NumberFormattingStyle.smart, .digits] {
            for input in ["one of the best", "one another", "one at a time", "one by one",
                          "two by two", "one and only", "one or two", "no one knows",
                          "all in one", "the one thing", "one-on-one", "my two cents",
                          "at one with nature", "seven@example.com", "https://seven.com",
                          "folder/seven.txt", "seven_items", "v.seven", "two times as many"] {
                XCTAssertEqual(NumberCompaction.apply(input, style: style), input, input)
            }
        }
    }

    func testKeepAsSpokenIsExactPassThrough() {
        for input in ["Seven items at four p. m.", "forty-two thousand", "8 percent",
                      "7 items", "  one hundred and seven\n"] {
            XCTAssertEqual(NumberCompaction.apply(input, style: .spoken), input)
        }
    }

    func testConjunctionsAreNotLostOrAddedTogether() {
        XCTAssertEqual(NumberCompaction.apply("and twenty five people and seven items"),
                       "and 25 people and 7 items")
        XCTAssertEqual(NumberCompaction.apply("one hundred and seven items"), "107 items")
        for input in ["seven and eight", "twenty and five", "ten thirty", "one two three",
                      "seven  eight", "one hundred hundred", "one thousand million",
                      "zero thousand", "twenty zero", "one hundred zero", "one hundred and two hundred"] {
            XCTAssertEqual(NumberCompaction.apply(input, style: .digits), input, input)
        }
    }

    func testRepeatedMagnitudesCannotOverflow() {
        let input = "one " + Array(repeating: "hundred", count: 40).joined(separator: " ")
        XCTAssertEqual(NumberCompaction.apply(input), input)
    }

    func testFormattingIsIdempotent() {
        for style in NumberFormattingStyle.allCases {
            for input in ["seven items", "one hundred and seven", "one-on-one", "4 p. m.",
                          "and twenty five people", "seven and eight"] {
                let once = NumberCompaction.apply(input, style: style)
                XCTAssertEqual(NumberCompaction.apply(once, style: style), once)
            }
        }
    }

    func testCleanupMustKeepNumberRepresentationInSpokenMode() {
        XCTAssertTrue(NumberCompaction.preservesNumberRepresentation(
            input: "seven items and 42 dollars", output: "Seven items and 42 dollars."))
        XCTAssertFalse(NumberCompaction.preservesNumberRepresentation(input: "seven items", output: "7 items"))
        XCTAssertFalse(NumberCompaction.preservesNumberRepresentation(input: "7 items", output: "seven items"))
        XCTAssertFalse(NumberCompaction.preservesNumberRepresentation(input: "7 items", output: "8 items"))
        XCTAssertFalse(NumberCompaction.preservesNumberRepresentation(input: "-0.725", output: "0.725"))
        XCTAssertFalse(NumberCompaction.preservesNumberRepresentation(input: "0.725", output: "0.72"))
    }

    func testCustomerDecimalExamplesWithoutCleanupOrSmartFormatting() {
        for style in [NumberFormattingStyle.smart, .digits] {
            let cases = [
                "zero point seven two five": "0.725",
                "zero point six seven four": "0.674",
                "Point six seven four": "0.674",
                "And zero point seven two five": "And 0.725",
                "The rate is point six seven four.": "The rate is 0.674.",
                "three point one four": "3.14",
                "point zero zero seven": "0.007",
                "minus zero point zero five": "-0.05",
                "negative two point five": "-2.5",
                "zero point 7 two 5": "0.725",
                "0 point six seven four": "0.674",
                "one hundred and seven point zero five": "107.05",
                "three point seven percent": "3.7%",
                "zero point one of the total": "0.1 of the total",
                "point one two three four five six seven eight nine zero": "0.1234567890"
            ]
            for (input, expected) in cases {
                XCTAssertEqual(NumberCompaction.apply(input, style: style), expected, input)
            }
        }
    }

    func testDecimalFormattingCanBeDisabled() {
        let input = "zero point seven two five"
        XCTAssertEqual(NumberCompaction.apply(input, style: .spoken), input)
    }

    func testPointAsANounIsNotADecimal() {
        for style in [NumberFormattingStyle.smart, .digits] {
            for input in ["at that point two people left", "At this point three of us agreed",
                          "my point two is simple", "good point two", "by which point five teams",
                          "the turning point seven years ago", "point two people showed up"] {
                XCTAssertEqual(NumberCompaction.apply(input, style: style), input, input)
            }
            // Number position still decimalizes, with or without a leading number.
            let cases = ["it's point two of a gram": "it's 0.2 of a gram",
                         "drop it by point five percent": "drop it by 0.5%",
                         "the rate is point six seven four": "the rate is 0.674"]
            for (input, expected) in cases {
                XCTAssertEqual(NumberCompaction.apply(input, style: style), expected, input)
            }
        }
    }

    func testIndefiniteOneStaysAWord() {
        for style in [NumberFormattingStyle.smart, .digits] {
            for input in ["one day we'll ship it", "I finished it in one day", "one time I tried",
                          "give me one second", "one more thing", "one last question",
                          "the one I liked", "you're the only one", "which one is it",
                          "One thing I learned is patience", "Thanks. One reason is cost",
                          "someone called", "no one knows", "one by one", "one of them"] {
                XCTAssertEqual(NumberCompaction.apply(input, style: style), input, input)
            }
        }
        // Clear counts and lone answers still convert.
        XCTAssertEqual(NumberCompaction.apply("one ticket please"), "one ticket please") // sentence-initial
        XCTAssertEqual(NumberCompaction.apply("I need one ticket"), "I need 1 ticket")
        XCTAssertEqual(NumberCompaction.apply("it costs one dollar"), "it costs 1 dollar")
        XCTAssertEqual(NumberCompaction.apply("One."), "1.")
        XCTAssertEqual(NumberCompaction.apply("room one"), "room 1")
        XCTAssertEqual(NumberCompaction.apply("I have one idea", style: .digits), "I have 1 idea")
        XCTAssertEqual(NumberCompaction.apply("seven items"), "7 items")
        XCTAssertEqual(NumberCompaction.apply("Seven days later"), "7 days later")
        XCTAssertEqual(NumberCompaction.apply("twenty one days"), "21 days")
    }

    func testDecimalAmbiguitiesStayUnchanged() {
        for input in ["point taken", "the point is seven", "point seven twenty",
                      "one two point five", "point seven point five"] {
            XCTAssertEqual(NumberCompaction.apply(input), input, input)
        }
    }

    /// From Noah's own history: his book title came out "1,000,000 Dollar Weekend".
    func testBareMagnitudeStaysAWord() {
        for input in ["Million Dollar Weekend", "Thanks a million.", "One in a million.",
                      "It was a million dollar idea.", "a hundred times better", "Thousand Oaks"] {
            XCTAssertEqual(NumberCompaction.apply(input), input, input)
            XCTAssertEqual(NumberCompaction.apply(input, style: .digits), input, input)
        }
        XCTAssertEqual(NumberCompaction.apply("a twenty five million dollar house"),
                       "a 25,000,000 dollar house")
        XCTAssertEqual(NumberCompaction.apply("one million views"), "1,000,000 views")
    }
}
