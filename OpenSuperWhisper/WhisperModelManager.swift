import Combine
import Foundation

class WhisperDownloadDelegate: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    private let progressCallback: (Double) -> Void
    private var expectedContentLength: Int64 = 0
    var completionHandler: ((URL?, Error?) -> Void)?
    weak var downloadTask: URLSessionDownloadTask?
    
    init(progressCallback: @escaping (Double) -> Void) {
        self.progressCallback = progressCallback
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        completionHandler?(location, nil)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
      
        if expectedContentLength == 0 {
            expectedContentLength = totalBytesExpectedToWrite
        }
        let progress = Double(totalBytesWritten) / Double(expectedContentLength)
        
        DispatchQueue.main.async { [weak self] in
            self?.progressCallback(progress)
        }

    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completionHandler?(nil, error)
        } else {
        }
    }
}

class WhisperModelManager {
    static let shared = WhisperModelManager()
    
    private let modelsDirectoryName = "whisper-models"
    private var activeDownloadTasks: [String: URLSessionDownloadTask] = [:]
    private let downloadTasksLock = NSLock()
    
    var modelsDirectory: URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDirectory = applicationSupport.appendingPathComponent(Bundle.main.bundleIdentifier!).appendingPathComponent(modelsDirectoryName)
        return modelsDirectory
    }
    
    private init() {
        createModelsDirectoryIfNeeded()
    }
    
    private func createModelsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create models directory: \(error)")
        }
    }
    
    
    func getAvailableModels() -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "bin" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("Failed to get available models: \(error)")
            return []
        }
    }
    
    /// True when the file at `url` is plausibly a complete download: at least 95% of the
    /// catalog size (base-10 MB, matching how Hugging Face reports it). A truncated .bin
    /// passes every "does it exist" check and then fails on every dictation, so reject it
    /// here where the user can still just retry the download.
    private func isPlausiblyComplete(_ url: URL, expectedMB: Int?) -> Bool {
        guard let expectedMB else { return true }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attributes?[.size] as? Int64) ?? 0
        return bytes >= Int64(expectedMB) * 1_000_000 * 95 / 100
    }

    // Download model with progress callback using delegate
    func downloadModel(url: URL, name: String, expectedMB: Int? = nil, progressCallback: @escaping (Double) -> Void) async throws {
        let destinationURL = modelsDirectory.appendingPathComponent(name)

        // Check if model already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            if isPlausiblyComplete(destinationURL, expectedMB: expectedMB) {
                print("Model already exists at: \(destinationURL.path)")
                DispatchQueue.main.async {
                    progressCallback(1.0)
                }
                return
            }
            // A stale partial file would otherwise short-circuit every retry as "done".
            print("Removing incomplete model at: \(destinationURL.path)")
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        print("Starting model download:")
        print("- URL: \(url.absoluteString)")
        print("- Destination: \(destinationURL.path)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = WhisperDownloadDelegate(progressCallback: progressCallback)
            let configuration = URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForResource = 600 // 10 minutes timeout for large models
            
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: .main)
            print("Initiating download...")
            
            // Create a download task without completion handler
            let downloadTask = session.downloadTask(with: url)
            delegate.downloadTask = downloadTask
            
            // Store task for cancellation
            downloadTasksLock.lock()
            activeDownloadTasks[name] = downloadTask
            downloadTasksLock.unlock()
            
            // Add completion handling to delegate
            delegate.completionHandler = { [weak self] location, error in
                // Remove task from active downloads
                self?.downloadTasksLock.lock()
                self?.activeDownloadTasks.removeValue(forKey: name)
                self?.downloadTasksLock.unlock()
                
                // Check if cancelled
                if let error = error as? URLError, error.code == .cancelled {
                    print("Download cancelled")
                    continuation.resume(throwing: CancellationError())
                    return
                }
                
                if let error = error {
                    print("Download failed with error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let location = location else {
                    let error = NSError(domain: "WhisperModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No download URL received"])
                    continuation.resume(throwing: error)
                    return
                }
                
                do {
                    print("Download completed. Moving file to destination...")
                    try FileManager.default.moveItem(at: location, to: destinationURL)

                    // A dropped connection can deliver a truncated file as "complete";
                    // reject it now, while retrying is one click, instead of shipping a
                    // model that fails to load on every dictation.
                    guard self?.isPlausiblyComplete(destinationURL, expectedMB: expectedMB) ?? true else {
                        try? FileManager.default.removeItem(at: destinationURL)
                        continuation.resume(throwing: NSError(
                            domain: "WhisperModelManager", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "The download was incomplete — please try again."]))
                        return
                    }
                    print("Model successfully saved to: \(destinationURL.path)")

                    DispatchQueue.main.async {
                        progressCallback(1.0)
                    }

                    continuation.resume(returning: ())
                } catch {
                    print("Failed to move downloaded file: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            downloadTask.resume()
        }
    }
    
    // Cancel download task
    func cancelDownload(name: String) {
        downloadTasksLock.lock()
        defer { downloadTasksLock.unlock() }
        
        if let task = activeDownloadTasks[name] {
            task.cancel()
            activeDownloadTasks.removeValue(forKey: name)
            print("Cancelled download for: \(name)")
        }
    }
    
    // Check if specific model is downloaded
    func isModelDownloaded(name: String) -> Bool {
        let modelPath = modelsDirectory.appendingPathComponent(name).path
        return FileManager.default.fileExists(atPath: modelPath)
    }
}
