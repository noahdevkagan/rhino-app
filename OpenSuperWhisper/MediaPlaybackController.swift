import AppKit
import Foundation

/// Pause is unconditional and idempotent. Resume requires explicit playback evidence:
/// one known playing player must announce its transition to paused during this recording.
///
/// CoreAudio output IO is NOT playback state: paused Music/Spotify and silent browser tabs
/// can keep streams open. MediaRemote reads are entitlement-gated in shipped builds, and a
/// cached read can be stale. Neither is allowed to arm a global Play command. Consequently
/// browsers and players without announcements stay paused until the user resumes them.
/// All mutable state and calls are main-thread confined.
final class MediaPlaybackController {
    static let shared = MediaPlaybackController()

    static let announcingPlayers: [(notification: Notification.Name, bundleID: String)] = [
        (Notification.Name("com.spotify.client.PlaybackStateChanged"), "com.spotify.client"),
        (Notification.Name("com.apple.Music.playerInfo"), "com.apple.Music"),
    ]

    private(set) var knownPlayerStates: [String: Bool] = [:]
    private(set) var didPauseMedia = false
    private var recording = false
    private var resumeCandidate: String?
    private let sendCommand: (UInt32) -> Bool
    private var announcementObserver: PlayerAnnouncementObserver?
    private var terminationObserver: NSObjectProtocol?

    private static let kMRPlay: UInt32 = 0
    private static let kMRPause: UInt32 = 1

    private convenience init() {
        let bundle = CFBundleCreate(
            kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
        typealias Send = @convention(c) (UInt32, UnsafeRawPointer?) -> Bool
        let send: Send? = bundle.flatMap {
            CFBundleGetFunctionPointerForName($0, "MRMediaRemoteSendCommand" as CFString)
        }.map { unsafeBitCast($0, to: Send.self) }
        self.init(sendCommand: { command in send?(command, nil) ?? false })
        observePlayerAnnouncements()
    }

    /// Inject commands for tests without controlling the user's actual media.
    init(sendCommand: @escaping (UInt32) -> Bool) {
        self.sendCommand = sendCommand
    }

    deinit {
        announcementObserver.map { DistributedNotificationCenter.default().removeObserver($0) }
        if let terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver)
        }
    }

    private func observePlayerAnnouncements() {
        // The Paused announcement must arrive DURING the recording, while Rhino (an accessory
        // app) is inactive. AppKit suspends distributed delivery for inactive apps and the
        // block API can't opt out, so it would coalesce until the next activation — after
        // resumeMedia already declined. `.deliverImmediately` needs the selector API.
        let observer = PlayerAnnouncementObserver { [weak self] bundleID, state in
            self?.notePlayerState(bundleID: bundleID, state: state)
        }
        for player in Self.announcingPlayers {
            DistributedNotificationCenter.default().addObserver(
                observer, selector: #selector(PlayerAnnouncementObserver.playerStateChanged(_:)),
                name: player.notification, object: nil, suspensionBehavior: .deliverImmediately)
        }
        announcementObserver = observer
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            self?.notePlayerTerminated(bundleID: bundleID)
        }
    }

    func notePlayerState(bundleID: String, state: String) {
        guard Self.announcingPlayers.contains(where: { $0.bundleID == bundleID }) else { return }
        let wasPlaying = knownPlayerStates[bundleID] == true
        switch state {
        case "Playing": knownPlayerStates[bundleID] = true
        case "Paused", "Stopped": knownPlayerStates[bundleID] = false
        default: knownPlayerStates.removeValue(forKey: bundleID)
        }

        guard recording, let candidate = resumeCandidate else { return }
        if bundleID == candidate {
            if state == "Paused" {
                // Require the actual Playing → Paused transition, not a silent open stream.
                if wasPlaying { didPauseMedia = true }
            } else {
                // Playback restarted, stopped, or became unknown: respect that new state.
                clearResume()
            }
        } else {
            // Another player changed state; a system-wide Play could target the wrong app.
            clearResume()
        }
    }

    func notePlayerTerminated(bundleID: String) {
        knownPlayerStates.removeValue(forKey: bundleID)
        if resumeCandidate == bundleID { clearResume() }
    }

    func pauseMedia() {
        guard !recording else { return }
        recording = true
        let playing = knownPlayerStates.filter { $0.value }.map { $0.key }
        // Multiple playing apps cannot be restored safely by one system-wide command.
        resumeCandidate = playing.count == 1 ? playing.first : nil
        didPauseMedia = false
        if !sendCommand(Self.kMRPause) { clearResume() }
        print("Media pause: awaiting explicit player pause=\(resumeCandidate ?? "none")")
    }

    /// Also used on cancellation. Consume the recording before sending, so repeated stops
    /// and late announcements cannot replay a resume from an earlier recording.
    func resumeMedia(allowResume: Bool = true) {
        let shouldResume = allowResume && recording && didPauseMedia && resumeCandidate.map {
            knownPlayerStates[$0] == false
        } == true
        recording = false
        clearResume()
        if shouldResume { _ = sendCommand(Self.kMRPlay) }
    }

    private func clearResume() {
        didPauseMedia = false
        resumeCandidate = nil
    }
}

/// Selector target for distributed player announcements (see `observePlayerAnnouncements`).
private final class PlayerAnnouncementObserver: NSObject {
    private let onState: (_ bundleID: String, _ state: String) -> Void

    init(onState: @escaping (_ bundleID: String, _ state: String) -> Void) {
        self.onState = onState
    }

    @objc func playerStateChanged(_ note: Notification) {
        guard let player = MediaPlaybackController.announcingPlayers.first(where: { $0.notification == note.name }),
              let state = note.userInfo?["Player State"] as? String else { return }
        // Controller state is main-confined; distributed notifications normally land on main.
        if Thread.isMainThread {
            onState(player.bundleID, state)
        } else {
            DispatchQueue.main.async { self.onState(player.bundleID, state) }
        }
    }
}
