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
    private var lastChimeAt: Date?
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
    
    private func createTemporaryDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create temporary recordings directory: \(error)")
        }
    }
    
    /// A fresh chime cuts off one already playing (`notificationSound` is the only strong
    /// reference), so a tap burst — hands-free double/triple taps restart the recording per
    /// tap — turns the chime into an audible stutter. One chime per burst is the feedback the
    /// user needs; within this window later requests are dropped. Longer than the 0.35s
    /// double-tap window so a triple tap still chimes once, and well under the gap to any
    /// deliberate next dictation.
    static let chimeDebounceInterval: TimeInterval = 0.75

    static func chimeShouldPlay(at now: Date, lastPlayedAt: Date?) -> Bool {
        guard let last = lastPlayedAt else { return true }
        return now.timeIntervalSince(last) >= chimeDebounceInterval
    }

    /// The short chime used to confirm a recording state change. Main thread only
    /// (`notificationSound` is main-confined alongside the playback state).
    func playNotificationSound() {
        let now = Date()
        guard Self.chimeShouldPlay(at: now, lastPlayedAt: lastChimeAt) else { return }
        lastChimeAt = now

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
        // Ground truth for "mic available" is the cached device, not the @Published
        // `canRecord` (that one is written on main for the UI — reading it here would race).
        let micAvailable = MicrophoneService.shared.getActiveMicrophone() != nil
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
            // Snapshot who is rendering audio NOW, before `.record()` can renegotiate a
            // Bluetooth headset and make other apps' output flicker (#32's invariant); the
            // pause itself hops to main, where MediaPlaybackController's state lives.
            let audioProcesses = MediaPlaybackController.audioProcesses()
            DispatchQueue.main.async { MediaPlaybackController.shared.pauseMedia(audioProcessesHint: audioProcesses) }
        }

        if AppPreferences.shared.playSoundOnRecordStart {
            DispatchQueue.main.async { self.playNotificationSound() }
        }

        // A UUID suffix keeps each recording's temp file unique. Without it, two recordings
        // started in the same wall-clock second share a path — and starting the next recording
        // would truncate the previous clip's file while the background pipeline is still reading
        // it to transcribe. (parallel-recording)
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "rec-\(timestamp)-\(UUID().uuidString.prefix(8)).wav"
        let fileURL = temporaryDirectory.appendingPathComponent(filename)
        currentRecordingURL = fileURL

        print("start record file to \(fileURL)")

        #if os(macOS)
        if let activeMic = MicrophoneService.shared.getActiveMicrophone() {
            Diag.measure("setAsSystemDefaultInput") {
                _ = MicrophoneService.shared.setAsSystemDefaultInput(activeMic)
            }
            print("Set system default input to: \(activeMic.displayName)")

            if let deviceID = MicrophoneService.shared.getCoreAudioDeviceID(for: activeMic) {
                recordingDeviceID = deviceID
            }
        }
        #endif

        let requiresConnection = Diag.measure("isActiveMicrophoneRequiresConnection") {
            MicrophoneService.shared.isActiveMicrophoneRequiresConnection()
        }
        updateRecordingState(isRecording: false, isConnecting: requiresConnection)
        startRecordingWithRecorder(fileURL: fileURL, monitorConnection: requiresConnection)
    }

    /// Runs on `stateQueue`.
    private func startRecordingWithRecorder(fileURL: URL, monitorConnection: Bool) {
        var channelCount = 1
        if let activeMic = MicrophoneService.shared.getActiveMicrophone() {
            channelCount = MicrophoneService.shared.getInputChannelCount(for: activeMic)
            print("Recording with \(channelCount) input channel(s) from \(activeMic.displayName)")
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true
        ]
        
        do {
            primedRecorder = nil  // release primed recorder just before starting; hardware stays warm
            try Diag.measure("AVAudioRecorder init+record") {
                audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
                audioRecorder?.delegate = self
                audioRecorder?.isMeteringEnabled = monitorConnection
                audioRecorder?.record()
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
    
    private func startConnectionMonitoring() {
        stopConnectionMonitoring()
        
        // The handler reads `audioRecorder`/`currentRecordingURL`, so it must share their queue.
        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now() + 0.05, repeating: 0.05)
        let initialFileSize: Int64 = 4096
        var growthCount = 0
        
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
            }
        }
        connectionCheckTimer = timer
        timer.resume()
    }
    
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
