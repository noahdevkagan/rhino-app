import Foundation

/// Input level handling shared by every engine, run on the decoded 16 kHz mono clip before
/// recognition (decisions.md 2026-11-25, "Quiet mics").
///
/// Two jobs:
/// 1. Tell quiet speech from silence. The old test was the clip's absolute peak (< 0.004, about
///    -48 dBFS), which also threw away a soft talker on a low-gain mic. Speech is bursty: syllables
///    rise well above the clip's own floor and hold there for a tenth of a second or more. Room
///    tone, hiss, hum and fans sit flat on their floor, and clicks or keystrokes are too short. So
///    a clip is speech-like when enough 20 ms frames stand clearly above its own noise floor AND at
///    least one run of them lasts as long as a syllable.
/// 2. Bring quiet speech up to a normal level. Both Parakeet and Whisper lose words on a clip 24 dB
///    down (bench/accents: Parakeet 3.4 -> 7.3% WER, Whisper 5.3 -> 11.6% on the Australian set) and
///    recover when it is normalised. Gain is computed from the loud frames (a high percentile of
///    frame RMS, robust to one pop), never attenuates, is capped, never clips, and is only applied
///    to speech-like clips, so a noise-only clip reaches the engine exactly as before.
///
/// Pure functions on `[Float]`; one pass over the clip plus a sort of the frame levels
/// (about 50 frames a second), well under a millisecond for a dictation.
enum InputLevel {
    static let sampleRate = 16000
    /// 20 ms analysis frames.
    static let frameLength = 320

    /// Below this peak (about -80 dBFS, three 16-bit steps) nothing a microphone picks up is
    /// left: digital silence, a muted input, converter dither. Always silent, whatever the shape.
    static let hardFloorPeak: Float = 0.0001
    /// The old absolute bail (WhisperEngine.isNearSilence). A clip above it always goes to the
    /// engine as before; below it, only a speech-like clip does.
    static let legacyPeak: Float = 0.004
    /// A frame counts as active when it is this far above the clip's own floor...
    static let activeAboveFloorDb: Float = 15
    /// ...and above this absolute level, so quantisation noise in a near-digital-silent clip
    /// can never look like contrast.
    static let activeAbsoluteDb: Float = -85
    /// Speech-like needs this much active audio in total...
    static let minActiveMs = 200
    /// ...including one unbroken run this long (a syllable; a keystroke or pop is 10-60 ms).
    static let minRunMs = 100
    /// Zero crossings per sample under which a frame looks voiced (a vowel at 100-300 Hz with
    /// formants crosses roughly 0.02-0.15; broadband noise about 0.5, pink noise about 0.25).
    static let maxVoicedZeroCrossingRate: Float = 0.2

    /// An isolated blip needs a floor below this (a quiet room or digital silence)...
    static let blipFloorDb: Float = -60
    /// ...with the loud-frame level (95th percentile) still within this of it, i.e. at least
    /// 95% of the clip is background.
    static let blipLevelAboveFloorDb: Float = 6

    /// The loud-frame level the gain aims for, in dBFS (normal close-mic dictation sits around here).
    static let targetLevelDb: Float = -22
    /// Most gain ever applied: 40 dB lifts a -60 dBFS talker to normal, and no further.
    static let maxGainDb: Float = 40
    /// Below this the clip is already at a usable level and is left bit-for-bit untouched.
    static let minGainDb: Float = 6
    /// Gain never pushes the peak past this (about -1 dBFS).
    static let peakCeiling: Float = 0.9

    struct Analysis: Equatable {
        var peak: Float
        /// 10th percentile of frame RMS, dBFS: the clip's own noise floor.
        var floorDb: Float
        /// 95th percentile of frame RMS, dBFS: how loud the loud parts are.
        var levelDb: Float
        var activeMs: Int
        var longestRunMs: Int

        var isSpeechLike: Bool {
            peak >= InputLevel.hardFloorPeak
                && activeMs >= InputLevel.minActiveMs
                && longestRunMs >= InputLevel.minRunMs
        }

        /// A quiet background where at most a blip stands out: a click, a pop, one thump.
        /// Nearly every frame sits on a low floor and what rises above it is too short to be a
        /// word. Parakeet turned exactly this into "Really" (gate set, 2026-11-25) because
        /// a loud pop clears the old peak bail.
        var isIsolatedBlip: Bool {
            floorDb < InputLevel.blipFloorDb
                && levelDb - floorDb < InputLevel.blipLevelAboveFloorDb
                && activeMs < InputLevel.minActiveMs
                && longestRunMs < InputLevel.minRunMs
        }

        /// Nothing worth sending to a recognizer: dead-mic quiet, an isolated blip, or below
        /// the old peak bail without the shape of speech.
        var isSilent: Bool {
            if peak < InputLevel.hardFloorPeak { return true }
            if isSpeechLike { return false }
            return isIsolatedBlip || peak < InputLevel.legacyPeak
        }

        /// Linear gain to apply before recognition (1 = untouched).
        var gain: Float {
            isSpeechLike ? InputLevel.gain(levelDb: levelDb, peak: peak) : 1
        }
    }

    static func dbfs(_ x: Float) -> Float {
        20 * log10(max(x, 1e-6))
    }

    static func analyze(_ samples: [Float]) -> Analysis {
        let frameCount = samples.count / frameLength
        var peak: Float = 0
        var levels = [Float]()
        var crossings = [Float]()
        levels.reserveCapacity(max(frameCount, 1))
        crossings.reserveCapacity(max(frameCount, 1))
        samples.withUnsafeBufferPointer { buf in
            for f in 0..<frameCount {
                var sum: Float = 0
                var zc = 0
                let base = f * frameLength
                var prev = buf[base]
                for i in base..<(base + frameLength) {
                    let s = buf[i]
                    sum += s * s
                    let a = abs(s)
                    if a > peak { peak = a }
                    if (s >= 0) != (prev >= 0) { zc += 1 }
                    prev = s
                }
                levels.append(dbfs((sum / Float(frameLength)).squareRoot()))
                crossings.append(Float(zc) / Float(frameLength))
            }
            for i in (frameCount * frameLength)..<buf.count {
                peak = max(peak, abs(buf[i]))
            }
        }
        guard !levels.isEmpty else {
            return Analysis(peak: peak, floorDb: dbfs(0), levelDb: dbfs(peak), activeMs: 0, longestRunMs: 0)
        }
        let sorted = levels.sorted()
        let floorDb = percentile(sorted, 0.10)
        let levelDb = percentile(sorted, 0.95)
        let threshold = max(floorDb + activeAboveFloorDb, activeAbsoluteDb)
        var active = 0, run = 0, longest = 0
        for (l, zcr) in zip(levels, crossings) {
            guard l > threshold else { run = 0; continue }
            active += 1
            // Only voiced-looking frames extend a run: vowels cross zero rarely, while a
            // keystroke, crackle or hiss burst is broadband and crosses constantly. Fast typing
            // can string its bursts together; this keeps that from looking like a syllable.
            if zcr < maxVoicedZeroCrossingRate {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }
        let msPerFrame = frameLength * 1000 / sampleRate
        return Analysis(peak: peak, floorDb: floorDb, levelDb: levelDb,
                        activeMs: active * msPerFrame, longestRunMs: longest * msPerFrame)
    }

    /// `sorted` must be ascending and non-empty.
    static func percentile(_ sorted: [Float], _ p: Double) -> Float {
        let i = Int((Double(sorted.count - 1) * p).rounded())
        return sorted[min(max(i, 0), sorted.count - 1)]
    }

    /// Boost that brings `levelDb` to the target: never below 1, at most `maxGainDb`, never
    /// past the peak ceiling, and exactly 1 when the boost would be under `minGainDb`.
    static func gain(levelDb: Float, peak: Float) -> Float {
        var db = min(targetLevelDb - levelDb, maxGainDb)
        if peak > 0 {
            db = min(db, dbfs(peakCeiling) - dbfs(peak))
        }
        guard db >= minGainDb else { return 1 }
        return pow(10, db / 20)
    }

    /// The clip as the recognizer should hear it, plus the analysis behind it.
    static func prepare(_ samples: [Float]) -> (samples: [Float], analysis: Analysis) {
        let analysis = analyze(samples)
        let g = analysis.gain
        guard g != 1 else { return (samples, analysis) }
        return (samples.map { $0 * g }, analysis)
    }
}
