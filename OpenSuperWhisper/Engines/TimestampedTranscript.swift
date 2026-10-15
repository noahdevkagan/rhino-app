import Foundation
import FluidAudio

/// Plain-text time ranges survive history, Copy and export. All times refer to
/// the original media; never estimate them from word count or trimmed audio.
enum TimestampedTranscript {
    enum TimingError: LocalizedError {
        case unavailable
        var errorDescription: String? {
            "The model did not return usable timestamps. Try another model or turn off Include timestamps in Settings → Output."
        }
    }

    static func time(_ seconds: TimeInterval) -> String {
        let milliseconds = Int((max(0, seconds) * 1_000).rounded())
        return String(format: "%02d:%02d:%02d.%03d", milliseconds / 3_600_000,
                      milliseconds / 60_000 % 60, milliseconds / 1_000 % 60, milliseconds % 1_000)
    }

    static func line(text: String, start: TimeInterval, end: TimeInterval) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return "[\(time(start)) → \(time(max(start, end)))] \(text)"
    }

    /// FluidAudio uses SentencePiece fragments: a leading space starts a word,
    /// while unspaced fragments (including punctuation) belong to the prior word.
    /// Close a line at a sentence, a pause, or about ten seconds, at word boundaries.
    static func parakeet(_ result: ASRResult, transform: (String) -> String) throws -> String {
        guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        guard let tokens = result.tokenTimings, !tokens.isEmpty,
              tokens.allSatisfy({ $0.startTime.isFinite && $0.endTime.isFinite &&
                  $0.startTime >= 0 && $0.endTime >= $0.startTime }) else {
            throw TimingError.unavailable
        }
        var lines: [String] = []
        var text = ""
        var start = tokens[0].startTime
        var end = start
        func flush() {
            if let line = line(text: transform(text.trimmingCharacters(in: .whitespacesAndNewlines)),
                               start: start, end: end) {
                lines.append(line)
            }
            text = ""
        }
        for token in tokens {
            let piece = token.token.replacingOccurrences(of: "▁", with: " ")
            let sentenceEnded = text.last.map { ".!?。！？".contains($0) } ?? false
            if !text.isEmpty && (piece.first?.isWhitespace == true || text.last.map { "。！？".contains($0) } == true),
               sentenceEnded || token.startTime - start >= 10 || token.startTime - end >= 1 {
                flush()
            }
            if text.isEmpty { start = token.startTime }
            text += piece
            end = max(end, token.endTime)
        }
        flush()
        guard !lines.isEmpty else { throw TimingError.unavailable }
        return lines.joined(separator: "\n")
    }

    /// Apply text formatting without letting numeric or dictionary rules edit a time range.
    static func mapText(_ transcript: String, transform: (String) -> String) -> String {
        transcript.components(separatedBy: "\n").map { line in
            guard line.hasPrefix("["), let boundary = line.range(of: "] ") else {
                return transform(line)
            }
            return String(line[..<boundary.upperBound]) + transform(String(line[boundary.upperBound...]))
        }.joined(separator: "\n")
    }
}
