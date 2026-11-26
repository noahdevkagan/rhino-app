import Accelerate
import Foundation

/// Input level handling shared by every engine, run on the decoded 16 kHz mono clip before
/// recognition (decisions.md 2026-11-25, "Quiet mics", and the rescue-only revision after review).
///
/// The rule is RESCUE ONLY. Compared with the old behaviour (a clip whose peak is under 0.004,
/// about -48 dBFS, is silence; everything else goes to the engine as recorded), this may:
/// - send a clip under the old peak bail to the engine, and
/// - raise the level of quiet speech,
/// but only when the clip carries real evidence of a talker (pitched frames in the human range
/// whose pitch moves, in syllable-length runs that come and go) AND that talker is no quieter
/// than `rescueFloorDb` (a TV in the next room must not be typed). Anything the old rule sent to
/// the engine still goes to it, with one narrow exception: an isolated pop (a single burst of at
/// most 60 ms, no pitched frame at all, 25 dB or more over a quiet floor), which Parakeet turned
/// into "Really". When the evidence is missing the clip is handled exactly as before.
///
/// Parakeet passes `boostAboveLegacyBail: false`: it gets no gain on any clip the old rule already
/// sent to it (measured: no WER benefit on the quiet Common Voice sets, and one clip that master
/// typed came back empty when boosted; decisions.md, "Parakeet: no boost above the bail"). A clip
/// rescued from under the bail is still lifted on every engine, since master typed nothing for it.
///
/// With the "Boost quiet speech" preference off, `analyze(_:enabled: false)` reproduces the old
/// rule exactly: silent iff peak < 0.004, gain 1.
///
/// Pure functions on `[Float]`. One pass for frame levels, then a normalised autocorrelation on
/// a 4 kHz copy for the frames that stand above the floor (a few ms per minute of audio).
enum InputLevel {
    static let sampleRate = 16000
    /// 20 ms analysis frames.
    static let frameLength = 320

    /// The old absolute bail (WhisperEngine.isNearSilence before 2026-11-25).
    static let legacyPeak: Float = 0.004

    /// A frame counts as active when it is this far above the clip's own floor (p10 of frame RMS)...
    static let activeAboveFloorDb: Float = 15
    /// ...and above this absolute level.
    static let activeAbsoluteDb: Float = -85
    /// Frames this far above the floor are checked for pitch.
    static let voicingAboveFloorDb: Float = 9

    /// Pitch search range, Hz (a low male voice to a high female one).
    static let minPitchHz: Float = 70
    static let maxPitchHz: Float = 400
    /// Normalised autocorrelation a frame needs at its pitch lag to count as voiced.
    static let minVoicingCorrelation: Float = 0.6

    // Evidence of a talker (all required).
    /// At least this much voiced audio.
    static let minVoicedMs = 120
    /// The pitch must move: 10th to 90th percentile of voiced-frame pitch at least this many
    /// semitones apart (a buzz or hum holds one pitch).
    static let minPitchSpreadSemitones: Float = 1.5
    /// ...and move from frame to frame (median change between neighbouring voiced frames).
    static let minPitchJitterSemitones: Float = 0.12
    /// Voiced runs are syllables: at most this share of voiced time may sit in runs longer than
    /// `sustainedRunMs` (a held note, a drone, a long tone).
    static let maxSustainedShare: Float = 0.75
    static let sustainedRunMs = 600
    /// Energy must come and go at syllable rate: the clip's active frames have to dip back
    /// toward the floor at least this often per second of voiced audio (one dip is enough
    /// for a short word, see `hasSpeechEvidence`).
    static let minRunsPerVoicedSecond: Float = 1.5

    /// The quietest talker that is ever rescued or boosted (power mean of voiced frames, dBFS).
    /// Below this the clip is handled exactly as before. Chosen from the curve in decisions.md:
    /// -58 is the knee: the lowest floor at which no 42-dB-down background clip is newly typed on
    /// Parakeet v2/v3 or whisper-turbo (-62 types 4-7 more), HANDOFF in scratchpad qm/.
    static var rescueFloorDb: Float = Experiment.floorOverride ?? -58
    /// Speech already at or above this level (power mean of voiced frames) is never touched.
    static let boostBelowDb: Float = -38
    /// The speech level the gain aims for.
    static let targetSpeechDb: Float = -22
    /// Most gain ever applied: brings a talker at the rescue floor to the target, no further.
    static var maxGainDb: Float { min(targetSpeechDb - rescueFloorDb, 40) }
    /// Boosts smaller than this are skipped (the clip goes through bit-for-bit).
    static let minGainDb: Float = 6
    /// Gain never pushes the peak past this (about -1 dBFS).
    static let peakCeiling: Float = 0.9

    /// An isolated pop: at most this much active audio...
    static let popMaxActiveMs = 60
    /// ...this far above a floor below `popFloorDb`, with no voiced frame at all.
    static let popMinContrastDb: Float = 25
    static let popFloorDb: Float = -60

    /// Clips longer than this (file imports) skip the analysis and keep the old behaviour.
    static let maxAnalysedSeconds = 600

    struct Analysis: Equatable {
        var enabled: Bool
        /// False for engines that only get gain on clips rescued from under the old bail.
        var boostAboveLegacyBail = true
        var peak: Float
        /// 10th percentile of frame RMS, dBFS: the clip's own noise floor.
        var floorDb: Float = -120
        var activeMs: Int = 0
        var longestActiveRunMs: Int = 0
        var voicedMs: Int = 0
        /// Power mean of the louder half of the voiced frames, dBFS (-120 when there are none).
        var speechDb: Float = -120
        var pitchSpread: Float = 0
        var pitchJitter: Float = 0
        var sustainedShare: Float = 0
        var voicedRuns: Int = 0

        /// What the old rule did: below the peak bail is silence.
        var legacySilent: Bool { peak < InputLevel.legacyPeak }

        /// Pitched, moving, syllabic: a talker, not a buzz, rumble, thump or drone.
        var hasSpeechEvidence: Bool {
            guard voicedMs >= InputLevel.minVoicedMs else { return false }
            let seconds = Float(voicedMs) / 1000
            return pitchSpread >= InputLevel.minPitchSpreadSemitones
                && pitchJitter >= InputLevel.minPitchJitterSemitones
                && sustainedShare <= InputLevel.maxSustainedShare
                && (voicedRuns >= 2 || seconds < 0.6)
                && Float(voicedRuns) >= min(InputLevel.minRunsPerVoicedSecond * seconds, 2)
        }

        /// Evidence of a talker loud enough to be the user.
        var canRescue: Bool {
            enabled && hasSpeechEvidence && speechDb >= InputLevel.rescueFloorDb
        }

        /// One short broadband burst over a quiet floor: a mic bump, a key release.
        var isIsolatedPop: Bool {
            enabled && activeMs > 0 && activeMs <= InputLevel.popMaxActiveMs
                && longestActiveRunMs <= InputLevel.popMaxActiveMs
                && voicedMs == 0
                && floorDb < InputLevel.popFloorDb
                && InputLevel.dbfs(peak) - floorDb >= InputLevel.popMinContrastDb
        }

        /// Nothing worth sending to a recognizer.
        var isSilent: Bool {
            guard enabled else { return legacySilent }
            if legacySilent { return !canRescue }
            return isIsolatedPop
        }

        /// Linear gain to apply before recognition (1 = untouched).
        var gain: Float {
            if Experiment.gainEverything, enabled {
                return InputLevel.gain(speechDb: InputLevel.dbfs(peak) - 12, peak: peak)
            }
            guard canRescue, speechDb < InputLevel.boostBelowDb,
              boostAboveLegacyBail || legacySilent else { return 1 }
            return InputLevel.gain(speechDb: speechDb, peak: peak)
        }
    }

    /// Debug-build-only switches for proving the gate catches each failure mode
    /// (tests/asr/score_levels.py). Release builds compile them out.
    enum Experiment {
        #if DEBUG
        static let env = ProcessInfo.processInfo.environment
        /// RHINO_INPUTLEVEL_FLOOR_DB=<dBFS>: a different rescue floor (-200 = no level check).
        static let floorOverride: Float? = env["RHINO_INPUTLEVEL_FLOOR_DB"].flatMap(Float.init)
        /// RHINO_INPUTLEVEL_GAIN_ALL=1: boost every clip, speech or not (what the gate must reject).
        static let gainEverything = env["RHINO_INPUTLEVEL_GAIN_ALL"] == "1"
        #else
        static let floorOverride: Float? = nil
        static let gainEverything = false
        #endif
    }

    static func dbfs(_ x: Float) -> Float {
        20 * log10(max(x, 1e-6))
    }

    static func analyze(_ samples: [Float], enabled: Bool = true,
                        boostAboveLegacyBail: Bool = true) -> Analysis {
        var peak: Float = 0
        if !samples.isEmpty {
            vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        }
        var a = Analysis(enabled: enabled, boostAboveLegacyBail: boostAboveLegacyBail, peak: peak)
        guard enabled, samples.count <= maxAnalysedSeconds * sampleRate else {
            a.enabled = false
            return a
        }
        let frameCount = samples.count / frameLength
        guard frameCount > 0 else { return a }

        var levels = [Float](repeating: 0, count: frameCount)
        samples.withUnsafeBufferPointer { buf in
            for f in 0..<frameCount {
                var ms: Float = 0
                vDSP_measqv(buf.baseAddress! + f * frameLength, 1, &ms, vDSP_Length(frameLength))
                levels[f] = 10 * log10(max(ms, 1e-12))
            }
        }
        let floorDb = percentile(levels.sorted(), 0.10)
        a.floorDb = floorDb
        let activeThreshold = max(floorDb + activeAboveFloorDb, activeAbsoluteDb)
        let voicingThreshold = max(floorDb + voicingAboveFloorDb, activeAbsoluteDb)
        let msPerFrame = frameLength * 1000 / sampleRate

        var active = 0, run = 0, longestActive = 0
        for l in levels {
            if l > activeThreshold {
                active += 1; run += 1; longestActive = max(longestActive, run)
            } else {
                run = 0
            }
        }
        a.activeMs = active * msPerFrame
        a.longestActiveRunMs = longestActive * msPerFrame

        // Pitch on the frames that stand above the floor.
        let pitches = pitchTrack(samples, levels: levels, threshold: voicingThreshold)
        var voicedLevels = [Float]()
        var voicedCount = 0
        var semis = [Float]()
        var jumps = [Float]()
        var runs = [Int]()
        var current = 0, gap = 0
        var lastSemi: Float?
        for f in 0..<frameCount {
            if let hz = pitches[f] {
                voicedCount += 1
                voicedLevels.append(levels[f])
                let s = 12 * log2(hz / 100)
                semis.append(s)
                if let p = lastSemi, gap == 0 { jumps.append(abs(s - p)) }
                lastSemi = s
                current += 1 + (current > 0 ? gap : 0)
                gap = 0
            } else if current > 0 {
                gap += 1
                // One unvoiced frame inside a vowel is a dropout, not a new syllable.
                if gap > 1 { runs.append(current); current = 0; gap = 0; lastSemi = nil }
            }
        }
        if current > 0 { runs.append(current) }
        a.voicedMs = voicedCount * msPerFrame
        a.voicedRuns = runs.count
        if voicedCount > 0 {
            // Speech level = power mean of the louder half of the voiced frames (vowel nuclei),
            // so the soft onsets and tails of words don't drag it down.
            let loud = voicedLevels.sorted().suffix(max(voicedLevels.count / 2, 1))
            let power = loud.reduce(Float(0)) { $0 + pow(10, $1 / 10) } / Float(loud.count)
            a.speechDb = 10 * log10(power)
            let sorted = semis.sorted()
            a.pitchSpread = percentile(sorted, 0.9) - percentile(sorted, 0.1)
            a.pitchJitter = jumps.isEmpty ? 0 : percentile(jumps.sorted(), 0.5)
            let sustainedFrames = runs.filter { $0 * msPerFrame > sustainedRunMs }.reduce(0, +)
            let runFrames = max(runs.reduce(0, +), 1)
            a.sustainedShare = Float(sustainedFrames) / Float(runFrames)
        }
        return a
    }

    /// Per 20 ms frame: the pitch in Hz when the frame is voiced, else nil. Frames under
    /// `threshold` (dB) are skipped. Works on a 4 kHz copy (high-passed, box-averaged) with a
    /// 40 ms window; a frame is voiced when its normalised autocorrelation has an interior peak
    /// in the pitch range of at least `minVoicingCorrelation`, clearly above the dip before it
    /// (rumble and hum-free noise decay smoothly and never form one).
    static func pitchTrack(_ samples: [Float], levels: [Float], threshold: Float) -> [Float?] {
        let decim = 4
        let rate = Float(sampleRate / decim)
        let n4 = samples.count / decim
        var out = [Float?](repeating: nil, count: levels.count)
        guard n4 > 0 else { return out }
        // One-pole high-pass (~60 Hz) to drop rumble, then average blocks of 4.
        var low = [Float](repeating: 0, count: n4)
        let alpha: Float = exp(-2 * .pi * 60 / Float(sampleRate))
        var prevX: Float = 0, prevY: Float = 0
        samples.withUnsafeBufferPointer { buf in
            for k in 0..<n4 {
                var acc: Float = 0
                for j in 0..<decim {
                    let x = buf[k * decim + j]
                    let y = alpha * (prevY + x - prevX)
                    prevX = x; prevY = y
                    acc += y
                }
                low[k] = acc / Float(decim)
            }
        }
        let minLag = Int((rate / maxPitchHz).rounded(.down))      // 10
        let maxLag = Int((rate / minPitchHz).rounded(.up))        // 58
        let window = Int(rate * 0.04)                              // 160
        let hop = frameLength / decim                              // 80
        var r = [Float](repeating: 0, count: maxLag + 2)
        low.withUnsafeBufferPointer { d in
            let base = d.baseAddress!
            for f in 0..<levels.count where levels[f] > threshold {
                let start = f * hop + hop / 2 - window / 2
                guard start >= 0, start + window + maxLag + 1 <= n4 else { continue }
                var e0: Float = 0
                vDSP_svesq(base + start, 1, &e0, vDSP_Length(window))
                guard e0 > 0 else { continue }
                for lag in (minLag - 1)...(maxLag + 1) {
                    var dot: Float = 0, e1: Float = 0
                    vDSP_dotpr(base + start, 1, base + start + lag, 1, &dot, vDSP_Length(window))
                    vDSP_svesq(base + start + lag, 1, &e1, vDSP_Length(window))
                    r[lag] = e1 > 0 ? dot / (e0 * e1).squareRoot() : 0
                }
                var best = -1
                var bestR: Float = minVoicingCorrelation
                var dip: Float = 1
                for lag in minLag...maxLag {
                    dip = min(dip, r[lag])
                    if r[lag] >= bestR, r[lag] >= r[lag - 1], r[lag] >= r[lag + 1], r[lag] - dip >= 0.3 {
                        best = lag; bestR = r[lag]
                    }
                }
                guard best > 0 else { continue }
                // Parabolic interpolation for a sub-lag period.
                let y0 = r[best - 1], y1 = r[best], y2 = r[best + 1]
                let denom = y0 - 2 * y1 + y2
                let shift = denom != 0 ? max(-0.5, min(0.5, 0.5 * (y0 - y2) / denom)) : 0
                out[f] = rate / (Float(best) + shift)
            }
        }
        return out
    }

    /// `sorted` must be ascending and non-empty.
    static func percentile(_ sorted: [Float], _ p: Double) -> Float {
        let i = Int((Double(sorted.count - 1) * p).rounded())
        return sorted[min(max(i, 0), sorted.count - 1)]
    }

    /// Boost that brings `speechDb` to the target: never below 1, at most `maxGainDb`, never
    /// past the peak ceiling, and exactly 1 when the boost would be under `minGainDb`.
    static func gain(speechDb: Float, peak: Float) -> Float {
        var db = min(targetSpeechDb - speechDb, maxGainDb)
        if peak > 0 {
            db = min(db, dbfs(peakCeiling) - dbfs(peak))
        }
        guard db >= minGainDb else { return 1 }
        return pow(10, db / 20)
    }

    /// Scales `samples` in place to what the recognizer should hear and returns the analysis
    /// behind it. In place so a long clip is never held twice.
    @discardableResult
    static func prepare(_ samples: inout [Float], enabled: Bool,
                        boostAboveLegacyBail: Bool = true) -> Analysis {
        let analysis = analyze(samples, enabled: enabled, boostAboveLegacyBail: boostAboveLegacyBail)
        var g = analysis.gain
        guard g != 1 else { return analysis }
        let n = vDSP_Length(samples.count)
        samples.withUnsafeMutableBufferPointer { buf in
            vDSP_vsmul(buf.baseAddress!, 1, &g, buf.baseAddress!, 1, n)
        }
        return analysis
    }
}
