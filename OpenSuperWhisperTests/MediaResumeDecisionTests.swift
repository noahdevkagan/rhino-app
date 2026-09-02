import XCTest
@testable import OpenSuperWhisper

/// The "was media playing when we paused?" decision that arms the post-dictation resume, on the
/// public-signal path (now-playing reads are entitlement-gated since macOS 15.4). Every case here
/// is a way the old device-level probe started music the user was not listening to.
final class MediaResumeDecisionTests: XCTestCase {
    private typealias Process = MediaPlaybackController.AudioProcess
    private let me: pid_t = 4242

    private func decide(_ processes: [Process], players: [String: Bool] = [:]) -> Bool {
        MediaPlaybackController.isMediaPlaying(processes: processes, selfPID: me, knownPlayerStates: players)
    }

    func testNothingRenderingIsNotPlaying() {
        XCTAssertFalse(decide([]))
        XCTAssertFalse(decide([Process(pid: 7, bundleID: "com.example.idle", isRunningOutput: false, isRunningInput: false)]))
    }

    func testAnotherProcessRenderingOutputIsPlaying() {
        // A browser tab or video player we have no announcements for: output IO is all we have.
        XCTAssertTrue(decide([Process(pid: 7, bundleID: "com.google.Chrome", isRunningOutput: true, isRunningInput: false)]))
        XCTAssertTrue(decide([Process(pid: 7, bundleID: nil, isRunningOutput: true, isRunningInput: false)]))
    }

    func testOurOwnOutputNeverCounts() {
        // The start chime holds the output device for ~3s; a quick second dictation used to
        // read that as "music playing" and wake the paused player on stop.
        XCTAssertFalse(decide([Process(pid: me, bundleID: "com.noahkagan.rhino", isRunningOutput: true, isRunningInput: false)]))
        XCTAssertFalse(decide([Process(pid: me, bundleID: "com.noahkagan.rhino", isRunningOutput: true, isRunningInput: true)]))
    }

    func testInputOnlyProcessesAreNotMedia() {
        // Another dictation/meeting app's AVAudioEngine input tap marks the output device running.
        XCTAssertFalse(decide([Process(pid: 7, bundleID: "com.example.recorder", isRunningOutput: false, isRunningInput: true)]))
    }

    func testCallsAreNotMedia() {
        // Zoom/Teams render output AND capture input; "resuming" after dictating on a call sent
        // play to the now-playing owner — the user's paused music — instead.
        XCTAssertFalse(decide([Process(pid: 7, bundleID: "us.zoom.xos", isRunningOutput: true, isRunningInput: true)]))
    }

    func testAnnouncedPausedPlayerHoldingTheDeviceIsNotPlaying() {
        // Observed: a paused Spotify keeps its output stream open for minutes after pausing.
        let spotify = Process(pid: 7, bundleID: "com.spotify.client", isRunningOutput: true, isRunningInput: false)
        XCTAssertFalse(decide([spotify], players: ["com.spotify.client": false]))
        // Without an announcement it's indistinguishable from playing, so the IO wins.
        XCTAssertTrue(decide([spotify]))
    }

    func testAnnouncedPlayingPlayerIsPlayingEvenWithoutLocalOutput() {
        // Spotify Connect renders on another device: no local IO, but our pause paused it, so
        // the resume must be armed.
        XCTAssertTrue(decide([], players: ["com.spotify.client": true]))
        XCTAssertTrue(decide([Process(pid: 7, bundleID: "com.spotify.client", isRunningOutput: false, isRunningInput: false)],
                             players: ["com.spotify.client": true]))
    }

    func testPausedPlayerDoesNotMaskOtherOutput() {
        let spotify = Process(pid: 7, bundleID: "com.spotify.client", isRunningOutput: true, isRunningInput: false)
        let browser = Process(pid: 8, bundleID: "com.apple.Safari", isRunningOutput: true, isRunningInput: false)
        XCTAssertTrue(decide([spotify, browser], players: ["com.spotify.client": false]))
    }

    func testAnnouncementParsing() {
        let controller = MediaPlaybackController.shared
        controller.notePlayerState(bundleID: "com.apple.Music", state: "Playing")
        XCTAssertEqual(controller.knownPlayerStates["com.apple.Music"], true)
        controller.notePlayerState(bundleID: "com.apple.Music", state: "Paused")
        XCTAssertEqual(controller.knownPlayerStates["com.apple.Music"], false)
        controller.notePlayerState(bundleID: "com.apple.Music", state: "Stopped")
        XCTAssertEqual(controller.knownPlayerStates["com.apple.Music"], false)
    }
}
