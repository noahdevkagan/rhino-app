import XCTest

@testable import OpenSuperWhisper

/// The model step's footer button is the one-click download while no model is on this Mac.
/// These pin which model it targets and that a failed or cancelled attempt leaves it ready
/// to press again. (The download itself is never started here: it is click-only and network.)
@MainActor
final class OnboardingOneClickSetupTests: XCTestCase {

    private func makeViewModel(downloaded: Set<Int> = []) -> OnboardingViewModel {
        let viewModel = OnboardingViewModel()
        var models = [
            OnboardingUnifiedModel(name: "Whisper", isDownloaded: false, description: "",
                                   type: .whisper(url: URL(string: "https://example.invalid/m.bin")!,
                                                  size: 1624)),
            OnboardingUnifiedModel(name: "Parakeet", isDownloaded: false, description: "",
                                   type: .parakeet(version: "v2"), isRecommended: true),
        ]
        for i in downloaded { models[i].isDownloaded = true }
        viewModel.selectedModelId = nil
        viewModel.unifiedModels = models
        return viewModel
    }

    func testTargetsTheRecommendedModelWhenNothingIsSelected() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.needsDownloadAction)
        XCTAssertEqual(viewModel.primaryDownloadTarget?.name, "Parakeet")
    }

    func testTargetsTheSelectedModelWhenItIsNotDownloaded() {
        let viewModel = makeViewModel()
        viewModel.selectedModelId = viewModel.unifiedModels[0].id
        XCTAssertEqual(viewModel.primaryDownloadTarget?.name, "Whisper")
    }

    func testPlainFinishOnceAModelIsDownloaded() {
        let viewModel = makeViewModel(downloaded: [1])
        XCTAssertFalse(viewModel.needsDownloadAction)
    }

    func testSelectedButAlreadyDownloadedIsNeverTheTarget() {
        let viewModel = makeViewModel(downloaded: [1])
        viewModel.selectedModelId = viewModel.unifiedModels[1].id
        XCTAssertEqual(viewModel.primaryDownloadTarget?.name, "Whisper")
    }

    func testFailedDownloadReturnsTheButtonToItsReadyState() {
        let viewModel = makeViewModel()
        let target = viewModel.primaryDownloadTarget!
        viewModel.isDownloading = true
        viewModel.downloadingModelName = target.name
        viewModel.downloadProgress = 0.4
        viewModel.downloadPhaseText = "Loading model…"
        viewModel.unifiedModels[1].downloadProgress = 0.4

        viewModel.resetDownloadState(for: target.id)

        XCTAssertFalse(viewModel.isDownloading)
        XCTAssertNil(viewModel.downloadingModelName)
        XCTAssertEqual(viewModel.downloadProgress, 0)
        XCTAssertNil(viewModel.downloadPhaseText)
        XCTAssertEqual(viewModel.unifiedModels[1].downloadProgress, 0)
        // Ready for a retry, and Finish stays unreachable: nothing is downloaded or selected.
        XCTAssertTrue(viewModel.needsDownloadAction)
        XCTAssertEqual(viewModel.primaryDownloadTarget?.name, "Parakeet")
        XCTAssertFalse(viewModel.canContinue)
    }

    func testSizeLabel() {
        let viewModel = makeViewModel()
        XCTAssertEqual(OnboardingViewModel.sizeLabel(for: viewModel.unifiedModels[0]), "1.6 GB")
        XCTAssertNil(OnboardingViewModel.sizeLabel(for: viewModel.unifiedModels[1]))
    }
}
