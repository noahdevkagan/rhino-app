import XCTest

@testable import OpenSuperWhisper

/// Rhino's modifier tap is listen-only, so macOS acts on the same Fn press Rhino watches.
/// On a factory-default Mac that means the emoji palette pops up on every dictation, which
/// is why picking Fn as a dictate key silences the system's lone-Fn action.
///
/// These cover the decision, not the write: `setDoNothing` mutates a real system preference,
/// so a test must never call it.
final class FnGlobeKeySettingTests: XCTestCase {

    /// The preference is absent on a Mac nobody has touched, and absent means emoji.
    /// Reading "unset" as "nothing happens" would skip the fix for the majority case.
    func testUnsetReadsAsEmojiPalette() {
        XCTAssertEqual(FnGlobeKeySetting.action(forRaw: nil), .showEmoji)
        XCTAssertTrue(FnGlobeKeySetting.shouldSilence(FnGlobeKeySetting.action(forRaw: nil)))
    }

    func testKnownValuesDecode() {
        XCTAssertEqual(FnGlobeKeySetting.action(forRaw: 0), .doNothing)
        XCTAssertEqual(FnGlobeKeySetting.action(forRaw: 1), .changeInputSource)
        XCTAssertEqual(FnGlobeKeySetting.action(forRaw: 2), .showEmoji)
        XCTAssertEqual(FnGlobeKeySetting.action(forRaw: 3), .startDictation)
    }

    /// A future macOS value we don't know falls back to the palette, so the worst case is
    /// offering the fix to someone who didn't need it — not leaving the conflict in place.
    func testUnknownValueFallsBackToEmojiPalette() {
        XCTAssertEqual(FnGlobeKeySetting.action(forRaw: 99), .showEmoji)
    }

    /// Only "Do Nothing" is actually conflict-free. Changing the input source or starting
    /// Apple's own dictation on a lone Fn fights Rhino just as much as the palette does.
    func testEveryNonSilentActionConflicts() {
        XCTAssertFalse(FnGlobeKeySetting.shouldSilence(.doNothing))
        XCTAssertTrue(FnGlobeKeySetting.shouldSilence(.showEmoji))
        XCTAssertTrue(FnGlobeKeySetting.shouldSilence(.changeInputSource))
        XCTAssertTrue(FnGlobeKeySetting.shouldSilence(.startDictation))
    }
}
