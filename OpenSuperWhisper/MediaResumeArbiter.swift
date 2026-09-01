import Foundation

/// Decides whether the media pause/resume *fallback* path (MediaRemote now-playing reads
/// unavailable — see MediaPlaybackController) may send a Play when recording ends.
///
/// The single instantaneous "is the output device running?" probe this replaces armed a
/// resume off evidence that can't tell audible media from a process merely holding the
/// output device open (a silent WebAudio tab, a just-finished notification ding) — and a
/// Play with nothing actually paused wakes whatever stale tab macOS still holds as the
/// now-playing owner (field report 2026-09-01: dictation with no music playing "auto plays
/// a random song or video in the background").
///
/// The evidence contract here: **resume only what the pause was seen to silence.**
///   • Armed only when some other process was rendering audio output continuously across
///     the idle window before the pause — a notification ding doesn't span ~3s of samples;
///     playing media does.
///   • Confirmed only when at least one of those continuous renderers *stops* rendering
///     after the pause. A silent device-holder keeps its IO running regardless of the
///     pause, so it never confirms; media the pause stopped goes quiet within seconds.
/// No confirmation, no Play. The failure mode this chooses is the benign one: media that
/// can't be told apart from a holder stays paused instead of random media being woken.
struct MediaResumeArbiter {
    /// Idle-time samples of the processes rendering audio output (this process excluded),
    /// newest last. Only the last `continuityWindow` are kept.
    private(set) var idleSamples: [Set<pid_t>] = []

    /// Processes that were rendering continuously when the pause was sent.
    private(set) var pausedRenderers: Set<pid_t> = []

    /// True once a paused renderer was seen to stop rendering — the proof the pause
    /// silenced real playback, and the green light for a resume.
    private(set) var pauseConfirmed = false

    /// Idle samples (at the poll cadence, ~1.5s apart) that must all show a renderer for
    /// it to count as continuous. Two samples plus the pause-instant sample span ~3s.
    static let continuityWindow = 2

    /// Feed one idle-time (not recording) sample of the currently rendering processes.
    mutating func recordIdleSample(_ renderers: Set<pid_t>) {
        idleSamples.append(renderers)
        if idleSamples.count > Self.continuityWindow {
            idleSamples.removeFirst(idleSamples.count - Self.continuityWindow)
        }
    }

    /// Called when the pause command goes out, with the renderers sampled at that instant.
    /// Arms the cycle only if something rendered across the whole continuity window; with
    /// too little idle history (app or poll just started) it stays unarmed — never guess.
    mutating func beginPause(renderersAtPause: Set<pid_t>) {
        pauseConfirmed = false
        guard idleSamples.count >= Self.continuityWindow else {
            pausedRenderers = []
            return
        }
        pausedRenderers = idleSamples.reduce(renderersAtPause) { $0.intersection($1) }
    }

    /// Whether the pause was armed for a possible resume this cycle.
    var isArmed: Bool { !pausedRenderers.isEmpty }

    /// Feed a post-pause sample. Any continuous renderer now missing means the pause
    /// stopped real playback. "Any", not "all": with a chronic silent holder *and* real
    /// media both in the snapshot, the media going quiet is exactly the confirmation
    /// wanted — requiring the holder to stop too would break every resume on such systems.
    mutating func recordPostPauseSample(_ renderers: Set<pid_t>) {
        guard isArmed, !pauseConfirmed else { return }
        if !pausedRenderers.subtracting(renderers).isEmpty {
            pauseConfirmed = true
        }
    }

    /// Armed and confirmed: a Play may be sent.
    var mayResume: Bool { isArmed && pauseConfirmed }

    /// Close the cycle. After a sent Play the idle history is seeded as if the resumed
    /// processes already render again — a dictation started back-to-back (inside the
    /// continuity window) must be able to re-arm, or it would strand the media paused.
    /// If they did not actually resume, the next pause-instant intersection drops them.
    mutating func finishCycle(resumed: Bool) {
        idleSamples = resumed
            ? Array(repeating: pausedRenderers, count: Self.continuityWindow)
            : []
        pausedRenderers = []
        pauseConfirmed = false
    }
}
