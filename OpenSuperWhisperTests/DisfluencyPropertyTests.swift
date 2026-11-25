import XCTest

@testable import OpenSuperWhisper

/// Property tests for `Disfluency` (the Polished level's code pass): over a few hundred
/// generated sentences full of hesitations, answers, fillers, repeats, commas and line
/// breaks, it only deletes words, keeps every line break where it was, leaves no double
/// space, stranded comma or doubled sentence end, and is idempotent.
final class DisfluencyPropertyTests: XCTestCase {
    func testInvariantsOverGeneratedSentences() {
        var rng = DisfluencyFuzz.RNG(state: 20261125)
        var failures: [String] = []
        for _ in 0..<600 {
            let input = DisfluencyFuzz.sentence(&rng)
            let output = Disfluency.apply(input)
            let problems = DisfluencyFuzz.problems(input, output, Disfluency.apply(output))
            if !problems.isEmpty {
                failures.append("\(input.debugDescription) → \(output.debugDescription): \(problems)")
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.prefix(10).joined(separator: "\n"))
    }

    func testLineBreaksStayPutForVariedInputs() {
        let inputs = [
            "Hi Sam,\num, the deck is ready.\nThanks,\nNoah",
            "Hi Sam,\n\nUm, so the the deck is ready.\n\nThanks, um\nNoah",
            "Shopping list:\n- um, eggs\n- uh milk\n- I I think bread",
            "um\nuh\nhmm",
            "We should, you know,\nmove it, um,\nto Friday.",
            "1. Um, buy milk\n2. uh, call Sam, um, Maya and Joe\n3. done? um.",
        ]
        for input in inputs {
            let output = Disfluency.apply(input)
            XCTAssertEqual(DisfluencyFuzz.problems(input, output, Disfluency.apply(output)), [],
                           "\(input.debugDescription) → \(output.debugDescription)")
        }
    }
}


private enum DisfluencyFuzz {
    struct RNG { var state: UInt64
        mutating func next(_ n: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(n))
        }
    }
    static let words = ["I", "we", "the", "a", "to", "Sam", "Maya", "deck", "is", "ready", "should",
        "go", "and", "milk", "eggs", "bread", "it", "my", "ER", "UM", "4", "mm", "think", "was",
        "could", "like", "you", "know", "huh", "uh", "um", "Um", "Uh", "hmm", "er", "mhm", "so",
        "Hi", "Thanks", "Noah", "V", "T", "minus", "do", "list", "if", "or", "an", "mean", "as"]
    static let phrases = ["um", "uh", "Um,", "you know", "I mean", "uh huh", "mm hmm", "uh uh", "I I", "the the", "we should we should"]

    static func sentence(_ rng: inout RNG) -> String {
        var out = ""
        let n = 3 + rng.next(14)
        var lastWasPunct = true
        for i in 0..<n {
            if !out.isEmpty, !lastWasPunct, rng.next(5) == 0 {
                out += [",", ",", ".", "?", "!"][rng.next(5)]
                lastWasPunct = true
            }
            if !out.isEmpty {
                out += (rng.next(9) == 0 && i > 0) ? "\n" : " "
            }
            let token = rng.next(4) == 0 ? phrases[rng.next(phrases.count)] : words[rng.next(words.count)]
            out += token
            lastWasPunct = token.hasSuffix(",")
        }
        if !lastWasPunct, rng.next(2) == 0 { out += [".", "?"][rng.next(2)] }
        return out
    }

    static func wordsOf(_ line: Substring) -> [String] {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map { $0.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'’")).inverted) }
            .filter { !$0.isEmpty }
    }

    static func isSubsequence(_ a: [String], of b: [String]) -> Bool {
        var it = b.makeIterator()
        return a.allSatisfy { w in while let x = it.next() { if x == w { return true } }; return false }
    }

    /// Problems with one input, or [] when every invariant holds.
    static func problems(_ input: String, _ output: String, _ again: String) -> [String] {
        var p: [String] = []
        let inLines = input.split(separator: "\n", omittingEmptySubsequences: false)
        let outLines = output.split(separator: "\n", omittingEmptySubsequences: false)
        if inLines.count != outLines.count { p.append("line count") }
        else {
            for (i, o) in zip(inLines, outLines) where !isSubsequence(wordsOf(o), of: wordsOf(i)) {
                p.append("line words not a subsequence: \(o.debugDescription)")
            }
        }
        if output.contains("  ") { p.append("double space") }
        if output.range(of: #"[,;:][ \t]*[.?!]"#, options: .regularExpression) != nil { p.append("comma before end") }
        if output.range(of: #"[.?!][ \t]*[.?!]"#, options: .regularExpression) != nil { p.append("two ends") }
        if output.range(of: #",[ \t]*,"#, options: .regularExpression) != nil { p.append("two commas") }
        if output.range(of: #"(?m)^[ \t]|[ \t]$"#, options: .regularExpression) != nil { p.append("edge space") }
        if again != output { p.append("not idempotent: \(again.debugDescription)") }
        return p
    }
}
