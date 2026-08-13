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
}
