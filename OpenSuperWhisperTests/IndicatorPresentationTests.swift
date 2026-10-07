import AppKit
import Combine
import XCTest
@testable import OpenSuperWhisper

/// Exercise the real hosting/panel lifecycle without starting the microphone.
@MainActor
final class IndicatorPresentationTests: XCTestCase {
    private let manager = IndicatorWindowManager.shared
    private var savedPosition = ""
    private var savedLayout = ""
    private var savedScale = 1.0

    override func setUp() {
        super.setUp()
        let prefs = AppPreferences.shared
        savedPosition = prefs.indicatorPosition
        savedLayout = prefs.indicatorLayout
        savedScale = prefs.textScale
        prefs.indicatorPosition = "cursor"
        prefs.indicatorLayout = IndicatorLayout.default.json
        prefs.textScale = 1
    }

    override func tearDown() async throws {
        manager.hide()
        await waitUntil { self.manager.viewModel == nil }
        let prefs = AppPreferences.shared
        prefs.indicatorPosition = savedPosition
        prefs.indicatorLayout = savedLayout
        prefs.textScale = savedScale
        try await super.tearDown()
    }

    func testFirstVisibleFrameIsTheMeasuredRecordingPill() async throws {
        // Hold presentation so we can observe the very first visible frame.
        let vm = manager.show(nearPoint: anchor, waitForCaret: true)
        XCTAssertEqual(vm.state, .recording)
        XCTAssertFalse(try XCTUnwrap(manager.window).isVisible)
        var firstFrame: NSRect?
        let observer = vm.$isVisible.filter { $0 }.prefix(1).sink { _ in
            firstFrame = self.manager.window?.frame
        }
        defer { observer.cancel() }

        manager.updateCaretAnchor(nil, for: vm)
        await waitUntil { firstFrame != nil }
        let frame = try XCTUnwrap(firstFrame)
        XCTAssertGreaterThan(frame.width, 64)
        XCTAssertLessThan(frame.width, 150, "Never expose the 200pt idle pill or 380pt seed canvas")
        XCTAssertLessThan(frame.height, 80)
        XCTAssertEqual(frame.midX, anchor.x, accuracy: 1)
        XCTAssertEqual(frame.minY, anchor.y + 20, accuracy: 1)

        try? await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(manager.window?.frame, frame, "Entrance animation must not resize or move the panel")
        try saveSnapshot(named: "recording-pill")
    }

    func testQuickCaretReplyChoosesTheInitialPosition() async throws {
        let vm = manager.show(nearPoint: anchor, waitForCaret: true)
        let caret = caretRect
        manager.updateCaretAnchor(caret, for: vm)
        await waitUntil { vm.isVisible }
        let frame = try XCTUnwrap(manager.window).frame
        let point = FocusUtils.convertAXPointToCocoa(caret.origin)
        XCTAssertEqual(frame.midX, point.x, accuracy: 1)
        XCTAssertEqual(frame.minY, point.y + 20, accuracy: 1)
    }

    func testInvalidCaretKeepsMouseFallback() async throws {
        let invalidCarets = [
            CGRect.zero,
            CGRect(x: 0, y: NSScreen.screens[0].frame.maxY, width: 0, height: 0),
            CGRect(x: -1_000_000, y: 1_000_000, width: 1, height: 18),
        ]
        for caret in invalidCarets {
            let vm = manager.show(nearPoint: anchor, waitForCaret: true)
            manager.updateCaretAnchor(caret, for: vm)
            await waitUntil { vm.isVisible }
            let frame = try XCTUnwrap(manager.window).frame
            XCTAssertEqual(frame.midX, anchor.x, accuracy: 1)
            XCTAssertEqual(frame.minY, anchor.y + 20, accuracy: 1)
        }
    }

    func testStateChangedDuringCaretLookupIsMeasuredBeforeReveal() async throws {
        let vm = manager.show(nearPoint: anchor, waitForCaret: true)
        vm.state = .connecting
        var firstFrame: NSRect?
        let observer = vm.$isVisible.filter { $0 }.prefix(1).sink { _ in
            firstFrame = self.manager.window?.frame
        }
        defer { observer.cancel() }
        manager.updateCaretAnchor(nil, for: vm)
        await waitUntil { firstFrame != nil }
        XCTAssertEqual(try XCTUnwrap(firstFrame).width, 200, accuracy: 1)
    }

    func testSlowCaretReplyKeepsTheMouseFallback() async throws {
        let vm = manager.show(nearPoint: anchor, waitForCaret: true)
        await waitUntil { vm.isVisible }
        let frame = try XCTUnwrap(manager.window).frame
        XCTAssertEqual(frame.midX, anchor.x, accuracy: 1)
        manager.updateCaretAnchor(caretRect, for: vm)
        XCTAssertEqual(manager.window?.frame, frame, "Late AX must not teleport a visible bubble")
    }

    func testPresentationWhileRhinoIsInactiveDoesNotStealFocus() async throws {
        NSApp.deactivate()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        await waitUntil {
            !NSApp.isActive && NSWorkspace.shared.frontmostApplication?.processIdentifier != ownPID
        }
        let vm = manager.show(nearPoint: anchor, waitForCaret: true)
        await waitUntil { vm.isVisible }
        try? await Task.sleep(for: .milliseconds(250))
        let panel = try XCTUnwrap(manager.window as? NSPanel)
        XCTAssertTrue(panel.isVisible)
        XCTAssertTrue(panel.occlusionState.contains(.visible), "The bubble must draw over the active app")
        XCTAssertEqual(panel.level, .screenSaver)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertFalse(panel.isKeyWindow)
        XCTAssertFalse(NSApp.isActive)
        XCTAssertNotEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, ownPID)
        try saveSnapshot(named: "inactive-app-pill")
    }

    func testReplacementRejectsThePreviousCaretAndHide() async throws {
        let old = manager.show(nearPoint: anchor, waitForCaret: true)
        manager.hide()
        let current = manager.show(nearPoint: anchor, waitForCaret: true)
        manager.updateCaretAnchor(caretRect, for: old)
        XCTAssertFalse(current.isVisible)
        manager.updateCaretAnchor(nil, for: current)
        await waitUntil { current.isVisible }
        try? await Task.sleep(for: .milliseconds(350))
        XCTAssertTrue(manager.viewModel === current)
        XCTAssertTrue(try XCTUnwrap(manager.window).isVisible)
        XCTAssertEqual(manager.window?.frame.midX ?? 0, anchor.x, accuracy: 1)
    }

    func testHideBeforeCaretTimeoutDoesNotResurrectThePanel() async throws {
        let vm = manager.show(nearPoint: anchor, waitForCaret: true)
        manager.hide()
        await waitUntil { self.manager.viewModel == nil }
        try? await Task.sleep(for: .milliseconds(150))
        manager.updateCaretAnchor(caretRect, for: vm)
        XCTAssertNil(manager.viewModel)
        XCTAssertFalse(try XCTUnwrap(manager.window).isVisible)
    }

    func testRepeatedPresentationAfterWideMessageStartsCompact() async throws {
        let message = manager.show(nearPoint: anchor, initialState: .info("Copied — press ⌘V"))
        await waitUntil { message.isVisible }
        XCTAssertEqual(try XCTUnwrap(manager.window).frame.width, 200, accuracy: 1)
        let recording = manager.show(nearPoint: anchor)
        await waitUntil { recording.isVisible }
        XCTAssertLessThan(try XCTUnwrap(manager.window).frame.width, 150)
        XCTAssertEqual(recording.state, .recording)
    }

    func testNotchAndScaledControlsStillMeasureBeforeShowing() async throws {
        AppPreferences.shared.indicatorPosition = "notch"
        let notch = manager.show(nearPoint: anchor)
        await waitUntil { notch.isVisible }
        let notchWindow = try XCTUnwrap(manager.window)
        XCTAssertEqual(notchWindow.frame.maxY, try XCTUnwrap(notchWindow.screen).frame.maxY, accuracy: 1)

        AppPreferences.shared.indicatorPosition = "bottom"
        AppPreferences.shared.textScale = 1.6
        var layout = IndicatorLayout.default
        layout.setVisible(true, for: .stopButton)
        layout.setVisible(true, for: .cancelButton)
        AppPreferences.shared.indicatorLayout = layout.json
        let scaled = manager.show(nearPoint: anchor)
        await waitUntil { scaled.isVisible }
        let window = try XCTUnwrap(manager.window)
        XCTAssertFalse(window.ignoresMouseEvents)
        XCTAssertGreaterThan(window.frame.width, 150)
        XCTAssertLessThan(window.frame.width, 380)
        XCTAssertGreaterThan(window.frame.height, 40)
        try? await Task.sleep(for: .milliseconds(250))
        try saveSnapshot(named: "scaled-pill-with-controls")
    }

    private var anchor: NSPoint {
        let frame = NSScreen.main!.frame
        return NSPoint(x: frame.midX, y: frame.midY)
    }

    private var caretRect: CGRect {
        let point = NSPoint(x: anchor.x + 180, y: anchor.y - 120)
        return CGRect(x: point.x, y: NSScreen.screens[0].frame.maxY - point.y, width: 1, height: 18)
    }

    private func waitUntil(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<100 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Indicator lifecycle did not settle within one second", file: file, line: line)
    }

    private func saveSnapshot(named name: String) throws {
        let host = try XCTUnwrap(manager.window?.contentView)
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
