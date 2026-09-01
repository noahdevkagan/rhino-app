import AVFoundation
import Foundation
import SwiftUI
import AppKit
import CoreAudio

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentlyPlayingURL: URL?
    @Published var canRecord = false
    @Published var isConnecting = false
    
    // All capture state lives on `stateQueue` — start used to run on a detached task while
    // stop ran on main, racing on these ARC references (orphaned hot mic on a fast
    // press-release, and UB from unsynchronized retain/release). `startRecording()` enqueues
    // async so the hotkey path never blocks (#freeze); `stopRecording()`/`cancelRecording()`
    // run queue-sync so a stop is always ordered after the start it belongs to.
    private let stateQueue = DispatchQueue(label: "com.noahkagan.rhino.audio-recorder", qos: .userInitiated)
    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var connectionCheckTimer: DispatchSourceTimer?
    private var recordingDeviceID: AudioDeviceID?
    // Keeps audio hardware warm so the first word is never cut off
    private var primedRecorder: AVAudioRecorder?

    // Playback state — main-thread only (driven by the history list UI).
    private var audioPlayer: AVAudioPlayer?
    private var notificationSound: NSSound?
    private let temporaryDirectory: URL
    private var notificationObserver: Any?
    private var microphoneChangeObserver: Any?

    // MARK: - Singleton Instance

    static let shared = AudioRecorder()
    
    override private init() {
        let tempDir = FileManager.default.temporaryDirectory
        temporaryDirectory = tempDir.appendingPathComponent("temp_recordings")
        
        super.init()
        createTemporaryDirectoryIfNeeded()
        setup()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = microphoneChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setup() {
        updateCanRecordStatus()
        stateQueue.async { [weak self] in self?.primeAudioHardware() }

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateCanRecordStatus()
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateCanRecordStatus()
        }
        
        microphoneChangeObserver = NotificationCenter.default.addObserver(
            forName: .microphoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateCanRecordStatus()
        }
    }
    
    private func updateCanRecordStatus() {
        canRecord = MicrophoneService.shared.getActiveMicrophone() != nil
    }

    /// Pre-warms the audio hardware by creating a prepared (but not recording) AVAudioRecorder.
    /// Keeping `primedRecorder` alive holds the audio engine in an initialized state,
    /// eliminating the cold-start delay when the user triggers the first real recording.
    /// Runs on `stateQueue`.
    private func primeAudioHardware() {
        let primedURL = temporaryDirectory.appendingPathComponent("primed.wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true
        ]
        primedRecorder = try? AVAudioRecorder(url: primedURL, settings: settings)
        primedRecorder?.prepareToRecord()
    }
    
    /// A UUID suffix keeps each recording's temp file unique. Without it, two recordings
    /// started in the same wall-clock second share a path — and starting the next recording
    /// would truncate the previous clip's file while the background pipeline is still reading
    /// it to transcribe. (parallel-recording)
    static func makeRecordingFilename() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "rec-\(timestamp)-\(UUID().uuidString.prefix(8)).wav"
    }

    private func createTemporaryDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create temporary recordings directory: \(error)")
        }
    }
    
    /// The short chime used to confirm a recording state change. Main thread only
    /// (`notificationSound` is main-confined alongside the playback state).
    func playNotificationSound() {
        // Try to play using NSSound first
        guard let soundURL = Bundle.main.url(forResource: "notification", withExtension: "mp3") else {
            print("Failed to find notification sound file")
            // Fall back to system sound if notification.mp3 is not found
            NSSound.beep()
            return
        }
        
        if let sound = NSSound(contentsOf: soundURL, byReference: false) {
            // Set maximum volume to ensure it's audible
            sound.volume = 0.3
            sound.play()
            notificationSound = sound
        } else {
            print("Failed to create NSSound from URL, falling back to system beep")
            // Fall back to system beep if NSSound creation fails
            NSSound.beep()
        }
    }
    
    /// Safe to call from any thread; returns immediately. The real work runs on `stateQueue`
    /// so the hotkey tap on the main thread never waits on AVFoundation/CoreAudio (#freeze).
    func startRecording() {
        stateQueue.async { [weak self] in self?.performStartRecording() }
    }

    private func performStartRecording() {
        // Ground truth for "mic available" is CoreAudio, not the cached device (nor the
        // @Published `canRecord`, which is written on main for the UI — reading it here
        // would race). After a headset drops off (AirPods into their case), the cache can
        // still hold the dead device until the disconnect notifications land; trusting it
        // used to point the system default input at a ghost and leave every subsequent
        // dictation stuck "connecting" until the app was restarted.
        let cachedMic = MicrophoneService.shared.getActiveMicrophone()
        var activeMic = cachedMic
        #if os(macOS)
        var activeDeviceID = cachedMic.flatMap { MicrophoneService.shared.getCoreAudioDeviceID(for: $0) }
        if cachedMic != nil, activeDeviceID == nil {
            print("Cached microphone is no longer present; falling back to the system default input")
            activeMic = nil
            // Recompute the published device state so the picker and canRecord recover too.
            DispatchQueue.main.async { MicrophoneService.shared.handleDevicesChanged() }
        }
        if activeMic == nil {
            activeDeviceID = MicrophoneService.shared.getCurrentSystemDefaultInputDevice()
                ?? MicrophoneService.shared.builtInInputDeviceID()
        }
        let micAvailable = activeDeviceID != nil
        #else
        let micAvailable = activeMic != nil
        #endif
        Diag.mark("recorder.startRecording (canRecord=\(micAvailable))")
        guard micAvailable else {
            print("Cannot start recording - no audio input available")
            return
        }

        if audioRecorder != nil || connectionCheckTimer != nil {
            print("stop recording while recording")
            _ = performStopRecording()
        }

        if AppPreferences.shared.pauseMediaOnRecord {
            // Sample the output probe NOW, before `.record()` or the chime can make sound or
            // disturb the output device (#32's invariant); the pause itself hops to main,
            // where MediaPlaybackController's poll timer and callbacks live.
            let outputActive = MediaPlaybackController.isSystemOutputActive()
            DispatchQueue.main.async { MediaPlaybackController.shared.pauseMedia(outputActiveHint: outputActive) }
        }

        if AppPreferences.shared.playSoundOnRecordStart {
            DispatchQueue.main.async { self.playNotificationSound() }
        }

        let fileURL = temporaryDirectory.appendingPathComponent(Self.makeRecordingFilename())
        currentRecordingURL = fileURL

        print("start record file to \(fileURL)")

        #if os(macOS)
        if let activeMic {
            Diag.measure("setAsSystemDefaultInput") {
                _ = MicrophoneService.shared.setAsSystemDefaultInput(activeMic)
            }
            print("Set system default input to: \(activeMic.displayName)")
        }
        recordingDeviceID = activeDeviceID
        #endif

        // When the cached device was stale, the fallback is the live system input — asking
        // "does the active microphone require connection?" would describe the dead device
        // and send us into the bluetooth warm-up path for a mic that no longer exists.
        let requiresConnection: Bool
        if activeMic != nil {
            requiresConnection = Diag.measure("isActiveMicrophoneRequiresConnection") {
                MicrophoneService.shared.isActiveMicrophoneRequiresConnection()
            }
        } else {
            requiresConnection = false
        }
        updateRecordingState(isRecording: false, isConnecting: requiresConnection)
        startRecordingWithRecorder(fileURL: fileURL, monitorConnection: requiresConnection)
    }

    /// Runs on `stateQueue`.
    private func startRecordingWithRecorder(fileURL: URL, monitorConnection: Bool) {
        // Channel count comes from the device we validated in performStartRecording, not
        // from the cached AudioDevice (which can describe a mic that just disconnected).
        var channelCount = 1
        #if os(macOS)
        if let deviceID = recordingDeviceID {
            channelCount = max(MicrophoneService.shared.inputChannelCount(deviceID: deviceID), 1)
            print("Recording with \(channelCount) input channel(s)")
        }
        #endif

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true
        ]

        do {
            primedRecorder = nil  // release primed recorder just before starting; hardware stays warm
            let started = try Diag.measure("AVAudioRecorder init+record") { () -> Bool in
                audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
                audioRecorder?.delegate = self
                audioRecorder?.isMeteringEnabled = monitorConnection
                return audioRecorder?.record() ?? false
            }
            guard started else {
                print("Failed to start recording: record() returned false")
                audioRecorder = nil
                try? FileManager.default.removeItem(at: fileURL)
                currentRecordingURL = nil
                updateRecordingState(isRecording: false, isConnecting: false)
                return
            }
            Task { @MainActor in SpectrumAnalyzer.shared.start() }
            if monitorConnection {
                startConnectionMonitoring()
            } else {
                updateRecordingState(isRecording: true, isConnecting: false)
            }
            print("Recording started successfully")
        } catch {
            print("Failed to start recording: \(error)")
            audioRecorder = nil
            currentRecordingURL = nil
            updateRecordingState(isRecording: false, isConnecting: false)
        }
    }
    
    /// Blocks briefly: runs after any in-flight start on `stateQueue`, so a fast press-release
    /// can never leave the recorder started with nobody to stop it (orphaned hot mic).
    func stopRecording() -> URL? {
        stateQueue.sync { performStopRecording() }
    }

    private func performStopRecording() -> URL? {
        // Capture the elapsed time BEFORE stop() (currentTime only reports while recording):
        // it's the clip duration, without re-opening the just-written file to ask.
        let recordedDuration = audioRecorder?.currentTime
        audioRecorder?.stop()
        audioRecorder = nil
        updateRecordingState(isRecording: false, isConnecting: false)
        Task { @MainActor in SpectrumAnalyzer.shared.stop() }
        stopConnectionMonitoring()
        stateQueue.async { [weak self] in
            self?.primeAudioHardware()  // re-prime so the next recording starts instantly too
        }

        if AppPreferences.shared.pauseMediaOnRecord {
            DispatchQueue.main.async { MediaPlaybackController.shared.resumeMedia() }
        }

        if let url = currentRecordingURL,
           Self.shouldDiscardRecording(duration: recordedDuration)
        {
            try? FileManager.default.removeItem(at: url)
            currentRecordingURL = nil
            return nil
        }
        
        let url = currentRecordingURL
        currentRecordingURL = nil
        return url
    }

    /// A missing or non-finite recorder duration cannot describe usable audio. Zero is a real
    /// sub-second duration too — do not send an empty header-only WAV through transcription.
    static func shouldDiscardRecording(duration: TimeInterval?) -> Bool {
        guard let duration, duration.isFinite else { return true }
        return duration < 1.0
    }
    
    /// Queue-sync like `stopRecording()` for the same reason: a cancel must always land
    /// after the start it is cancelling.
    func cancelRecording() {
        stateQueue.sync { performCancelRecording() }
    }

    private func performCancelRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        updateRecordingState(isRecording: false, isConnecting: false)
        Task { @MainActor in SpectrumAnalyzer.shared.stop() }
        stopConnectionMonitoring()

        if AppPreferences.shared.pauseMediaOnRecord {
            DispatchQueue.main.async { MediaPlaybackController.shared.resumeMedia() }
        }

        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
    }
    
    
    func moveTemporaryRecording(from tempURL: URL, to finalURL: URL) throws {

        let directory = finalURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        if FileManager.default.fileExists(atPath: finalURL.path) {
            try FileManager.default.removeItem(at: finalURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: finalURL)
    }
    
    func playRecording(url: URL) {
        // Stop current playback if any
        stopPlaying()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
            currentlyPlayingURL = url
        } catch {
            print("Failed to play recording: \(error), url: \(url)")
            isPlaying = false
            currentlyPlayingURL = nil
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentlyPlayingURL = nil
    }
    
    private func updateRecordingState(isRecording: Bool, isConnecting: Bool) {
        DispatchQueue.main.async {
            self.isRecording = isRecording
            self.isConnecting = isConnecting
        }
    }
    
    /// How long the bluetooth/continuity warm-up may sit with no audio before the input is
    /// declared dead (50ms ticks). A live AirPods link starts delivering in well under 2s;
    /// without this bound a mic that disconnected between dictations left the app stuck in
    /// "connecting" until it was restarted.
    private static let connectionTimeoutTicks = 80  // 4 seconds

    private func startConnectionMonitoring() {
        stopConnectionMonitoring()

        // The handler reads `audioRecorder`/`currentRecordingURL`, so it must share their queue.
        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now() + 0.05, repeating: 0.05)
        let initialFileSize: Int64 = 4096
        var growthCount = 0
        var elapsedTicks = 0

        timer.setEventHandler { [weak self] in
            guard let self = self, let _ = self.audioRecorder, let url = self.currentRecordingURL else { return }

            let currentFileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            let totalGrowth = currentFileSize - initialFileSize

            if totalGrowth > 8000 {
                growthCount += 1
            }

            if growthCount >= 2 {
                self.stopConnectionMonitoring()
                self.updateRecordingState(isRecording: true, isConnecting: false)
                return
            }

            elapsedTicks += 1
            if elapsedTicks >= Self.connectionTimeoutTicks {
                self.stopConnectionMonitoring()
                #if os(macOS)
                self.recoverFromDeadInput(deadFileURL: url)
                #else
                self.updateRecordingState(isRecording: false, isConnecting: false)
                #endif
            }
        }
        connectionCheckTimer = timer
        timer.resume()
    }

    #if os(macOS)
    /// Pure decision for recovering from an input that delivered no audio: which device to
    /// re-record from, and whether the system default input must be repointed at it first
    /// (AVAudioRecorder always captures from the system default, and the app itself may
    /// have pointed that default at the now-dead device). nil = nothing live to fall back to.
    static func fallbackInput(systemDefault: AudioDeviceID?, builtIn: AudioDeviceID?, failed: AudioDeviceID?)
        -> (deviceID: AudioDeviceID, mustSetSystemDefault: Bool)?
    {
        if let systemDefault, systemDefault != failed {
            return (systemDefault, false)
        }
        if let builtIn, builtIn != failed {
            return (builtIn, true)
        }
        return nil
    }

    /// Runs on `stateQueue`. The chosen input produced no audio for the whole connection
    /// window — typical when a bluetooth mic dropped off between dictations and the cache
    /// (or the system default input) still pointed at it. Tear the dead recorder down and
    /// restart on a live input instead of sitting in "connecting" until an app restart.
    private func recoverFromDeadInput(deadFileURL: URL) {
        print("No audio from input after \(Self.connectionTimeoutTicks / 20)s; falling back to a live input")
        audioRecorder?.stop()
        audioRecorder = nil
        try? FileManager.default.removeItem(at: deadFileURL)
        currentRecordingURL = nil

        // Recompute the published device state so the picker and canRecord recover too.
        DispatchQueue.main.async { MicrophoneService.shared.handleDevicesChanged() }

        let fallback = Self.fallbackInput(
            systemDefault: MicrophoneService.shared.getCurrentSystemDefaultInputDevice(),
            builtIn: MicrophoneService.shared.builtInInputDeviceID(),
            failed: recordingDeviceID
        )
        guard let fallback else {
            print("No live audio input to fall back to")
            updateRecordingState(isRecording: false, isConnecting: false)
            return
        }
        if fallback.mustSetSystemDefault {
            _ = MicrophoneService.shared.setSystemDefaultInput(deviceID: fallback.deviceID)
        }
        recordingDeviceID = fallback.deviceID

        // Fresh file, and no connection monitoring: the fallback is the live system input,
        // so a second silent run here means recording genuinely can't proceed.
        let fileURL = temporaryDirectory.appendingPathComponent(Self.makeRecordingFilename())
        currentRecordingURL = fileURL
        startRecordingWithRecorder(fileURL: fileURL, monitorConnection: false)
    }
    #endif
    
    private func stopConnectionMonitoring() {
        connectionCheckTimer?.cancel()
        connectionCheckTimer = nil
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Delivered on AVFoundation's own thread; a stale callback (recorder already replaced
        // or stopped) must not clear the URL of the recording that superseded it.
        stateQueue.async { [weak self] in
            guard let self, recorder === self.audioRecorder else { return }
            if !flag {
                self.currentRecordingURL = nil
            }
        }
    }
}

extension AudioRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentlyPlayingURL = nil
    }
}
