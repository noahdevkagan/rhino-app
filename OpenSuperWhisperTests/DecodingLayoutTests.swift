import XCTest

@testable import OpenSuperWhisper

/// What the bubble shows while a clip is transcribing.
///
/// It follows the layout the user chose, or stopping a recording would resize the window under
/// them: someone who picked the meter alone would see it swapped for a wide label. One element
/// in, one element out, same footprint.
final class DecodingLayoutTests: XCTestCase {

    private func layout(hiding hidden: [IndicatorElement]) -> IndicatorLayout {
        var layout = IndicatorLayout.default
        for element in hidden { layout.setVisible(false, for: element) }
        return layout
    }

    func testMeterOnlyStaysMeterOnly() {
        let elements = layout(hiding: [.label, .stopButton, .cancelButton]).decodingLeading

        XCTAssertTrue(elements.contains(.waveform))
        XCTAssertFalse(elements.contains(.label), "a label would widen a bubble that had none")
    }

    func testLabelOnlyStaysLabelOnly() {
        // The label is hidden in the default (wordless-pill) layout, so this
        // scenario asks for it explicitly rather than inheriting it.
        var labelOnly = layout(hiding: [.appIcon, .waveform, .stopButton, .cancelButton])
        labelOnly.setVisible(true, for: .label)

        let elements = labelOnly.decodingLeading

        XCTAssertTrue(elements.contains(.label))
        XCTAssertFalse(elements.contains(.waveform))
    }

    func testBothStayBoth() {
        // Meter + label together — both enabled explicitly, since the default
        // layout no longer shows the label.
        var both = layout(hiding: [.stopButton, .cancelButton])
        both.setVisible(true, for: .waveform)
        both.setVisible(true, for: .label)

        let elements = both.decodingLeading

        XCTAssertTrue(elements.contains(.waveform))
        XCTAssertTrue(elements.contains(.label))
    }

    /// The controls are trailing, drawn separately and greyed by the element view rather than
    /// removed: taking them out would reflow the bubble at the moment recording stops.
    func testControlsAreNotPartOfTheLeadingRun() {
        // Both buttons are hidden by default, so they have to be asked for.
        var withButtons = layout(hiding: [])
        withButtons.setVisible(true, for: .stopButton)
        withButtons.setVisible(true, for: .cancelButton)

        XCTAssertFalse(withButtons.decodingLeading.contains(.stopButton))
        XCTAssertFalse(withButtons.decodingLeading.contains(.cancelButton))
        XCTAssertEqual(withButtons.trailing, [.stopButton, .cancelButton],
                       "they stay in the layout, just on the other side")
    }

    /// A lone dot cannot say "still working": it looks the same either way. The meter is
    /// borrowed to carry the spinner rather than leaving no signal at all.
    func testALayoutThatCannotShowProgressGetsTheSpinner() {
        // The dot is hidden by default, so it has to be asked for to be the only thing left.
        var dotOnly = layout(hiding: [.waveform, .label, .stopButton, .cancelButton])
        dotOnly.setVisible(true, for: .dot)

        let elements = dotOnly.decodingLeading

        XCTAssertTrue(elements.contains(.waveform), "nothing else could show progress")
        XCTAssertTrue(elements.contains(.dot), "the dot the user chose is still theirs")
    }

    /// Order is the user's, not ours: the spinner appears where their meter was.
    func testOrderMatchesTheRecordingLayout() {
        let chosen = layout(hiding: [.stopButton, .cancelButton])

        XCTAssertEqual(chosen.decodingLeading, chosen.leading)
    }

    /// Hiding everything is a layout someone can actually save.
    func testAnEmptyLayoutStillShowsSomething() {
        let elements = layout(hiding: IndicatorElement.allCases).decodingLeading

        XCTAssertEqual(elements, [.waveform])
    }
}
