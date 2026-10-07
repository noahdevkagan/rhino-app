import AppKit
import XCTest
@testable import OpenSuperWhisper

final class FocusUtilsCaretTests: XCTestCase {
    private let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900),
                           CGRect(x: -1920, y: -180, width: 1920, height: 1080)]

    private func point(_ rect: CGRect) -> NSPoint? {
        FocusUtils.validatedCaretPoint(rect, primaryScreenMaxY: 900, screenFrames: screens)
    }

    func testEmptyAndBottomLeftSentinelsAreRejected() {
        XCTAssertNil(point(.zero))
        XCTAssertNil(point(CGRect(x: 0, y: 900, width: 0, height: 0)))
        XCTAssertNil(point(CGRect(x: 50, y: 100, width: 10, height: 0)))
    }

    func testZeroWidthInsertionCaretAndSelectionAreAccepted() {
        XCTAssertEqual(point(CGRect(x: 120, y: 100, width: 0, height: 18)), NSPoint(x: 120, y: 800))
        XCTAssertEqual(point(CGRect(x: 120, y: 100, width: 80, height: 18)), NSPoint(x: 120, y: 800))
    }

    func testSecondaryScreenAndRealBottomLeftCaretAreAccepted() {
        XCTAssertEqual(point(CGRect(x: -1500, y: 950, width: 0, height: 18)), NSPoint(x: -1500, y: -50))
        XCTAssertEqual(point(CGRect(x: 0, y: 900, width: 0, height: 18)), NSPoint(x: 0, y: 0))
    }

    func testOffscreenAndMalformedBoundsAreRejected() {
        XCTAssertNil(point(CGRect(x: -10000, y: 10000, width: 1, height: 18)))
        XCTAssertNil(point(CGRect(x: 100, y: 100, width: -1, height: 18)))
        XCTAssertNil(point(CGRect(x: 100, y: 100, width: 1, height: -18)))
        for value in [CGFloat.nan, CGFloat.infinity, -CGFloat.infinity] {
            XCTAssertNil(point(CGRect(x: value, y: 100, width: 1, height: 18)))
            XCTAssertNil(point(CGRect(x: 100, y: value, width: 1, height: 18)))
            XCTAssertNil(point(CGRect(x: 100, y: 100, width: value, height: 18)))
            XCTAssertNil(point(CGRect(x: 100, y: 100, width: 1, height: value)))
        }
    }
}
