import AppKit
import ApplicationServices
import Carbon
import Cocoa
import Foundation
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    // No baked-in combo default: a fresh install's default trigger is hold-Fn
    // (seeded in migrateRecordingTriggers), and this slot only holds a combo
    // the user explicitly records.
    static let toggleRecord = Self("toggleRecord")
    static let escape = Self("escape", default: .init(.escape))
    /// Command Mode (beta): hold, speak an instruction, release; the selection is rewritten.
    /// ⌃⌥⌘C by default ("C" for command): a combination, not a lone modifier, because the
    /// modifier tap fires on every press and Command Mode reads the selection (possibly with a
    /// synthetic ⌘C) at key-down; and three modifiers stay clear of the dictation trigger (Fn),
    /// Rectangle's ⌃⌥ letters and Finder's ⌥⌘C. Only enabled while Command Mode is on.
    static let commandMode = Self("commandMode", default: .init(.c, modifiers: [.control, .option, .command]))

    /// One registration handle per recorded key combination. Names are dynamic because the
    /// number of triggers is: the combinations themselves live in `recordingTriggers`, and
    /// these slots are only how the library is told about them. (#48)
    static func recordTriggerSlot(_ index: Int) -> Self { Self("recordTriggerSlot\(index)") }
    /// Slots are cleared up to this index when the list shrinks, so a removed combination
    /// can't stay bound. Well above any realistic number of triggers.
    static let recordTriggerSlotLimit = 16
}

class ShortcutManager {
    static let shared = ShortcutManager()

    private var activeVm: IndicatorViewModel?
    private let caretQueue = DispatchQueue(label: "com.noahkagan.rhino.caret", qos: .userInitiated)
    private var holdWorkItem: DispatchWorkItem?
    private let holdThreshold: TimeInterval = 0.3
    private var holdMode = false
    private var useModifierOnlyHotkey = false
    /// The live take is a Command Mode take (started by the Command Mode shortcut).
    private var commandTake = false
    /// Command Mode's own press/release state, separate from the dictation trigger's
    /// `holdMode`/`holdWorkItem` so neither shortcut can disturb the other's take.
    private var commandGesture = CommandGesture()
    /// Bumped per release poll, so only the latest poll may deliver a release.
    private var commandReleasePoll = 0

    /// Hands-free lock: once locked, release (and hold-release) no longer stops the recording;
    /// the next press does. A press locks instead of stopping whenever stopping would throw the
    /// take away (`shouldLock`), so a double-tap locks however loosely it's timed.
    private var lockedOn = false
    /// When the trigger press that started the current take landed.
    private var takeStartedAt: Date?
    /// How long a too-short hold-release waits for the double-tap's second press before it stops.
    private let secondTapGrace: TimeInterval = 0.35
    /// The stop a too-short hold-release deferred (see `handleKeyUp`).
    private var pendingHoldStop: DispatchWorkItem?
    /// Which press is held, whether it became a chord, and which press started the live take.
    private var chords = ChordState()

    /// Per-press bookkeeping for chords: a non-modifier key pressed soon after a modifier
    /// trigger goes down (Fn+↑ is Page Up, Fn+Delete, Fn+F5…) makes that press a shortcut,
    /// not dictation. Presses are numbered so a later main-actor Task can tell whether its
    /// press was chorded. Presses, chords and releases arrive on main in that order
    /// (ModifierKeyMonitor reports at most one key per press).
    struct ChordState {
        private(set) var press = 0
        private var pressedAt: Date?
        private var chordedPress: Int?
        private var takeOwner: Int?

        /// A new trigger press. Returns its number.
        mutating func pressBegan(at time: Date) -> Int {
            press += 1
            pressedAt = time
            return press
        }

        /// A key went down during the held press. Within `chordCancelWindow` of the press it
        /// makes the press a chord (returns its number); later it is a stray key during real
        /// dictation and is ignored entirely (nil), so the take behaves as it always did.
        mutating func chord(at time: Date) -> Int? {
            guard press > 0, let pressedAt,
                  ShortcutManager.keyIsChord(sincePress: time.timeIntervalSince(pressedAt))
            else { return nil }
            chordedPress = press
            return press
        }

        /// A chorded press's release does nothing: not a tap, no lock, no deferred stop.
        func isChorded(_ press: Int) -> Bool { chordedPress == press }
        func startedTake(_ press: Int) -> Bool { takeOwner == press }

        mutating func takeStarted(by press: Int) { takeOwner = press }
        mutating func takeEnded() { takeOwner = nil }
    }

    /// How soon after the trigger press a key makes it a chord. A shortcut like Fn+↑ lands
    /// almost at once; a key after this is a stray press during real dictation, which keeps
    /// recording (a long take is never wiped without the Esc confirmation).
    static let chordCancelWindow: TimeInterval = 1.0

    /// How long a new take's audible and visible side effects (bubble, start chime, media
    /// pause, paywall) wait, so a chord landing in that time never shows or plays them. The mic
    /// itself starts at once, so no audio is lost. Real Fn+↑ chords in Noah's logs landed
    /// 20–120 ms after the press; 200 ms covers them with margin and stays under the ~250 ms
    /// where a late bubble starts to read as lag (see decisions.md 2026-11-13).
    static let chordSettleDelay: TimeInterval = 0.2

    /// How long the bubble stays hidden after a trigger press. Only a modifier trigger can be
    /// the start of a chord (Fn+↑); a key-combination trigger or Command Mode shows at once.
    static func bubbleSettle(triggerCanChord: Bool) -> TimeInterval {
        triggerCanChord ? chordSettleDelay : 0
    }

    static func keyIsChord(sincePress elapsed: TimeInterval) -> Bool {
        elapsed < chordCancelWindow
    }

    /// A chord only cancels a take that the chorded press itself started. With a locked
    /// (hands-free) take, the trigger press itself stops (or locks) the take before any chord
    /// arrives, exactly as before chords existed, so the chord then has nothing to cancel.
    static func chordDiscardsTake(startedByThisPress: Bool, takeLive: Bool, lockedOn: Bool) -> Bool {
        startedByThisPress && takeLive && !lockedOn
    }

    /// Whether a trigger press on a live take locks it on rather than stopping it. A take
    /// younger than the recorder's keep threshold would be discarded by a stop, so the only
    /// thing a press can usefully mean there is the second tap of a double-tap. A press during
    /// a too-short hold's grace window is that second tap too, whatever the take's age.
    static func shouldLock(takeAge: TimeInterval, awaitingSecondTap: Bool,
                           lockedOn: Bool, doubleTapLock: Bool) -> Bool {
        guard doubleTapLock, !lockedOn else { return false }
        return awaitingSecondTap || takeAge < AudioRecorder.minimumKeptDuration
    }

    /// Whether a hold-to-talk release should wait for a second tap instead of stopping now.
    /// Only a release that would discard the take: a first tap held a little past the hold
    /// threshold otherwise stopped and hid the bubble, and the second tap then started a new
    /// take — the bubble popped up, vanished and popped back.
    static func shouldDeferHoldStop(takeAge: TimeInterval, doubleTapLock: Bool) -> Bool {
        doubleTapLock && takeAge < AudioRecorder.minimumKeptDuration
    }

    private init() {
        print("ShortcutManager init")

        setupKeyboardShortcuts()
        setupRecordingTrigger()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: .hotkeySettingsChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(globalEventListeningPermissionChanged),
            name: .globalEventListeningPermissionChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(indicatorWindowDidHide),
            name: .indicatorWindowDidHide,
            object: nil
        )
    }
    
    @objc private func indicatorWindowDidHide() {
        activeVm = nil
        holdMode = false
        lockedOn = false
        if commandTake { commandGesture.reset() }
        commandTake = false
        takeStartedAt = nil
        chords.takeEnded()
        pendingHoldStop?.cancel()
        pendingHoldStop = nil
    }

    @objc private func hotkeySettingsChanged() {
        setupRecordingTrigger()
    }

    @objc private func globalEventListeningPermissionChanged() {
        // The modifier monitor stays unarmed until TCC approves event listening. Build its tap
        // as soon as Accessibility (or an existing Input Monitoring grant) becomes available.
        setupRecordingTrigger()
    }

    private func setupKeyboardShortcuts() {
        // Self-heal a cleared cancel shortcut: KeyboardShortcuts' `default:` only applies when
        // the key is ABSENT from UserDefaults; a stored-empty value (`false`) overrides it, which
        // leaves cancel-on-Esc silently dead — and there's no UI to re-enable it. Restore the
        // default Esc when nothing is bound.
        if KeyboardShortcuts.getShortcut(for: .escape) == nil {
            KeyboardShortcuts.setShortcut(.init(.escape), for: .escape)
        }

        // One pair of handlers per slot, registered once for the process lifetime.
        for index in 0..<KeyboardShortcuts.Name.recordTriggerSlotLimit {
            let slot = KeyboardShortcuts.Name.recordTriggerSlot(index)
            KeyboardShortcuts.onKeyDown(for: slot) { [weak self] in self?.handleKeyDown(canChord: false) }
            KeyboardShortcuts.onKeyUp(for: slot) { [weak self] in self?.handleKeyUp() }
        }

        KeyboardShortcuts.onKeyDown(for: .commandMode) { [weak self] in self?.handleCommandKeyDown() }
        KeyboardShortcuts.onKeyUp(for: .commandMode) { [weak self] in self?.handleCommandKeyUp() }

        KeyboardShortcuts.onKeyUp(for: .escape) { [weak self] in
            Task { @MainActor in
                // The manager decides by bubble state: while recording this is the cancel
                // flow (a long recording arms a confirmation and returns false — leave
                // activeVm set so the next Esc confirms); in any later state it just
                // dismisses the bubble. No activeVm gate: activeVm is cleared the moment
                // the stop press is handled, and gating on it left a bubble stuck in
                // `.decoding` immune to Esc while Rhino swallowed the key system-wide.
                if IndicatorWindowManager.shared.handleEscape() {
                    self?.activeVm = nil
                }
            }
        }
        KeyboardShortcuts.disable(.escape)
    }
    
    private func setupRecordingTrigger() {
        let set = RecordingTriggerSet.load(from: AppPreferences.shared.recordingTriggers)

        ModifierKeyMonitor.shared.stop()
        let modifiers = set.modifiers
        if !modifiers.isEmpty {
            ModifierKeyMonitor.shared.onKeyDown = { [weak self] _ in self?.handleKeyDown(canChord: true) }
            ModifierKeyMonitor.shared.onKeyUp = { [weak self] _ in self?.handleKeyUp() }
            ModifierKeyMonitor.shared.onChord = { [weak self] in self?.handleChord() }
            ModifierKeyMonitor.shared.start(modifierKeys: modifiers)
        }

        bindKeyComboSlots(set.keyCombos)

        // Off by default; while off, its combination must not be swallowed system-wide.
        // A combination also on the dictation list stays a dictation trigger: one press must
        // not start both.
        let commandCombo = KeyboardShortcuts.getShortcut(for: .commandMode)
        if AppPreferences.shared.commandModeEnabled,
           commandCombo.map({ !set.keyCombos.contains($0) }) ?? false {
            KeyboardShortcuts.enable(.commandMode)
        } else {
            KeyboardShortcuts.disable(.commandMode)
        }

        useModifierOnlyHotkey = !set.modifiers.isEmpty
        print("ShortcutManager: \(set.triggers.count) recording trigger(s) armed")
    }

    /// Points one library slot at each recorded combination and clears the rest, so removing a
    /// trigger actually unbinds it rather than leaving a stale slot listening.
    ///
    /// Only the bindings move here. The handlers are registered once at launch, because
    /// `KeyboardShortcuts.onKeyDown` appends to a list rather than replacing: re-registering on
    /// every settings change stacked duplicates, and one key press then ran the toggle twice —
    /// starting a recording and immediately ending it, which looked like the mic firing with no
    /// indicator.
    private func bindKeyComboSlots(_ combos: [KeyboardShortcuts.Shortcut]) {
        for index in 0..<KeyboardShortcuts.Name.recordTriggerSlotLimit {
            let slot = KeyboardShortcuts.Name.recordTriggerSlot(index)
            if index < combos.count {
                KeyboardShortcuts.setShortcut(combos[index], for: slot)
                KeyboardShortcuts.enable(slot)
            } else {
                KeyboardShortcuts.setShortcut(nil, for: slot)
                KeyboardShortcuts.disable(slot)
            }
        }
    }

    /// `canChord`: a modifier trigger, which a following key can turn into a shortcut (Fn+↑);
    /// its bubble waits out `chordSettleDelay` hidden while the mic already records.
    private func handleKeyDown(canChord: Bool) {
        // A Command Mode take owns the bubble until it ends (Esc still cancels it).
        guard !commandGesture.isBusy else { return }
        holdWorkItem?.cancel()
        holdMode = false

        let holdToRecordEnabled = AppPreferences.shared.holdToRecord
        let doubleTapLock = AppPreferences.shared.doubleTapLock
        // Timed and cancelled here (not in the Task) so queue latency can't stretch the
        // gesture, and a deferred stop can't fire between this press and its handling.
        let now = Date()
        let press = chords.pressBegan(at: now)
        let awaitingSecondTap = pendingHoldStop != nil
        pendingHoldStop?.cancel()
        pendingHoldStop = nil

        Task { @MainActor in
            if self.activeVm == nil {
                // Already a chord (the key landed before this Task ran): never start.
                guard !self.chords.isChorded(press) else { return }
                guard !UnlockRhino.shared.recordingBlocked else {
                    // Over the free limit: the flash and panel wait out the settle delay, so
                    // a Page Up (Fn+↑) doesn't pop the paywall.
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.chordSettleDelay) {
                        [weak self] in
                        guard let self, !self.chords.isChorded(press) else { return }
                        UnlockRhino.shared.showRecordingBlocked()
                    }
                    return
                }
                Diag.mark("keyDown → start recording")
                let cursorPosition = FocusUtils.getCurrentCursorPosition()
                let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier
                let needsCaret = FocusUtils.shouldAnchorToCaret(
                    indicatorPosition: AppPreferences.shared.indicatorPosition) && processID != nil
                // The first hosted frame needs the current app's icon, too.
                // Optional title metadata stays on RecordingContext's worker queue.
                RecordingContext.shared.captureFrontmost()
                let vm = Diag.measure("IndicatorWindowManager.show") {
                    IndicatorWindowManager.shared.show(
                        nearPoint: cursorPosition, waitForCaret: needsCaret,
                        chordSettle: Self.bubbleSettle(triggerCanChord: canChord))
                }
                Diag.measure("vm.startRecording") { vm.startRecording() }
                self.activeVm = vm
                self.lockedOn = false
                self.takeStartedAt = now
                self.chords.takeStarted(by: press)
                // The mic is already starting. Resolve placement in the background;
                // the manager briefly holds the bubble offscreen, then keeps its anchor.
                if needsCaret, let processID {
                    self.caretQueue.async {
                        let caret = FocusUtils.getCaretRect(processID: processID)
                        DispatchQueue.main.async { [weak self, weak vm] in
                            guard let vm, self?.activeVm === vm else { return }
                            IndicatorWindowManager.shared.updateCaretAnchor(caret, for: vm)
                        }
                    }
                }
            } else if Self.shouldLock(
                takeAge: self.takeStartedAt.map { now.timeIntervalSince($0) } ?? .infinity,
                awaitingSecondTap: awaitingSecondTap,
                lockedOn: self.lockedOn,
                doubleTapLock: doubleTapLock) {
                // Hands-free: the double-tap's second press locks the same take on — the bubble
                // never leaves the screen. Any later press (once locked) stops.
                self.lockedOn = true
            } else if !self.holdMode || self.lockedOn {
                self.lockedOn = false
                self.stopActiveTake()
            }
        }

        // A locking press may arm this too: if it's held past the threshold, holdMode flips on,
        // but handleKeyUp returns before it reads holdMode while locked, so the lock holds.
        if holdToRecordEnabled {
            let workItem = DispatchWorkItem { [weak self] in
                self?.holdMode = true
            }
            holdWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: workItem)
        }
    }
    
    /// A non-modifier key went down while a modifier trigger was held (see `ChordState`).
    private func handleChord() {
        guard let press = chords.chord(at: Date()) else { return }
        // The release will be a no-op; the hold timer must not flip holdMode behind it.
        holdWorkItem?.cancel()
        holdWorkItem = nil
        Task { @MainActor in
            guard Self.chordDiscardsTake(startedByThisPress: self.chords.startedTake(press),
                                         takeLive: self.activeVm != nil,
                                         lockedOn: self.lockedOn) else { return }
            // Quietly: transcribe and insert nothing, and don't block main on the recorder.
            Diag.mark("trigger chord → discard take")
            self.discardChordTake()
        }
    }

    private func handleKeyUp() {
        guard !commandGesture.isBusy else { return }
        holdWorkItem?.cancel()
        holdWorkItem = nil
        // A chorded press's release is not a tap: no stop, no lock, no deferred stop.
        if chords.isChorded(chords.press) { return }
        let press = chords.press

        let holdToRecordEnabled = AppPreferences.shared.holdToRecord
        let doubleTapLock = AppPreferences.shared.doubleTapLock
        let now = Date()

        Task { @MainActor in
            // No chord can land after the release, so a quick tap's bubble needn't wait out
            // the rest of the settle.
            if let vm = self.activeVm, self.chords.startedTake(press) {
                IndicatorWindowManager.shared.settleChord(for: vm)
            }
            // Locked on (hands-free): releases never stop the recording; only a press does.
            if self.lockedOn { return }
            guard holdToRecordEnabled && self.holdMode else { return }
            self.holdMode = false
            let takeAge = self.takeStartedAt.map { now.timeIntervalSince($0) } ?? .infinity
            if Self.shouldDeferHoldStop(takeAge: takeAge, doubleTapLock: doubleTapLock),
               let vm = self.activeVm {
                // Too short to keep: likely a slow first tap. Give the second tap a moment to
                // land (handleKeyDown cancels this and locks); otherwise discard the take. A
                // plain stop here could find it past the keep threshold after the wait, and
                // transcribe a hold judged too short plus audio from after the release.
                let stop = DispatchWorkItem { [weak self, weak vm] in
                    MainActor.assumeIsolated {
                        guard let self, let vm, self.activeVm === vm else { return }
                        self.pendingHoldStop = nil
                        self.stopActiveTake(discard: true)
                    }
                }
                self.pendingHoldStop = stop
                DispatchQueue.main.asyncAfter(deadline: .now() + self.secondTapGrace, execute: stop)
                return
            }
            self.stopActiveTake()
        }
    }

    @MainActor private func stopActiveTake(discard: Bool = false) {
        // No take of ours: a late release (holdMode flipped after the stop press) must not
        // stop whatever the bubble shows now, such as the previous take still decoding.
        if activeVm != nil {
            IndicatorWindowManager.shared.stopRecording(discard: discard)
        }
        activeVm = nil
        holdMode = false
        if commandTake { commandGesture.reset() }
        commandTake = false
        takeStartedAt = nil
        chords.takeEnded()
    }

    /// A chord's discard. Unlike `stopActiveTake(discard:)` it doesn't wait on the recorder's
    /// queue, where the take's own CoreAudio start may still be running.
    @MainActor private func discardChordTake() {
        activeVm?.discardRecording()
        activeVm = nil
        holdMode = false
        takeStartedAt = nil
        chords.takeEnded()
    }

    // MARK: - Command Mode

    /// Command Mode press. Hold to talk (release stops) or tap to start and tap again to stop;
    /// no hands-free lock. The selection is read before anything records, so a missing
    /// selection or model costs nothing but a message. See `CommandGesture`.
    private func handleCommandKeyDown() {
        let now = Date()
        Task { @MainActor in
            let dictationActive = self.activeVm != nil && !self.commandTake
            switch self.commandGesture.press(at: now, dictationActive: dictationActive,
                                             commandInFlight: SelectionCapture.isBusy) {
            case .startCapture: await self.startCommandTake()
            case .stop: self.stopActiveTake()
            case .busy:
                IndicatorWindowManager.shared.flash(.info(CommandMode.Failure.busy.message))
            default: break
            }
        }
    }

    private func handleCommandKeyUp() {
        let now = Date()
        let keyStillDown = Self.commandKeyPhysicallyDown()
        Task { @MainActor in
            self.deliverCommandRelease(at: now, keyStillDown: keyStillDown)
            // Reported while the key is still down: most likely the synthetic ⌘C's C key-up
            // matched the hotkey. The real release may then never be reported, so watch the
            // key and deliver it when it actually comes up.
            if keyStillDown { self.pollForCommandRelease() }
        }
    }

    @MainActor private func deliverCommandRelease(at now: Date, keyStillDown: Bool) {
        let action = commandGesture.release(at: now, keyStillDown: keyStillDown,
                                            holdToRecord: AppPreferences.shared.holdToRecord)
        if action == .stop, commandTake { stopActiveTake() }
    }

    @MainActor private func pollForCommandRelease() {
        commandReleasePoll += 1
        let generation = commandReleasePoll
        Task { @MainActor in
            while self.commandReleasePoll == generation, self.commandGesture.isBusy {
                try? await Task.sleep(nanoseconds: 30_000_000)
                if !Self.commandKeyPhysicallyDown() {
                    if self.commandReleasePoll == generation {
                        self.deliverCommandRelease(at: Date(), keyStillDown: false)
                    }
                    return
                }
            }
        }
    }

    /// Whether the Command Mode shortcut's key is physically down (hardware state, which the
    /// synthetic ⌘C doesn't change).
    private static func commandKeyPhysicallyDown() -> Bool {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .commandMode) else { return false }
        return CGEventSource.keyState(.hidSystemState, key: CGKeyCode(shortcut.carbonKeyCode))
    }

    @MainActor private func startCommandTake() async {
        let holdToRecord = AppPreferences.shared.holdToRecord
        guard AppPreferences.shared.commandModeEnabled else {
            _ = commandGesture.captureFinished(selected: false, holdToRecord: holdToRecord)
            return
        }
        guard LLMPostProcessor.currentBackend().isReady else {
            _ = commandGesture.captureFinished(selected: false, holdToRecord: holdToRecord)
            IndicatorWindowManager.shared.flash(.error(CommandMode.Failure.modelNotDownloaded.message))
            return
        }
        let captureStart = CFAbsoluteTimeGetCurrent()
        let captured = await SelectionCapture.capture(in: LiveSelectionCaptureEnvironment())
        print(String(format: "Command Mode: selection capture %.0fms (%@)",
                     (CFAbsoluteTimeGetCurrent() - captureStart) * 1000,
                     captured.map { "\($0.method)" } ?? "none"))
        if let failure = CommandMode.validateSelection(captured?.text) {
            _ = commandGesture.captureFinished(selected: false, holdToRecord: holdToRecord)
            IndicatorWindowManager.shared.flash(failure.isInfo ? .info(failure.message)
                                                               : .error(failure.message))
            return
        }
        guard activeVm == nil, let captured else {
            commandGesture.reset()
            return
        }
        switch commandGesture.captureFinished(selected: true, holdToRecord: holdToRecord) {
        case .startRecording:
            break
        case .releasedEarly:
            IndicatorWindowManager.shared.flash(.info(CommandMode.Failure.releasedEarly.message))
            return
        default:
            commandGesture.reset()
            return
        }

        Diag.mark("command keyDown → start recording (\(captured.method))")
        RecordingContext.shared.captureFrontmost()
        let vm = IndicatorWindowManager.shared.show(nearPoint: FocusUtils.getCurrentCursorPosition(),
                                                    waitForCaret: false)
        vm.commandSelection = captured
        vm.startRecording()
        activeVm = vm
        commandTake = true
        lockedOn = false
        takeStartedAt = Date()
    }
}
