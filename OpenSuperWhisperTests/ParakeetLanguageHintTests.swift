import FluidAudio
import XCTest

@testable import OpenSuperWhisper

/// The Parakeet v3 multilingual decoder auto-detects language per chunk, and unhinted it can
/// drift into the wrong script mid-dictation — reported as German dictations coming back in
/// Russian. The engine now passes FluidAudio's script-filter language hint derived from the
/// selected dictation language, and runs v3 with `melChunkContext` off (upstream #594: the
/// mel prepend pushes the v3 decoder back to its English-biased prior). These tests pin the
/// language-code mapping and the per-version config split.
final class ParakeetLanguageHintTests: XCTestCase {

    func testSelectedLanguageMapsToScriptFilterHint() {
        XCTAssertEqual(FluidAudioEngine.languageHint(for: "de"), .german)
        XCTAssertEqual(FluidAudioEngine.languageHint(for: "ru"), .russian)
        XCTAssertEqual(FluidAudioEngine.languageHint(for: "en"), .english)
        XCTAssertEqual(FluidAudioEngine.languageHint(for: "pl"), .polish)
    }

    func testAutoDetectAndUncoveredLanguagesGetNoHint() {
        // "auto" must keep the decoder unconstrained, and languages the script filter
        // doesn't cover (Turkish, Arabic, Chinese, Japanese, Catalan are offered for v3)
        // must degrade to no filtering rather than a wrong hint.
        XCTAssertNil(FluidAudioEngine.languageHint(for: "auto"))
        for code in ["tr", "ar", "zh", "ja", "ca"] {
            XCTAssertNil(FluidAudioEngine.languageHint(for: code), code)
        }
    }

    func testEveryFilterableV3LanguageProducesAHint() {
        // Each v3 picker language that FluidAudio's filter knows must map, so no user with a
        // covered language selected is left on unhinted auto-detection.
        let v3Languages = EngineCapabilities.supportedLanguages(
            engine: "fluidaudio", fluidAudioModelVersion: "v3")
        let filterable = Set(Language.allCases.map(\.rawValue))
        for code in v3Languages where filterable.contains(code) {
            XCTAssertNotNil(FluidAudioEngine.languageHint(for: code), code)
        }
    }

    func testV3ConfigDisablesMelChunkContext() {
        XCTAssertFalse(FluidAudioEngine.asrConfig(for: .v3).melChunkContext)
        // v2 is English-only; the mel prepend is its fix for all-blank chunk boundaries and
        // must stay on.
        XCTAssertTrue(FluidAudioEngine.asrConfig(for: .v2).melChunkContext)
    }
}
