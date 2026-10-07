import AppKit
import Combine
import KeyboardShortcuts
import SwiftUI

@MainActor
class IndicatorWindowManager: IndicatorViewDelegate {
    static let shared = IndicatorWindowManager()

    /// The indicator window is sized manually (see `resizeToContent`) — NEVER via NSHostingView's
    /// `.preferredContentSize` auto-resize. That auto-resize animates the window frame on macOS 26
    /// (`NSHostingView.updateAnimatedWindowSize`) and recurses into layout until the main-thread
    /// stack overflows (#11/#15/#19). Must stay empty; `IndicatorLayoutRecursionTests` guards it.
    nonisolated static let hostingSizingOptions: NSHostingSizingOptions = []

    var window: NSWindow?
    var viewModel: IndicatorViewModel?

    // The window auto-sizes to its content (so the live caption pill grows with the text).
    // We keep the bottom edge anchored near the caret so it grows upward, not over the caret.
    private var anchorBottomY: CGFloat = 0
    private var anchorCenterX: CGFloat = 0
    // Notch mode anchors the *top* edge instead (the pill hangs from the screen top, growing down).
    private var anchorFromTop = false
    private var anchorTopY: CGFloat = 0
    private var resizeObserver: NSObjectProtocol?
    private var drainObserver: AnyCancellable?

    // Lay out offscreen, then reveal once at the chosen anchor. Cursor mode gives the
    // background AX query a short head start, never delaying the microphone. Once the
    // bubble is visible, a late AX reply must not teleport it away from the mouse.
    static let caretPresentationDelay: Duration = .milliseconds(100)
    private var presentationTask: Task<Void, Never>?
    private var presentationPending = false
    private var awaitingCaret = false
    private var preparePresentation: (() -> Void)?

    /// In the `.decoding` state the bubble's only exit is the pipeline draining — and
    /// `DictationPipeline` awaits the engine with no timeout, so a hung (non-throwing)
    /// transcription used to strand the bubble on screen until the app was quit
    /// (customer report, 2026-09-11). After this long the bubble hides itself; the
    /// pipeline keeps working and the text still lands if the engine ever returns.
    /// Generous on purpose: a long clip on a slow Whisper model can legitimately take
    /// a minute or two, and hiding early is only cosmetic.
    static let decodeWatchdogTimeout: TimeInterval = 120
    private var decodeWatchdog: Task<Void, Never>?

    private init() {}
    
    func show(nearPoint point: NSPoint? = nil,
              initialState: RecordingState = .recording,
              waitForCaret: Bool = false) -> IndicatorViewModel {
        ShareRhino.shared.dismissForRecording()

        presentationTask?.cancel()
        presentationTask = nil
        presentationPending = false
        preparePresentation = nil
        awaitingCaret = waitForCaret
        window?.orderOut(nil)

        KeyboardShortcuts.enable(.escape)

        // A recording started while the previous one was still transcribing: the bubble belongs
        // to the new take now, so stop waiting to hide it on the old one's behalf.
        drainObserver?.cancel()
        drainObserver = nil
        decodeWatchdog?.cancel()
        decodeWatchdog = nil

        // Create new view model
        let newViewModel = IndicatorViewModel()
        // Hosting can perform its first layout before show() returns. Starting at
        // .idle exposed a blank 200pt pill, then animated it down to the recording size.
        newViewModel.state = initialState
        newViewModel.delegate = self
        viewModel = newViewModel
        
        if window == nil {
            // Create window if it doesn't exist - using NSPanel for full-screen compatibility
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 120),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            panel.isFloatingPanel = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            // Fully click-through by default, matching the my-monkeys baseline: the
            // indicator never intercepts clicks meant for the app underneath. When the
            // opt-in on-bubble Stop/Cancel buttons are enabled, this is flipped per
            // show() below so they're tappable.
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            // Belt-and-suspenders: the window is sized manually + non-animated via
            // `resizeToContent` (#19), and this also stops AppKit from animating the frame on
            // its own. Size changes should snap, never animate (macOS 26 recursion guard).
            panel.animationBehavior = .none

            self.window = panel
        }
        
        // Accept clicks only when the stored layout shows an on-bubble button (so it's
        // tappable); otherwise stay fully click-through (baseline). Re-evaluated each show().
        window?.ignoresMouseEvents = IndicatorLayout
            .load(from: AppPreferences.shared.indicatorLayout).trailing.isEmpty

        // Position window - use the screen containing the point, or main screen as fallback
        let targetScreen = point.flatMap { FocusUtils.screenContaining(point: $0) } ?? NSScreen.main
        if let window = window, let screen = targetScreen {
            let screenFrame = screen.frame

            anchorFromTop = false
            switch AppPreferences.shared.indicatorPosition {
            case "notch":
                // Hang from the very top-center, growing downward — sitting in/around the notch
                // on notched Macs, or as a faux-notch pill on Macs without one.
                anchorFromTop = true
                anchorCenterX = screenFrame.midX
                anchorTopY = screenFrame.maxY
            case "top":
                anchorCenterX = screenFrame.midX
                anchorBottomY = screenFrame.maxY - 140
            case "center":
                anchorCenterX = screenFrame.midX
                anchorBottomY = screenFrame.midY
            case "bottom":
                anchorCenterX = screenFrame.midX
                anchorBottomY = screenFrame.minY + 120
            default: // "cursor": sit just above the caret, falling back to a band near the top
                if let point = point {
                    anchorBottomY = point.y + 20
                    anchorCenterX = point.x
                } else {
                    anchorBottomY = screenFrame.maxY - 260
                    anchorCenterX = screenFrame.midX
                }
            }

            reposition(window: window, screen: screen)

            // Keep the bottom edge anchored as the content (and window) grows upward.
            if resizeObserver == nil {
                resizeObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification, object: window, queue: .main
                ) { [weak self, weak window] _ in
                    guard let self, let window, let screen = window.screen ?? NSScreen.main else { return }
                    self.reposition(window: window, screen: screen)
                }
            }
        }

        // The indicator must draw over the menu bar AND over apps in a native full-screen space
        // (dictating into a full-screen app). `.fullScreenAuxiliary` + `.canJoinAllSpaces` let the
        // panel join the full-screen space, but that's not enough on its own: a `.statusBar`/
        // `.mainMenu`-level window (25) is occluded by the full-screen app's system-elevated window,
        // so the pill goes invisible there (#notch-fullscreen). `.screenSaver` (1000) is the level
        // dedicated overlay/notch apps (Lunar, boring.notch) use to sit above full-screen content;
        // it's also comfortably above the menu bar, so the notch pill still clears it.
        window?.level = .screenSaver
        window?.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]

        // Build the host at reveal time: the mic may enter Connecting (or an error)
        // while AX is outstanding. A prebuilt host can cache the old state's size,
        // even when asked for sizeThatFits immediately after that state changes.
        preparePresentation = { [weak self, weak newViewModel] in
            guard let self, let newViewModel, self.viewModel === newViewModel else { return }
            let hostingController = NSHostingController(
                rootView: IndicatorWindow(viewModel: newViewModel) { [weak self, weak newViewModel] size in
                    guard let self, let newViewModel, self.viewModel === newViewModel else { return }
                    self.resizeToContent(size)
                }
                // Read once per presentation, so a settings change cannot resize a live pill (#80).
                .environment(\.appTextScale, AppPreferences.shared.textScale)
            )
            // NEVER use .preferredContentSize: its animated auto-resize recurses into
            // layout on macOS 26 and overflows the stack (#11/#15/#19).
            hostingController.sizingOptions = Self.hostingSizingOptions
            self.window?.contentViewController = hostingController
            // Empty sizingOptions can leave a new host at 0×0 on macOS 15/26.
            // Seed a nonzero canvas, still hidden, so the content can lay out.
            self.window?.setContentSize(NSSize(width: 380, height: 120))
            // Hidden hosts need not publish geometry preferences (macOS 15). Explicit
            // measurement sizes the first frame; preferences handle later updates.
            self.resizeToContent(hostingController.sizeThatFits(in: NSSize(width: 380, height: 120)))
            hostingController.view.layoutSubtreeIfNeeded()
        }
        presentationPending = true
        presentIfReady()
        if awaitingCaret {
            presentationTask = Task { [weak self, weak newViewModel] in
                try? await Task.sleep(for: Self.caretPresentationDelay)
                guard !Task.isCancelled, let self, let newViewModel,
                      self.viewModel === newViewModel else { return }
                self.awaitingCaret = false
                self.presentIfReady()
            }
        }
        return newViewModel
    }

    private func presentIfReady() {
        guard presentationPending, !awaitingCaret,
              let window, let viewModel else { return }
        presentationPending = false
        preparePresentation?()
        preparePresentation = nil
        // Fn is normally pressed while another app owns the key window. The
        // conditional orderFront can leave this deferred presentation behind it;
        // orderFrontRegardless raises only the panel, without taking keyboard focus.
        window.orderFrontRegardless()
        viewModel.isVisible = true
        Diag.mark("indicator presented (appActive=\(NSApp.isActive), visible=\(window.isVisible), frame=\(window.frame))")
    }

    /// Sizes the indicator window to its SwiftUI content, *non-animated*. This replaces
    /// NSHostingView's `.preferredContentSize` auto-resize, whose animated variant recurses into
    /// layout and overflows the main-thread stack on macOS 26 (#11/#15/#19). `setContentSize`
    /// snaps in a single pass, so no SwiftUI animation can ever drive a window resize.
    private func resizeToContent(_ size: CGSize) {
        guard let window, size.width > 1, size.height > 1 else { return }
        let newSize = NSSize(width: ceil(size.width), height: ceil(size.height))
        let current = window.contentRect(forFrameRect: window.frame).size
        if abs(current.width - newSize.width) > 0.5 || abs(current.height - newSize.height) > 0.5 {
            window.setContentSize(newSize)
        }
        if let screen = window.screen ?? NSScreen.main {
            reposition(window: window, screen: screen)
        }
    }

    /// Finish the startup lookup, including a failed lookup (use the mouse fallback).
    /// A delayed AX reply must never move a visible, replacement or stopped bubble.
    func updateCaretAnchor(_ caret: CGRect?, for recording: IndicatorViewModel) {
        guard viewModel === recording,
              presentationPending, awaitingCaret,
              recording.state == .recording || recording.state == .connecting,
              let window else { return }
        let screens = NSScreen.screens
        if AppPreferences.shared.indicatorPosition == "cursor", let caret,
           let primaryScreen = screens.first,
           let point = FocusUtils.validatedCaretPoint(
               caret, primaryScreenMaxY: primaryScreen.frame.maxY,
               screenFrames: screens.map(\.frame)),
           let screen = screens.first(where: { $0.frame.contains(point) }) {
            anchorCenterX = point.x
            anchorBottomY = point.y + 20
            reposition(window: window, screen: screen)
        }
        presentationTask?.cancel()
        presentationTask = nil
        awaitingCaret = false
        presentIfReady()
    }

    private func reposition(window: NSWindow, screen: NSScreen) {
        let w = window.frame.width
        let h = window.frame.height
        let screenFrame = screen.frame
        let x = max(screenFrame.minX, min(anchorCenterX - w / 2, screenFrame.maxX - w))
        // Notch mode pins the top edge (grows down); everything else pins the bottom (grows up).
        let y = anchorFromTop
            ? max(screenFrame.minY, anchorTopY - h)
            : max(screenFrame.minY, min(anchorBottomY, screenFrame.maxY - h))
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Briefly shows the indicator at the configured position (without recording) so the user
    /// can see where it will appear. Used by the position picker's "Preview" button.
    func preview() {
        guard viewModel == nil else { return } // don't interfere with a live recording
        let vm = show(nearPoint: FocusUtils.getCurrentCursorPosition())
        vm.state = .recording
        vm.isBlinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.hide()
        }
    }

    /// Briefly show a status message (error / info) WITHOUT recording. Used by the background
    /// `DictationPipeline` to surface a failure, "no speech", or the "copied — press ⌘V" notice now
    /// that transcription no longer runs in a live indicator. Skipped while a recording is in
    /// progress so it never interrupts the live recording bubble. The message auto-hides via the
    /// view model's own timer (showError/showInfo). (parallel-recording #3)
    func flash(_ state: RecordingState) {
        if let current = viewModel, current.state == .recording || current.state == .connecting {
            return
        }
        let vm = show(nearPoint: FocusUtils.getCurrentCursorPosition(), initialState: state)
        switch state {
        case .error(let message): vm.showError(message)
        case .info(let message): vm.showInfo(message)
        default: vm.showBusyMessage()
        }
    }

    func stopRecording() {
        viewModel?.startDecoding()
    }

    func stopForce() {
        viewModel?.cancelRecording()
        viewModel?.cleanup()
        hide()
    }

    /// An Esc-cancel request. Returns `true` when the recording was actually
    /// discarded; `false` when a long recording is now waiting for a confirming
    /// second Esc (see `IndicatorViewModel.handleCancelRequest`).
    @discardableResult
    func requestCancel() -> Bool {
        guard let viewModel else { return false }
        guard viewModel.handleCancelRequest() else { return false }
        stopForce()
        return true
    }

    /// Global-Esc entry point while the bubble is up (the `.escape` shortcut is enabled
    /// from `show()` to `hide()`). Recording keeps the cancel flow (with the long-recording
    /// confirmation); every later state — decoding, busy, a flash — just dismisses the
    /// bubble, and the pipeline keeps transcribing in the background. Esc used to work only
    /// while recording, so a bubble stuck in `.decoding` swallowed Esc system-wide while
    /// offering no way out short of quitting the app (customer report, 2026-09-11).
    /// Returns `true` when a live recording was actually discarded.
    @discardableResult
    func handleEscape() -> Bool {
        guard let viewModel else {
            // No live take, but the panel may still be on screen (orphaned) — clear it.
            hide()
            return false
        }
        switch viewModel.state {
        case .recording, .connecting:
            return requestCancel()
        default:
            hide()
            return false
        }
    }

    func hide() {
        presentationTask?.cancel()
        presentationTask = nil
        presentationPending = false
        awaitingCaret = false
        preparePresentation = nil
        KeyboardShortcuts.disable(.escape)
        drainObserver?.cancel()
        drainObserver = nil
        decodeWatchdog?.cancel()
        decodeWatchdog = nil

        let hidingViewModel = viewModel
        Task {
            guard self.viewModel === hidingViewModel else { return }
            if let viewModel = hidingViewModel {
                await viewModel.hideWithAnimation()
                viewModel.cleanup()

                // A new recording may have started during the hide animation (rapid re-record now
                // that recording is decoupled from transcription). If show() has since installed a
                // different view model, this teardown belongs to the *previous* recording — don't
                // clear the window/content out from under the new one, or reset the hotkey state.
                // (parallel-recording)
                guard self.viewModel === viewModel else { return }
            }
            // No `else return`: with no view model at all (never true in the normal flow) the
            // panel is an orphan, and tearing it down is exactly what's needed.

            self.window?.orderOut(nil)
            self.window?.contentViewController = nil
            self.viewModel = nil

            NotificationCenter.default.post(name: .indicatorWindowDidHide, object: nil)
        }
    }
    
    func didFinishDecoding() {
        // The clip has gone to the background pipeline and the bubble is free for the next
        // recording. It used to vanish here, which left nothing on screen between the moment
        // you stop talking and the moment the text lands: on a slow model that reads as the
        // dictation having been dropped. It stays instead, showing that work is still running.
        guard DictationPipeline.shared.isProcessing else {
            hide()
            return
        }

        viewModel?.state = .decoding
        watchPipelineDrain()
        armDecodeWatchdog()
    }

    /// Backstop for `watchPipelineDrain`: hides the bubble if the pipeline never drains
    /// (see `decodeWatchdogTimeout`). Cancelled by `show()` and `hide()`; a fired watchdog
    /// double-checks it still watches the current view model in its still-`.decoding` state.
    private func armDecodeWatchdog() {
        decodeWatchdog?.cancel()
        let watched = viewModel
        decodeWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.decodeWatchdogTimeout * 1_000_000_000))
            guard !Task.isCancelled, let self,
                  self.viewModel === watched, self.viewModel?.state == .decoding else { return }
            Diag.log.error("decode watchdog fired: pipeline still busy after \(Int(Self.decodeWatchdogTimeout))s — hiding the indicator")
            self.hide()
        }
    }

    /// Hides the bubble once the queue empties.
    ///
    /// Nothing is torn down if a new recording arrives first: `show()` hands out a fresh view
    /// model, and this only ever hides while the one it is watching is still the current one and
    /// still decoding.
    private func watchPipelineDrain() {
        drainObserver?.cancel()
        let watched = viewModel
        drainObserver = DictationPipeline.shared.$isProcessing
            .removeDuplicates()
            .filter { !$0 }
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.viewModel === watched, self.viewModel?.state == .decoding
                    else { return }
                    self.hide()
                }
            }
    }
}
