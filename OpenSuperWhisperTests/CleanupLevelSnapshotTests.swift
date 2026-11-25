import AppKit
import SwiftUI
import XCTest
@testable import OpenSuperWhisper

/// Renders the Output tab's cleanup-level control to PNGs for a human to look at. Opt-in:
///   TEST_RUNNER_RHINO_SNAPSHOT_DIR=/tmp/shots xcodebuild test ... -only-testing:OpenSuperWhisperTests/CleanupLevelSnapshotTests
/// (xcodebuild hands the test host only TEST_RUNNER_-prefixed variables, minus the prefix.)
@MainActor
final class CleanupLevelSnapshotTests: XCTestCase {
    private var outputDir: URL!

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["RHINO_SNAPSHOT_DIR"] else {
            throw XCTSkip("set RHINO_SNAPSHOT_DIR to render the cleanup-level control")
        }
        outputDir = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    func testRenderCleanupLevels() throws {
        try render(level: .polished, downloaded: true, name: "cleanup-level-polished")
        try render(level: .light, downloaded: false, name: "cleanup-level-needs-model")
        try render(level: .exact, downloaded: false, name: "cleanup-level-exact")
    }

    private func render(level: CleanupLevel, downloaded: Bool, name: String) throws {
        let view = VStack(alignment: .leading, spacing: 20) {
            SSection(title: "How much should Rhino tidy?") {
                CleanupLevelPicker(level: .constant(level), modelDownloaded: downloaded,
                                   downloadProgress: nil, downloadError: nil, onDownload: {})
                if level != .polished {
                    SRow(title: "Remove um and uh", hint: "Also at this level, before anything else") {
                        SToggle(isOn: .constant(false))
                    }
                }
                if level == .light {
                    SRow(title: "Spoken edits", hint: "Say “scrap that” to replace what you just said") {
                        SToggle(isOn: .constant(false))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        let size = NSSize(width: 560, height: level == .light ? 400 : 330)
        for (appearance, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
            let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height)
                .background(STheme.windowBg))
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
