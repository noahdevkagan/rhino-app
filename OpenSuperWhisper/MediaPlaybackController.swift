import CoreAudio
import Foundation

/// Pauses/resumes system media playback via the private MediaRemote framework.
///
/// The pause is always sent **unconditionally** — a synchronous "is something playing?" probe at
/// record-start reads false, because starting `AVAudioRecorder` transiently clears the system Now
/// Playing flag (#126), so a probe there wrongly skips the pause (browser tabs like YouTube never
/// paused). A pause command is a harmless no-op when nothing plays, so this is safe and reliable.
///
/// The resume is where it gets subtle: we want to resume only what was actually playing, so an
/// idle/already-paused source isn't *woken* when recording stops (macOS keeps stale/closed media —
/// e.g. the last YouTube tab — as the now-playing owner, so a blind play command frequently wakes
/// things the user didn't know were "playing"). Two signals feed the was-it-playing decision:
///
///   • MediaRemote now-playing reads (the Now Playing app's playback rate) — precise, but since
///     macOS 15.4 they're gated on a private Apple entitlement: Apple platform binaries read fine
///     (the signed `swift` toolchain reads `rate=1` for a playing Chrome tab) while our builds —
///     Developer ID and ad-hoc alike — read nothing back. When reads do work (`canRead`), poll
///     while not recording, snapshot at pause, and resume only if it was playing.
///   • CoreAudio fallback (public API, always works): the HAL's per-process objects say which
///     processes are rendering audio output right now (`kAudioProcessPropertyIsRunningOutput`,
///     macOS 14.4+), with this process excluded so our own chimes never count. That feeds
///     `MediaResumeArbiter`: armed only when another process rendered continuously across the
///     idle window before the pause, and Play is sent only once one of those renderers is seen
///     to *stop* after the pause — proof the pause silenced real playback. A process that just
///     holds the output device open (a silent WebAudio tab) never stops rendering, so it never
///     arms a wake of the stale now-playing owner; that was the earlier device-level probe's
///     failure (`kAudioDevicePropertyDeviceIsRunningSomewhere` — field report: dictation with
///     no music playing "auto plays a random song or video"). For a dictation shorter than the
///     confirmation lag the Play is simply deferred until the confirmation lands (media fades
///     back in a few seconds after the text does) or abandoned at a deadline.
///
/// Earlier builds left playback paused whenever MediaRemote reads failed, expecting a signed
/// release to read fine — but team signing isn't enough on macOS 15.4+, so the shipped app never
/// resumed anything. Send commands are NOT entitlement-gated, which is why the pause half always
/// worked. MediaRemote's now-playing is a single system-wide owner, so this acts on the active
/// player; it can't restore several sources at once.
final class MediaPlaybackController {
    static let shared = MediaPlaybackController()

    /// Whether we armed a resume this cycle (something was audibly playing when we paused).
    private(set) var didPauseMedia = false

    /// Cached "is the Now Playing app playing?" (from the playback rate), refreshed while not
    /// recording so it reflects the state from *before* a recording disrupts the flag. Only
    /// meaningful when `canRead` is true.
    private var isNowPlaying = false

    /// Whether this process can actually read now-playing state (see the type doc — entitlement-
    /// gated since macOS 15.4). Set true the first time a now-playing info dict comes back. While
    /// false the was-it-playing decision falls back to the per-process renderer evidence.
    private var canRead = false
    private var readAttempts = 0

    /// Fallback-path evidence and decisions (pure logic; unit-tested). Main-thread only, like
    /// the rest of the mutable state here.
    private var arbiter = MediaResumeArbiter()
    /// Watches the renderers after a pause for the stop that confirms real playback was paused.
    private var confirmTimer: Timer?
    /// Set when recording already ended but the confirmation hasn't landed yet — the Play is
    /// sent the moment it does (or abandoned at `resumeDeadline`).
    private var resumeRequested = false
    private var resumeDeadline = Date.distantFuture

    private static let kMRPlay: UInt32 = 0
    private static let kMRPause: UInt32 = 1
    private static let pollInterval: TimeInterval = 1.5
    /// Give now-playing reads a few tries; if none succeed this process can't read them — stop
    /// asking (the poll itself keeps running for the fallback's renderer samples).
    private static let maxReadAttempts = 5
    /// How long past recording-stop a pending confirmation may still turn into a Play. Paused
    /// players release their output IO within a few seconds; a "renderer" that hasn't stopped
    /// this long after the pause was never audibly playing.
    private static let resumeGrace: TimeInterval = 12

    private let sendCommand: (@convention(c) (UInt32, UnsafeRawPointer?) -> Bool)?
    /// MRMediaRemoteGetNowPlayingInfo(queue, completion(infoDict?)). The dict is nil when this
    /// process can't read now-playing, which doubles as the capability signal.
    private let getInfo: (@convention(c) (DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void) -> Void)?
    private var pollTimer: Timer?

    private init() {
        let bundle = CFBundleCreate(
            kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        )
        if let bundle,
           let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            sendCommand = unsafeBitCast(ptr, to: (@convention(c) (UInt32, UnsafeRawPointer?) -> Bool).self)
        } else {
            sendCommand = nil
        }
        if let bundle,
           let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            getInfo = unsafeBitCast(
                ptr, to: (@convention(c) (DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void) -> Void).self)
        } else {
            getInfo = nil
        }

        // Prime the now-playing connection — reads don't work in signed builds without registering.
        if let bundle,
           let regPtr = CFBundleGetFunctionPointerForName(
            bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) {
            typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
            unsafeBitCast(regPtr, to: RegisterFn.self)(DispatchQueue.main)
        }

        startPolling()
    }

    /// Poll while not recording (fires in `.common` mode so it keeps ticking during menu
    /// tracking / window resizing): now-playing reads while they might work, and the fallback's
    /// idle renderer samples once they don't.
    private func startPolling() {
        guard sendCommand != nil, pollTimer == nil else { return }
        refreshIdleState()
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.refreshIdleState()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshIdleState() {
        if !canRead {
            arbiter.recordIdleSample(Self.outputRenderingProcesses())
            // Now-playing reads get a few tries; after that this process can't read them and
            // the renderer samples above are the whole signal.
            guard readAttempts <= Self.maxReadAttempts else { return }
            readAttempts += 1
        }
        getInfo?(DispatchQueue.main) { [weak self] info in
            guard let self, let dict = info as? [String: Any] else { return }
            self.canRead = true
            let rate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
            self.isNowPlaying = rate > 0
        }
    }

    /// Pause playback (unconditional = reliable), arming a resume only if something was actually
    /// playing when we paused, and freezing the idle evidence while the recording runs.
    ///
    /// `renderersHint`: the renderer sample must be taken BEFORE this recording cycle makes any
    /// sound or disturbs audio IO (Bluetooth codec switches). AudioRecorder calls this via an
    /// async hop to main, which can land after `.record()` — so it samples on its own queue
    /// first and passes the result here. Sampling inline stays the fallback.
    func pauseMedia(renderersHint: Set<pid_t>? = nil) {
        guard let sendCommand else { return }
        // A new cycle abandons any still-pending resume from the previous one — never send a
        // stale Play into a fresh recording.
        stopConfirmWatch()
        resumeRequested = false

        let wasPlaying: Bool
        if canRead {
            wasPlaying = isNowPlaying
        } else {
            arbiter.beginPause(renderersAtPause: renderersHint ?? Self.outputRenderingProcesses())
            wasPlaying = arbiter.isArmed
            print("media: pause; continuous renderers=\(arbiter.pausedRenderers.sorted())")
        }
        stopPolling()
        _ = sendCommand(Self.kMRPause, nil)
        didPauseMedia = wasPlaying
        if !canRead, arbiter.isArmed { startConfirmWatch() }
    }

    /// The processes currently rendering audio output, this one excluded (so our own chimes and
    /// UI sounds never look like media). Public-API HAL process objects; stateless reads — safe
    /// from any thread. Empty below macOS 14.4 (no process objects) — harmless, because the
    /// fallback only ever engages on 15.4+ where now-playing reads are entitlement-gated;
    /// before that `canRead` keeps the precise path in charge.
    static func outputRenderingProcesses() -> Set<pid_t> {
        guard #available(macOS 14.4, *) else { return [] }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0
        else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &objects) == noErr
        else { return [] }

        let ownPID = getpid()
        var renderers = Set<pid_t>()
        for object in objects {
            address.mSelector = kAudioProcessPropertyIsRunningOutput
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(object, &address, 0, nil, &runningSize, &running) == noErr,
                  running != 0
            else { continue }
            address.mSelector = kAudioProcessPropertyPID
            var pid: pid_t = -1
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            guard AudioObjectGetPropertyData(object, &address, 0, nil, &pidSize, &pid) == noErr,
                  pid != ownPID
            else { continue }
            renderers.insert(pid)
        }
        return renderers
    }

    /// Resume playback, but only if we paused something this cycle. On the fallback path the
    /// Play additionally waits for the arbiter's confirmation (see the type doc) — immediate
    /// when it already landed during the recording, deferred up to `resumeGrace` otherwise.
    func resumeMedia() {
        if canRead {
            defer { startPolling() }
            guard didPauseMedia, let sendCommand else { return }
            _ = sendCommand(Self.kMRPlay, nil)
            didPauseMedia = false
            return
        }

        guard didPauseMedia, sendCommand != nil, arbiter.isArmed else {
            finishFallbackCycle(resumed: false)
            return
        }
        if arbiter.mayResume {
            sendConfirmedPlay()
            return
        }
        // Recording ended before the paused renderer was seen to stop (short dictation):
        // let the confirm watch finish the job, bounded by the deadline.
        print("media: resume pending confirmation")
        resumeRequested = true
        resumeDeadline = Date().addingTimeInterval(Self.resumeGrace)
    }

    // MARK: - Fallback confirmation plumbing

    private func startConfirmWatch() {
        stopConfirmWatch()
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.confirmTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        confirmTimer = timer
    }

    private func stopConfirmWatch() {
        confirmTimer?.invalidate()
        confirmTimer = nil
    }

    private func confirmTick() {
        arbiter.recordPostPauseSample(Self.outputRenderingProcesses())
        if arbiter.mayResume {
            // Confirmed: the pause silenced real playback. Play now if recording already
            // ended; otherwise the state holds until resumeMedia() asks.
            stopConfirmWatch()
            if resumeRequested { sendConfirmedPlay() }
            return
        }
        if resumeRequested, Date() >= resumeDeadline {
            // Long past the pause and nothing we "paused" ever stopped rendering — it was a
            // silent device-holder, not media. Waking the stale now-playing owner is exactly
            // the bug this path exists to avoid, so stand down.
            print("media: no renderer stopped after the pause — skipping resume")
            finishFallbackCycle(resumed: false)
        }
    }

    private func sendConfirmedPlay() {
        _ = sendCommand?(Self.kMRPlay, nil)
        print("media: resumed")
        finishFallbackCycle(resumed: true)
    }

    private func finishFallbackCycle(resumed: Bool) {
        stopConfirmWatch()
        resumeRequested = false
        arbiter.finishCycle(resumed: resumed)
        didPauseMedia = false
        startPolling()
    }
}
