import AVFoundation
import AppKit
import Foundation

enum Permission {
    case microphone
    case accessibility
    case inputMonitoring
}

class PermissionsManager: ObservableObject {
    @Published var isMicrophonePermissionGranted = false
    @Published var isAccessibilityPermissionGranted = false
    @Published var isInputMonitoringPermissionGranted = false
    @Published private(set) var isInputMonitoringRequired: Bool

    private var permissionCheckTimer: Timer?
    private var windowObservers: [NSObjectProtocol] = []

    init() {
        isInputMonitoringRequired = RecordingTriggerSet
            .load(from: AppPreferences.shared.recordingTriggers)
            .requiresInputMonitoring
        checkMicrophonePermission()
        checkAccessibilityPermission()
        checkInputMonitoringPermission()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(accessibilityPermissionChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )

        setupWindowObservers()

        let hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .hotkeySettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isInputMonitoringRequired = RecordingTriggerSet
                .load(from: AppPreferences.shared.recordingTriggers)
                .requiresInputMonitoring
            self?.checkInputMonitoringPermission()
        }
        windowObservers.append(hotkeyObserver)
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

        windowObservers = [showObserver, closeObserver, hideObserver]

        if let window = NSApplication.shared.mainWindow, window.isKeyWindow {
            startPermissionChecking()
        }
    }

    private func startPermissionChecking() {
        guard permissionCheckTimer == nil else { return }
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkMicrophonePermission()
            self?.checkAccessibilityPermission()
            self?.checkInputMonitoringPermission()
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
        #if DEBUG
        // The DEBUG build is signed with a different identity than the release app, so its TCC
        // Accessibility grant is separate and goes stale on each rebuild. Treat it as granted while
        // developing so the permission gate doesn't block the app and we can test without
        // re-granting every time. (macOS still blocks real *global* event taps / synthetic
        // insertion without the grant — this only unblocks the in-app flow + the UI.)
        let granted = true
        #else
        let granted = AXIsProcessTrusted()
        #endif
        DispatchQueue.main.async { [weak self] in
            self?.isAccessibilityPermissionGranted = granted
        }
    }

    func checkInputMonitoringPermission() {
        let granted = CGPreflightListenEventAccess()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let becameGranted = granted && !self.isInputMonitoringPermissionGranted
            self.isInputMonitoringPermissionGranted = granted
            if becameGranted {
                NotificationCenter.default.post(name: .inputMonitoringPermissionChanged,
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

    func requestInputMonitoringPermissionOrOpenSystemPreferences() {
        if CGRequestListenEventAccess() {
            checkInputMonitoringPermission()
        } else {
            openSystemPreferences(for: .inputMonitoring)
        }
    }

    @objc private func accessibilityPermissionChanged() {
        checkAccessibilityPermission()
    }

    func openSystemPreferences(for permission: Permission) {
        let urlString: String
        switch permission {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString =
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }

        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
