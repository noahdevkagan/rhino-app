import Foundation
import FluidAudio

/// Process-wide cache of one loaded Parakeet CoreML model set.
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
/// task. Failures are not cached. At most one version stays resident — asking
/// for the other one (the v2/v3 picker, a one-off rerun) drops the previous
/// set instead of pinning both. `evictAll()` frees it entirely when the user
/// switches away from the Parakeet engine, matching the old memory behavior.
/// Either way a set already handed to a running manager lives until that
/// manager is released; only the cache's own reference goes away.
actor ParakeetModelCache {
    static let shared = ParakeetModelCache()

    private var loads: [AsrModelVersion: Task<AsrModels, Error>] = [:]

    func models(for version: AsrModelVersion) async throws -> AsrModels {
        // Keep at most one version resident: switching v2↔v3 would otherwise pin both
        // full CoreML sets (~460MB each) for the life of the process, since the engine
        // stays "fluidaudio" and nothing calls evictAll().
        loads = loads.filter { $0.key == version }
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
