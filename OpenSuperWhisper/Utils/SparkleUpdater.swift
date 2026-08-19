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
}

extension SparkleUpdater: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in self.updateAvailable = true }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in self.updateAvailable = false }
    }
}
