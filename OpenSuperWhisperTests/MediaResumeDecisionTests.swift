import XCTest
import Carbon
@testable import OpenSuperWhisper

/// The backend is fake: tests never send commands to the user's players or prompt TCC.
final class MediaResumeDecisionTests: XCTestCase {
    private var backend: FakeMediaBackend!
    private var queue: DispatchQueue!
    private var controller: MediaPlaybackController!
    private let music = MediaPlayer(bundleID: "com.apple.Music", pid: 1, launchDate: .distantPast)
    private let spotify = MediaPlayer(bundleID: "com.spotify.client", pid: 2, launchDate: .distantPast)

    override func setUp() {
        super.setUp()
        backend = FakeMediaBackend()
        queue = DispatchQueue(label: "test.media")
        controller = MediaPlaybackController(backend: backend, queue: queue)
    }

    private func drain() { queue.sync {} }
    private func playing(_ player: MediaPlayer) {
        backend.players.append(player)
        backend.states[player.pid] = .init(state: .playing, trackID: "track", position: 42)
    }
    private func pause() { controller.pauseMedia(); drain() }
    private func resume() { controller.resumeMedia(); drain() }

    func testMusicPlayingBeforeFirstDictationResumesWithoutAnnouncements() {
        playing(music)
        pause()
        XCTAssertEqual(backend.commands, ["pause:1"])
        resume()
        XCTAssertEqual(backend.commands, ["pause:1", "play:1"])
    }

    func testSpotifyResumesSamePlayer() {
        playing(spotify)
        pause()
        resume()
        XCTAssertEqual(backend.commands, ["pause:2", "play:2"])
    }

    func testAlreadyPausedMusicNeverStarts() {
        playing(music)
        backend.states[1] = .init(state: .paused, trackID: "track", position: 42)
        pause()
        resume()
        XCTAssertEqual(backend.commands, [])
    }

    func testStoppedPlayerNeverStarts() {
        playing(music)
        backend.states[1] = .init(state: .stopped, trackID: "", position: 0)
        pause()
        resume()
        XCTAssertEqual(backend.commands, [])
    }

    func testNoSupportedPlayerDoesNothingInsteadOfGlobalPause() {
        pause()
        resume()
        XCTAssertEqual(backend.commands, [])
    }

    func testUnknownStateDoesNotPause() {
        playing(music)
        backend.failRead = true
        pause()
        backend.failRead = false
        resume()
        XCTAssertEqual(backend.commands, [])
    }

    func testMissingPermissionLeavesPlaybackAloneThenWorksWhenGranted() {
        playing(music)
        backend.authorized = false
        pause()
        resume()
        XCTAssertEqual(backend.commands, [])
        backend.authorized = true
        pause()
        resume()
        XCTAssertEqual(backend.commands, ["pause:1", "play:1"])
    }

    func testMultiplePlayersAreRestoredIndependently() {
        playing(music)
        playing(spotify)
        pause()
        resume()
        XCTAssertEqual(backend.commands, ["pause:1", "pause:2", "play:1", "play:2"])
    }

    func testOnePlayerFailureDoesNotPreventAnotherFromResuming() {
        playing(music)
        playing(spotify)
        pause()
        backend.states.removeValue(forKey: 1)
        resume()
        XCTAssertEqual(backend.commands, ["pause:1", "pause:2", "play:2"])
    }

    func testTerminatedPlayerIsNotRelaunched() {
        playing(music)
        pause()
        backend.states.removeValue(forKey: 1)
        resume()
        XCTAssertEqual(backend.commands, ["pause:1"])
    }

    func testChangedTrackDoesNotResume() {
        playing(music)
        pause()
        backend.states[1] = .init(state: .paused, trackID: "different", position: 42)
        resume()
        XCTAssertEqual(backend.commands, ["pause:1"])
    }

    func testUserSeekDoesNotResume() {
        playing(music)
        pause()
        backend.states[1] = .init(state: .paused, trackID: "track", position: 90)
        resume()
        XCTAssertEqual(backend.commands, ["pause:1"])
    }

    func testUserRestartDoesNotSendAnotherPlay() {
        playing(music)
        pause()
        backend.states[1] = .init(state: .playing, trackID: "track", position: 42)
        resume()
        XCTAssertEqual(backend.commands, ["pause:1"])
    }

    func testDuplicateStartAndStopRestoreExactlyOnce() {
        playing(music)
        pause()
        pause()
        resume()
        resume()
        XCTAssertEqual(backend.commands, ["pause:1", "play:1"])
    }

    func testStopWithoutStartDoesNothing() {
        resume()
        XCTAssertEqual(backend.commands, [])
    }

    func testStopBeforeWorkerStartsDoesNotPauseLater() {
        playing(music)
        queue.suspend()
        controller.pauseMedia()
        controller.resumeMedia()
        queue.resume()
        drain()
        XCTAssertEqual(backend.commands, [])
    }

    func testStopDuringPlaybackReadDoesNotPauseLater() {
        playing(music)
        let entered = expectation(description: "read started")
        let release = DispatchSemaphore(value: 0)
        backend.onRead = {
            entered.fulfill()
            release.wait()
        }
        controller.pauseMedia()
        wait(for: [entered], timeout: 2)
        controller.resumeMedia()
        release.signal()
        drain()
        XCTAssertEqual(backend.commands, [])
    }

    func testStopDuringPauseStillRestores() {
        playing(music)
        let entered = expectation(description: "pause started")
        let release = DispatchSemaphore(value: 0)
        backend.onPause = {
            entered.fulfill()
            release.wait()
        }
        controller.pauseMedia()
        wait(for: [entered], timeout: 2)
        controller.resumeMedia()
        release.signal()
        drain()
        XCTAssertEqual(backend.commands, ["pause:1", "play:1"])
    }

    func testNextRecordingWaitsForPreviousRestore() {
        playing(music)
        pause()
        controller.resumeMedia()
        controller.pauseMedia()
        drain()
        resume()
        XCTAssertEqual(backend.commands, ["pause:1", "play:1", "pause:1", "play:1"])
    }

    func testRejectedPauseDoesNotClaimPlayback() {
        playing(music)
        backend.pauseError = NSError(domain: NSOSStatusErrorDomain, code: Int(errAEEventNotPermitted))
        pause()
        // Even if someone else pauses it, Rhino must not resume a rejected request.
        backend.states[1] = .init(state: .paused, trackID: "track", position: 42)
        resume()
        XCTAssertEqual(backend.commands, ["pause:1"])
    }

    func testPauseTimeoutChecksFreshStateBeforeRestoring() {
        playing(music)
        backend.pauseError = NSError(domain: NSOSStatusErrorDomain, code: Int(errAETimeout))
        pause()
        backend.states[1] = .init(state: .paused, trackID: "track", position: 42)
        resume()
        XCTAssertEqual(backend.commands, ["pause:1", "play:1"])
    }

    func testUnconfirmedPauseCanBeRestoredFromFreshState() {
        playing(music)
        backend.onPause = { self.backend.failRead = true }
        pause()
        backend.failRead = false
        resume()
        XCTAssertEqual(backend.commands, ["pause:1", "play:1"])
    }

    func testConfirmedTrackChangeDiscardsTicketEvenIfOriginalTrackReturns() {
        playing(music)
        backend.onPause = {
            self.backend.states[1] = .init(state: .playing, trackID: "new-track", position: 0)
        }
        pause()
        backend.states[1] = .init(state: .paused, trackID: "track", position: 42)
        resume()
        XCTAssertEqual(backend.commands, ["pause:1"])
    }

    func testFailedResumeReadNeverSendsPlay() {
        playing(music)
        pause()
        backend.failRead = true
        resume()
        XCTAssertEqual(backend.commands, ["pause:1"])
    }

    func testQuitRejectsLateRecordingStart() {
        playing(music)
        pause()
        let complete = expectation(description: "quit may proceed")
        controller.prepareForTermination { complete.fulfill() }
        controller.pauseMedia()
        wait(for: [complete], timeout: 2)
        drain()
        XCTAssertEqual(backend.commands, ["pause:1", "play:1"])
    }

    func testQuitCompletionWaitsForAlreadyQueuedRestore() {
        playing(music)
        pause()
        controller.resumeMedia()
        let complete = expectation(description: "quit may proceed")
        controller.resumeMedia {
            XCTAssertEqual(self.backend.commands, ["pause:1", "play:1"])
            complete.fulfill()
        }
        wait(for: [complete], timeout: 2)
    }
}

private final class FakeMediaBackend: MediaPlaybackBackend {
    var players: [MediaPlayer] = []
    var states: [pid_t: MediaPlaybackSnapshot] = [:]
    var commands: [String] = []
    var authorized = true
    var failRead = false
    var pauseError: Error?
    var onRead: (() -> Void)?
    var onPause: (() -> Void)?
    enum Failure: Error { case unavailable }

    func runningPlayers() -> [MediaPlayer] { players }
    func hasPermission(for player: MediaPlayer) -> Bool { authorized }
    func snapshot(_ player: MediaPlayer) throws -> MediaPlaybackSnapshot {
        let hook = onRead
        onRead = nil
        hook?()
        guard !failRead, let state = states[player.pid] else { throw Failure.unavailable }
        return state
    }
    func pause(_ player: MediaPlayer) throws {
        commands.append("pause:\(player.pid)")
        onPause?()
        if let pauseError { throw pauseError }
        let state = states[player.pid]!
        states[player.pid] = .init(state: .paused, trackID: state.trackID, position: state.position)
    }
    func play(_ player: MediaPlayer) throws {
        commands.append("play:\(player.pid)")
        let state = states[player.pid]!
        states[player.pid] = .init(state: .playing, trackID: state.trackID, position: state.position)
    }
}
