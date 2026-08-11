import FluidAudio
import Foundation

/// One selectable dictation model across all engines. Used by the menu-bar model picker.
struct DictationModelOption: Codable, Equatable, Hashable {
    /// "whisper" | "fluidaudio" — matches AppPreferences.selectedEngine.
    let engine: String
    /// whisper: model file path; fluidaudio: version ("v2"/"v3").
    let identifier: String
    let displayName: String
}

/// Single source of truth for which models are actually usable right now
/// (downloaded locally) and for applying a selection.
enum ModelCatalog {
    /// Downloaded whisper.cpp model files.
    static func whisperModels() -> [DictationModelOption] {
        WhisperModelManager.shared.getAvailableModels().map { url in
            DictationModelOption(
                engine: "whisper",
                identifier: url.path,
                displayName: url.deletingPathExtension().lastPathComponent
            )
        }
    }

    /// Downloaded Parakeet (FluidAudio) model versions only — hide ones that
    /// aren't on disk, since the menu must never trigger a download.
    static func parakeetModels() -> [DictationModelOption] {
        SettingsFluidAudioModels.availableModels.compactMap { model in
            let version: AsrModelVersion = model.version == "v2" ? .v2 : .v3
            let cache = AsrModels.defaultCacheDirectory(for: version)
            guard AsrModels.modelsExist(at: cache, version: version) else { return nil }
            return DictationModelOption(
                engine: "fluidaudio",
                identifier: model.version,
                displayName: model.name
            )
        }
    }

    /// Every usable model across engines. Used to decide whether switching is
    /// even meaningful (one model → nothing to choose).
    static func allAvailable() -> [DictationModelOption] {
        whisperModels() + parakeetModels()
    }

    /// The model currently in effect (active engine + its selected model).
    static func activeOption() -> DictationModelOption? {
        let prefs = AppPreferences.shared
        switch prefs.selectedEngine {
        case "whisper":
            guard let path = prefs.selectedWhisperModelPath else { return nil }
            return DictationModelOption(
                engine: "whisper",
                identifier: path,
                displayName: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            )
        case "fluidaudio":
            return DictationModelOption(
                engine: "fluidaudio",
                identifier: prefs.fluidAudioModelVersion,
                displayName: prefs.fluidAudioModelVersion
            )
        default:
            return nil
        }
    }

    /// Switch the active engine + model, then invalidate the engine so the next
    /// recording re-initializes with the new choice. Mirrors the Settings UI.
    static func activate(_ option: DictationModelOption) {
        let prefs = AppPreferences.shared
        prefs.selectedEngine = option.engine
        switch option.engine {
        case "whisper":
            prefs.selectedWhisperModelPath = option.identifier
        case "fluidaudio":
            prefs.fluidAudioModelVersion = option.identifier
        default:
            break
        }
        // reloadEngine() is @MainActor-isolated on TranscriptionService.
        Task { @MainActor in
            TranscriptionService.shared.reloadEngine()
        }
        // AppPreferences is the source of truth for the active model; tell any open
        // Settings window to reflect this change (it caches its own @Published copies).
        NotificationCenter.default.post(name: .modelSelectionDidChange, object: nil)
    }
}
