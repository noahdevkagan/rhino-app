import XCTest

@testable import OpenSuperWhisper

/// The media pause/resume fallback (MediaRemote reads unavailable — every shipped build on
/// macOS 15.4+) must resume only what the pause was seen to silence. These tests pin the
/// arbiter's evidence contract: continuous rendering before the pause to arm, an observed
/// stop after it to confirm, and no Play without both — the 2026-09-01 field bug was a
/// resume armed off a process that merely held the output device open, which woke a random
/// stale now-playing tab after a dictation with nothing playing.
final class MediaResumeArbiterTests: XCTestCase {

    private let music: pid_t = 100
    private let holder: pid_t = 200

    func testContinuousRendererArmsAndObservedStopConfirms() {
        var arbiter = MediaResumeArbiter()
        arbiter.recordIdleSample([music])
        arbiter.recordIdleSample([music])
        arbiter.beginPause(renderersAtPause: [music])
        XCTAssertTrue(arbiter.isArmed)
        XCTAssertFalse(arbiter.mayResume, "a Play needs the observed stop, not just the arming")
        arbiter.recordPostPauseSample([])
        XCTAssertTrue(arbiter.mayResume)
    }

    func testSilentDeviceHolderNeverConfirms() {
        // The reported bug: no audible media, but some process keeps output IO running.
        // The pause can't silence it, so it keeps rendering — and no Play may go out.
        var arbiter = MediaResumeArbiter()
        arbiter.recordIdleSample([holder])
        arbiter.recordIdleSample([holder])
        arbiter.beginPause(renderersAtPause: [holder])
        XCTAssertTrue(arbiter.isArmed)
        arbiter.recordPostPauseSample([holder])
        arbiter.recordPostPauseSample([holder])
        XCTAssertFalse(arbiter.mayResume, "an unstopped renderer is a holder, not paused media")
    }

    func testTransientSoundDoesNotArm() {
        // A notification ding rendering at the pause instant doesn't span the idle window.
        var arbiter = MediaResumeArbiter()
        arbiter.recordIdleSample([])
        arbiter.recordIdleSample([holder])
        arbiter.beginPause(renderersAtPause: [holder])
        XCTAssertFalse(arbiter.isArmed)
    }

    func testInsufficientIdleHistoryDoesNotArm() {
        // Right after launch (or a poll restart) there is no continuity evidence yet.
        var arbiter = MediaResumeArbiter()
        arbiter.recordIdleSample([music])
        arbiter.beginPause(renderersAtPause: [music])
        XCTAssertFalse(arbiter.isArmed)
    }

    func testHolderPlusMediaConfirmsWhenTheMediaStops() {
        // "Any renderer stopped", not "all": a chronic holder must not veto the resume of
        // media the pause really silenced.
        var arbiter = MediaResumeArbiter()
        arbiter.recordIdleSample([music, holder])
        arbiter.recordIdleSample([music, holder])
        arbiter.beginPause(renderersAtPause: [music, holder])
        XCTAssertTrue(arbiter.isArmed)
        arbiter.recordPostPauseSample([holder])
        XCTAssertTrue(arbiter.mayResume)
    }

    func testResumedCycleSeedsHistoryForBackToBackDictations() {
        // After a sent Play the next dictation can start inside the continuity window; the
        // seeded history keeps the resumed media resumable instead of stranding it paused.
        var arbiter = MediaResumeArbiter()
        arbiter.recordIdleSample([music])
        arbiter.recordIdleSample([music])
        arbiter.beginPause(renderersAtPause: [music])
        arbiter.recordPostPauseSample([])
        XCTAssertTrue(arbiter.mayResume)
        arbiter.finishCycle(resumed: true)
        XCTAssertFalse(arbiter.mayResume, "finishing the cycle clears the armed state")
        arbiter.beginPause(renderersAtPause: [music])
        XCTAssertTrue(arbiter.isArmed)
    }

    func testSeededHistoryStillRequiresTheRendererAtTheNextPause() {
        // If the Play didn't actually restart the media, the pause-instant intersection
        // drops it — the seed is a bridge, not a blanket re-arm.
        var arbiter = MediaResumeArbiter()
        arbiter.recordIdleSample([music])
        arbiter.recordIdleSample([music])
        arbiter.beginPause(renderersAtPause: [music])
        arbiter.recordPostPauseSample([])
        arbiter.finishCycle(resumed: true)
        arbiter.beginPause(renderersAtPause: [])
        XCTAssertFalse(arbiter.isArmed)
    }

    func testAbandonedCycleClearsHistory() {
        var arbiter = MediaResumeArbiter()
        arbiter.recordIdleSample([music])
        arbiter.recordIdleSample([music])
        arbiter.beginPause(renderersAtPause: [music])
        arbiter.finishCycle(resumed: false)
        arbiter.beginPause(renderersAtPause: [music])
        XCTAssertFalse(arbiter.isArmed, "stale pre-recording samples must not re-arm a new cycle")
    }

    func testPostPauseSampleBeforeArmingIsIgnored() {
        var arbiter = MediaResumeArbiter()
        arbiter.recordPostPauseSample([])
        XCTAssertFalse(arbiter.mayResume)
    }
}
