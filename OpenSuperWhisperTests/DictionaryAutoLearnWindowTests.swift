import XCTest

@testable import OpenSuperWhisper

/// The tail-window reads auto-learn uses for fields too long to copy whole (Terminal's scrollback).
/// Simulates a field as a string and reads it the way `readFocusedField` does, by `readPlan`.
final class DictionaryAutoLearnWindowTests: XCTestCase {
    private let limit = FocusUtils.caretContextValueFallbackLimit

    /// ~135k characters of earlier terminal output, like Noah's Terminal window.
    private lazy var scrollback: String = (0..<4_500).map { "line \($0) build output ok\n" }.joined()
    private let prompt = "> please ask Apsumo about the launch date"
    private let status = "\n? for shortcuts · esc to interrupt\n"
    private let dictation = DictionaryLearner.words("please ask Apsumo about the launch date")

    /// Reads `field` per the plan for `windowStart`; `nil` text when the plan skips.
    private func read(_ field: String, windowStart: Int?) -> (text: String, start: Int)? {
        let ns = field as NSString
        switch DictionaryAutoLearn.readPlan(count: ns.length, windowStart: windowStart) {
        case .whole: return (field, 0)
        case .range(let location, let length):
            return (ns.substring(with: NSRange(location: location, length: length)), location)
        case .skip: return nil
        }
    }

    /// The baseline read: window start, and the words before and after the dictation.
    private func baseline(_ field: String) throws -> (start: Int, before: [String], after: [String]) {
        let first = try XCTUnwrap(read(field, windowStart: nil))
        let words = DictionaryLearner.words(first.text)
        let range = try XCTUnwrap(DictionaryAutoLearn.lastRange(of: dictation, in: words))
        return (first.start, Array(words[..<range.lowerBound]), Array(words[range.upperBound...]))
    }

    private func stretch(_ field: String, _ base: (start: Int, before: [String], after: [String])) -> [String]? {
        guard let next = read(field, windowStart: base.start) else { return nil }
        return DictionaryAutoLearn.stretch(in: DictionaryLearner.words(next.text),
                                           before: base.before, after: base.after)
    }

    // MARK: - readPlan

    func testShortFieldIsReadWhole() {
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: 500, windowStart: nil), .whole)
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: nil, windowStart: nil), .whole)
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: 600, windowStart: 0), .whole)
    }

    func testLongFieldBaselineReadsTheTail() {
        let tail = DictionaryAutoLearn.tailWindow
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: 135_000, windowStart: nil),
                       .range(location: 135_000 - tail, length: tail))
    }

    func testWindowKeepsItsStartAsTheFieldGrowsOrShrinks() {
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: 127_010, windowStart: 127_000),
                       .range(location: 127_000, length: 10))
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: 127_000, windowStart: 127_000),
                       .range(location: 127_000, length: 0))
    }

    func testWholeFieldWatchDoesNotSwitchToAWindow() {
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: limit + 1, windowStart: 0), .skip(.tooBig))
    }

    func testWindowSkipsWhenTheFieldShrinksOrOutputPilesUp() {
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: 99, windowStart: 100), .skip(.shrank))
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: 100 + DictionaryAutoLearn.maxWindowSpan + 1,
                                                    windowStart: 100), .skip(.outputGrew))
        XCTAssertEqual(DictionaryAutoLearn.readPlan(count: nil, windowStart: 100), .skip(.unreadable))
    }

    // MARK: - stretch

    func testStretchNeedsBothAnchorsInPlace() {
        let before = ["a", "b"], after = ["z"]
        XCTAssertEqual(DictionaryAutoLearn.stretch(in: ["a", "b", "x", "y", "z"], before: before, after: after),
                       ["x", "y"])
        XCTAssertNil(DictionaryAutoLearn.stretch(in: ["a", "c", "x", "z"], before: before, after: after))
        XCTAssertNil(DictionaryAutoLearn.stretch(in: ["a", "b", "x", "z", "more"], before: before, after: after))
        XCTAssertNil(DictionaryAutoLearn.stretch(in: ["a", "z"], before: before, after: after))
    }

    // MARK: - A long terminal field end to end

    func testCorrectionInALongTerminalFieldIsFound() throws {
        let field = scrollback + prompt + status
        XCTAssertGreaterThan((field as NSString).length, limit)
        let base = try baseline(field)
        XCTAssertGreaterThan(base.start, 0)

        // The user retypes the brand; the field gets longer, the window start stays put.
        let edited = scrollback + prompt.replacingOccurrences(of: "Apsumo", with: "AppSumo") + status
        let found = try XCTUnwrap(stretch(edited, base))
        XCTAssertEqual(found, DictionaryLearner.words("please ask AppSumo about the launch date"))
        XCTAssertEqual(DictionaryLearner.correction(inserted: dictation, edited: found, trailingOpen: false),
                       .init(heard: "Apsumo", correct: "AppSumo"))
    }

    func testUnchangedTerminalFieldGivesTheDictationBack() throws {
        let field = scrollback + prompt + status
        let base = try baseline(field)
        XCTAssertEqual(stretch(field, base), dictation)
    }

    func testOutputPrintedAfterTheDictationIsNotAnEdit() throws {
        let base = try baseline(scrollback + prompt + status)
        let more = scrollback + prompt + status + "Compiling Apsumo AppSumo 3 files\n"
        XCTAssertNil(stretch(more, base))
    }

    func testStatusLineRedrawIsNotAnEdit() throws {
        let base = try baseline(scrollback + prompt + status)
        let redrawn = scrollback + prompt.replacingOccurrences(of: "Apsumo", with: "AppSumo")
            + "\n✻ Thinking… (3s)\n"
        XCTAssertNil(stretch(redrawn, base))
    }

    func testScrollbackTrimmedAtTheTopBreaksTheAlignment() throws {
        let base = try baseline(scrollback + prompt + status)
        // Terminal drops its oldest lines: everything shifts left under the fixed window start.
        let trimmed = String(scrollback.dropFirst(26)) + prompt.replacingOccurrences(of: "Apsumo", with: "AppSumo")
            + status
        XCTAssertNil(stretch(trimmed, base))
    }

    func testClearedTerminalStopsTheWatch() throws {
        let base = try baseline(scrollback + prompt + status)
        XCTAssertNil(read("> " + status, windowStart: base.start))
    }

    // MARK: - Learner rejection reasons (logged when a watch ends without learning)

    private func verdict(_ inserted: String, _ edited: String) -> DictionaryLearner.Verdict {
        DictionaryLearner.verdict(inserted: DictionaryLearner.words(inserted),
                                  edited: DictionaryLearner.words(edited), trailingOpen: false,
                                  isRealWord: { ["going", "ran", "run", "maybe", "may", "be"].contains($0.lowercased()) },
                                  isCommonWord: { ["going", "ran", "run", "maybe", "may", "be"].contains($0) })
    }

    func testVerdictNamesTheRule() {
        XCTAssertEqual(verdict("we use Apsumo daily", "we use AppSumo daily"),
                       .learn(.init(heard: "Apsumo", correct: "AppSumo")))
        XCTAssertEqual(verdict("we use Apsumo daily", "we use Apsumo daily"), .reject(.unchanged))
        XCTAssertEqual(verdict("we use Apsumo daily", "they love the tool"), .reject(.rewrite))
        XCTAssertEqual(verdict("we use Apsumo daily", "we use Ap daily"), .reject(.tooShort))
        XCTAssertEqual(verdict("we use Apsumo daily", "we use Zendesk daily"), .reject(.tooDifferent))
        XCTAssertEqual(verdict("I was going home", "I was goin home"), .reject(.realToNonWord))
        XCTAssertEqual(verdict("I ran home", "I run home"), .reject(.realToReal))
        XCTAssertEqual(verdict("it may be fine", "it maybe fine"), .reject(.joinNotAllowed))
        XCTAssertEqual(verdict("buy Widget now", "buy Widgets now"), .reject(.pluralOrPossessive))
    }
}
