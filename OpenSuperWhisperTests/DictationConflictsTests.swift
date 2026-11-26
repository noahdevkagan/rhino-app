import XCTest
@testable import OpenSuperWhisper

final class DictationConflictsTests: XCTestCase {

    func testFindsKnownDictationAppsByName() {
        let names = ["Slack", "Wispr Flow", "Finder", "superwhisper", "Wispr Flow"]
        XCTAssertEqual(DictationConflicts.otherDictationApps(running: names),
                       ["Wispr Flow", "superwhisper"])
    }

    func testNoDictationAppsAmongOrdinaryApps() {
        XCTAssertEqual(DictationConflicts.otherDictationApps(running: ["Slack", "Muse", "Safari"]), [])
    }

    func testAppleDictationLine() {
        XCTAssertEqual(DictationConflicts.appleDictationLine(enabled: nil, globeKey: .showEmoji),
                       "Apple Dictation: not set up")
        XCTAssertEqual(DictationConflicts.appleDictationLine(enabled: false, globeKey: .startDictation),
                       "Apple Dictation: off")
        XCTAssertEqual(DictationConflicts.appleDictationLine(enabled: true, globeKey: .doNothing),
                       "Apple Dictation: on")
        XCTAssertEqual(DictationConflicts.appleDictationLine(enabled: true, globeKey: .startDictation),
                       "Apple Dictation: on, started by the 🌐 key")
    }

    func testLines() {
        XCTAssertEqual(
            DictationConflicts.lines(rhinoCopies: 2, running: ["Slack"], appleDictation: "Apple Dictation: off"),
            ["Rhino copies running: 2", "Other dictation apps running: none", "Apple Dictation: off"])
    }
}
