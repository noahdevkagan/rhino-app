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
///   • CoreAudio fallback (public API, always works): at pause time, ask whether the default
///     output device is rendering audio for *any* process
///     (`kAudioDevicePropertyDeviceIsRunningSomewhere`). Playing media keeps the output device
///     running; paused/idle players release it within a few seconds. Coarser than a now-playing
///     read (an active call would also count as "playing"), but it answers exactly the question
///     that matters: was audio audible when we paused?
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
    /// false the was-it-playing decision falls back to the CoreAudio output-device probe.
    private var canRead = false
    private var readAttempts = 0

    private static let kMRPlay: UInt32 = 0
    private static let kMRPause: UInt32 = 1
    private static let pollInterval: TimeInterval = 1.5
    /// Give reads a few tries; if none succeed this process can't read now-playing — stop polling
    /// and settle into the CoreAudio-probe fallback rather than polling forever.
    private static let maxReadAttempts = 5

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

    /// Poll the playing state while not recording (fires in `.common` mode so it keeps ticking
    /// during menu tracking / window resizing).
    private func startPolling() {
        guard getInfo != nil, pollTimer == nil else { return }
        refreshNowPlaying()
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.refreshNowPlaying()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshNowPlaying() {
        // If reads never succeed, this process can't see now-playing — stop polling and rely on
        // the CoreAudio-probe fallback.
        if !canRead {
            readAttempts += 1
            if readAttempts > Self.maxReadAttempts { stopPolling(); return }
        }
        getInfo?(DispatchQueue.main) { [weak self] info in
            guard let self, let dict = info as? [String: Any] else { return }
            self.canRead = true
            let rate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
            self.isNowPlaying = rate > 0
        }
    }

    /// Pause playback (unconditional = reliable), arming a resume only if something was actually
    /// playing when we paused, and freezing the cache while the recording runs.
    ///
    /// `outputActiveHint`: the output probe must sample BEFORE this recording cycle makes any
    /// sound (or disturbs the output device — Bluetooth codec switches). AudioRecorder now calls
    /// this via an async hop to main, which can land after `.record()` — so it samples the probe
    /// on its own queue first and passes the result here. Probing inline stays the fallback.
    func pauseMedia(outputActiveHint: Bool? = nil) {
        guard let sendCommand else { return }
        // Precise path when now-playing reads work; the CoreAudio output probe otherwise (see the
        // type doc). The probe must see the audio while it is still audibly rendering.
        let wasPlaying = canRead ? isNowPlaying : (outputActiveHint ?? Self.isSystemOutputActive())
        stopPolling()
        _ = sendCommand(Self.kMRPause, nil)
        didPauseMedia = wasPlaying
    }

    /// Public-API proxy for "is audio audibly playing right now?": whether any process is running
    /// IO on the default output device. Playing media keeps this true; paused players release the
    /// device within a few seconds. Stateless CoreAudio reads — safe from any thread.
    static func isSystemOutputActive() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr,
            deviceID != kAudioObjectUnknown
        else { return false }

        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &running) == noErr
        else { return false }
        return running != 0
    }

    /// Resume playback, but only if we paused something this cycle; then re-arm the poll (only if
    /// reads work — otherwise we've settled into the fallback and there's nothing to poll).
    func resumeMedia() {
        defer { if canRead { startPolling() } }
        guard didPauseMedia, let sendCommand else { return }
        _ = sendCommand(Self.kMRPlay, nil)
        didPauseMedia = false
    }
}
