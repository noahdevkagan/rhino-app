import AVFoundation
import Foundation

enum MicTapError: Error, LocalizedError, Equatable {
    /// The input device reported a 0 Hz / 0-channel format (unplugged or mid-switch).
    case noAudioInput
    /// AVFoundation raised an Objective-C exception while installing the tap (e.g. the
    /// engine's cached format no longer matches the hardware). Carries the exception text.
    case tapRejected(String)

    var errorDescription: String? {
        switch self {
        case .noAudioInput: return "No audio input device"
        case .tapRejected(let reason): return "Microphone tap rejected: \(reason)"
        }
    }
}

/// Runs an Objective-C-exception-prone call and surfaces the exception as a Swift error.
///
/// Why this exists: on 2026-09-05 `installTap(onBus:)` raised "Input HW format and tap
/// format not matching" inside a main-actor task. Swift can't catch that; it unwound
/// through libdispatch and wedged the main queue, so the app drew "Connecting…" forever
/// while the WAV recorder kept running. The exception has to become an `Error` before it
/// reaches Swift frames.
enum ObjCExceptionCatcher {
    static func run(_ body: () -> Void) throws {
        if let error = RhinoCatchObjCException(body) {
            throw error
        }
    }
}

/// Shared rules for the two AVAudioEngine mic taps (live preview + spectrum meter).
enum MicTap {
    /// Whether a device format is something a tap can be installed with. A vanished or
    /// mid-switch device reports 0 Hz / 0 channels.
    static func isUsable(_ format: AVAudioFormat) -> Bool {
        format.sampleRate > 0 && format.channelCount > 0
    }

    /// The format a tap on the input node must use. The node's *output* format is a cached
    /// value that goes stale when the default device changes underneath a long-lived engine
    /// (AirPods re-register with a new CoreAudio ID on every reconnect); the *hardware*
    /// format is what AVFoundation checks the tap against. Prefer the hardware format and
    /// flag a disagreement so the caller can log it.
    static func resolveFormat(hardware: AVAudioFormat, output: AVAudioFormat) -> (format: AVAudioFormat, stale: Bool)? {
        guard isUsable(hardware) else { return nil }
        let stale = hardware.sampleRate != output.sampleRate || hardware.channelCount != output.channelCount
        return (hardware, stale)
    }

    /// Installs a tap on a fresh engine's input node using the hardware format, turning a
    /// raised NSException into `MicTapError.tapRejected`. Returns the format the tap uses.
    @discardableResult
    static func install(on input: AVAudioInputNode,
                        bufferSize: AVAudioFrameCount,
                        label: String,
                        block: @escaping AVAudioNodeTapBlock) throws -> AVAudioFormat {
        let hardware = input.inputFormat(forBus: 0)
        let output = input.outputFormat(forBus: 0)
        guard let resolved = resolveFormat(hardware: hardware, output: output) else {
            throw MicTapError.noAudioInput
        }
        if resolved.stale {
            print("\(label): input node format \(output.sampleRate) Hz/\(output.channelCount)ch was stale; hardware is \(hardware.sampleRate) Hz/\(hardware.channelCount)ch")
        }
        do {
            try ObjCExceptionCatcher.run {
                input.installTap(onBus: 0, bufferSize: bufferSize, format: resolved.format, block: block)
            }
        } catch {
            // A rejected tap can leave a half-installed one behind; clear it so the next
            // start on this engine doesn't raise again.
            _ = RhinoCatchObjCException { input.removeTap(onBus: 0) }
            throw MicTapError.tapRejected(error.localizedDescription)
        }
        return resolved.format
    }
}
