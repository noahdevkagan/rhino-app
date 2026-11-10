import XCTest
@testable import OpenSuperWhisper

final class PendingNoticeSlotTests: XCTestCase {
    func testHoldsAndReleasesOnce() {
        var slot = PendingNoticeSlot()
        XCTAssertTrue(slot.isEmpty)
        slot.hold(.info("Copied"))
        XCTAssertEqual(slot.take(), .info("Copied"))
        XCTAssertNil(slot.take(), "released once, then empty")
    }

    func testNewestInfoWins() {
        var slot = PendingNoticeSlot()
        slot.hold(.info("A"))
        slot.hold(.info("B"))
        XCTAssertEqual(slot.take(), .info("B"))
    }

    func testErrorReplacesInfo() {
        var slot = PendingNoticeSlot()
        slot.hold(.info("A"))
        slot.hold(.error("E"))
        XCTAssertEqual(slot.take(), .error("E"))
    }

    func testInfoNeverReplacesError() {
        var slot = PendingNoticeSlot()
        slot.hold(.error("E"))
        slot.hold(.info("A"))
        XCTAssertEqual(slot.take(), .error("E"))
    }

    func testNewestErrorWins() {
        var slot = PendingNoticeSlot()
        slot.hold(.error("E1"))
        slot.hold(.error("E2"))
        XCTAssertEqual(slot.take(), .error("E2"))
    }

    func testNonNoticeStatesAreIgnored() {
        var slot = PendingNoticeSlot()
        slot.hold(.recording)
        slot.hold(.decoding)
        XCTAssertTrue(slot.isEmpty)
    }

    func testClear() {
        var slot = PendingNoticeSlot()
        slot.hold(.error("E"))
        slot.clear()
        XCTAssertTrue(slot.isEmpty)
    }
}

final class RecorderStartFailureTests: XCTestCase {
    func testRecordingAndConnectingBecomeError() {
        XCTAssertEqual(RecorderStartFailure.stateAfterFailure(from: .recording),
                       .error(RecorderStartFailure.message))
        XCTAssertEqual(RecorderStartFailure.stateAfterFailure(from: .connecting),
                       .error(RecorderStartFailure.message))
    }

    func testOtherStatesAreLeftAlone() {
        for state: RecordingState in [.idle, .decoding, .busy, .error("x"), .info("x")] {
            XCTAssertNil(RecorderStartFailure.stateAfterFailure(from: state))
        }
    }

    func testEmptyStopIsSilentUnlessTheStartFailed() {
        XCTAssertFalse(RecorderStartFailure.shouldReportOnEmptyStop(discard: false, startFailed: false),
                       "a too-short take returns no file and is not an error")
        XCTAssertFalse(RecorderStartFailure.shouldReportOnEmptyStop(discard: true, startFailed: false))
        XCTAssertFalse(RecorderStartFailure.shouldReportOnEmptyStop(discard: true, startFailed: true),
                       "a deliberate discard stays silent")
        XCTAssertTrue(RecorderStartFailure.shouldReportOnEmptyStop(discard: false, startFailed: true))
    }

    func testFailureNoticeCopy() {
        XCTAssertEqual(DictationPipeline.failureNotice(reason: "Transcription failed", keptForRetry: true),
                       "Transcription failed — retry in History")
        XCTAssertEqual(DictationPipeline.failureNotice(reason: "Transcription failed", keptForRetry: false),
                       "Transcription failed")
        XCTAssertEqual(
            DictationPipeline.failureNotice(reason: "Model not loaded — check Settings → Models", keptForRetry: true),
            "Model not loaded — check Settings → Models")
    }
}

@MainActor
final class IndicatorNoticeHoldTests: XCTestCase {
    private let manager = IndicatorWindowManager.shared

    override func tearDown() async throws {
        manager.pendingNotice.clear()
        manager.hide()
        for _ in 0..<50 where manager.viewModel != nil {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try await super.tearDown()
    }

    func testStartFailureTurnsRecordingBubbleIntoError() {
        let vm = IndicatorViewModel()
        vm.state = .recording
        vm.handleRecorderStartFailure()
        XCTAssertEqual(vm.state, .error(RecorderStartFailure.message))
        XCTAssertFalse(vm.isBlinking)
    }

    func testStartFailureDoesNotTouchAFinishedTake() {
        let vm = IndicatorViewModel()
        vm.state = .decoding
        vm.handleRecorderStartFailure()
        XCTAssertEqual(vm.state, .decoding)
    }

    func testFlashDuringRecordingIsHeldNotDropped() {
        let vm = manager.show(initialState: .recording)
        XCTAssertEqual(vm.state, .recording)
        manager.flash(.info("Copied"))
        XCTAssertEqual(manager.pendingNotice.held, .info("Copied"))
        XCTAssertTrue(manager.viewModel === vm, "the recording bubble is not replaced")
        XCTAssertEqual(vm.state, .recording)
    }

    func testHeldErrorOutranksLaterInfo() {
        _ = manager.show(initialState: .recording)
        manager.flash(.error("Transcription failed"))
        manager.flash(.info("Copied"))
        XCTAssertEqual(manager.pendingNotice.held, .error("Transcription failed"))
    }

    func testHeldNoticeShownWhenRecordingEnds() {
        let vm = manager.show(initialState: .recording)
        manager.flash(.error("Transcription failed"))
        vm.startDecoding(discard: true)  // recording ends; bubble is free
        XCTAssertTrue(manager.pendingNotice.isEmpty)
        XCTAssertEqual(manager.viewModel?.state, .error("Transcription failed"))
    }

    func testStaleTimerDoesNotReleaseDuringANewRecording() {
        _ = manager.show(initialState: .recording)
        manager.flash(.info("Copied"))
        manager.didFinishDecoding()
        XCTAssertEqual(manager.pendingNotice.held, .info("Copied"))
    }

    func testStopForceClearsTheHeldNotice() {
        _ = manager.show(initialState: .recording)
        manager.flash(.error("Transcription failed"))
        manager.stopForce()
        XCTAssertTrue(manager.pendingNotice.isEmpty)
    }

    func testFlashWhenIdleShowsImmediately() {
        manager.flash(.info("Copied"))
        XCTAssertTrue(manager.pendingNotice.isEmpty)
        XCTAssertEqual(manager.viewModel?.state, .info("Copied"))
    }
}
