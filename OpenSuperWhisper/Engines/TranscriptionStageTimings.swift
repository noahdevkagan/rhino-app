import Foundation

/// Wall-clock breakdown of one transcription, for latency diagnosis (bench JSON + log lines
/// that diagnose reports collect). Stages, in order:
///   - loadConvertMs: reading the audio file and converting to 16kHz mono Float32. Near-zero
///     for real dictations (the recorder already writes that format).
///   - inferenceMs: the FluidAudio call — mel preprocessing, encoder, TDT decode. `path` says
///     which invocation ran: "parakeet-offline" (default) or "parakeet-boosted" (custom
///     dictionary boosting via the sliding-window manager, a much heavier path).
///   - postProcessMs: trim + custom-dictionary text replacement.
/// There is no VAD stage — the offline path has none; audio ≤15s runs as a single padded window.
struct TranscriptionStageTimings {
    let path: String
    let audioSeconds: Double
    let loadConvertMs: Double
    let inferenceMs: Double
    let postProcessMs: Double

    var totalMs: Double { loadConvertMs + inferenceMs + postProcessMs }

    /// One greppable line for logs and diagnose output.
    var logLine: String {
        String(format: "path=%@ audio=%.1fs load=%.0fms infer=%.0fms post=%.0fms total=%.0fms",
               path, audioSeconds, loadConvertMs, inferenceMs, postProcessMs, totalMs)
    }

    /// JSON-friendly form for the bench CLI's per-clip output.
    var asJSON: [String: Any] {
        [
            "path": path,
            "audio_s": (audioSeconds * 10).rounded() / 10,
            "load_ms": loadConvertMs.rounded(),
            "infer_ms": inferenceMs.rounded(),
            "post_ms": postProcessMs.rounded(),
        ]
    }
}
