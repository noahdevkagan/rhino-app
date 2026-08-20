import AVFoundation
import AppKit
import Foundation

enum Permission {
    case microphone
    case accessibility
}

class PermissionsManager: ObservableObject {
    @Published var isMicrophonePermissionGranted = false
    @Published var isAccessibilityPermissionGranted = false

    private var permissionCheckTimer: Timer?
    private var windowObservers: [NSObjectProtocol] = []
    private var isGlobalEventListeningPermissionGranted = false

    init() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
        checkGlobalEventListeningPermission()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(accessibilityPermissionChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )

        setupWindowObservers()
    }

    deinit {
        stopPermissionChecking()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupWindowObservers() {
        let showObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startPermissionChecking()
        }

        let closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopPermissionChecking()
        }

        let hideObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopPermissionChecking()
        }

        // Re-check the instant the user comes back from System Settings, so a fresh
        // grant shows green immediately instead of after the next timer tick.
        let activateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkMicrophonePermission()
            self?.checkAccessibilityPermission()
            self?.checkGlobalEventListeningPermission()
        }

        windowObservers = [showObserver, closeObserver, hideObserver, activateObserver]

        if let window = NSApplication.shared.mainWindow, window.isKeyWindow {
            startPermissionChecking()
        }
    }

    private func startPermissionChecking() {
        guard permissionCheckTimer == nil else { return }
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkMicrophonePermission()
            self?.checkAccessibilityPermission()
            self?.checkGlobalEventListeningPermission()
        }
    }

    private func stopPermissionChecking() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        DispatchQueue.main.async { [weak self] in
            switch status {
            case .authorized:
                self?.isMicrophonePermissionGranted = true
            default:
                self?.isMicrophonePermissionGranted = false
            }
        }
    }

    func checkAccessibilityPermission() {
        let granted = AXIsProcessTrusted()
        DispatchQueue.main.async { [weak self] in
            self?.isAccessibilityPermissionGranted = granted
        }
    }

    /// A listen-only CGEvent tap may be authorized by either TCC grant. Rhino already needs
    /// Accessibility to insert the finished text, so Input Monitoring must never become a
    /// second mandatory permission. Keep watching the combined capability so a modifier tap
    /// can be armed immediately after the user grants Accessibility without relaunching Rhino.
    func checkGlobalEventListeningPermission() {
        let granted = GlobalEventListeningAccess.current
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let becameGranted = granted && !self.isGlobalEventListeningPermissionGranted
            self.isGlobalEventListeningPermissionGranted = granted
            if becameGranted {
                NotificationCenter.default.post(name: .globalEventListeningPermissionChanged,
                                                object: nil)
            }
        }
    }

    func requestMicrophonePermissionOrOpenSystemPreferences() {

        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isMicrophonePermissionGranted = granted
                }
            }
        case .authorized:
            self.isMicrophonePermissionGranted = true
        default:
            openSystemPreferences(for: .microphone)
        }
    }

    /// Asks macOS to register *this* binary in the Accessibility list and show the system prompt
    /// (`AXIsProcessTrustedWithOptions`), then opens the Accessibility pane. Registering ourselves
    /// matters: making the user add Rhino by hand is how the wrong copy (dev build vs /Applications)
    /// ends up granted — the classic "checkbox is on but pasting doesn't work" stale-TCC state,
    /// which only remove-and-re-add fixes.
    func requestAccessibilityPermissionOrOpenSystemPreferences() {
        guard !AXIsProcessTrusted() else {
            isAccessibilityPermissionGranted = true
            return
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        openSystemPreferences(for: .accessibility)
    }

    @objc private func accessibilityPermissionChanged() {
        checkAccessibilityPermission()
        checkGlobalEventListeningPermission()
    }

    func openSystemPreferences(for permission: Permission) {
        let urlString: String
        switch permission {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString =
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }

        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

/// Capability-level authorization for a listen-only global event tap. Accessibility includes
/// both event posting and listening; Input Monitoring grants listening only. Rhino needs the
/// former for text insertion, but accepting either here keeps the monitor correct for existing
/// installs that already granted Input Monitoring.
enum GlobalEventListeningAccess {
    static func isGranted(accessibility: Bool, inputMonitoring: Bool) -> Bool {
        accessibility || inputMonitoring
    }

    static var current: Bool {
        isGranted(accessibility: AXIsProcessTrusted(),
                  inputMonitoring: CGPreflightListenEventAccess())
    }
}
