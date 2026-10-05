import AudioToolbox
import Foundation

/// Decode local containers without AVAudioFile's exception-raising framePosition
/// getter. ExtAudioFile reports decode/resample failures as OSStatus values.
enum LocalAudioReader {
    static func samples(at url: URL) throws -> [Float] {
        guard url.isFileURL else { throw ReadError(operation: "open local file", status: OSStatus(paramErr)) }
        var opened: ExtAudioFileRef?
        try check(ExtAudioFileOpenURL(url as CFURL, &opened), operation: "open")
        guard let file = opened else { throw ReadError(operation: "open", status: OSStatus(paramErr)) }
        defer { ExtAudioFileDispose(file) }

        var format = AudioStreamBasicDescription(
            mSampleRate: 16_000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagsNativeFloatPacked,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
            mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        try check(ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat,
                                         UInt32(MemoryLayout.size(ofValue: format)), &format),
                  operation: "set transcription format")

        // Read to EOF rather than trusting container lengths or querying the
        // current frame position. Chunking also avoids allocating from corrupt metadata.
        var chunk = [Float](repeating: 0, count: 16_384)
        var samples: [Float] = []
        while true {
            try Task.checkCancellation()
            var frames = UInt32(chunk.count)
            let status = chunk.withUnsafeMutableBytes { bytes in
                var buffers = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
                    mNumberChannels: 1, mDataByteSize: UInt32(bytes.count), mData: bytes.baseAddress))
                return ExtAudioFileRead(file, &frames, &buffers)
            }
            try check(status, operation: "decode")
            if frames == 0 { break }
            samples.append(contentsOf: chunk.prefix(Int(frames)))
        }
        guard !samples.isEmpty else { throw ReadError(operation: "read empty audio", status: OSStatus(eofErr)) }
        return samples
    }

    private static func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else { throw ReadError(operation: operation, status: status) }
    }

    struct ReadError: LocalizedError {
        let operation: String
        let status: OSStatus

        var errorDescription: String? {
            "Could not read the audio file (\(operation), Core Audio error \(status))."
        }
    }
}
