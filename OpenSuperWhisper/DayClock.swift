import AppKit
import Combine
import Foundation

/// Publishes the current day so day-relative UI ("Today", "Yesterday", the Stats ranges,
/// Home's "This week") rolls over at midnight without waiting for a new dictation.
///
/// Checks on the system's day-change, clock-change and time-zone-change notifications,
/// and whenever a window becomes key (covers a Mac that slept through midnight and
/// missed the day-change notification). Publishes only when the day or zone moved.
@MainActor
final class DayClock: ObservableObject {
    static let shared = DayClock()

    /// Start of today in the current zone. Changes at most once per check.
    @Published private(set) var today: Date
    private var zone: String

    private let now: () -> Date
    private let calendar: () -> Calendar
    private var observers: [NSObjectProtocol] = []

    init(now: @escaping () -> Date = Date.init,
         calendar: @escaping () -> Calendar = { Calendar.autoupdatingCurrent },
         observe: Bool = true) {
        self.now = now
        self.calendar = calendar
        let cal = calendar()
        today = cal.startOfDay(for: now())
        zone = cal.timeZone.identifier
        guard observe else { return }
        let names: [Notification.Name] = [
            .NSCalendarDayChanged,
            .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange,
            NSWindow.didBecomeKeyNotification,
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.check() }
            }
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Re-reads the date; publishes when the day (or time zone) differs from the last one.
    /// Returns whether it changed.
    @discardableResult
    func check() -> Bool {
        // NSTimeZone caches the system zone; drop it so a zone change is seen right away.
        NSTimeZone.resetSystemTimeZone()
        let cal = calendar()
        let day = cal.startOfDay(for: now())
        let newZone = cal.timeZone.identifier
        guard day != today || newZone != zone else { return false }
        zone = newZone
        today = day
        return true
    }
}
