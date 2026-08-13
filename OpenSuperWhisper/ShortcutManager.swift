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
    private var holdWorkItem: DispatchWorkItem?
    private let holdThreshold: TimeInterval = 0.3
    private var holdMode = false
    private var useModifierOnlyHotkey = false

    /// Hands-free lock: a second trigger press within this window of the first locks the
    /// recording on — release (and hold-release) no longer stops it; the next press does.
    /// Shorter than holdThreshold + a beat, so a double-tap can't be mistaken for a hold.
    private let doubleTapWindow: TimeInterval = 0.35
    private var lastTriggerDownAt: Date?
    private var lockedOn = false

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
                // requestCancel() discards immediately for short recordings, but a long
                // one arms a confirmation and returns false — leave activeVm set so the
                // next Esc (within the window) confirms the cancel.
                if self?.activeVm != nil, IndicatorWindowManager.shared.requestCancel() {
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

        let holdToRecordEnabled = AppPreferences.shared.holdToRecord
        // Second press of a quick double-tap. Timed here (not in the Task) so queue latency
        // can't stretch the gesture window.
        let now = Date()
        let isDoubleTap = AppPreferences.shared.doubleTapLock
            && lastTriggerDownAt.map { now.timeIntervalSince($0) < doubleTapWindow } ?? false
        lastTriggerDownAt = now

        Task { @MainActor in
            if self.activeVm == nil {
                Diag.mark("keyDown → start recording")
                let cursorPosition = FocusUtils.getCurrentCursorPosition()
                var caret: CGRect? = nil
                // Only "cursor" mode needs the caret; other positions anchor to
                // screen geometry, so skip the synchronous AX caret query (a
                // main-thread hang risk) when its result would be discarded.
                if FocusUtils.shouldAnchorToCaret(indicatorPosition: AppPreferences.shared.indicatorPosition) {
                    caret = Diag.measure("getCaretRect") { FocusUtils.getCaretRect() }
                }
                let indicatorPoint: NSPoint? = caret.map { FocusUtils.convertAXPointToCocoa($0.origin) } ?? cursorPosition
                let vm = Diag.measure("IndicatorWindowManager.show") {
                    IndicatorWindowManager.shared.show(nearPoint: indicatorPoint)
                }
                Diag.measure("vm.startRecording") { vm.startRecording() }
                self.activeVm = vm
                self.lockedOn = false
            } else if isDoubleTap && !self.lockedOn {
                // Hands-free: the double-tap's second press locks the recording on instead of
                // stopping it. Any later press (outside the window, or while locked) stops.
                self.lockedOn = true
            } else if !self.holdMode || self.lockedOn {
                IndicatorWindowManager.shared.stopRecording()
                self.activeVm = nil
                self.lockedOn = false
            }
        }

        // A locking press must not also arm push-to-talk: holding the second tap past the
        // threshold would otherwise flip to holdMode and its release would undo the lock.
        if holdToRecordEnabled && !isDoubleTap {
            let workItem = DispatchWorkItem { [weak self] in
                self?.holdMode = true
            }
            holdWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: workItem)
        }
    }
    
    private func handleKeyUp() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        
        let holdToRecordEnabled = AppPreferences.shared.holdToRecord
        
        Task { @MainActor in
            // Locked on (hands-free): releases never stop the recording; only a press does.
            if self.lockedOn { return }
            if holdToRecordEnabled && self.holdMode {
                IndicatorWindowManager.shared.stopRecording()
                self.activeVm = nil
                self.holdMode = false
            }
        }
    }
}
