import Foundation

/// One held bubble notice (see `IndicatorWindowManager.flash`).
///
/// Background results (no speech, copied, failures) arrive while the user may already be
/// recording the next take, when the bubble belongs to that take. The notice waits here and
/// is shown as soon as that recording ends. One slot is enough: an error is never replaced by
/// an info, otherwise the newest wins.
struct PendingNoticeSlot: Equatable {
    private(set) var held: RecordingState?

    var isEmpty: Bool { held == nil }

    /// Only `.error` and `.info` are notices; anything else is ignored.
    mutating func hold(_ notice: RecordingState) {
        switch notice {
        case .error:
            held = notice
        case .info:
            if case .error = held { return }
            held = notice
        default:
            return
        }
    }

    mutating func take() -> RecordingState? {
        defer { held = nil }
        return held
    }

    mutating func clear() { held = nil }
}

/// Decisions about a recorder that failed to start. The recorder starts on its own queue, so
/// the bubble has already said "Recording" by the time a failure is known.
enum RecorderStartFailure {
    static let message = "Couldn't start the microphone"

    /// The bubble state after a start failure: an error while it still shows this take
    /// recording or connecting, otherwise nil (the take already ended or already shows an error).
    static func stateAfterFailure(from current: RecordingState) -> RecordingState? {
        switch current {
        case .recording, .connecting: return .error(message)
        default: return nil
        }
    }

    /// Whether a stop that produced no file should say so. Silent for every deliberate or
    /// ordinary nil: a discard (too-short hold, abandoned take) and a take that recorded fine
    /// but was under the keep threshold. Only a recorder that failed to start is an error.
    static func shouldReportOnEmptyStop(discard: Bool, startFailed: Bool) -> Bool {
        startFailed && !discard
    }
}
