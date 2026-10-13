import AppKit
import Carbon

/// Local, addressed playback control. Never send a global Play/Pause: its recipient can
/// change while dictating. Browser media is tracked separately by exact DOM element.
final class MediaPlaybackController {
    static let shared = MediaPlaybackController(backend: AppleEventMediaBackend(),
                                                browsers: BrowserMediaController())

    private let backend: MediaPlaybackBackend
    private let queue: DispatchQueue
    private let browsers: BrowserMediaController?
    // Accessed only by callers on main. The worker owns each session's resume tickets.
    private var session: MediaPauseSession?
    private var isTerminating = false

    init(backend: MediaPlaybackBackend,
         browsers: BrowserMediaController? = nil,
         queue: DispatchQueue = DispatchQueue(label: "rhino.media-playback")) {
        self.backend = backend
        self.browsers = browsers
        self.queue = queue
    }

    func pauseMedia() {
        guard !isTerminating, session == nil else { return }
        let session = MediaPauseSession()
        self.session = session
        queue.async { [backend, browsers] in
            for player in backend.runningPlayers() {
                guard session.isActive else { break }
                // Permission is asked for only from Settings. Until granted, leave
                // playback alone; never hold up the mic or show a dialog mid-recording.
                guard backend.hasPermission(for: player),
                      let before = try? backend.snapshot(player), before.state == .playing,
                      session.isActive else { continue }
                do {
                    try backend.pause(player)
                    // Keep the original ticket even if the confirmation read fails: at
                    // stop, a fresh read can still safely restore this exact track.
                    session.tickets.append((player, before))
                    if let paused = try? backend.snapshot(player) {
                        if paused.state == .paused, paused.trackID == before.trackID {
                            session.tickets[session.tickets.count - 1].1 = paused
                        } else {
                            // A successful read proves playback changed instead of pausing
                            // this track. Do not claim a later manual pause as our own.
                            session.tickets.removeLast()
                        }
                    }
                } catch where (error as NSError).domain == NSOSStatusErrorDomain
                    && (error as NSError).code == Int(errAETimeout) {
                    // A timeout is ambiguous: the player may have executed Pause before
                    // its reply was lost. Recheck the original track on stop, never toggle.
                    session.tickets.append((player, before))
                } catch {
                    // A denied/rejected command did not give Rhino ownership of playback.
                }
            }
            if session.isActive {
                session.browserTickets = browsers?.pause(isActive: { session.isActive }) ?? []
            }
        }
    }

    /// Settings action (turning the toggle on, or "Allow access"): ask macOS for Automation
    /// access to each supported player/browser that is open now. Runs on its own queue
    /// because each consent dialog blocks until answered; the playback worker stays free.
    static func requestAutomationAccess() {
        permissionQueue.async {
            let events = MediaAppleEventClient()
            for player in events.runningApplications(MediaAppleEventClient.supported) {
                events.requestPermission(for: player)
            }
        }
    }
    private static let permissionQueue = DispatchQueue(label: "rhino.media-permission")

    func prepareForTermination(completion: @escaping () -> Void) {
        isTerminating = true
        resumeMedia(completion: completion)
    }

    /// Restore what Rhino paused even when the setting was turned off mid-recording.
    /// Disabling it controls the NEXT recording, not whether we abandon paused playback.
    func resumeMedia(completion: (() -> Void)? = nil) {
        let ending = session
        session = nil
        ending?.cancel()
        queue.async { [backend, browsers] in
            for (player, paused) in ending?.tickets ?? [] {
                guard let now = try? backend.snapshot(player),
                      now.state == .paused, now.trackID == paused.trackID,
                      abs(now.position - paused.position) < 1 else { continue }
                try? backend.play(player)
            }
            browsers?.resume(ending?.browserTickets ?? [])
            // A barrier even without an active session: quit waits for an earlier stop.
            if let completion { DispatchQueue.main.async(execute: completion) }
        }
    }
}

private final class MediaPauseSession {
    private let lock = NSLock()
    private var active = true
    var tickets: [(MediaPlayer, MediaPlaybackSnapshot)] = [] // worker queue only
    var browserTickets: [BrowserMediaTicket] = []

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    func cancel() {
        lock.lock()
        active = false
        lock.unlock()
    }
}

struct MediaPlayer: Equatable {
    let bundleID: String
    let pid: pid_t
    let launchDate: Date
}

struct MediaPlaybackSnapshot {
    enum State { case playing, paused, stopped }
    let state: State
    let trackID: String
    let position: Double
}

protocol MediaPlaybackBackend: AnyObject {
    func runningPlayers() -> [MediaPlayer]
    func hasPermission(for player: MediaPlayer) -> Bool
    func snapshot(_ player: MediaPlayer) throws -> MediaPlaybackSnapshot
    func pause(_ player: MediaPlayer) throws
    func play(_ player: MediaPlayer) throws
}

/// Uses the players' shipping scripting dictionaries, addressed to a live PID rather
/// than a bundle ID (which can launch an app). No shell, network, or private framework.
final class AppleEventMediaBackend: MediaPlaybackBackend {
    private let events = MediaAppleEventClient()
    private enum Failure: Error { case badReply }

    func runningPlayers() -> [MediaPlayer] {
        events.runningApplications(["com.apple.Music", "com.spotify.client"])
    }

    func hasPermission(for player: MediaPlayer) -> Bool { events.hasPermission(for: player) }

    func snapshot(_ player: MediaPlayer) throws -> MediaPlaybackSnapshot {
        let stateCode = try property("pPlS", player: player).enumCodeValue
        let state: MediaPlaybackSnapshot.State
        switch stateCode {
        case MediaAppleEventClient.code("kPSP"): state = .playing
        case MediaAppleEventClient.code("kPSp"): state = .paused
        case MediaAppleEventClient.code("kPSS"): state = .stopped
        default: throw Failure.badReply
        }
        // A stopped/empty player has no current track; no reason to ask for one.
        if state == .stopped { return .init(state: state, trackID: "", position: 0) }
        let track = MediaAppleEventClient.propertySpecifier("pTrk")
        let id = try property(player.bundleID == "com.apple.Music" ? "pPIS" : "ID  ",
                              player: player, container: track).stringValue
        let positionValue = try property("pPos", player: player)
        guard let number = positionValue.coerce(toDescriptorType: typeIEEE64BitFloatingPoint),
              let id, !id.isEmpty else { throw Failure.badReply }
        let position = number.doubleValue
        guard position.isFinite, position >= 0 else { throw Failure.badReply }
        return .init(state: state, trackID: id, position: position)
    }

    func pause(_ player: MediaPlayer) throws { try command("Paus", player: player) }
    func play(_ player: MediaPlayer) throws { try command("Play", player: player) }

    private func command(_ id: String, player: MediaPlayer) throws {
        _ = try events.send(eventClass: player.bundleID == "com.apple.Music" ? "hook" : "spfy",
                     id: id, player: player)
    }

    private func property(_ name: String, player: MediaPlayer,
                          container: NSAppleEventDescriptor = .null()) throws -> NSAppleEventDescriptor {
        let reply = try events.send(eventClass: "core", id: "getd", player: player,
                             object: MediaAppleEventClient.propertySpecifier(name, container: container))
        guard let value = reply.paramDescriptor(forKeyword: keyDirectObject) else { throw Failure.badReply }
        return value
    }

}
