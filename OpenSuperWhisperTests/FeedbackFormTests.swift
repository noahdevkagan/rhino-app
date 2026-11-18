import XCTest
@testable import OpenSuperWhisper

final class FeedbackFormTests: XCTestCase {
    func testEmailURLAddressesNoahAndIncludesVersionAndFeedback() throws {
        let url = try XCTUnwrap(FeedbackFormView.emailURL(
            feedback: "The hotkey works great & I'd like another option.",
            version: "1.2.3"
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.path, "noahkagan@gmail.com")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "subject" })?.value,
            "Rhino feedback (v1.2.3)"
        )
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "body" })?.value,
            "The hotkey works great & I'd like another option."
        )
    }

    func testDiagnosticsGoUnderTheFeedback() throws {
        let url = try XCTUnwrap(FeedbackFormView.emailURL(
            feedback: "Fn flashes.", version: "1.2.3", diagnostics: ["A: 1", "B: 2"]))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "body" })?.value,
                       "Fn flashes.\n\n----\nA: 1\nB: 2")
    }
}
