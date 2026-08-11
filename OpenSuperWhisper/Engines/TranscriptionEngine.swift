import Foundation
import AVFoundation

protocol TranscriptionEngine: AnyObject {
    var isModelLoaded: Bool { get }
    var engineName: String { get }

    func initialize() async throws
    func transcribeAudio(url: URL, settings: Settings) async throws -> String
    func cancelTranscription()
    func getSupportedLanguages() -> [String]
}

/// Static engine capabilities keyed by the stored engine id (`AppPreferences.selectedEngine`),
/// so the UI can gate features without instantiating an engine.
enum EngineCapabilities {
    /// Engines that can translate to English. Whisper translates locally; Parakeet
    /// (fluidaudio) silently ignores `translateToEnglish` (#124).
    static let translationCapableEngines: Set<String> = ["whisper"]

    static func supportsTranslation(engine: String) -> Bool {
        translationCapableEngines.contains(engine)
    }

    /// Whisper can translate, but the turbo models cannot, whatever their documentation says.
    ///
    /// Measured on the same Czech clip: `ggml-small` returns English with `translate` set, while
    /// `ggml-large-v3-turbo-q5_0` returns the Czech unchanged, byte for byte identical to the
    /// untranslated run. Every Whisper model the setup screen offers is a turbo build, so a user
    /// who followed setup had no reachable configuration that could translate, and the toggle
    /// stayed enabled while doing nothing. Reported by a Czech user on 0.10.2.
    static func supportsTranslation(engine: String, modelPath: String?) -> Bool {
        guard supportsTranslation(engine: engine) else { return false }
        guard engine == "whisper", let modelPath else { return true }
        return !isTurboModel(modelPath)
    }

    static func isTurboModel(_ modelPath: String) -> Bool {
        (modelPath as NSString).lastPathComponent.lowercased().contains("turbo")
    }

    /// The language codes an engine+model can transcribe, in display order. The single source of
    /// truth for both the engines' `getSupportedLanguages()` and the language picker, so the UI can
    /// filter without instantiating an engine and the two can't drift (#155). Whisper uses the full
    /// Whisper set; "auto" (where present) means let the model detect the language.
    static func supportedLanguages(engine: String, fluidAudioModelVersion: String) -> [String] {
        switch engine {
        case "fluidaudio":
            return fluidAudioModelVersion == "v2"
                ? ["en"]
                : ["en", "de", "es", "fr", "it", "pt", "ru", "pl", "nl", "tr", "cs", "ar", "zh", "ja",
                   "hu", "fi", "hr", "sk", "sr", "sl", "uk", "ca", "da", "el", "bg"]
        default: // whisper — the full Whisper language set
            return LanguageUtil.availableLanguages
        }
    }
}

