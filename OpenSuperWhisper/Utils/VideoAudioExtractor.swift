import AVFoundation
import UniformTypeIdentifiers

/// Reads only the first audio track, in bounded chunks. No video decoding or network access.
enum VideoAudioExtractor {
    enum ExtractionError: LocalizedError {
        case noAudio, unreadableAudio, nonLocalFile

        var errorDescription: String? {
            switch self {
            case .nonLocalFile: return "Choose a video file stored on this Mac."
            case .noAudio: return "This video has no audio track."
            case .unreadableAudio: return "The video's audio could not be read."
            }
        }
    }

    /// Matches what the drop target accepts (.mp4, .m4v, …), not just the `mp4` extension.
    static func isVideo(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .mpeg4Movie) == true
    }

    /// The caller owns the returned temporary WAV and must remove it after use.
    static func extract(from source: URL) async throws -> URL {
        guard source.isFileURL else { throw ExtractionError.nonLocalFile }
        let worker = Task.detached(priority: .userInitiated) { () throws -> URL in
            try Task.checkCancellation()
            let asset = AVURLAsset(url: source)
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
                throw ExtractionError.noAudio
            }
            try Task.checkCancellation()
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("rhino-video-\(UUID().uuidString).wav")
            var succeeded = false
            defer {
                if !succeeded { try? FileManager.default.removeItem(at: destination) }
            }

            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                       sampleRate: 16_000, channels: 1, interleaved: false)!
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ])
            guard reader.canAdd(output) else { throw ExtractionError.unreadableAudio }
            reader.add(output)
            guard reader.startReading() else {
                throw reader.error ?? ExtractionError.unreadableAudio
            }
            defer { reader.cancelReading() }
            let file = try AVAudioFile(forWriting: destination, settings: format.settings)
            var frameCount: Int64 = 0
            while true {
                try Task.checkCancellation()
                let frames: Int = try autoreleasepool {
                    guard let sample = output.copyNextSampleBuffer() else { return 0 }
                    let count = CMSampleBufferGetNumSamples(sample)
                    guard count > 0,
                          let block = CMSampleBufferGetDataBuffer(sample),
                          let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                                       frameCapacity: AVAudioFrameCount(count)),
                          let data = buffer.floatChannelData?[0],
                          CMBlockBufferGetDataLength(block) == count * MemoryLayout<Float>.size else {
                        throw ExtractionError.unreadableAudio
                    }
                    buffer.frameLength = AVAudioFrameCount(count)
                    guard CMBlockBufferCopyDataBytes(block, atOffset: 0,
                        dataLength: count * MemoryLayout<Float>.size, destination: data) == kCMBlockBufferNoErr else {
                        throw ExtractionError.unreadableAudio
                    }
                    try file.write(from: buffer)
                    return count
                }
                if frames == 0 { break }
                frameCount += Int64(frames)
            }
            try Task.checkCancellation()
            guard reader.status == .completed, frameCount > 0 else {
                throw reader.error ?? ExtractionError.unreadableAudio
            }
            succeeded = true
            return destination
        }
        return try await withTaskCancellationHandler {
            let result = try await worker.value
            if Task.isCancelled {
                try? FileManager.default.removeItem(at: result)
                throw CancellationError()
            }
            return result
        } onCancel: {
            worker.cancel()
        }
    }
}
