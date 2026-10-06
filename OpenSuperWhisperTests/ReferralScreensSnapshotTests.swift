import AppKit
import SwiftUI
import XCTest
@testable import OpenSuperWhisper

/// Renders the referral screens to PNGs for a human to look at. Opt-in, so the gate skips it:
///   RHINO_SNAPSHOT_DIR=/tmp/shots xcodebuild test ... -only-testing:OpenSuperWhisperTests/ReferralScreensSnapshotTests
/// Drawn through a real NSHostingView so native buttons and text fields look as they do in the app.
@MainActor
final class ReferralScreensSnapshotTests: XCTestCase {
    private var outputDir: URL!

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["RHINO_SNAPSHOT_DIR"] else {
            throw XCTSkip("set RHINO_SNAPSHOT_DIR to render referral screens")
        }
        outputDir = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    func testRenderReferralScreens() throws {
        let link = ReferralLink(defaults: DefaultsStore.current)
        XCTAssertFalse(UnlockRhino.shared.gate.isUnlocked, "test defaults must be a free user")

        try render(UnlockRhinoView(limitReached: true, wordsThisWeek: 2_140, isUnlocked: false,
                                   unlock: { _ in false }, invite: {}, dismiss: {}),
                   size: UnlockRhino.panelSize, name: "1-paywall-limit-reached")
        try render(UnlockRhinoView(limitReached: false, wordsThisWeek: 860, isUnlocked: false,
                                   unlock: { _ in false }, invite: {}, dismiss: {}),
                   size: UnlockRhino.panelSize, name: "2-paywall-from-menu")
        try render(ShareRhinoView(link: link, isUnlocked: false, dismiss: {}),
                   size: NSSize(width: 420, height: 350), name: "3-share-panel-free-user")
        try render(ShareRhinoView(link: link, isUnlocked: true, dismiss: {}),
                   size: NSSize(width: 420, height: 350), name: "4-share-panel-unlocked-user")
        try render(MainSidebar(selection: .constant(.home), openSettings: {}, openReleaseNotes: {}),
                   size: NSSize(width: 168, height: 520), name: "5-sidebar-free-user")
    }

    private func render<V: View>(_ view: V, size: NSSize, name: String) throws {
        for (appearance, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
            let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height)
                .background(Color(nsColor: .windowBackgroundColor)))
            host.appearance = NSAppearance(named: appearance)
            host.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless],
                                  backing: .buffered, defer: false)
            window.appearance = host.appearance
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
            try png.write(to: outputDir.appendingPathComponent("\(name)-\(suffix).png"))
        }
    }
}
