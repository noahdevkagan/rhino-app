import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

@MainActor
class FileDropHandler: ObservableObject {
    static let shared = FileDropHandler()
    
    @Published var isDragging = false
    
    private let transcriptionQueue: TranscriptionQueue
    
    private init() {
        self.transcriptionQueue = TranscriptionQueue.shared
    }
    
    func handleDrop(of providers: [NSItemProvider]) async {
        for provider in providers {
            if let type = [UTType.audio, .mpeg4Movie].first(where: {
                provider.hasItemConformingToTypeIdentifier($0.identifier)
            }) {
                do {
                    let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL?, Error>) in
                        provider.loadItem(forTypeIdentifier: type.identifier) { item, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                                return
                            }
                            continuation.resume(returning: item as? URL)
                        }
                    }
                    
                    guard let url = url, url.isFileURL else {
                        print("Error loading item: not a URL")
                        continue
                    }
                    
                    print("Adding to queue: \(url)")
                    await transcriptionQueue.addFileToQueue(url: url)
                    
                } catch {
                    print("Error loading dropped media file: \(error)")
                }
            }
        }
    }
}

struct FileDropOverlay: ViewModifier {
    @ObservedObject private var handler: FileDropHandler
    
    init() {
        self.handler = FileDropHandler.shared
    }
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if handler.isDragging {
                    ZStack {
                        Color(NSColor.windowBackgroundColor)
                            .opacity(0.95)
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.circle")
                                .scaledFont(size: 48)
                                .foregroundColor(.accentColor)
                                .symbolEffect(.bounce, value: handler.isDragging)
                            Text("Drop audio or MP4 files to transcribe")
                                .font(.headline)
                            Text("Multiple files will be queued")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            .onDrop(of: [.audio, .mpeg4Movie], isTargeted: $handler.isDragging) { providers in
                Task {
                    await handler.handleDrop(of: providers)
                }
                return true
            }
    }
}

extension View {
    func fileDropHandler() -> some View {
        modifier(FileDropOverlay())
    }
}
