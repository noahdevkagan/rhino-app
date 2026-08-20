import Foundation
import FluidAudio

/// Process-wide cache of loaded Parakeet CoreML model sets, one per version.
///
/// FluidAudio 0.15.4 has no in-process cache: every `AsrModels.downloadAndLoad`
/// builds fresh `MLModel` instances for the whole set (preprocessor, encoder,
/// decoder, joint). The live-preview and vocabulary-boosting paths called it per
/// dictation, and CoreML/ANE allocations return to the OS slowly — steady RSS
/// growth that reads as a memory leak (the "randomly crashes / memory leak"
/// user report). Managers stay per-use — they hold stream state — only the
/// expensive model set is shared; `loadModels(models)` on a fresh manager is
/// cheap reference wiring, and MLModel prediction is thread-safe.
///
/// Loads are deduplicated: concurrent callers for the same version await one
/// task. Failures are not cached. `evictAll()` frees the models when the user
/// switches away from the Parakeet engine, matching the old memory behavior.
actor ParakeetModelCache {
    static let shared = ParakeetModelCache()

    private var loads: [AsrModelVersion: Task<AsrModels, Error>] = [:]

    func models(for version: AsrModelVersion) async throws -> AsrModels {
        if let inFlight = loads[version] {
            return try await inFlight.value
        }
        let load = Task { try await AsrModels.downloadAndLoad(version: version) }
        loads[version] = load
        do {
            return try await load.value
        } catch {
            loads[version] = nil
            throw error
        }
    }

    func evictAll() {
        loads.removeAll()
    }
}
