import AppKit
import Foundation
import Sparkle

extension Notification.Name {
    /// Posted whenever `SparkleUpdater.updateAvailable` flips, so the menu-bar
    /// icon can add/remove its red dot and rebuild the menu.
    static let updateAvailabilityChanged = Notification.Name("updateAvailabilityChanged")
}

/// Thin wrapper around Sparkle's standard updater. Sparkle reads `SUFeedURL` and `SUPublicEDKey`
/// from Info.plist, fetches the appcast, and performs verified in-place download + install.
@MainActor
final class SparkleUpdater: NSObject {
    static let shared = SparkleUpdater()

    /// True once a scheduled or manual check finds a newer version — drives the
    /// menu-bar red dot. Cleared when a later check comes back empty (the update
    /// was installed, or the item was pulled from the feed).
    private(set) var updateAvailable = false {
        didSet {
            guard updateAvailable != oldValue else { return }
            NotificationCenter.default.post(name: .updateAvailabilityChanged, object: nil)
        }
    }

    private var controller: SPUStandardUpdaterController!

    /// Sparkle's "automatically download and install" switch. Defaults to on via
    /// `SUAutomaticallyUpdate` in Info.plist; Sparkle persists the user's choice.
    var automaticallyInstallsUpdates: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    /// Minimum system-wide keyboard/mouse quiet time before a downloaded update
    /// may install itself. Five minutes means the user has stepped away.
    nonisolated static let idleInstallThreshold: TimeInterval = 5 * 60
    nonisolated static let idlePollInterval: TimeInterval = 60

    /// Sparkle's handler to install the downloaded update and relaunch now. Held
    /// until Rhino is idle; if the user quits first, Sparkle installs on quit anyway.
    private var pendingInstall: (() -> Void)?
    private var idleTimer: Timer?

    /// Pure gate for a silent install: never mid-dictation, never while a take is
    /// still transcribing/pasting, and only once the user has been away a while.
    nonisolated static func shouldInstallNow(isRecording: Bool,
                                             isTranscribing: Bool,
                                             indicatorVisible: Bool,
                                             secondsSinceUserInput: TimeInterval) -> Bool {
        !isRecording && !isTranscribing && !indicatorVisible
            && secondsSinceUserInput >= idleInstallThreshold
    }

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    /// Manual check — shows Sparkle's UI (up-to-date, or the update prompt).
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    fileprivate func holdInstallUntilIdle(_ install: @escaping () -> Void) {
        pendingInstall = install
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: Self.idlePollInterval, repeats: true) { _ in
            Task { @MainActor in SparkleUpdater.shared.installIfIdle() }
        }
    }

    private func installIfIdle() {
        guard let install = pendingInstall else { return }
        // Any event type: keys, clicks, mouse moves, scrolls. Needs no TCC permission.
        let quiet = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                            eventType: CGEventType(rawValue: ~0)!)
        guard Self.shouldInstallNow(
            isRecording: AudioRecorder.shared.isRecording || AudioRecorder.shared.isConnecting,
            isTranscribing: TranscriptionQueue.shared.isProcessing,
            indicatorVisible: IndicatorWindowManager.shared.window?.isVisible ?? false,
            secondsSinceUserInput: quiet) else { return }
        idleTimer?.invalidate()
        idleTimer = nil
        pendingInstall = nil
        Diag.mark("update: installing downloaded update while idle (\(Int(quiet))s quiet)")
        install()
    }
}

extension SparkleUpdater: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in self.updateAvailable = true }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in self.updateAvailable = false }
    }

    /// Automatic mode downloaded an update. Stock Sparkle would wait for quit,
    /// but Rhino lives in the menu bar and rarely quits, so we take the install
    /// handler and fire it the next time the user is idle.
    nonisolated func updater(_ updater: SPUUpdater,
                             willInstallUpdateOnQuit item: SUAppcastItem,
                             immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        Task { @MainActor in self.holdInstallUntilIdle(immediateInstallHandler) }
        return true
    }
}
