import Carbon
import XCTest
@testable import OpenSuperWhisper

final class BrowserMediaControllerTests: XCTestCase {
    private var transport: FakeBrowserTransport!
    private var controller: BrowserMediaController!

    override func setUp() {
        super.setUp()
        transport = FakeBrowserTransport()
        controller = BrowserMediaController(transport: transport)
    }

    func testAllElementsUsesAbsoluteOrdinalRequiredByBrowsers() throws {
        // Live Safari and Chrome returned -1700 when "all" was encoded as typeEnumerated.
        for kind in ["cwin", "bTab", "CrTb"] {
            let specifier = try XCTUnwrap(MediaAppleEventClient.allElementsSpecifier(kind))
            XCTAssertEqual(specifier.descriptorType, typeObjectSpecifier)
            let selector = try XCTUnwrap(specifier.forKeyword(AEKeyword(keyAEKeyData)))
            XCTAssertEqual(selector.descriptorType, typeAbsoluteOrdinal)
            XCTAssertEqual(selector.data, NSAppleEventDescriptor(enumCode: OSType(kAEAll)).data)
        }
    }

    func testOnlyPlayingTabsAreRestored() {
        let tickets = controller.pause { true }
        XCTAssertEqual(tickets.count, 1)
        XCTAssertFalse(transport.playing.contains("video"))
        controller.resume(tickets)
        XCTAssertEqual(transport.playing, ["video"])
    }

    func testReorderedOrMovedTabIsFoundByToken() {
        let tickets = controller.pause { true }
        transport.documents = ["tab1": "unrelated", "tab3": "video"]
        controller.resume(tickets)
        XCTAssertEqual(transport.playing, ["video"])
        XCTAssertEqual(transport.enumerations, 2, "one initial enumeration, one fallback")
    }

    func testClosedTabNeverStartsItsReplacement() {
        let tickets = controller.pause { true }
        transport.documents = ["tab1": "replacement", "tab2": "other"]
        controller.resume(tickets)
        XCTAssertTrue(transport.playing.isEmpty)
    }

    func testDeniedPermissionLeavesBrowserAlone() {
        transport.permission = false
        let tickets = controller.pause { true }
        controller.resume(tickets)
        XCTAssertTrue(tickets.isEmpty)
        XCTAssertEqual(transport.executions, 0)
        XCTAssertEqual(transport.playing, ["video"])
    }

    func testJavaScriptDeniedDoesNotCreateRestoreTickets() {
        transport.errorBeforeExecution = NSError(domain: NSOSStatusErrorDomain, code: Int(errAEEventNotPermitted))
        let tickets = controller.pause { true }
        controller.resume(tickets)
        XCTAssertTrue(tickets.isEmpty)
        XCTAssertEqual(transport.playing, ["video"])
    }

    func testTimedOutPauseStillRestoresItsToken() {
        transport.timeoutAfterPause = true
        let tickets = controller.pause { true }
        XCTAssertEqual(tickets.count, 1)
        controller.resume(tickets)
        XCTAssertEqual(transport.playing, ["video"])
    }

    func testHungTabIsRetriedOnceWithoutRescanningEveryTab() {
        transport.hungTabs = ["tab1"]
        let tickets = controller.pause { true }
        XCTAssertEqual(tickets.count, 1)
        transport.executions = 0
        controller.resume(tickets)
        XCTAssertEqual(transport.executions, 1, "one direct retry, no per-tab rescan")
        XCTAssertEqual(transport.enumerations, 1, "no fallback enumeration")
    }

    func testCancellationStopsPausingFurtherTabs() {
        transport.playing.insert("other")
        var active = true
        transport.onPause = { active = false }
        let tickets = controller.pause { active }
        XCTAssertEqual(tickets.count, 1)
        XCTAssertEqual(transport.playing, ["other"])
        controller.resume(tickets)
        XCTAssertEqual(transport.playing, ["other", "video"])
    }

    func testCancellationBeforeStartDoesNotInspectTabs() {
        let tickets = controller.pause { false }
        XCTAssertTrue(tickets.isEmpty)
        XCTAssertEqual(transport.enumerations, 0)
    }

    func testSpentBudgetStopsStartingNewTabs() {
        transport.playing.insert("other")
        var clock = Date(timeIntervalSince1970: 0)
        transport.onExecute = { clock.addTimeInterval(2) } // first tab is slow
        let tickets = controller.pause(budget: 1.5, now: { clock }) { true }
        XCTAssertEqual(transport.executions, 1, "second tab not started after the budget")
        XCTAssertEqual(tickets.count, 1)
        XCTAssertEqual(transport.playing, ["other"])
    }

    func testMultiplePlayingTabsHaveIndependentTokens() {
        transport.playing.insert("other")
        let tickets = controller.pause { true }
        XCTAssertEqual(Set(tickets.map(\.token)).count, 2)
        controller.resume(tickets)
        XCTAssertEqual(transport.playing, ["other", "video"])
    }

    func testStopDuringBrowserPauseRestoresBeforeQuitCompletes() {
        let queue = DispatchQueue(label: "test.browser-coordinator")
        let media = MediaPlaybackController(backend: NoMusicBackend(), browsers: controller, queue: queue)
        let entered = expectation(description: "browser pause started")
        let release = DispatchSemaphore(value: 0)
        transport.onPause = { entered.fulfill(); release.wait() }
        media.pauseMedia()
        wait(for: [entered], timeout: 2)
        let finished = expectation(description: "restored before quit")
        media.prepareForTermination {
            XCTAssertEqual(self.transport.playing, ["video"])
            finished.fulfill()
        }
        release.signal()
        wait(for: [finished], timeout: 2)
    }

    func testUnknownOrDeadBrowserCannotReceiveAppleEvents() {
        let events = MediaAppleEventClient()
        let dead = MediaPlayer(bundleID: "com.google.Chrome", pid: -1, launchDate: .distantPast)
        XCTAssertThrowsError(try events.send(eventClass: "core", id: "getd", player: dead))
        XCTAssertFalse(events.hasPermission(for: dead))
    }
}

private final class FakeBrowserTransport: BrowserMediaTransport {
    let browser = MediaPlayer(bundleID: "com.apple.Safari", pid: 123, launchDate: .distantPast)
    var documents = ["tab1": "video", "tab2": "other"]
    var playing: Set<String> = ["video"]
    var tokens: [String: Set<String>] = [:]
    var permission = true
    var enumerations = 0
    var executions = 0
    var timeoutAfterPause = false
    var hungTabs: Set<String> = []
    var errorBeforeExecution: Error?
    var onPause: (() -> Void)?
    var onExecute: (() -> Void)?

    func runningBrowsers() -> [MediaPlayer] { [browser] }
    func hasPermission(for browser: MediaPlayer) -> Bool { permission }
    func tabs(in browser: MediaPlayer) throws -> [NSAppleEventDescriptor] {
        enumerations += 1
        return documents.keys.sorted().map { NSAppleEventDescriptor(string: $0) }
    }
    func execute(_ script: String, in tab: NSAppleEventDescriptor, browser: MediaPlayer) throws -> String {
        executions += 1
        onExecute?()
        if let errorBeforeExecution { throw errorBeforeExecution }
        if hungTabs.contains(tab.stringValue ?? "") {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errAETimeout))
        }
        guard let doc = documents[tab.stringValue ?? ""] else { return "[]" }
        let start = script.range(of: "tokens = ")!.upperBound
        let end = script.range(of: ", deadline = ")!.lowerBound
        let requested = try JSONDecoder().decode([String].self, from: Data(script[start..<end].utf8))
        if script.contains("action = 'pause'") {
            guard playing.remove(doc) != nil else { return "idle" }
            tokens[doc, default: []].formUnion(requested)
            onPause?()
            if timeoutAfterPause { throw NSError(domain: NSOSStatusErrorDomain, code: Int(errAETimeout)) }
            return "paused"
        }
        let matched = Set(requested).intersection(tokens[doc, default: []])
        tokens[doc, default: []].subtract(matched)
        if !matched.isEmpty { playing.insert(doc) }
        return String(data: try JSONEncoder().encode(Array(matched)), encoding: .utf8)!
    }
}

private final class NoMusicBackend: MediaPlaybackBackend {
    func runningPlayers() -> [MediaPlayer] { [] }
    func hasPermission(for player: MediaPlayer) -> Bool { false }
    func snapshot(_ player: MediaPlayer) throws -> MediaPlaybackSnapshot { fatalError("no players") }
    func pause(_ player: MediaPlayer) throws { XCTFail("no players") }
    func play(_ player: MediaPlayer) throws { XCTFail("no players") }
}
