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

    /// Per-press bookkeeping for chords: a non-modifier key pressed while a modifier trigger is
    /// held (Fn+↑ is Page Up, Fn+Delete, Fn+F5…) makes that press a shortcut, not dictation.
    /// Presses are numbered so a later main-actor Task can tell whether its press was chorded.
    /// Presses, chords and releases arrive on main in that order (ModifierKeyMonitor).
    struct ChordState {
        private(set) var press = 0
        private var chordedPress: Int?
        private var takeOwner: Int?

        /// A new trigger press. Returns its number.
        mutating func pressBegan() -> Int {
            press += 1
            return press
        }

        /// Marks the held press as a chord. Returns its number, or nil if it already was one.
        mutating func chord() -> Int? {
            guard press > 0, chordedPress != press else { return nil }
            chordedPress = press
            return press
        }

        func isChorded(_ press: Int) -> Bool { chordedPress == press }

        mutating func takeStarted(by press: Int) { takeOwner = press }
        mutating func takeEnded() { takeOwner = nil }

        /// Whether a chord on `press` should throw the live take away.
        func chordDiscardsTake(press: Int, takeLive: Bool, lockedOn: Bool) -> Bool {
            ShortcutManager.chordDiscardsTake(startedByThisPress: takeOwner == press,
                                              takeLive: takeLive, lockedOn: lockedOn)
        }

        /// A chorded press's release does nothing: not a tap, no lock, no deferred stop.
        func releaseIgnored(_ press: Int) -> Bool { isChorded(press) }
    }

    /// A chord only cancels a take that the chorded press itself started. A take that was
    /// already locked on (hands-free), or one the press locked or stopped, keeps today's
    /// behavior, so Fn+↑ while dictating hands-free scrolls without losing the dictation.
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
            KeyboardShortcuts.onKeyDown(for: slot) { [weak self] in self?.handleKeyDown() }
            KeyboardShortcuts.onKeyUp(for: slot) { [weak self] in self?.handleKeyUp() }
        }

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
            ModifierKeyMonitor.shared.onKeyDown = { [weak self] _ in self?.handleKeyDown() }
            ModifierKeyMonitor.shared.onKeyUp = { [weak self] _ in self?.handleKeyUp() }
            ModifierKeyMonitor.shared.onChord = { [weak self] _ in self?.handleChord() }
            ModifierKeyMonitor.shared.start(modifierKeys: modifiers)
        }

        bindKeyComboSlots(set.keyCombos)

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

    private func handleKeyDown() {
        holdWorkItem?.cancel()
        holdMode = false
        let press = chords.pressBegan()

        let holdToRecordEnabled = AppPreferences.shared.holdToRecord
        let doubleTapLock = AppPreferences.shared.doubleTapLock
        // Timed and cancelled here (not in the Task) so queue latency can't stretch the
        // gesture, and a deferred stop can't fire between this press and its handling.
        let now = Date()
        let awaitingSecondTap = pendingHoldStop != nil
        pendingHoldStop?.cancel()
        pendingHoldStop = nil

        Task { @MainActor in
            if self.activeVm == nil {
                // Already a chord (the key landed before this Task ran): never start.
                guard !self.chords.isChorded(press) else { return }
                guard UnlockRhino.shared.allowRecording() else { return }
                Diag.mark("keyDown → start recording")
                let cursorPosition = FocusUtils.getCurrentCursorPosition()
                let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier
                let needsCaret = FocusUtils.shouldAnchorToCaret(
                    indicatorPosition: AppPreferences.shared.indicatorPosition) && processID != nil
                // The first hosted frame needs the current app's icon, too.
                // Optional title metadata stays on RecordingContext's worker queue.
                RecordingContext.shared.captureFrontmost()
                let vm = Diag.measure("IndicatorWindowManager.show") {
                    IndicatorWindowManager.shared.show(nearPoint: cursorPosition, waitForCaret: needsCaret)
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
        guard let press = chords.chord() else { return }
        holdWorkItem?.cancel()
        holdWorkItem = nil
        Task { @MainActor in
            guard self.chords.chordDiscardsTake(
                press: press, takeLive: self.activeVm != nil, lockedOn: self.lockedOn) else { return }
            // Quietly: hide the bubble, transcribe and insert nothing.
            Diag.mark("trigger chord → discard take")
            self.stopActiveTake(discard: true)
        }
    }

    private func handleKeyUp() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        // A chorded press's release is not a tap: no stop, no lock, no deferred stop.
        if chords.releaseIgnored(chords.press) { return }

        let holdToRecordEnabled = AppPreferences.shared.holdToRecord
        let doubleTapLock = AppPreferences.shared.doubleTapLock
        let now = Date()

        Task { @MainActor in
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
        IndicatorWindowManager.shared.stopRecording(discard: discard)
        activeVm = nil
        holdMode = false
        takeStartedAt = nil
        chords.takeEnded()
    }
}
