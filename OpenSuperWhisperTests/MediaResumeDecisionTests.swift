import XCTest
@testable import OpenSuperWhisper

/// Commands are injected: these tests never control real media or depend on system playback.
final class MediaResumeDecisionTests: XCTestCase {
    private var commands: [UInt32] = []
    private var pauseSucceeds = true
    private var controller: MediaPlaybackController!
    private let music = "com.apple.Music"
    private let spotify = "com.spotify.client"

    override func setUp() {
        super.setUp()
        commands = []
        pauseSucceeds = true
        controller = MediaPlaybackController(sendCommand: { [unowned self] command in
            self.commands.append(command)
            return command != 1 || self.pauseSucceeds
        })
    }

    override func tearDown() {
        controller = nil
        super.tearDown()
    }

    private func confirmPause(_ bundleID: String = "com.apple.Music") {
        controller.notePlayerState(bundleID: bundleID, state: "Playing")
        controller.pauseMedia()
        controller.notePlayerState(bundleID: bundleID, state: "Paused")
    }

    func testUnknownPlaybackIncludingPausedBrowserNeverResumes() {
        // Browser IO is deliberately never consulted: paused and playing tabs can report
        // identical output IO. An unconditional Pause is safe; an unverified Play is not.
        controller.pauseMedia()
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testMusicBeforeFirstAnnouncementNeverResumes() {
        controller.pauseMedia()
        controller.notePlayerState(bundleID: music, state: "Paused")
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testAlreadyPausedMusicAndSpotifyNeverResume() {
        controller.notePlayerState(bundleID: music, state: "Paused")
        controller.notePlayerState(bundleID: spotify, state: "Paused")
        controller.pauseMedia()
        controller.notePlayerState(bundleID: music, state: "Paused")
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testPausedMusicWithUnconfirmedBrowserNeverResumes() {
        controller.notePlayerState(bundleID: music, state: "Paused")
        // Browsers have no supported playback announcements; arbitrary input cannot arm Play.
        controller.notePlayerState(bundleID: "com.google.Chrome", state: "Playing")
        controller.pauseMedia()
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testConfirmedMusicResumesExactlyOnce() {
        confirmPause()
        XCTAssertTrue(controller.didPauseMedia)
        controller.resumeMedia()
        controller.resumeMedia()
        XCTAssertEqual(commands, [1, 0])
        XCTAssertFalse(controller.didPauseMedia)
    }

    func testConfirmedSpotifyResumesWithoutLocalAudioIO() {
        confirmPause(spotify)
        controller.resumeMedia()
        XCTAssertEqual(commands, [1, 0])
    }

    func testPlayingWithoutPauseConfirmationDoesNotResume() {
        controller.notePlayerState(bundleID: music, state: "Playing")
        controller.pauseMedia()
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testFailedPauseDoesNotResumeEvenIfAnnouncementArrives() {
        pauseSucceeds = false
        confirmPause()
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testDuplicatePausePreservesConfirmedCycle() {
        confirmPause()
        controller.pauseMedia()
        controller.resumeMedia()
        XCTAssertEqual(commands, [1, 0])
    }

    func testRepeatedPauseAnnouncementPreservesConfirmedCycle() {
        confirmPause()
        controller.notePlayerState(bundleID: music, state: "Paused")
        controller.resumeMedia()
        XCTAssertEqual(commands, [1, 0])
    }

    func testPlaybackRestartDuringRecordingCancelsResume() {
        confirmPause()
        controller.notePlayerState(bundleID: music, state: "Playing")
        controller.notePlayerState(bundleID: music, state: "Paused")
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testStoppedPlayerCancelsResume() {
        confirmPause()
        controller.notePlayerState(bundleID: music, state: "Stopped")
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testUnknownPlayerStateCancelsResume() {
        confirmPause()
        controller.notePlayerState(bundleID: music, state: "Unknown")
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
        XCTAssertNil(controller.knownPlayerStates[music])
    }

    func testAnotherPlayerChangeCancelsResume() {
        confirmPause()
        controller.notePlayerState(bundleID: spotify, state: "Paused")
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testMultiplePlayingPlayersDoNotArmGlobalResume() {
        controller.notePlayerState(bundleID: music, state: "Playing")
        controller.notePlayerState(bundleID: spotify, state: "Playing")
        controller.pauseMedia()
        controller.notePlayerState(bundleID: music, state: "Paused")
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
    }

    func testTerminatedPlayerCannotResumeOrLeaveStaleState() {
        confirmPause()
        controller.notePlayerTerminated(bundleID: music)
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
        XCTAssertNil(controller.knownPlayerStates[music])
        controller.pauseMedia()
        controller.notePlayerState(bundleID: music, state: "Paused")
        controller.resumeMedia()
        XCTAssertEqual(commands, [1, 1])
    }

    func testLatePauseDoesNotCarryIntoNextRecording() {
        controller.notePlayerState(bundleID: music, state: "Playing")
        controller.pauseMedia()
        controller.resumeMedia()
        controller.notePlayerState(bundleID: music, state: "Paused")
        controller.resumeMedia()
        controller.pauseMedia()
        controller.resumeMedia()
        XCTAssertEqual(commands, [1, 1])
    }

    func testDisablingSettingConsumesResumeAndAllowsNextRecording() {
        confirmPause()
        controller.resumeMedia(allowResume: false)
        controller.resumeMedia()
        XCTAssertEqual(commands, [1])
        confirmPause()
        controller.resumeMedia()
        XCTAssertEqual(commands, [1, 1, 0])
    }

    func testStopWithoutRecordingDoesNothing() {
        controller.resumeMedia()
        XCTAssertEqual(commands, [])
    }
}
