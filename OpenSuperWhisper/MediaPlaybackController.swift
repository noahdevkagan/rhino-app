import AppKit
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
/// things the user didn't know were "playing"). Three signals feed the was-it-playing decision:
///
///   • MediaRemote now-playing reads (the Now Playing app's playback rate) — precise, but since
///     macOS 15.4 they're gated on a private Apple entitlement: Apple platform binaries read fine
///     (the signed `swift` toolchain reads `rate=1` for a playing Chrome tab) while our builds —
///     Developer ID and ad-hoc alike — read nothing back. When reads do work (`canRead`), poll
///     while not recording, snapshot at pause, and resume only if it was playing.
///   • Player announcements (public, passive): Spotify and Music broadcast every play/pause over
///     `DistributedNotificationCenter` with a "Player State". Once we've seen one, that app's
///     state is authoritative — it is the only public way to tell a *paused* player from a
///     playing one, because a paused Spotify keeps its output stream open for minutes.
///   • CoreAudio per-process IO (public, always works): which processes are rendering output
///     right now (`kAudioHardwarePropertyProcessObjectList` + `kAudioProcessPropertyIsRunningOutput`).
///     Coarse — it answers "is audio being rendered", not "is media playing" — so it's the
///     fallback for apps that don't announce (browsers, video players). Our own process is
///     ignored (the start chime holds the output device for ~3s after it plays; our AVAudioEngine
///     input taps mark the output device running too), and so is any process that also runs
///     *input* (a Zoom/Teams call is not media, and a "resume" during a call woke the user's
///     paused music player instead).
///
/// Earlier builds used the device-level `kAudioDevicePropertyDeviceIsRunningSomewhere` probe,
/// which cannot tell any of those apart: it read true for our own chime, for a call, and for a
/// paused Spotify — and in all three cases the stop-of-dictation "resume" started music the
/// user had not been listening to.
///
/// Send commands are NOT entitlement-gated, which is why the pause half always worked.
/// MediaRemote's now-playing is a single system-wide owner, so this acts on the active player;
/// it can't restore several sources at once.
final class MediaPlaybackController {
    static let shared = MediaPlaybackController()

    /// One process's audio IO state, as CoreAudio reports it (process objects, macOS 14.2+).
    struct AudioProcess: Equatable {
        let pid: pid_t
        let bundleID: String?
        let isRunningOutput: Bool
        let isRunningInput: Bool
    }

    /// Players that announce their playback state over distributed notifications, and the
    /// CoreAudio bundle id their output IO shows up under.
    static let announcingPlayers: [(notification: Notification.Name, bundleID: String)] = [
        (Notification.Name("com.spotify.client.PlaybackStateChanged"), "com.spotify.client"),
        (Notification.Name("com.apple.Music.playerInfo"), "com.apple.Music"),
    ]

    /// Whether we armed a resume this cycle (something was audibly playing when we paused).
    private(set) var didPauseMedia = false

    /// Latest announced state per player bundle id (`true` = playing). Main-confined. An entry
    /// exists only for a player we've heard from since it (or we) launched; it's dropped when
    /// the player quits so a relaunched one starts unknown again.
    private(set) var knownPlayerStates: [String: Bool] = [:]

    /// Cached "is the Now Playing app playing?" (from the playback rate), refreshed while not
    /// recording so it reflects the state from *before* a recording disrupts the flag. Only
    /// meaningful when `canRead` is true.
    private var isNowPlaying = false

    /// Whether this process can actually read now-playing state (see the type doc — entitlement-
    /// gated since macOS 15.4). Set true the first time a now-playing info dict comes back. While
    /// false the was-it-playing decision uses player announcements + the CoreAudio process probe.
    private var canRead = false
    private var readAttempts = 0

    private static let kMRPlay: UInt32 = 0
    private static let kMRPause: UInt32 = 1
    private static let pollInterval: TimeInterval = 1.5
    /// Give reads a few tries; if none succeed this process can't read now-playing — stop polling
    /// and settle into the announcement/CoreAudio path rather than polling forever.
    private static let maxReadAttempts = 5

    private let sendCommand: (@convention(c) (UInt32, UnsafeRawPointer?) -> Bool)?
    /// MRMediaRemoteGetNowPlayingInfo(queue, completion(infoDict?)). The dict is nil when this
    /// process can't read now-playing, which doubles as the capability signal.
    private let getInfo: (@convention(c) (DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void) -> Void)?
    private var pollTimer: Timer?
    private var observers: [NSObjectProtocol] = []

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

        observePlayerAnnouncements()
        startPolling()
    }

    deinit {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    // MARK: - Player announcements

    private func observePlayerAnnouncements() {
        let dnc = DistributedNotificationCenter.default()
        for player in Self.announcingPlayers {
            observers.append(dnc.addObserver(forName: player.notification, object: nil, queue: .main) { [weak self] note in
                guard let state = note.userInfo?["Player State"] as? String else { return }
                self?.notePlayerState(bundleID: player.bundleID, state: state)
            })
        }
        // A quit player's stale "Playing" must not arm a resume once it's relaunched paused.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            self?.knownPlayerStates.removeValue(forKey: bundleID)
        })
    }

    /// Records an announced state. Both Spotify and Music use "Playing" / "Paused" / "Stopped".
    func notePlayerState(bundleID: String, state: String) {
        knownPlayerStates[bundleID] = (state == "Playing")
    }

    // MARK: - Now-playing reads (only where they work)

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
        // player announcements + the CoreAudio process probe.
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

    // MARK: - Pause / resume

    /// Pause playback (unconditional = reliable), arming a resume only if something was actually
    /// playing when we paused, and freezing the cache while the recording runs. Main thread only
    /// (`knownPlayerStates` and the poll timer live here).
    ///
    /// `audioProcessesHint`: the CoreAudio snapshot should be taken BEFORE this recording cycle
    /// touches the audio hardware — starting the mic on a Bluetooth headset can renegotiate the
    /// device, and other processes' output IO flickers while it does. AudioRecorder calls this via
    /// an async hop to main, which can land after `.record()`, so it samples the snapshot on its
    /// own queue first and passes it here. Sampling inline stays the fallback.
    func pauseMedia(audioProcessesHint: [AudioProcess]? = nil) {
        guard let sendCommand else { return }
        let wasPlaying: Bool
        let via: String
        if canRead {
            // Precise path when now-playing reads work (see the type doc).
            wasPlaying = isNowPlaying
            via = "now-playing"
        } else if let processes = audioProcessesHint ?? Self.audioProcesses() {
            wasPlaying = Self.isMediaPlaying(
                processes: processes, selfPID: getpid(), knownPlayerStates: knownPlayerStates)
            let rendering = processes.filter { $0.isRunningOutput }
                .map { "\($0.bundleID ?? "pid \($0.pid)")\($0.isRunningInput ? "+input" : "")" }
            let announced = knownPlayerStates.map { "\($0.key)=\($0.value ? "playing" : "paused")" }.sorted()
            via = "processes output=\(rendering) announced=\(announced)"
        } else {
            wasPlaying = Self.isSystemOutputActive()
            via = "output-device"
        }
        print("Media pause: resume \(wasPlaying ? "armed" : "not armed") via \(via)")
        stopPolling()
        _ = sendCommand(Self.kMRPause, nil)
        didPauseMedia = wasPlaying
    }

    /// The was-it-playing decision from public signals, for when now-playing reads are gated.
    ///
    /// A player we've heard from is authoritative: playing → true even without local output IO
    /// (Spotify Connect renders elsewhere, yet our pause paused it); paused → its still-open
    /// output stream is ignored. Otherwise any *other* process rendering output counts, unless
    /// it also runs input (a call, not media). Our own process never counts — the start chime
    /// and our AVAudioEngine taps are not the user's music.
    static func isMediaPlaying(processes: [AudioProcess], selfPID: pid_t, knownPlayerStates: [String: Bool]) -> Bool {
        if knownPlayerStates.values.contains(true) { return true }
        return processes.contains { process in
            process.pid != selfPID
                && process.isRunningOutput
                && !process.isRunningInput
                && process.bundleID.flatMap { knownPlayerStates[$0] } == nil
        }
    }

    /// Every process CoreAudio knows about and whether it is running output/input IO right now.
    /// Stateless CoreAudio reads — safe from any thread. `nil` if the process-object list is
    /// unavailable (it's a macOS 14.2+ API; we deploy on 15.1, so this is defensive).
    static func audioProcesses() -> [AudioProcess]? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return nil }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else { return nil }

        return objects.compactMap { object in
            guard let pid: pid_t = integerProperty(object, kAudioProcessPropertyPID) else { return nil }
            let bundleID = stringProperty(object, kAudioProcessPropertyBundleID)
            return AudioProcess(
                pid: pid,
                bundleID: (bundleID?.isEmpty ?? true) ? nil : bundleID,
                isRunningOutput: (integerProperty(object, kAudioProcessPropertyIsRunningOutput) ?? UInt32(0)) != 0,
                isRunningInput: (integerProperty(object, kAudioProcessPropertyIsRunningInput) ?? UInt32(0)) != 0)
        }
    }

    private static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
    }

    private static func integerProperty<T: FixedWidthInteger>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> T? {
        var address = globalAddress(selector)
        var value: T = 0
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func stringProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = globalAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    /// Device-level proxy for "is audio audibly playing right now?": whether any process is
    /// running IO on the default output device. Kept only as the fallback when the per-process
    /// list is unavailable — it can't exclude our own chime, calls, or a paused-but-holding player.
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
