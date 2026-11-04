import AppKit
import ApplicationServices
import Foundation

/// Pause is unconditional and idempotent. Resume requires explicit playback evidence:
/// one known playing player must announce its transition to paused during this recording.
///
/// CoreAudio output IO is NOT playback state: paused Music/Spotify and silent browser tabs
/// can keep streams open. MediaRemote reads are entitlement-gated in shipped builds, and a
/// cached read can be stale. Neither is allowed to arm a global Play command. Consequently
/// players without announcements stay paused until the user resumes them.
///
/// Chrome is the exception: its tab labels say "- Audio playing". Play is sent only when one
/// tab was audible at the pause and that same tab has gone quiet, which also proves the
/// system-wide Pause reached it rather than some other player.
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
    private let scanTabs: (@escaping ([String]) -> Void) -> Void
    private let delay: (TimeInterval, @escaping () -> Void) -> Void
    /// Bumped to abandon the browser resume of a recording, including scans still in flight.
    private var browserCycle = 0
    private var audibleTab: String?
    private var announcementObserver: PlayerAnnouncementObserver?
    private var terminationObserver: NSObjectProtocol?

    private static let kMRPlay: UInt32 = 0
    private static let kMRPause: UInt32 = 1
    private static let audibleSuffix = " - Audio playing"
    /// Chrome holds the label about 2 s after sound stops; a tab still audible after this
    /// never took the Pause.
    private static let quietCheckAttempts = 10
    private static let quietCheckInterval: TimeInterval = 0.5

    private convenience init() {
        let bundle = CFBundleCreate(
            kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
        typealias Send = @convention(c) (UInt32, UnsafeRawPointer?) -> Bool
        let send: Send? = bundle.flatMap {
            CFBundleGetFunctionPointerForName($0, "MRMediaRemoteSendCommand" as CFString)
        }.map { unsafeBitCast($0, to: Send.self) }
        let scanQueue = DispatchQueue(label: "rhino.media.tabscan", qos: .userInitiated)
        self.init(
            sendCommand: { command in send?(command, nil) ?? false },
            // Serial, so a stop's scan always lands after the scan its start queued.
            scanTabs: { done in
                scanQueue.async {
                    let labels = ChromeTabLabels.read()
                    DispatchQueue.main.async { done(labels) }
                }
            },
            delay: { DispatchQueue.main.asyncAfter(deadline: .now() + $0, execute: $1) })
        observePlayerAnnouncements()
    }

    /// Inject commands for tests without controlling the user's actual media.
    init(
        sendCommand: @escaping (UInt32) -> Bool,
        scanTabs: @escaping (@escaping ([String]) -> Void) -> Void = { $0([]) },
        delay: @escaping (TimeInterval, @escaping () -> Void) -> Void = { $1() }
    ) {
        self.sendCommand = sendCommand
        self.scanTabs = scanTabs
        self.delay = delay
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
        // A player moved, so a system-wide Play might no longer reach the browser tab.
        abandonTabResume()
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
        abandonTabResume()
        // Read before pausing; the label outlasts the Pause, so the scan needn't delay it.
        if playing.isEmpty { noteAudibleTab(cycle: browserCycle) }
        if !sendCommand(Self.kMRPause) {
            clearResume()
            abandonTabResume()
        }
        print("Media pause: awaiting explicit player pause=\(resumeCandidate ?? "none")")
    }

    /// Also used on cancellation. Consume the recording before sending, so repeated stops
    /// and late announcements cannot replay a resume from an earlier recording.
    func resumeMedia(allowResume: Bool = true) {
        let shouldResume = allowResume && recording && didPauseMedia && resumeCandidate.map {
            knownPlayerStates[$0] == false
        } == true
        let wasRecording = recording
        recording = false
        clearResume()
        if shouldResume {
            _ = sendCommand(Self.kMRPlay)
        } else if wasRecording {
            if allowResume {
                resumeTabOnceQuiet(cycle: browserCycle, attemptsLeft: Self.quietCheckAttempts)
            } else {
                abandonTabResume()
            }
        }
    }

    private func abandonTabResume() {
        browserCycle += 1
        audibleTab = nil
    }

    private func noteAudibleTab(cycle: Int) {
        scanTabs { [weak self] labels in
            guard let self, cycle == self.browserCycle else { return }
            let audible = labels.filter { $0.hasSuffix(Self.audibleSuffix) }
            // Several audible tabs cannot be restored safely by one system-wide command.
            self.audibleTab = audible.count == 1 ? String(audible[0].dropLast(Self.audibleSuffix.count)) : nil
        }
    }

    private func resumeTabOnceQuiet(cycle: Int, attemptsLeft: Int) {
        scanTabs { [weak self] labels in
            guard let self, cycle == self.browserCycle, let tab = self.audibleTab else { return }
            if labels.contains(where: { $0.hasSuffix(Self.audibleSuffix) }) {
                guard attemptsLeft > 1 else { return }
                self.delay(Self.quietCheckInterval) { [weak self] in
                    self?.resumeTabOnceQuiet(cycle: cycle, attemptsLeft: attemptsLeft - 1)
                }
            } else if labels.contains(tab) {
                self.abandonTabResume()
                _ = self.sendCommand(Self.kMRPlay)
            }
        }
    }

    private func clearResume() {
        didPauseMedia = false
        resumeCandidate = nil
    }
}

/// Chrome's tab labels via Accessibility, which Rhino already holds for pasting.
/// The label is translated, so non-English Chrome simply stays paused.
private enum ChromeTabLabels {
    static func read() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == "com.google.Chrome" }
            .flatMap { chrome -> [String] in
                let app = AXUIElementCreateApplication(chrome.processIdentifier)
                // A windowless Chrome process can stall each call by seconds otherwise.
                AXUIElementSetMessagingTimeout(app, 0.25)
                var labels: [String] = []
                for window in children(of: app, attribute: kAXWindowsAttribute) {
                    collect(window, depth: 0, inTabGroup: false, into: &labels)
                }
                return labels
            }
    }

    private static func collect(_ element: AXUIElement, depth: Int, inTabGroup: Bool, into labels: inout [String]) {
        guard depth < 14 else { return }
        let role = string(element, kAXRoleAttribute)
        if role == "AXWebArea" { return }
        if inTabGroup, string(element, kAXSubroleAttribute) == "AXTabButton" {
            labels.append(string(element, kAXDescriptionAttribute))
            return
        }
        for child in children(of: element, attribute: kAXChildrenAttribute) {
            collect(child, depth: depth + 1, inTabGroup: inTabGroup || role == "AXTabGroup", into: &labels)
        }
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value as? String ?? ""
    }

    private static func children(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value as? [AXUIElement] ?? []
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
