//
//  RhinoApp.swift
//  Rhino
//
//  Created by user on 05.02.2025.
//

import AVFoundation
import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

@main
enum AppMain {
    static func main() {
        // `Rhino transcribe <file>` runs headless and never launches the GUI (#150).
        let args = CommandLine.arguments
        if CLI.shouldHandle(args) {
            CLI.run(args)
        }
        RhinoApp.main()
    }
}

struct RhinoApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
            .frame(minWidth: 780, minHeight: 540)
            .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 640)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            // Standard About panel, plus credits — a thank-you to the people whose
            // feedback shaped the app.
            CommandGroup(replacing: .appInfo) {
                Button("About Rhino") {
                    NSApp.activate(ignoringOtherApps: true)
                    let credits = NSMutableAttributedString(
                        string: "Thank you to Paul Stamatiou and Ross Di for all the feedback.",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                            .foregroundColor: NSColor.secondaryLabelColor,
                        ])
                    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    if let delegate = NSApplication.shared.delegate as? AppDelegate {
                        delegate.showMainWindow()
                    }
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "openMainWindow"))

        // Settings is presented as a sheet inside the main window (ContentView) —
        // Paul S.: "I don't like that the settings page opens up a new window."

        // Direct-email feedback, matching Meeting Coach: Rhino never uploads
        // the message itself; Send hands a prefilled draft to the user's mail app.
        Window("Send Feedback", id: "feedback") {
            FeedbackFormView()
        }
        .windowResizability(.contentSize)
    }

    init() {
        MainThreadWatchdog.shared.start()
        _ = ShortcutManager.shared
        _ = MicrophoneService.shared
    }
}

/// Keeps window-routing alive during both onboarding and normal use. The status
/// menu is AppKit-owned, so it posts a notification that this SwiftUI root turns
/// into the scene-level `openWindow` action.
private struct AppRootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                ContentView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFeedback)) { _ in
            openWindow(id: "feedback")
        }
    }
}

extension RhinoApp {
    static func startTranscriptionQueue() {
        Task { @MainActor in
            TranscriptionQueue.shared.startProcessingQueue()
        }
    }

    static func startRetentionScheduler() {
        Task { @MainActor in
            RecordingStore.shared.startRetentionScheduler()
        }
    }
}

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            AppPreferences.shared.hasCompletedOnboarding = hasCompletedOnboarding
        }
    }

    init() {
        var onboarding = AppPreferences.shared.hasCompletedOnboarding
        #if DEBUG
        if let force = DevConfig.shared.forceShowOnboarding {
            onboarding = !force
        }
        #endif
        self.hasCompletedOnboarding = onboarding
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var languageSubmenu: NSMenu?
    private var modelSubmenu: NSMenu?
    private var recentSubmenu: NSMenu?

    /// Rows for the "Recent" submenu, kept current by `recordingsDidUpdateNotification` rather
    /// than fetched when the menu opens: reading the store is async, and `menuNeedsUpdate` is
    /// not, so an open menu can't wait for it.
    private var recentTranscripts: [Recording] = []
    private var microphoneService = MicrophoneService.shared
    private var microphoneObserver: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // White-first product (design: Gebbia minimal, per the Typeless-style
        // mockups) — the whole app renders light regardless of system theme.
        NSApp.appearance = NSAppearance(named: .aqua)

        #if DEBUG
        applyDevDockBadge()
        #endif

        setupStatusBarItem()

        if let window = NSApplication.shared.windows.first(where: { $0.title != "Settings" }) {
            self.mainWindow = window
            window.delegate = self

            window.minSize = NSSize(width: 780, height: 540)

            // Start in the menu bar only (don't show the main window) when requested.
            // Never hide during onboarding — the user needs the window to finish setup.
            if AppPreferences.shared.startHidden && AppPreferences.shared.hasCompletedOnboarding {
                window.orderOut(nil)
                NSApplication.shared.setActivationPolicy(.accessory)
            } else if !AppPreferences.shared.hasCompletedOnboarding {
                // Setup is a one-step-at-a-time wizard now; the tallest step (Speech
                // model, mid-download with the add-on card) fits in ~740pt. Clamp to
                // the screen so small displays still fit; the ScrollView stays as
                // the fallback.
                let visible = (window.screen ?? NSScreen.main)?.visibleFrame.height ?? 740
                window.setContentSize(NSSize(width: 900, height: min(740, visible - 24)))
                window.center()
            }
        }

        // Default-on launch-at-login, registered exactly once after onboarding —
        // an update never re-registers behind a user who turned it off.
        if AppPreferences.shared.hasCompletedOnboarding,
           !AppPreferences.shared.didDefaultLaunchAtLogin {
            LaunchAtLoginManager.shared.setEnabled(true)
            AppPreferences.shared.didDefaultLaunchAtLogin = true
        }

        RhinoApp.startTranscriptionQueue()
        RhinoApp.startRetentionScheduler()
        observeMicrophoneChanges()

        // Speed: warm the heavy pieces at launch so the FIRST dictation doesn't
        // pay their load time — the ASR engine (~1-3s) and, when cleanup is on,
        // the LLM context. Both no-op when nothing is configured yet.
        Task { @MainActor in
            TranscriptionService.shared.preloadEngine()
            if AppPreferences.shared.aiPostProcessingEnabled {
                BuiltInLlamaBackend.shared.preload()
            }
        }
    }

    /// Launching Rhino again while it's running (Applications, Spotlight, Dock) lands here.
    /// Bring the hidden main window back ourselves — with the menu bar icon hidden this is
    /// the only route back into the app. When no window survives, returning true lets
    /// SwiftUI re-create the WindowGroup window (the showMainWindow fallback relies on it).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        NSApplication.shared.setActivationPolicy(.regular)
        guard let window = NSApplication.shared.windows
            .first(where: { $0.styleMask.contains(.titled) && $0.title != "Settings" }) else {
            return true
        }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        return false
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        guard isAudioFile(url) else {
            return false
        }

        queueAudioURLs([url])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let audioURLs = filenames
            .map { URL(fileURLWithPath: $0) }
            .filter { isAudioFile($0) }

        sender.reply(toOpenOrPrint: audioURLs.isEmpty ? .failure : .success)
        queueAudioURLs(audioURLs)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let audioURLs = urls.filter { isAudioFile($0) }
        queueAudioURLs(audioURLs)
    }

    private func queueAudioURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        Task { @MainActor in
            showMainWindow()

            for url in urls {
                await TranscriptionQueue.shared.addFileToQueue(url: url)
            }
        }
    }

    private func isAudioFile(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType.conforms(to: .audio)
        }
        return UTType(filenameExtension: url.pathExtension)?.conforms(to: .audio) ?? false
    }
    
    #if DEBUG
    /// Composites an orange "DEV" pill onto the Dock/app-switcher icon so a dev
    /// build is never mistaken for the installed copy. Runtime-only — the bundle's
    /// icon file is untouched, and Release builds never run this.
    private func applyDevDockBadge() {
        guard let base = NSApp.applicationIconImage else { return }
        let badged = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            let text = "DEV" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: rect.height * 0.18),
                .foregroundColor: NSColor.white,
            ]
            let textSize = text.size(withAttributes: attrs)
            let padX = textSize.height * 0.35
            let pill = NSRect(x: rect.maxX - textSize.width - padX * 2 - rect.width * 0.05,
                              y: rect.minY + rect.height * 0.05,
                              width: textSize.width + padX * 2,
                              height: textSize.height * 1.25)
            NSColor.systemOrange.setFill()
            NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
            text.draw(at: NSPoint(x: pill.midX - textSize.width / 2,
                                  y: pill.midY - textSize.height / 2),
                      withAttributes: attrs)
            return true
        }
        NSApp.applicationIconImage = badged
    }
    #endif

    private func observeMicrophoneChanges() {
        microphoneObserver = microphoneService.$availableMicrophones
            .sink { [weak self] _ in
                self?.updateStatusBarMenu()
            }
    }
    
    private func setupStatusBarItem() {
        if !AppPreferences.shared.hideMenuBarIcon {
            buildStatusItem()
        }

        // Registered here rather than in updateStatusBarMenu: that runs again on every language
        // or model change, so observers added there piled up one per rebuild. Also registered
        // even while the icon is hidden — the caches they maintain feed the menu when it's back.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languagePreferenceChanged),
            name: .appPreferencesLanguageChanged,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshRecentTranscripts),
            name: RecordingStore.recordingsDidUpdateNotification,
            object: nil)
        refreshRecentTranscripts()

        // Red dot + "Install Update…" item appear when a background Sparkle
        // check finds a newer version, and clear once it's installed.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateAvailabilityChanged),
            name: .updateAvailabilityChanged,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarIconVisibilityChanged),
            name: .menuBarIconVisibilityChanged,
            object: nil)
    }

    private func buildStatusItem() {
        // Variable length: the icon may carry a "DEV" tag (debug builds) and/or a
        // red update dot, both rendered as the button's attributed title.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.imagePosition = .imageLeft
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
        }
        refreshStatusBadge()
        updateStatusBarMenu()
    }

    /// Settings toggled "Hide menu bar icon" — add or remove the status item live.
    @objc private func menuBarIconVisibilityChanged() {
        if AppPreferences.shared.hideMenuBarIcon {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        } else if statusItem == nil {
            buildStatusItem()
        }
    }

    @objc private func updateAvailabilityChanged() {
        refreshStatusBadge()
        updateStatusBarMenu()
    }

    /// The tray glyph (rhino), template so the menu bar tints it for light/dark.
    private static func trayIcon() -> NSImage? {
        if let icon = NSImage(named: "tray_icon") {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = true
            return icon
        }
        return NSImage(systemSymbolName: "waveform", accessibilityDescription: "Rhino")
    }

    /// The tray glyph with a red update dot badged onto its top-right corner —
    /// on the rhino, not trailing behind it. A colored badge forces the image
    /// out of template mode, so the glyph is tinted with `labelColor` inside a
    /// drawing handler; that block re-runs per draw, so it re-resolves when the
    /// menu bar switches between light and dark.
    private static func badgedTrayIcon() -> NSImage? {
        guard let base = trayIcon() else { return nil }
        let badged = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            NSColor.labelColor.set()
            rect.fill(using: .sourceAtop)

            // Placed to overlap the rhino's back — the glyph doesn't reach the
            // frame's top-right corner, so a corner-anchored dot floats in space.
            let dot = NSRect(x: rect.maxX - 7, y: rect.maxY - 9, width: 6, height: 6)
            // Punch a thin gap around the dot so it reads as a badge sitting on
            // the glyph rather than a blob merged into it.
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.setBlendMode(.clear)
                NSBezierPath(ovalIn: dot.insetBy(dx: -1.25, dy: -1.25)).fill()
                ctx.setBlendMode(.normal)
            }
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        badged.isTemplate = false
        return badged
    }

    /// Keeps the status button current: the plain rhino normally, the badged one
    /// while an update is waiting — the quiet "something's new up here" cue —
    /// plus a "DEV" text suffix on debug builds.
    private func refreshStatusBadge() {
        guard let button = statusItem?.button else { return }
        let badge = NSMutableAttributedString()
        #if DEBUG
        badge.append(NSAttributedString(
            string: " DEV",
            attributes: [.font: NSFont.systemFont(ofSize: 9, weight: .bold)]))
        #endif
        button.attributedTitle = badge

        let updateWaiting = MainActor.assumeIsolated { SparkleUpdater.shared.updateAvailable }
        button.image = (updateWaiting ? Self.badgedTrayIcon() : nil) ?? Self.trayIcon()
    }

    private func updateStatusBarMenu() {
        let menu = NSMenu()

        // Surfaced at the very top while an update is waiting, mirroring the red
        // dot on the icon. Opens Sparkle's normal install prompt.
        if MainActor.assumeIsolated({ SparkleUpdater.shared.updateAvailable }) {
            let updateReady = NSMenuItem(title: "Install Update…",
                                         action: #selector(checkForUpdates), keyEquivalent: "")
            updateReady.target = self
            updateReady.image = NSImage(systemSymbolName: "arrow.down.circle.fill",
                                        accessibilityDescription: "Update available")
            menu.addItem(updateReady)
            menu.addItem(NSMenuItem.separator())
        }

        let openItem = NSMenuItem(title: "Open Window", action: #selector(openApp), keyEquivalent: "o")
        openItem.target = self   // without a target macOS disables the item (it did nothing)
        menu.addItem(openItem)

        // Direct route to dictionary editing — adding a word mid-dictation otherwise
        // costs Open Window → sidebar → Dictionary.
        let dictionaryItem = NSMenuItem(title: "Dictionary…", action: #selector(openDictionary), keyEquivalent: "d")
        dictionaryItem.target = self
        menu.addItem(dictionaryItem)

        let transcriptionLanguageItem = NSMenuItem(title: NSLocalizedString("Language", comment: ""), action: nil, keyEquivalent: "")
        languageSubmenu = NSMenu()
        
        // Add language options — only those the active engine/model can transcribe (#155).
        let menuLanguages = EngineCapabilities.supportedLanguages(
            engine: AppPreferences.shared.selectedEngine,
            fluidAudioModelVersion: AppPreferences.shared.fluidAudioModelVersion)
        for languageCode in menuLanguages {
            let languageName = LanguageUtil.languageNames[languageCode] ?? languageCode
            let languageItem = NSMenuItem(title: languageName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            languageItem.target = self
            languageItem.representedObject = languageCode
            languageItem.state = (AppPreferences.shared.whisperLanguage == languageCode) ? .on : .off
            languageSubmenu?.addItem(languageItem)
        }
        
        transcriptionLanguageItem.submenu = languageSubmenu
        menu.addItem(transcriptionLanguageItem)

        // Model picker — quick cross-engine switch. Its items are (re)built each time
        // the submenu opens (menuNeedsUpdate) so newly-downloaded or newly-fetched
        // remote models show up without relaunching. (F2)
        let modelMenuItem = NSMenuItem(title: NSLocalizedString("Model", comment: ""), action: nil, keyEquivalent: "")
        let modelMenu = NSMenu()
        modelMenu.delegate = self
        modelSubmenu = modelMenu
        populateModelSubmenu()
        modelMenuItem.submenu = modelMenu
        menu.addItem(modelMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Reaching an earlier dictation otherwise means opening the main window and copying out
        // of the history list. Rebuilt on open like the model submenu, from a cache the store's
        // change notification keeps current.
        let recentItem = NSMenuItem(title: NSLocalizedString("Recent", comment: ""), action: nil, keyEquivalent: "")
        let recentMenu = NSMenu()
        recentMenu.delegate = self
        recentSubmenu = recentMenu
        populateRecentSubmenu()
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)

        let microphoneMenu = NSMenuItem(title: NSLocalizedString("Microphone", comment: ""), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        
        let microphones = microphoneService.availableMicrophones
        let currentMic = microphoneService.currentMicrophone
        
        if microphones.isEmpty {
            let noDeviceItem = NSMenuItem(title: NSLocalizedString("No microphones available", comment: ""), action: nil, keyEquivalent: "")
            noDeviceItem.isEnabled = false
            submenu.addItem(noDeviceItem)
        } else {
            let builtInMicrophones = microphones.filter { $0.isBuiltIn }
            let externalMicrophones = microphones.filter { !$0.isBuiltIn }
            
            for microphone in builtInMicrophones {
                let item = NSMenuItem(
                    title: microphone.displayName,
                    action: #selector(selectMicrophone(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = microphone
                
                if let current = currentMic, current.id == microphone.id {
                    item.state = .on
                }
                
                submenu.addItem(item)
            }
            
            if !builtInMicrophones.isEmpty && !externalMicrophones.isEmpty {
                submenu.addItem(NSMenuItem.separator())
            }
            
            for microphone in externalMicrophones {
                let item = NSMenuItem(
                    title: microphone.displayName,
                    action: #selector(selectMicrophone(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = microphone
                
                if let current = currentMic, current.id == microphone.id {
                    item.state = .on
                }
                
                submenu.addItem(item)
            }
        }
        
        microphoneMenu.submenu = submenu
        menu.addItem(microphoneMenu)
        
        menu.addItem(NSMenuItem.separator())

        // No "," keyEquivalent: it makes macOS treat this as the standard Settings
        // command and auto-adds a gear icon, which the other plain items don't have.
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.image = nil
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(title: NSLocalizedString("Check for Updates…", comment: ""),
                                    action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let feedbackItem = NSMenuItem(title: "Send Feedback…",
                                      action: #selector(openFeedback), keyEquivalent: "")
        feedbackItem.target = self
        menu.addItem(feedbackItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? MicrophoneService.AudioDevice else { return }
        microphoneService.selectMicrophone(device)
        updateStatusBarMenu()
    }

    // MARK: - Model picker (F2)

    // The Model submenu opening is the moment to snapshot the app the user is in,
    // so binding a model targets the right app without requiring a recording first.
    // Opening a status-bar menu doesn't steal focus, so the frontmost app is still
    // the one the cursor is in.
    func menuWillOpen(_ menu: NSMenu) {
        RecordingContext.shared.captureFrontmost()
    }

    // Rebuild the Model submenu just before it opens, so it reflects the latest
    // downloaded/fetched models and the current selection.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === modelSubmenu {
            populateModelSubmenu()
        }
        if menu === recentSubmenu {
            populateRecentSubmenu()
        }
    }

    private func populateRecentSubmenu() {
        guard let submenu = recentSubmenu else { return }
        submenu.removeAllItems()

        guard !recentTranscripts.isEmpty else {
            let empty = NSMenuItem(title: NSLocalizedString("No transcriptions yet", comment: ""),
                                   action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return
        }

        for recording in recentTranscripts {
            let item = NSMenuItem(title: RecentTranscripts.menuTitle(for: recording.transcription),
                                  action: #selector(insertRecentTranscript(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = recording.transcription
            // The truncated title loses the end of a long dictation; the tooltip keeps it, so
            // picking between two that start alike doesn't need the main window.
            item.toolTip = recording.transcription
            submenu.addItem(item)
        }
    }

    @objc private func insertRecentTranscript(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        Task { @MainActor in
            await RecentTranscripts.insert(text)
        }
    }

    /// Refreshes the cache behind the "Recent" submenu. Cheap (one indexed read) and only runs
    /// when the stored recordings actually changed.
    @objc private func refreshRecentTranscripts() {
        Task { @MainActor in
            guard let recordings = try? await RecordingStore.shared.fetchRecordings(
                limit: RecentTranscripts.scanDepth, offset: 0) else { return }

            recentTranscripts = RecentTranscripts.pick(from: recordings,
                                                       limit: RecentTranscripts.menuCount)
            populateRecentSubmenu()
        }
    }

    private func populateModelSubmenu() {
        guard let submenu = modelSubmenu else { return }
        submenu.removeAllItems()

        let active = ModelCatalog.activeOption()
        let groups: [(label: String, options: [DictationModelOption])] = [
            ("Whisper", ModelCatalog.whisperModels()),
            ("Parakeet", ModelCatalog.parakeetModels()),
        ]

        var addedAnything = false
        for group in groups where !group.options.isEmpty {
            if addedAnything { submenu.addItem(NSMenuItem.separator()) }
            let header = NSMenuItem(title: group.label, action: nil, keyEquivalent: "")
            header.isEnabled = false
            submenu.addItem(header)

            for option in group.options {
                let item = NSMenuItem(
                    title: option.displayName,
                    action: #selector(selectModel(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = option
                item.indentationLevel = 1
                if let active, active.engine == option.engine, active.identifier == option.identifier {
                    item.state = .on
                }
                submenu.addItem(item)
            }
            addedAnything = true
        }

        if !addedAnything {
            let none = NSMenuItem(title: NSLocalizedString("No models available", comment: ""), action: nil, keyEquivalent: "")
            none.isEnabled = false
            submenu.addItem(none)
        }
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let option = sender.representedObject as? DictationModelOption else { return }
        MainActor.assumeIsolated { ModelSelectionStore.shared.select(option) }
        populateModelSubmenu()
    }

    @objc private func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in
            SparkleUpdater.shared.checkForUpdates()
        }
    }

    @objc private func statusBarButtonClicked(_ sender: Any) {
        statusItem?.button?.performClick(nil)
    }
    
    @objc private func openApp() {
        showMainWindow()
    }

    @objc private func openSettings() {
        showMainWindow()
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc private func openDictionary() {
        showMainWindow()
        NotificationCenter.default.post(name: .openDictionary, object: nil)
    }

    @objc private func openFeedback() {
        NotificationCenter.default.post(name: .openFeedback, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let languageCode = sender.representedObject as? String else { return }

        // Single mutation point — persists and notifies an open Settings window.
        MainActor.assumeIsolated { LanguageStore.shared.select(languageCode) }

        // Update menu item states
        if let submenu = sender.menu {
            for item in submenu.items {
                item.state = .off
            }
            sender.state = .on
        }
    }
    
    @objc private func languagePreferenceChanged() {
        updateLanguageMenuSelection()
    }
    
    private func updateLanguageMenuSelection() {
        guard let languageSubmenu = languageSubmenu else { return }
        
        let currentLanguage = AppPreferences.shared.whisperLanguage
        
        for item in languageSubmenu.items {
            if let languageCode = item.representedObject as? String {
                item.state = (languageCode == currentLanguage) ? .on : .off
            }
        }
    }
    
    func showMainWindow() {
        NSApplication.shared.setActivationPolicy(.regular)

        // Never bring up the Settings window here — it's a separate scene. Use the
        // stored ref only if it isn't Settings, else find the real main window.
        let target = mainWindow.flatMap { $0.title == "Settings" ? nil : $0 }
            ?? NSApplication.shared.windows.first { $0.styleMask.contains(.titled) && $0.title != "Settings" }
        if let window = target {
            if !window.isVisible {
                window.makeKeyAndOrderFront(nil)
            }
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
        } else {
            // No window exists (the WindowGroup window was closed, or macOS didn't
            // open it at launch — seen on macOS 26/27). Re-opening the app bundle
            // triggers the reopen handler, which makes SwiftUI re-create the window.
            // (The old `openSuperWhisper://` scheme was never declared in Info.plist,
            // so that fallback silently failed — hence the menu item doing nothing.)
            NSWorkspace.shared.open(Bundle.main.bundleURL)
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Keep the main window alive — just hide it — instead of letting SwiftUI destroy
        // it on close. A destroyed WindowGroup window can't be reliably re-created from
        // within the app on macOS 26, which left the menu-bar "Open Window"/"Settings"
        // items doing nothing. Hidden, it stays in the windows list so showMainWindow()
        // can always bring it back. (Settings is a separate scene — let it close.)
        guard sender.title != "Settings" else { return true }
        sender.orderOut(nil)
        NSApplication.shared.setActivationPolicy(.accessory)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        return NSSize(width: 450, height: frameSize.height)
    }
}
